"""Student-facing content features (FR-029..034, 050..057, 070..074, 079).

Browsing, search, filters, protected viewing, favorites, follows, reports.
"""

import pytest
from django.test import override_settings
from rest_framework.test import APIClient

from apps.content.models import ContentItem
from apps.notifications.models import Notification
from conftest import authenticate, new_installation_id
from tests.content_helpers import build_world, pdf_bytes
from tests.factories import StudentFactory

pytestmark = pytest.mark.django_db
CATALOG = "/api/v1/catalog/contents/"


@pytest.fixture
def world(db):
    return build_world()


def ids(response):
    return [row["id"] for row in response.json()["results"]]


class TestVisibility:
    def test_only_published_visible(self, world, student_client):
        published = world.create_published()
        draft = world.create().json()["id"]
        archived = world.create_published()
        world.library_client.post(f"/api/v1/manage/contents/{archived}/archive/")
        result = ids(student_client.get(CATALOG))
        assert result == [published]
        for hidden in (draft, archived):
            assert student_client.get(f"{CATALOG}{hidden}/").status_code == 404
            assert student_client.get(f"{CATALOG}{hidden}/file/").status_code == 404

    def test_pending_review_not_visible(self, world, student_client, admin_user):
        from apps.config.services import update_settings

        update_settings({"require_content_review": True}, admin_user)
        content_id = world.create().json()["id"]
        world.library_client.post(f"/api/v1/manage/contents/{content_id}/submit/")
        assert student_client.get(f"{CATALOG}{content_id}/").status_code == 404

    def test_inactive_academic_path_hides_content(self, world, student_client):
        content_id = world.create_published()
        faculty = world.course.level.faculty
        faculty.is_active = False
        faculty.save()
        assert student_client.get(f"{CATALOG}{content_id}/").status_code == 404

    def test_detail_metadata_before_opening(self, world, student_client):
        content_id = world.create_published()
        body = student_client.get(f"{CATALOG}{content_id}/").json()
        assert body["title"] and body["published_at"]
        assert body["course"]["id"] == world.course.pk
        assert body["university"]["id"] == world.course.level.faculty.university_id
        assert body["instructor"]["id"] == world.instructor.pk
        assert body["category"]["name"] == "Theory"
        assert body["file"]["page_count"] == 2
        assert body["file_endpoint"] == f"{CATALOG}{content_id}/file/"
        assert "status" not in body and "library" not in body and "original_name" not in body["file"]

    def test_list_query_count_is_constant(self, world, student_client, django_assert_max_num_queries):
        for i in range(6):
            world.create_published(world.lecture_payload(title=f"L{i}", lecture_number=i + 1))
        with django_assert_max_num_queries(8):
            response = student_client.get(CATALOG)
        assert response.json()["count"] == 6

    def test_default_order_by_lecture_number(self, world, student_client):
        second = world.create_published(world.lecture_payload(title="B", lecture_number=2))
        first = world.create_published(world.lecture_payload(title="A", lecture_number=1))
        assert ids(student_client.get(f"{CATALOG}?kind=lecture")) == [first, second]


class TestSearchAndFilters:
    def test_search_arabic_keyword(self, world, student_client):
        match = world.create_published(world.lecture_payload(title="مقدمة في علم التشريح"))
        world.create_published(world.lecture_payload(title="Physiology"))
        assert ids(student_client.get(f"{CATALOG}?search=التشريح")) == [match]

    def test_search_never_returns_unpublished(self, world, student_client):
        world.create(world.lecture_payload(title="secret draft"))
        assert ids(student_client.get(f"{CATALOG}?search=secret")) == []

    def test_filters(self, world, student_client):
        lecture = world.create_published()
        exam = world.create_published(world.exam_payload())
        assert ids(student_client.get(f"{CATALOG}?kind=exam")) == [exam]
        assert ids(student_client.get(f"{CATALOG}?instructor={world.instructor.pk}")) == [lecture]
        assert ids(student_client.get(f"{CATALOG}?exam_year=2023&exam_type={world.exam_type.pk}")) == [exam]
        assert set(ids(student_client.get(f"{CATALOG}?course={world.course.pk}"))) == {lecture, exam}
        assert set(ids(student_client.get(f"{CATALOG}?semester={world.semester.pk}"))) == {lecture, exam}
        assert ids(student_client.get(f"{CATALOG}?faculty={world.course.level.faculty_id}&kind=lecture")) == [
            lecture
        ]
        assert ids(student_client.get(f"{CATALOG}?university=999999")) == []


