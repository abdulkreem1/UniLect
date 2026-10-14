"""Library/admin content management (FR-035..049, 059..066, 078).

Upload, validation, classification, workflow and scope.
"""

import json

import pytest
from django.db import IntegrityError
from django.utils import timezone
from rest_framework.test import APIClient

from apps.audit.models import AuditLog
from apps.config.services import update_settings
from apps.content.models import ContentFile, ContentItem
from apps.notifications.models import Notification
from conftest import authenticate
from tests.content_helpers import build_world, pdf_bytes, png_bytes, upload
from tests.factories import CourseFactory, CourseInstructorFactory, InstructorFactory, LibraryUserFactory

pytestmark = pytest.mark.django_db
MANAGE = "/api/v1/manage/contents/"


@pytest.fixture
def world(db):
    return build_world()


def err(response):
    return response.json()["error"]


class TestCreate:
    def test_create_lecture_with_file_as_draft(self, world):
        response = world.create()
        assert response.status_code == 201, response.json()
        body = response.json()
        assert body["status"] == "draft"
        assert body["library"]["id"] == world.library_user.library_id
        assert body["current_file"]["version"] == 1
        assert body["current_file"]["page_count"] == 2
        assert body["current_file"]["mime_type"] == "application/pdf"
        stored = ContentFile.objects.get(content_id=body["id"])
        assert "lecture" not in stored.file.name  # random storage key, not client filename
        assert AuditLog.objects.filter(action="content.created", target_id=body["id"]).exists()

    def test_create_exam_paper(self, world):
        response = world.create(world.exam_payload())
        assert response.status_code == 201
        assert response.json()["exam_year"] == 2023

    def test_image_upload_accepted(self, world):
        response = world.create(file=upload("scan.png", png_bytes(), "image/png"))
        assert response.status_code == 201
        assert response.json()["current_file"]["mime_type"] == "image/png"

    def test_draft_without_file_allowed(self, world):
        assert world.create(file=False).status_code == 201

    def test_missing_title_rejected(self, world):
        response = world.create(world.lecture_payload(title=""))
        assert response.status_code == 400

    def test_course_outside_scope_rejected(self, world):
        other_course = CourseFactory()
        CourseInstructorFactory(course=other_course, instructor=world.instructor)
        response = world.create(world.lecture_payload(course=other_course.pk))
        assert response.status_code == 400
        assert "course" in err(response)["details"]["fields"]

    def test_instructor_must_be_linked_to_course(self, world):
        response = world.create(world.lecture_payload(instructor=InstructorFactory().pk))
        assert response.status_code == 400
        assert "instructor" in err(response)["details"]["fields"]

    def test_exam_fields_not_allowed_on_lecture(self, world):
        response = world.create(world.lecture_payload(exam_year=2020))
        assert response.status_code == 400
        assert "exam_year" in err(response)["details"]["fields"]

    def test_exam_semester_must_match_faculty(self, world):
        from tests.factories import SemesterFactory

        response = world.create(world.exam_payload(semester=SemesterFactory().pk))
        assert response.status_code == 400

    def test_exam_year_range(self, world):
        assert world.create(world.exam_payload(exam_year=1800)).status_code == 400

    def test_admin_cannot_upload(self, admin_client, world):
        response = world.create(client=admin_client)
        assert response.status_code == 403
        assert err(response)["code"] == "library_only"

    def test_students_have_no_access(self, student_client, world):
        assert student_client.get(MANAGE).status_code == 403
        assert world.create(client=student_client).status_code == 403

    def test_inactive_library_blocked(self, world):
        world.library_user.library.is_active = False
        world.library_user.library.save()
        assert world.library_client.get(MANAGE).status_code == 403


class TestUploadValidation:
    @pytest.mark.parametrize(
        ("name", "data", "reason"),
        [
            ("virus.exe", b"MZ\x90\x00" + b"\x00" * 100, "extension_not_allowed"),
            ("notes.docx", b"PK\x03\x04" + b"\x00" * 100, "unsupported_format"),
            ("fake.pdf", png_bytes(), "content_mismatch"),
            ("broken.pdf", b"%PDF-1.7\n" + b"garbage" * 50, "corrupt_file"),
            ("empty.pdf", b"", "empty_file"),
            ("image.png", b"\x89PNG\r\n\x1a\n" + b"\x00" * 64, "corrupt_file"),
        ],
    )
    def test_rejections_explain_reason_and_store_nothing(self, world, name, data, reason):
        response = world.create(file=upload(name, data, "application/octet-stream"))
        assert response.status_code == 400
        body = err(response)
        assert body["code"] in ("file_rejected", "validation_error")
        if body["code"] == "file_rejected":
            assert body["details"]["reason"] == reason
            assert body["message"]
        assert ContentItem.objects.count() == 0
        assert ContentFile.objects.count() == 0

    def test_size_limit_from_settings(self, world, admin_user):
        update_settings({"max_upload_size_mb": 1}, admin_user)
        big = pdf_bytes() + b"\x00" * (1024 * 1024 + 10)
        response = world.create(file=upload("big.pdf", big))
        assert response.status_code == 400
        assert err(response)["details"]["reason"] == "file_too_large"

    def test_extension_disabled_by_admin(self, world, admin_user):
        update_settings({"allowed_extensions": ["pdf"]}, admin_user)
        response = world.create(file=upload("scan.png", png_bytes(), "image/png"))
        assert err(response)["details"]["reason"] == "extension_not_allowed"


