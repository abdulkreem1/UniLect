"""Authentication, sessions, logout, refresh rotation, password flows (FR-002..005, FR-014, FR-080)."""

import re

import pytest
from django.core import mail
from rest_framework.test import APIClient

from apps.accounts import throttling
from apps.accounts.models import AuthSession
from apps.audit.models import AuditLog
from conftest import api_login, authenticate, new_installation_id
from tests.factories import DEFAULT_PASSWORD, AdminFactory, LibraryUserFactory, StudentFactory

pytestmark = pytest.mark.django_db

ME = "/api/v1/me/"


def error_code(response) -> str:
    return response.json()["error"]["code"]


class TestLogin:
    def test_admin_login_returns_tokens_and_user(self, api_client):
        admin = AdminFactory()
        response = api_login(api_client, admin)
        assert response.status_code == 200
        body = response.json()
        assert {"access", "refresh", "access_expires_in", "user"} <= body.keys()
        assert body["user"]["role"] == "admin"
        assert "password" not in body["user"]
        assert AuthSession.objects.filter(user=admin, revoked_at__isnull=True).count() == 1

    def test_email_is_case_insensitive(self, api_client):
        admin = AdminFactory(email="boss@example.com")
        response = api_client.post(
            "/api/v1/auth/login/", {"email": "BOSS@Example.com", "password": DEFAULT_PASSWORD}, format="json"
        )
        assert response.status_code == 200
        assert response.json()["user"]["id"] == str(admin.pk)

    def test_wrong_password_and_unknown_email_are_indistinguishable(self, api_client):
        AdminFactory(email="known@example.com")
        wrong = api_client.post("/api/v1/auth/login/", {"email": "known@example.com", "password": "nope"})
        unknown = api_client.post("/api/v1/auth/login/", {"email": "ghost@example.com", "password": "nope"})
        assert wrong.status_code == unknown.status_code == 401
        assert wrong.json() == unknown.json()
        assert error_code(wrong) == "invalid_credentials"

    def test_password_not_leaked_in_audit_or_response(self, api_client):
        admin = AdminFactory()
        api_login(api_client, admin)
        for log in AuditLog.objects.all():
            assert DEFAULT_PASSWORD not in str(log.metadata)

    def test_disabled_account_cannot_login(self, api_client):
        user = AdminFactory(is_active=False)
        response = api_login(api_client, user)
        assert response.status_code == 403
        assert error_code(response) == "account_disabled"

    def test_inactive_library_blocks_library_staff_login(self, api_client):
        user = LibraryUserFactory(library__is_active=False)
        response = api_login(api_client, user)
        assert response.status_code == 403
        assert error_code(response) == "account_disabled"

    def test_student_login_by_student_number(self, api_client):
        student = StudentFactory(student_number="2024-77")
        response = api_client.post(
            "/api/v1/auth/login/",
            {
                "student_number": "2024-77",
                "university": student.university_id,
                "password": DEFAULT_PASSWORD,
                "device": {"installation_id": new_installation_id(), "platform": "ios"},
            },
            format="json",
        )
        assert response.status_code == 200

    def test_must_send_exactly_one_identifier(self, api_client):
        response = api_client.post("/api/v1/auth/login/", {"password": "x"}, format="json")
        assert response.status_code == 400
        assert error_code(response) == "validation_error"

    def test_student_without_device_info_rejected(self, api_client):
        student = StudentFactory()
        response = api_login(api_client, student)
        assert response.status_code == 400
        assert error_code(response) == "device_info_required"

    def test_malformed_installation_id_rejected(self, api_client):
        student = StudentFactory()
        response = api_client.post(
            "/api/v1/auth/login/",
            {
                "email": student.email,
                "password": DEFAULT_PASSWORD,
                "device": {"installation_id": "x", "platform": "ios"},
            },
            format="json",
        )
        assert response.status_code == 400

    def test_failed_attempts_lock_identifier(self, api_client):
        admin = AdminFactory()
        for _ in range(throttling.MAX_FAILURES_PER_SOURCE):
            assert api_login(api_client, admin, password="wrong-password").status_code == 401
        locked = api_login(api_client, admin)  # even the right password is refused while locked
        assert locked.status_code == 429
        assert error_code(locked) == "too_many_failed_attempts"

    def test_successful_login_resets_failure_counter(self, api_client):
        admin = AdminFactory()
        for _ in range(throttling.MAX_FAILURES_PER_SOURCE - 1):
            api_login(api_client, admin, password="wrong-password")
        assert api_login(api_client, admin).status_code == 200
        assert api_login(api_client, admin, password="wrong-password").status_code == 401
        assert api_login(api_client, admin).status_code == 200