class TestProtectedFile:
    def test_stream_headers(self, world, student_client, student):
        content_id = world.create_published()
        response = student_client.get(f"{CATALOG}{content_id}/file/")
        assert response.status_code == 200
        assert response["Content-Type"] == "application/pdf"
        assert response["Content-Disposition"] == f'inline; filename="{content_id}.pdf"'
        assert "no-store" in response["Cache-Control"]
        assert response["X-Content-Type-Options"] == "nosniff"
        watermark = response["X-Watermark-Text"]
        assert watermark.startswith("UL-") and student.email not in watermark
        assert b"".join(response.streaming_content) == pdf_bytes()

    def test_unauthenticated_and_wrong_device_rejected(self, world, student_client):
        content_id = world.create_published()
        assert APIClient().get(f"{CATALOG}{content_id}/file/").status_code == 401
        student_client.credentials(
            HTTP_AUTHORIZATION=student_client._credentials["HTTP_AUTHORIZATION"],
            HTTP_X_DEVICE_ID=new_installation_id(),
        )
        assert student_client.get(f"{CATALOG}{content_id}/file/").status_code == 403

    @override_settings(PRIVATE_MEDIA_ACCEL_PREFIX="/protected-media/")
    def test_x_accel_redirect_in_production_mode(self, world, student_client):
        content_id = world.create_published()
        response = student_client.get(f"{CATALOG}{content_id}/file/")
        assert response["X-Accel-Redirect"].startswith("/protected-media/content/")
        assert response.content == b""

    def test_no_storage_url_anywhere(self, world, student_client):
        content_id = world.create_published()
        text = student_client.get(f"{CATALOG}{content_id}/").content.decode()
        assert "private_media" not in text and "content/" + content_id + "/" not in text.replace(CATALOG, "")


class TestFavorites:
    def test_add_list_remove(self, world, student_client):
        content_id = world.create_published()
        assert (
            student_client.post("/api/v1/me/favorites/", {"content": content_id}, format="json").status_code
            == 201
        )
        assert (
            student_client.post("/api/v1/me/favorites/", {"content": content_id}, format="json").status_code
            == 200
        )
        rows = student_client.get("/api/v1/me/favorites/").json()["results"]
        assert [r["content"] for r in rows] == [content_id]
        assert student_client.get(f"{CATALOG}{content_id}/").json()["is_favorite"] is True
        assert student_client.delete(f"/api/v1/me/favorites/{content_id}/").status_code == 204
        assert student_client.get("/api/v1/me/favorites/").json()["count"] == 0

    def test_persist_across_logins(self, world, student):
        content_id = world.create_published()
        first = APIClient()
        info = authenticate(first, student)
        first.post("/api/v1/me/favorites/", {"content": content_id}, format="json")
        first.post("/api/v1/auth/logout/")
        second = APIClient()
        authenticate(second, student, info["installation_id"])
        assert second.get("/api/v1/me/favorites/").json()["count"] == 1

    def test_cannot_favorite_draft(self, world, student_client):
        draft = world.create().json()["id"]
        assert (
            student_client.post("/api/v1/me/favorites/", {"content": draft}, format="json").status_code == 400
        )

    def test_archived_favorites_disappear(self, world, student_client):
        content_id = world.create_published()
        student_client.post("/api/v1/me/favorites/", {"content": content_id}, format="json")
        world.library_client.post(f"/api/v1/manage/contents/{content_id}/archive/")
        assert student_client.get("/api/v1/me/favorites/").json()["count"] == 0

    def test_favorites_are_private(self, world, student_client):
        content_id = world.create_published()
        student_client.post("/api/v1/me/favorites/", {"content": content_id}, format="json")
        other = APIClient()
        authenticate(other, StudentFactory())
        assert other.get("/api/v1/me/favorites/").json()["count"] == 0


