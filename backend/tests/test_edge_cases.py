"""Edge and failure paths: restricted-token negatives, orphan-file safety, logging, retention toggles."""

import io
import json
import logging
import sys
from datetime import timedelta

import pytest
from django.test import override_settings
from django.urls import path
from django.utils import timezone
from PIL import Image
from pypdf import PdfWriter
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.test import APIClient

from apps.accounts.models import AuthSession
from apps.audit.models import AuditLog
from apps.config.services import update_settings
from apps.content import validation
from apps.content.models import ContentFile, ContentItem, CourseFollow
from apps.core.logging import JSONFormatter
from apps.maintenance import services as maintenance
from apps.notifications.models import Notification
from conftest import api_login, authenticate, new_installation_id
from tests.content_helpers import build_world, pdf_bytes, upload
from tests.factories import AdminFactory, StudentFactory, UniversityFactory

pytestmark = pytest.mark.django_db
RESTRICTED = "/api/v1/auth/device-change-requests/"


def code(response):
    return response.json()["error"]["code"]


class TestRestrictedTokenNegatives:
    def _restricted(self, student):
        authenticate(APIClient(), student)
        install = new_installation_id()
        token = api_login(APIClient(), student, installation_id=install).json()["error"]["details"][
            "device_change_token"
        ]
        return token, install

    def test_garbage_token(self):
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION="Bearer nope", HTTP_X_DEVICE_ID=new_installation_id())
        response = client.post(RESTRICTED, {}, format="json")
        assert response.status_code == 401 and code(response) == "token_not_valid"

    def test_refresh_token_is_not_a_device_change_token(self):
        tokens = authenticate(APIClient(), StudentFactory())
        client = APIClient()
        client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {tokens['refresh']}", HTTP_X_DEVICE_ID=tokens["installation_id"]
        )
        assert client.post(RESTRICTED, {}, format="json").status_code == 401

    def test_token_dies_with_account(self):
        student = StudentFactory()
        token, install = self._restricted(student)
        student.is_active = False
        student.save()
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}", HTTP_X_DEVICE_ID=install)
        assert client.post(RESTRICTED, {}, format="json").status_code == 401

    def test_token_dies_when_account_stops_being_student(self, admin_client):
        from tests.factories import LibraryFactory

        student = StudentFactory()
        token, install = self._restricted(student)
        admin_client.patch(
            f"/api/v1/admin/users/{student.pk}/",
            {"role": "library", "library": LibraryFactory().pk},
            format="json",
        )
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}", HTTP_X_DEVICE_ID=install)
        assert client.post(RESTRICTED, {}, format="json").status_code == 401

    def test_non_bearer_scheme_is_unauthenticated(self):
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION="Basic dXNlcjpwYXNz")
        response = client.get("/api/v1/me/")
        assert response.status_code == 401 and code(response) == "not_authenticated"


class TestSessionsAdmin:
    def test_revoke_sessions_endpoint(self, admin_client):
        other = AdminFactory()
        first, second = APIClient(), APIClient()
        authenticate(first, other)
        authenticate(second, other)
        response = admin_client.post(f"/api/v1/admin/users/{other.pk}/revoke-sessions/")
        assert response.json() == {"revoked": 2}
        assert first.get("/api/v1/me/").status_code == second.get("/api/v1/me/").status_code == 401
        assert AuditLog.objects.filter(action="account.sessions_revoked", target_id=str(other.pk)).exists()

    def test_reset_device_rejects_non_students(self, admin_client):
        response = admin_client.post(f"/api/v1/admin/users/{AdminFactory().pk}/reset-device/")
        assert response.status_code == 400 and code(response) == "not_a_student"

    def test_last_used_is_refreshed_lazily(self, admin_client, admin_user):
        stale = timezone.now() - timedelta(hours=1)
        AuthSession.objects.filter(user=admin_user).update(last_used_at=stale)
        admin_client.get("/api/v1/me/")
        assert AuthSession.objects.get(user=admin_user).last_used_at > stale

    def test_catalog_update_is_audited(self, admin_client):
        uni = UniversityFactory()
        admin_client.patch(f"/api/v1/admin/universities/{uni.pk}/", {"name": "Renamed"}, format="json")
        log = AuditLog.objects.get(action="university.updated")
        assert log.metadata == {"fields": ["name"]} and log.target_id == str(uni.pk)