class TestProtectedAccess:
    def test_anonymous_rejected(self, api_client):
        response = api_client.get(ME)
        assert response.status_code == 401
        assert error_code(response) == "not_authenticated"

    def test_garbage_token_rejected(self, api_client):
        api_client.credentials(HTTP_AUTHORIZATION="Bearer not-a-jwt")
        response = api_client.get(ME)
        assert response.status_code == 401
        assert error_code(response) == "token_not_valid"

    def test_refresh_token_cannot_be_used_as_access(self, api_client):
        tokens = authenticate(api_client, AdminFactory())
        api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['refresh']}")
        assert api_client.get(ME).status_code == 401

    def test_deactivation_invalidates_existing_tokens(self, admin_client, admin_user):
        other = AdminFactory()
        other_client = APIClient()
        authenticate(other_client, other)
        assert other_client.get(ME).status_code == 200
        admin_client.post(f"/api/v1/admin/users/{other.pk}/deactivate/")
        response = other_client.get(ME)
        assert response.status_code == 401


class TestLogout:
    def test_logout_revokes_access_and_refresh(self, api_client):
        tokens = authenticate(api_client, AdminFactory())
        assert api_client.post("/api/v1/auth/logout/").status_code == 204
        response = api_client.get(ME)
        assert response.status_code == 401
        assert error_code(response) == "session_revoked"
        refresh = APIClient().post("/api/v1/auth/refresh/", {"refresh": tokens["refresh"]}, format="json")
        assert refresh.status_code == 401

    def test_logout_only_ends_current_session(self):
        admin = AdminFactory()
        first, second = APIClient(), APIClient()
        authenticate(first, admin)
        authenticate(second, admin)
        first.post("/api/v1/auth/logout/")
        assert second.get(ME).status_code == 200


class TestRefresh:
    def test_rotation_issues_new_pair(self, api_client):
        tokens = authenticate(api_client, AdminFactory())
        response = APIClient().post("/api/v1/auth/refresh/", {"refresh": tokens["refresh"]}, format="json")
        assert response.status_code == 200
        assert response.json()["refresh"] != tokens["refresh"]

    def test_reusing_rotated_refresh_token_revokes_session(self, api_client):
        tokens = authenticate(api_client, AdminFactory())
        client = APIClient()
        new = client.post("/api/v1/auth/refresh/", {"refresh": tokens["refresh"]}, format="json").json()
        replay = client.post("/api/v1/auth/refresh/", {"refresh": tokens["refresh"]}, format="json")
        assert replay.status_code == 401
        # The legitimate holder's new tokens are now dead too (theft containment).
        assert (
            client.post("/api/v1/auth/refresh/", {"refresh": new["refresh"]}, format="json").status_code
            == 401
        )
        assert api_client.get(ME).status_code == 401
        assert AuditLog.objects.filter(action="auth.refresh_reuse").exists()

    def test_student_refresh_requires_bound_device_header(self):
        student = StudentFactory()
        client = APIClient()
        tokens = authenticate(client, student)
        stranger = APIClient()
        stranger.credentials(HTTP_X_DEVICE_ID=new_installation_id())
        response = stranger.post("/api/v1/auth/refresh/", {"refresh": tokens["refresh"]}, format="json")
        assert response.status_code == 403
        assert error_code(response) == "device_mismatch"
        owner = APIClient()
        owner.credentials(HTTP_X_DEVICE_ID=tokens["installation_id"])
        assert (
            owner.post("/api/v1/auth/refresh/", {"refresh": tokens["refresh"]}, format="json").status_code
            == 200
        )