class TestWorkflow:
    def test_submit_publishes_when_review_not_required(self, world):
        content_id = world.create_published()
        item = ContentItem.objects.get(pk=content_id)
        assert item.status == "published" and item.published_at is not None

    def test_cannot_publish_without_file(self, world):
        content_id = world.create(file=False).json()["id"]
        response = world.library_client.post(f"{MANAGE}{content_id}/submit/")
        assert response.status_code == 400
        assert err(response)["code"] == "incomplete_content"
        assert "file" in err(response)["details"]

    def test_cannot_publish_lecture_without_category_or_instructor(self, world):
        content_id = world.create(world.lecture_payload(category=None, instructor=None)).json()["id"]
        response = world.library_client.post(f"{MANAGE}{content_id}/submit/")
        assert response.status_code == 400
        assert {"category", "instructor"} <= err(response)["details"].keys()

    def test_exam_requires_type_year_semester(self, world):
        content_id = world.create(world.exam_payload(exam_type=None)).json()["id"]
        response = world.library_client.post(f"{MANAGE}{content_id}/submit/")
        assert response.status_code == 400
        assert "exam_type" in err(response)["details"]

    def test_database_rejects_incomplete_published_row(self, world):
        with pytest.raises(IntegrityError):
            ContentItem.objects.create(
                kind="lecture",
                status="published",
                published_at=timezone.now(),
                library=world.library_user.library,
                course=world.course,
                title="x",
            )

    def test_review_required_flow(self, world, admin_user, admin_client):
        update_settings({"require_content_review": True}, admin_user)
        content_id = world.create().json()["id"]
        submitted = world.library_client.post(f"{MANAGE}{content_id}/submit/")
        assert submitted.json()["status"] == "pending_review"

        assert world.library_client.post(f"{MANAGE}{content_id}/approve/").status_code == 403
        rejected = admin_client.post(f"{MANAGE}{content_id}/reject/", {"note": "Wrong course"}, format="json")
        assert rejected.json()["status"] == "draft"
        assert rejected.json()["review_note"] == "Wrong course"

        world.library_client.post(f"{MANAGE}{content_id}/submit/")
        approved = admin_client.post(f"{MANAGE}{content_id}/approve/")
        assert approved.status_code == 200
        assert approved.json()["status"] == "published"
        assert Notification.objects.filter(recipient=world.library_user, type="content_review").count() == 2

    def test_archive_and_restore(self, world):
        content_id = world.create_published()
        archived = world.library_client.post(f"{MANAGE}{content_id}/archive/")
        assert archived.json()["status"] == "archived"
        assert world.library_client.post(f"{MANAGE}{content_id}/archive/").status_code == 409
        restored = world.library_client.post(f"{MANAGE}{content_id}/restore/")
        assert restored.json()["status"] == "draft"

    def test_library_deletes_only_drafts(self, world, admin_client):
        draft_id = world.create().json()["id"]
        published_id = world.create_published()
        response = world.library_client.delete(f"{MANAGE}{published_id}/")
        assert response.status_code == 409
        assert err(response)["code"] == "invalid_transition"
        assert world.library_client.delete(f"{MANAGE}{draft_id}/").status_code == 204
        assert admin_client.delete(f"{MANAGE}{published_id}/").status_code == 204
        assert ContentItem.objects.count() == 0

    def test_editing_published_cannot_remove_required_fields(self, world):
        content_id = world.create_published()
        response = world.library_client.patch(f"{MANAGE}{content_id}/", {"category": None}, format="json")
        assert response.status_code == 400
        assert ContentItem.objects.get(pk=content_id).category_id == world.category.pk

    def test_kind_is_immutable(self, world):
        content_id = world.create().json()["id"]
        response = world.library_client.patch(f"{MANAGE}{content_id}/", {"kind": "exam"}, format="json")
        assert response.status_code == 400

    def test_update_title(self, world):
        content_id = world.create_published()
        response = world.library_client.patch(f"{MANAGE}{content_id}/", {"title": "Renamed"}, format="json")
        assert response.status_code == 200
        assert response.json()["title"] == "Renamed"


