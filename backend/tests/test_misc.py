"""System settings, libraries admin, audit scrubbing, notifications, error format, docs."""

import pytest

from apps.audit.models import AuditLog
from apps.audit.services import REDACTED, scrub
from apps.notifications.models import Notification
from tests.factories import LibraryFactory, StudentFactory, UniversityFactory

pytestmark = pytest.mark.django_db


class TestSettings:
    def test_get_defaults(self, admin_client):
        body = admin_client.get("/api/v1/admin/settings/").json()
        assert body["require_content_review"] is False
        assert "pdf" in body["allowed_extensions"]

    def test_update_and_audit(self, admin_client):
        response = admin_client.patch(
            "/api/v1/admin/settings/",
            {"max_upload_size_mb": 10, "allowed_extensions": ["PDF"]},
            format="json",
        )
        assert response.status_code == 200
        assert response.json()["allowed_extensions"] == ["pdf"]
        assert AuditLog.objects.filter(action="settings.updated").exists()

    @pytest.mark.parametrize(
        "payload",
        [{"allowed_extensions": ["exe"]}, {"max_upload_size_mb": 100000}, {"allowed_extensions": []}],
    )
    def test_cannot_exceed_hard_limits(self, admin_client, payload):
        assert admin_client.patch("/api/v1/admin/settings/", payload, format="json").status_code == 400

    def test_non_admin_forbidden(self, library_client):
        assert library_client.get("/api/v1/admin/settings/").status_code == 403


class TestLibrariesAdmin:
    def test_create_with_scope(self, admin_client):
        uni = UniversityFactory()
        response = admin_client.post(
            "/api/v1/admin/libraries/", {"name": "Al-Noor", "scope_universities": [uni.pk]}, format="json"
        )
        assert response.status_code == 201
        assert response.json()["scope_universities"] == [uni.pk]

    def test_library_with_staff_cannot_be_deleted(self, admin_client, library_user):
        response = admin_client.delete(f"/api/v1/admin/libraries/{library_user.library_id}/")
        assert response.status_code == 409

    def test_delete_empty_library(self, admin_client):
        assert admin_client.delete(f"/api/v1/admin/libraries/{LibraryFactory().pk}/").status_code == 204


class TestAudit:
    def test_scrub_nested_secrets(self):
        cleaned = scrub({"password": "x", "nested": {"refresh_token": "y", "ok": 1}, "list": [{"Secret": 2}]})
        assert cleaned == {
            "password": REDACTED,
            "nested": {"refresh_token": REDACTED, "ok": 1},
            "list": [{"Secret": REDACTED}],
        }

    def test_admin_can_filter_logs(self, admin_client):
        admin_client.post("/api/v1/admin/universities/", {"name": "U"}, format="json")
        response = admin_client.get("/api/v1/admin/audit-logs/?category=catalog")
        assert response.status_code == 200
        assert response.json()["count"] >= 1
        row = response.json()["results"][0]
        assert {"action", "actor", "created_at", "target_repr"} <= row.keys()  # FR-068

    def test_non_admin_cannot_read_logs(self, student_client):
        assert student_client.get("/api/v1/admin/audit-logs/").status_code == 403


class TestNotifications:
    def test_user_sees_only_own_notifications_and_marks_read(self, student_client, student):
        mine = Notification.objects.create(recipient=student, type="system", title="hi")
        theirs = Notification.objects.create(recipient=StudentFactory(), type="system", title="secret")
        rows = student_client.get("/api/v1/me/notifications/").json()["results"]
        assert [r["id"] for r in rows] == [str(mine.pk)]
        assert student_client.get(f"/api/v1/me/notifications/{theirs.pk}/").status_code == 404
        assert student_client.get("/api/v1/me/notifications/unread-count/").json() == {"unread": 1}
        assert student_client.post(f"/api/v1/me/notifications/{mine.pk}/read/").status_code == 204
        assert student_client.get("/api/v1/me/notifications/?unread=true").json()["count"] == 0

    def test_read_all(self, student_client, student):
        Notification.objects.create(recipient=student, type="system", title="a")
        Notification.objects.create(recipient=student, type="system", title="b")
        assert student_client.post("/api/v1/me/notifications/read-all/").json() == {"updated": 2}