class TestPasswordFlows:
    def test_change_password_keeps_current_session_and_revokes_others(self):
        admin = AdminFactory()
        current, other = APIClient(), APIClient()
        authenticate(current, admin)
        authenticate(other, admin)
        response = current.post(
            "/api/v1/auth/password/change/",
            {"current_password": DEFAULT_PASSWORD, "new_password": "Brand-New-Secret-42"},
            format="json",
        )
        assert response.status_code == 204
        assert current.get(ME).status_code == 200
        assert other.get(ME).status_code == 401

    def test_change_password_wrong_current(self, admin_client):
        response = admin_client.post(
            "/api/v1/auth/password/change/",
            {"current_password": "wrong", "new_password": "Brand-New-Secret-42"},
            format="json",
        )
        assert response.status_code == 400
        assert error_code(response) == "invalid_current_password"

    def test_weak_new_password_rejected(self, admin_client):
        response = admin_client.post(
            "/api/v1/auth/password/change/",
            {"current_password": DEFAULT_PASSWORD, "new_password": "123"},
            format="json",
        )
        assert response.status_code == 400

    def test_must_change_password_restricts_access(self):
        admin = AdminFactory(must_change_password=True)
        client = APIClient()
        authenticate(client, admin)
        assert client.get(ME).status_code == 200  # allowed
        blocked = client.get("/api/v1/admin/users/")
        assert blocked.status_code == 403
        assert error_code(blocked) == "password_change_required"
        client.post(
            "/api/v1/auth/password/change/",
            {"current_password": DEFAULT_PASSWORD, "new_password": "Brand-New-Secret-42"},
            format="json",
        )
        assert client.get("/api/v1/admin/users/").status_code == 200

    def test_reset_flow_is_single_use_and_revokes_sessions(
        self, api_client, django_capture_on_commit_callbacks
    ):
        admin = AdminFactory(email="reset@example.com")
        logged_in = APIClient()
        authenticate(logged_in, admin)

        with django_capture_on_commit_callbacks(execute=True):
            response = api_client.post("/api/v1/auth/password/reset/", {"email": "reset@example.com"})
        assert response.status_code == 202
        assert len(mail.outbox) == 1
        uid, token = re.search(r"uid=([^&\s]+)&token=([^\s]+)", mail.outbox[0].body).groups()

        payload = {"uid": uid, "token": token, "new_password": "Reset-Secret-Value-1"}
        assert api_client.post("/api/v1/auth/password/reset/confirm/", payload).status_code == 204
        again = api_client.post("/api/v1/auth/password/reset/confirm/", payload)
        assert again.status_code == 400
        assert error_code(again) == "invalid_reset_token"

        assert logged_in.get(ME).status_code == 401
        assert api_login(api_client, admin, password="Reset-Secret-Value-1").status_code == 200

    def test_reset_unknown_email_looks_identical(self, api_client):
        response = api_client.post("/api/v1/auth/password/reset/", {"email": "ghost@example.com"})
        assert response.status_code == 202
        assert len(mail.outbox) == 0

    def test_reset_with_garbage_uid(self, api_client):
        response = api_client.post(
            "/api/v1/auth/password/reset/confirm/",
            {"uid": "!!!", "token": "x", "new_password": "Reset-Secret-Value-1"},
        )
        assert response.status_code == 400
        assert error_code(response) == "invalid_reset_token"