class TestFileVersions:
    def test_replace_keeps_history_and_serves_current(self, world, student_client):
        content_id = world.create_published()
        new_pdf = pdf_bytes(pages=5)
        response = world.library_client.post(
            f"{MANAGE}{content_id}/file/", {"file": upload("v2.pdf", new_pdf)}, format="multipart"
        )
        assert response.status_code == 201
        assert response.json()["version"] == 2
        versions = world.library_client.get(f"{MANAGE}{content_id}/versions/").json()
        assert [v["version"] for v in versions] == [2, 1]
        assert [v["is_current"] for v in versions] == [True, False]
        served = student_client.get(f"/api/v1/catalog/contents/{content_id}/file/")
        assert b"".join(served.streaming_content) == new_pdf

    def test_preview_draft_file(self, world, student_client):
        content_id = world.create().json()["id"]
        preview = world.library_client.get(f"{MANAGE}{content_id}/file/")
        assert preview.status_code == 200
        assert preview["Content-Disposition"].startswith("inline")
        assert student_client.get(f"/api/v1/catalog/contents/{content_id}/file/").status_code == 404

    def test_cannot_replace_file_of_archived(self, world):
        content_id = world.create_published()
        world.library_client.post(f"{MANAGE}{content_id}/archive/")
        response = world.library_client.post(
            f"{MANAGE}{content_id}/file/", {"file": upload()}, format="multipart"
        )
        assert response.status_code == 409


class TestScope:
    def test_other_library_cannot_see_or_modify(self, world):
        content_id = world.create().json()["id"]
        intruder = LibraryUserFactory()
        intruder.library.scope_faculties.add(world.course.level.faculty)  # same scope, different owner
        client = APIClient()
        authenticate(client, intruder)
        assert client.get(f"{MANAGE}{content_id}/").status_code == 404
        assert client.patch(f"{MANAGE}{content_id}/", {"title": "x"}, format="json").status_code == 404
        assert client.delete(f"{MANAGE}{content_id}/").status_code == 404
        assert client.post(f"{MANAGE}{content_id}/submit/").status_code == 404
        assert client.get(f"{MANAGE}{content_id}/file/").status_code == 404
        assert client.get(MANAGE).json()["count"] == 0

    def test_scope_revocation_removes_access(self, world):
        content_id = world.create().json()["id"]
        world.library_user.library.scope_faculties.clear()
        assert world.library_client.get(f"{MANAGE}{content_id}/").status_code == 404

    def test_course_level_scope(self, world):
        library = world.library_user.library
        library.scope_faculties.clear()
        library.scope_courses.add(world.course)
        assert world.create().status_code == 201

    def test_admin_sees_everything(self, world, admin_client):
        world.create()
        assert admin_client.get(MANAGE).json()["count"] == 1

    def test_admin_can_edit_and_archive_any(self, world, admin_client):
        content_id = world.create_published()
        assert (
            admin_client.patch(f"{MANAGE}{content_id}/", {"title": "Fixed"}, format="json").status_code == 200
        )
        assert admin_client.post(f"{MANAGE}{content_id}/archive/").json()["status"] == "archived"

    def test_filters_search_and_stats(self, world):
        world.create_published(world.lecture_payload(title="مقدمة في التشريح"))
        world.create(world.exam_payload())
        assert world.library_client.get(f"{MANAGE}?status=draft").json()["count"] == 1
        assert world.library_client.get(f"{MANAGE}?search=التشريح").json()["count"] == 1
        stats = world.library_client.get("/api/v1/manage/stats/").json()
        assert stats["total"] == 2
        assert stats["by_status"]["published"] == 1 and stats["by_status"]["draft"] == 1
        assert stats["by_kind"] == {"lecture": 1, "exam": 1}


class TestBulkUpload:
    def test_each_item_reported_independently(self, world):
        items = [
            {**world.lecture_payload(title="Good"), "file_field": "f1"},
            {**world.lecture_payload(title="Bad file"), "file_field": "f2"},
            {**world.lecture_payload(title="Bad course", course=999999), "file_field": "f3"},
        ]
        response = world.library_client.post(
            f"{MANAGE}bulk/",
            {
                "items": json.dumps(items),
                "f1": upload("a.pdf"),
                "f2": upload("b.exe", b"MZ" + b"\x00" * 10),
                "f3": upload("c.pdf"),
            },
            format="multipart",
        )
        assert response.status_code == 200
        results = response.json()["results"]
        assert [r["ok"] for r in results] == [True, False, False]
        assert results[1]["error"]["details"]["reason"] == "extension_not_allowed"
        assert ContentItem.objects.count() == 1
        assert ContentFile.objects.count() == 1

    def test_bad_items_payload(self, world):
        response = world.library_client.post(f"{MANAGE}bulk/", {"items": "not json"}, format="multipart")
        assert response.status_code == 400


class TestLookupsAdmin:
    def test_exam_types_manageable_and_listed(self, admin_client, student_client):
        created = admin_client.post("/api/v1/admin/exam-types/", {"name": "Supplementary"}, format="json")
        assert created.status_code == 201
        names = [r["name"] for r in student_client.get("/api/v1/catalog/exam-types/").json()]
        assert "Supplementary" in names
        assert (
            student_client.post("/api/v1/admin/exam-types/", {"name": "x"}, format="json").status_code == 403
        )

    def test_disabled_exam_type_cannot_be_used(self, world):
        world.exam_type.is_active = False
        world.exam_type.save()
        assert world.create(world.exam_payload()).status_code == 400
