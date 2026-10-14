"""Session lifetime, retention, lockout tiers, throttles, review policy, role changes, deploy checks."""

from datetime import timedelta
from io import StringIO

import pytest
from django.core.management import call_command
from django.test import override_settings
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework.throttling import ScopedRateThrottle

from apps.accounts import throttling
from apps.accounts.models import AuthSession
from apps.audit.models import AuditLog
from apps.config.services import update_settings
from apps.content import validation
from apps.content.models import ContentFile, ContentItem
from apps.core.checks import shared_cache_check
from apps.devices.models import DeviceChangeRequest, StudentDevice
from apps.notifications.models import Notification
from conftest import api_login, authenticate, new_installation_id
from tests.content_helpers import build_world, upload
from tests.factories import AdminFactory, LibraryFactory, StudentFactory

pytestmark = pytest.mark.django_db


def code(response):
    return response.json()["error"]["code"]


class TestSessionLifetime:
    def test_refresh_never_extends_past_absolute_lifetime(self, settings):
        admin = AdminFactory()
        tokens = authenticate(APIClient(), admin)
        session = AuthSession.objects.get(user=admin)
        cap = session.created_at + settings.SESSION_ABSOLUTE_LIFETIME
        AuthSession.objects.filter(pk=session.pk).update(
            created_at=timezone.now() - settings.SESSION_ABSOLUTE_LIFETIME + timedelta(hours=1)
        )
        response = APIClient().post("/api/v1/auth/refresh/", {"refresh": tokens["refresh"]}, format="json")
        assert response.status_code == 200
        session.refresh_from_db()
        assert session.expires_at <= session.created_at + settings.SESSION_ABSOLUTE_LIFETIME
        assert session.expires_at < cap

    def test_session_past_absolute_lifetime_is_rejected(self):
        admin = AdminFactory()
        client = APIClient()
        authenticate(client, admin)
        AuthSession.objects.filter(user=admin).update(expires_at=timezone.now() - timedelta(seconds=1))
        response = client.get("/api/v1/me/")
        assert response.status_code == 401
        assert code(response) == "session_revoked"


class TestRetention:
    def test_purge_command(self, django_capture_on_commit_callbacks):
        admin = AdminFactory()
        authenticate(APIClient(), admin)
        live = AuthSession.objects.get(user=admin)
        old = timezone.now() - timedelta(days=400)
        dead = AuthSession.objects.create(user=admin, refresh_jti="x", expires_at=old, revoked_at=old)
        Notification.objects.create(recipient=admin, type="system", title="old", read_at=old)
        Notification.objects.create(recipient=admin, type="system", title="unread")
        AuditLog.objects.create(category="auth", action="x")

        out = StringIO()
        with django_capture_on_commit_callbacks(execute=True):
            call_command("purge_expired", stdout=out)
        assert "ended_sessions: 1 removed" in out.getvalue()
        assert AuthSession.objects.filter(pk=live.pk).exists()
        assert not AuthSession.objects.filter(pk=dead.pk).exists()
        assert list(Notification.objects.values_list("title", flat=True)) == ["unread"]
        assert AuditLog.objects.exists()  # audit retention disabled by default

        call_command("purge_expired", "--audit-days", "0", stdout=StringIO())
        assert AuditLog.objects.exists()

    def test_prune_old_file_versions_keeps_current_and_recent(self, django_capture_on_commit_callbacks):
        world = build_world()
        content_id = world.create().json()["id"]
        for _ in range(4):
            world.library_client.post(
                f"/api/v1/manage/contents/{content_id}/file/", {"file": upload()}, format="multipart"
            )
        assert ContentFile.objects.filter(content_id=content_id).count() == 5
        oldest = ContentFile.objects.get(content_id=content_id, version=1)
        storage = oldest.file.storage
        assert storage.exists(oldest.file.name)

        with django_capture_on_commit_callbacks(execute=True):
            call_command("purge_expired", "--keep-file-versions", "2", stdout=StringIO())
        assert list(
            ContentFile.objects.filter(content_id=content_id)
            .order_by("version")
            .values_list("version", flat=True)
        ) == [3, 4, 5]
        assert ContentFile.objects.get(content_id=content_id, is_current=True).version == 5
        assert not storage.exists(oldest.file.name)


class TestLoginLockoutTiers:
    def test_attacker_ip_lockout_does_not_lock_owner_elsewhere(self):
        admin = AdminFactory()
        attacker = APIClient(REMOTE_ADDR="198.51.100.7")
        for _ in range(throttling.MAX_FAILURES_PER_SOURCE):
            api_login(attacker, admin, password="wrong-password-x")
        assert api_login(attacker, admin).status_code == 429
        owner = APIClient(REMOTE_ADDR="203.0.113.20")
        assert api_login(owner, admin).status_code == 200

    def test_account_wide_ceiling_stops_distributed_guessing(self, monkeypatch):
        monkeypatch.setattr(throttling, "MAX_FAILURES_PER_ACCOUNT", 3)
        admin = AdminFactory()
        for i in range(3):
            api_login(APIClient(REMOTE_ADDR=f"192.0.2.{i + 1}"), admin, password="wrong-password-x")
        response = api_login(APIClient(REMOTE_ADDR="192.0.2.99"), admin)
        assert response.status_code == 429
        assert code(response) == "too_many_failed_attempts"