class TestUploadEdgeCases:
    @pytest.fixture
    def world(self, db):
        return build_world()

    def test_encrypted_pdf_rejected(self, world):
        writer = PdfWriter()
        writer.add_blank_page(width=100, height=100)
        writer.encrypt("secret")
        buffer = io.BytesIO()
        writer.write(buffer)
        response = world.create(file=upload("locked.pdf", buffer.getvalue()))
        assert response.json()["error"]["details"]["reason"] == "encrypted_pdf"

    def test_image_pixel_bomb_rejected(self, world, monkeypatch):
        monkeypatch.setattr(validation, "MAX_IMAGE_PIXELS", 100)
        buffer = io.BytesIO()
        Image.new("RGB", (20, 20)).save(buffer, format="PNG")
        response = world.create(file=upload("big.png", buffer.getvalue(), "image/png"))
        assert response.json()["error"]["details"]["reason"] == "image_too_large"

    def test_webp_accepted(self, world):
        buffer = io.BytesIO()
        Image.new("RGB", (10, 10), "blue").save(buffer, format="WEBP")
        response = world.create(file=upload("scan.webp", buffer.getvalue(), "image/webp"))
        assert response.status_code == 201
        assert response.json()["current_file"]["mime_type"] == "image/webp"

    def test_no_orphan_file_when_row_write_fails(self, world, monkeypatch, settings):
        content_id = world.create(file=False).json()["id"]
        before = {p for p in settings.PRIVATE_MEDIA_ROOT.rglob("*") if p.is_file()}

        def boom(*args, **kwargs):
            raise RuntimeError("db down")

        monkeypatch.setattr(ContentFile, "save", boom)
        client = world.library_client
        client.raise_request_exception = False
        response = client.post(
            f"/api/v1/manage/contents/{content_id}/file/",
            {"file": upload("x.pdf", pdf_bytes())},
            format="multipart",
        )
        assert response.status_code == 500
        after = {p for p in settings.PRIVATE_MEDIA_ROOT.rglob("*") if p.is_file()}
        assert after == before

    def test_followers_not_notified_when_disabled(
        self, world, admin_user, django_capture_on_commit_callbacks
    ):
        update_settings({"notify_followers_on_publish": False}, admin_user)
        CourseFollow.objects.create(student=StudentFactory(), course=world.course)
        with django_capture_on_commit_callbacks(execute=True):
            world.create_published()
        assert not Notification.objects.filter(type="new_content").exists()
        assert ContentItem.objects.count() == 1


@api_view(["GET"])
@permission_classes([AllowAny])
def _drf_boom(request):
    raise RuntimeError("internal secret")


urlpatterns = [path("drf-boom/", _drf_boom)]
handler500 = "apps.core.views.server_error"


@override_settings(ROOT_URLCONF=__name__, DEBUG=False)
def test_unhandled_error_inside_drf_view_is_json_500():
    response = APIClient(raise_request_exception=False).get("/drf-boom/")
    assert response.status_code == 500
    assert response.json()["error"]["code"] == "server_error"
    assert b"internal secret" not in response.content


def test_json_log_formatter_includes_extra_and_exception():
    try:
        raise ValueError("bad")
    except ValueError:
        record = logging.LogRecord(
            "unilect.security", logging.WARNING, __file__, 1, "msg %s", ("x",), sys.exc_info()
        )
    record.event = "device_mismatch"
    record.request_id = "abc"
    payload = json.loads(JSONFormatter().format(record))
    assert payload["message"] == "msg x" and payload["event"] == "device_mismatch"
    assert payload["request_id"] == "abc" and "ValueError" in payload["exc"]


def test_retention_rules_disabled_with_zero():
    assert maintenance.purge_ended_sessions(0) == 0
    assert maintenance.purge_read_notifications(0) == 0
    assert maintenance.purge_audit_logs(0) == 0
    assert maintenance.prune_old_file_versions(0) == 0


def test_audit_retention_when_enabled():
    old = AuditLog.objects.create(category="auth", action="old")
    AuditLog.objects.filter(pk=old.pk).update(created_at=timezone.now() - timedelta(days=500))
    AuditLog.objects.create(category="auth", action="new")
    assert maintenance.purge_audit_logs(365) == 1
    assert list(AuditLog.objects.values_list("action", flat=True)) == ["new"]