class TestPlumbing:
    def test_health(self, api_client):
        assert api_client.get("/health/").json() == {"status": "ok"}

    def test_request_id_header(self, api_client):
        response = api_client.get("/health/", HTTP_X_REQUEST_ID="abcdef123456")
        assert response["X-Request-ID"] == "abcdef123456"

    def test_404_uses_error_envelope(self, admin_client):
        body = admin_client.get("/api/v1/admin/universities/999999/").json()
        assert body["error"]["code"] == "not_found"

    def test_openapi_schema_generates(self, api_client):
        response = api_client.get("/api/v1/schema/")
        assert response.status_code == 200


class TestClientIp:
    def test_forwarded_header_ignored_without_trusted_proxy(self, rf):
        from apps.audit.services import client_ip

        request = rf.get("/", REMOTE_ADDR="10.0.0.1", HTTP_X_FORWARDED_FOR="6.6.6.6")
        assert client_ip(request) == "10.0.0.1"

    def test_trusted_proxy_uses_last_hop(self, rf, settings):
        from apps.audit.services import client_ip

        settings.REST_FRAMEWORK = {**settings.REST_FRAMEWORK, "NUM_PROXIES": 1}
        request = rf.get("/", REMOTE_ADDR="127.0.0.1", HTTP_X_FORWARDED_FOR="6.6.6.6, 203.0.113.9")
        assert client_ip(request) == "203.0.113.9"

    def test_garbage_ip_is_dropped(self, rf, settings):
        from apps.audit.services import client_ip

        settings.REST_FRAMEWORK = {**settings.REST_FRAMEWORK, "NUM_PROXIES": 1}
        assert client_ip(rf.get("/", HTTP_X_FORWARDED_FOR="not-an-ip")) is None

    def test_device_record_ids_are_not_redacted(self):
        assert scrub({"old_device_id": "abc", "installation_id": "secret"}) == {
            "old_device_id": "abc",
            "installation_id": REDACTED,
        }


class TestArabicLocalisation:
    def test_errors_follow_accept_language(self, api_client):
        body = api_client.post(
            "/api/v1/auth/login/",
            {"email": "ghost@example.com", "password": "x"},
            format="json",
            HTTP_ACCEPT_LANGUAGE="ar",
        ).json()
        assert body["error"]["code"] == "invalid_credentials"  # stable code
        assert body["error"]["message"] == "البريد الإلكتروني/الرقم الجامعي أو كلمة المرور غير صحيحة."

    def test_english_still_available(self, api_client):
        body = api_client.post(
            "/api/v1/auth/login/",
            {"email": "g@example.com", "password": "x"},
            format="json",
            HTTP_ACCEPT_LANGUAGE="en",
        ).json()
        assert body["error"]["message"].startswith("The email")

    def test_notifications_use_site_language_not_actor_language(self, settings, admin_client):
        from apps.devices import services as device_services
        from tests.factories import StudentFactory

        settings.LANGUAGE_CODE = "ar"
        student = StudentFactory()
        from rest_framework.test import APIClient as _Client

        from conftest import authenticate as _auth

        _auth(_Client(), student)
        change = device_services.create_change_request(
            student, device_services.DeviceInfo(installation_id_hash="d" * 64, platform="ios")
        )
        admin_client.post(
            f"/api/v1/admin/device-change-requests/{change.pk}/approve/",
            {},
            format="json",
            HTTP_ACCEPT_LANGUAGE="en",
        )
        notification = Notification.objects.get(recipient=student)
        assert notification.title == "تمت الموافقة على تغيير الجهاز"