class TestThrottles:
    def test_login_rate_per_ip(self, monkeypatch, api_client):
        monkeypatch.setattr(ScopedRateThrottle, "THROTTLE_RATES", {"auth_login": "2/min"})
        admin = AdminFactory()
        assert [api_login(api_client, admin).status_code for _ in range(3)] == [200, 200, 429]
        response = api_login(api_client, admin)
        assert code(response) == "throttled"
        assert response.json()["error"]["details"]["retry_after_seconds"] > 0

    def test_file_view_rate(self, monkeypatch, student_client):
        world = build_world()
        content_id = world.create_published()
        rates = {**ScopedRateThrottle.THROTTLE_RATES, "content_file": "1/min"}
        monkeypatch.setattr(ScopedRateThrottle, "THROTTLE_RATES", rates)
        url = f"/api/v1/catalog/contents/{content_id}/file/"
        assert student_client.get(url).status_code == 200
        assert student_client.get(url).status_code == 429


class TestReviewPolicy:
    @pytest.fixture
    def world(self, db, admin_user):
        world = build_world()
        world.published_id = world.create_published()  # published before review was switched on
        update_settings({"require_content_review": True}, admin_user)
        return world

    def test_library_edit_of_published_goes_back_to_review(self, world, student_client):
        response = world.library_client.patch(
            f"/api/v1/manage/contents/{world.published_id}/", {"title": "Edited"}, format="json"
        )
        assert response.json()["status"] == "pending_review"
        assert student_client.get(f"/api/v1/catalog/contents/{world.published_id}/").status_code == 404

    def test_library_file_replacement_goes_back_to_review(self, world):
        world.library_client.post(
            f"/api/v1/manage/contents/{world.published_id}/file/", {"file": upload()}, format="multipart"
        )
        assert ContentItem.objects.get(pk=world.published_id).status == "pending_review"

    def test_no_op_edit_keeps_published(self, world):
        title = ContentItem.objects.get(pk=world.published_id).title
        response = world.library_client.patch(
            f"/api/v1/manage/contents/{world.published_id}/", {"title": title}, format="json"
        )
        assert response.json()["status"] == "published"

    def test_admin_edit_applies_immediately(self, world, admin_client):
        response = admin_client.patch(
            f"/api/v1/manage/contents/{world.published_id}/", {"title": "Fixed by admin"}, format="json"
        )
        assert response.json()["status"] == "published"


class TestVisibilityPolicy:
    def test_inactive_instructor_hides_content_but_inactive_category_does_not(self, student_client):
        world = build_world()
        content_id = world.create_published()
        world.category.is_active = False
        world.category.save()
        assert student_client.get(f"/api/v1/catalog/contents/{content_id}/").status_code == 200
        world.instructor.is_active = False
        world.instructor.save()
        assert student_client.get(f"/api/v1/catalog/contents/{content_id}/").status_code == 404


class TestRoleChange:
    def test_student_turned_staff_loses_binding_and_pending_request(self, admin_client):
        student = StudentFactory()
        authenticate(APIClient(), student)
        new_install = new_installation_id()
        response = api_login(APIClient(), student, installation_id=new_install)
        token = response.json()["error"]["details"]["device_change_token"]
        restricted = APIClient()
        restricted.credentials(HTTP_AUTHORIZATION=f"Bearer {token}", HTTP_X_DEVICE_ID=new_install)
        restricted.post("/api/v1/auth/device-change-requests/", {}, format="json")

        changed = admin_client.patch(
            f"/api/v1/admin/users/{student.pk}/",
            {"role": "library", "library": LibraryFactory().pk},
            format="json",
        )
        assert changed.status_code == 200
        assert not StudentDevice.objects.filter(student=student, status="active").exists()
        assert DeviceChangeRequest.objects.get(student=student).status == "cancelled"
        assert AuditLog.objects.filter(action="device.released_on_role_change").exists()


class TestUploadLimits:
    def test_pdf_page_cap(self, monkeypatch):
        monkeypatch.setattr(validation, "MAX_PDF_PAGES", 1)
        world = build_world()
        response = world.create()  # helper PDFs have 2 pages
        assert response.status_code == 400
        assert response.json()["error"]["details"]["reason"] == "too_many_pages"

    def test_classification_validation_query_budget(self, django_assert_max_num_queries):
        from apps.content.services import validate_classification

        world = build_world()
        item = ContentItem.objects.get(pk=world.create(world.exam_payload()).json()["id"])
        item = ContentItem.objects.select_related("course__level", "semester", "exam_type").get(pk=item.pk)
        with django_assert_max_num_queries(2):  # scope check + nothing else for an exam without instructor
            validate_classification(item, world.library_user)


class TestDeployChecks:
    def test_process_local_cache_is_flagged(self):
        assert [w.id for w in shared_cache_check(None)] == ["unilect.W001"]

    @override_settings(
        CACHES={
            "default": {"BACKEND": "django.core.cache.backends.redis.RedisCache", "LOCATION": "redis://x"}
        }
    )
    def test_shared_cache_passes(self):
        assert shared_cache_check(None) == []