class TestFollowNotifications:
    def test_followers_notified_once_on_first_publication(
        self, world, student_client, student, django_capture_on_commit_callbacks
    ):
        follow = student_client.post(
            "/api/v1/me/followed-courses/", {"course": world.course.pk}, format="json"
        )
        assert follow.status_code == 201
        opted_out = StudentFactory()
        from apps.content.models import CourseFollow

        CourseFollow.objects.create(student=opted_out, course=world.course, notify_new_content=False)

        with django_capture_on_commit_callbacks(execute=True):
            content_id = world.create_published()
        assert Notification.objects.filter(recipient=student, type="new_content").count() == 1
        assert not Notification.objects.filter(recipient=opted_out).exists()

        with django_capture_on_commit_callbacks(execute=True):
            world.library_client.post(f"/api/v1/manage/contents/{content_id}/archive/")
            world.library_client.post(f"/api/v1/manage/contents/{content_id}/restore/")
            world.library_client.post(f"/api/v1/manage/contents/{content_id}/submit/")
        assert Notification.objects.filter(recipient=student, type="new_content").count() == 1

    def test_update_follow_preference(self, world, student_client):
        follow_id = student_client.post(
            "/api/v1/me/followed-courses/", {"course": world.course.pk}, format="json"
        ).json()["id"]
        response = student_client.patch(
            f"/api/v1/me/followed-courses/{follow_id}/", {"notify_new_content": False}, format="json"
        )
        assert response.json()["notify_new_content"] is False


class TestReports:
    def test_report_lifecycle(self, world, student_client, student, admin_client):
        content_id = world.create_published()
        url = f"{CATALOG}{content_id}/reports/"
        created = student_client.post(
            url, {"reason": "duplicate", "message": "Same as lecture 2"}, format="json"
        )
        assert created.status_code == 201
        duplicate = student_client.post(url, {"reason": "wrong"}, format="json")
        assert duplicate.status_code == 409

        report_id = created.json()["id"]
        admin_client.post(
            f"/api/v1/admin/reports/{report_id}/transition/", {"status": "in_review"}, format="json"
        )
        admin_client.post(f"/api/v1/admin/reports/{report_id}/notes/", {"note": "Checking"}, format="json")
        resolved = admin_client.post(
            f"/api/v1/admin/reports/{report_id}/transition/",
            {"status": "resolved", "note": "Removed"},
            format="json",
        )
        body = resolved.json()
        assert body["status"] == "resolved"
        assert [a["to_status"] for a in body["actions"]] == ["in_review", "in_review", "resolved"]
        assert Notification.objects.filter(recipient=student, type="report_update").exists()

        invalid = admin_client.post(
            f"/api/v1/admin/reports/{report_id}/transition/", {"status": "open"}, format="json"
        )
        assert invalid.status_code == 409
        # once closed, a new report may be filed
        assert student_client.post(url, {"reason": "wrong"}, format="json").status_code == 201

    def test_cannot_report_invisible_content(self, world, student_client):
        draft = world.create().json()["id"]
        assert (
            student_client.post(f"{CATALOG}{draft}/reports/", {"reason": "wrong"}, format="json").status_code
            == 404
        )

    def test_students_cannot_list_reports(self, student_client):
        assert student_client.get("/api/v1/admin/reports/").status_code == 403


class TestAdminDashboard:
    def test_counts_reflect_data(self, world, admin_client):
        world.create_published()
        world.create()
        body = admin_client.get("/api/v1/admin/dashboard/").json()
        assert body["content"]["by_status"]["published"] == 1
        assert body["content"]["by_status"]["draft"] == 1
        assert body["accounts"]["library"] == 1
        assert body["pending_actions"]["device_change_requests"] == 0
        assert ContentItem.objects.count() == 2

    def test_non_admin_forbidden(self, world):
        assert world.library_client.get("/api/v1/admin/dashboard/").status_code == 403
