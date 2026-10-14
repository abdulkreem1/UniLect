"""Endpoints and options that exist for the mobile client: client config, course path fields,
library-scoped pickers (``in_scope``) and the ``seed_demo`` development dataset."""

import pytest
from django.core.management import call_command
from django.core.management.base import CommandError

from apps.accounts.models import User
from apps.content.models import ContentItem
from apps.devices.models import DeviceChangeRequest
from apps.maintenance.management.commands import seed_demo
from tests.factories import CourseFactory, FacultyFactory, LevelFactory, UniversityFactory

pytestmark = pytest.mark.django_db


def ids(response):
    return {row["id"] for row in response.json()["results"]}


class TestClientConfig:
    def test_any_role_reads_upload_limits(self, student_client, library_client):
        for client in (student_client, library_client):
            response = client.get("/api/v1/config/")
            assert response.status_code == 200
            assert set(response.json()) == {
                "max_upload_size_mb",
                "allowed_extensions",
                "require_content_review",
            }

    def test_reflects_admin_settings(self, admin_client, library_client):
        admin_client.patch(
            "/api/v1/admin/settings/",
            {"max_upload_size_mb": 12, "allowed_extensions": ["pdf"], "require_content_review": True},
            format="json",
        )
        assert library_client.get("/api/v1/config/").json() == {
            "max_upload_size_mb": 12,
            "allowed_extensions": ["pdf"],
            "require_content_review": True,
        }

    def test_requires_authentication(self, api_client):
        assert api_client.get("/api/v1/config/").status_code == 401


def test_catalog_course_carries_its_faculty_and_university(student_client):
    course = CourseFactory()
    body = student_client.get(f"/api/v1/catalog/courses/{course.pk}/").json()
    assert body["faculty"] == course.level.faculty_id
    assert body["university"] == course.level.faculty.university_id


class TestLibraryScopePickers:
    @pytest.fixture
    def world(self, library_user):
        inside_uni, outside_uni = UniversityFactory(), UniversityFactory()
        inside_fac = FacultyFactory(university=inside_uni)
        other_fac = FacultyFactory(university=inside_uni)  # same university, out of scope
        inside_level = LevelFactory(faculty=inside_fac)
        inside = CourseFactory(level=inside_level)
        outside = CourseFactory(level=LevelFactory(faculty=other_fac))
        CourseFactory(level=LevelFactory(faculty=FacultyFactory(university=outside_uni)))
        library_user.library.scope_faculties.set([inside_fac])
        return {
            "uni": inside_uni,
            "fac": inside_fac,
            "level": inside_level,
            "course": inside,
            "outside_course": outside,
        }

    def test_library_sees_only_nodes_with_courses_in_scope(self, library_client, world):
        get = library_client.get
        assert ids(get("/api/v1/catalog/universities/?in_scope=true")) == {world["uni"].pk}
        assert ids(get(f"/api/v1/catalog/faculties/?university={world['uni'].pk}&in_scope=true")) == {
            world["fac"].pk
        }
        assert ids(get(f"/api/v1/catalog/levels/?faculty={world['fac'].pk}&in_scope=true")) == {
            world["level"].pk
        }
        assert ids(get("/api/v1/catalog/courses/?in_scope=true")) == {world["course"].pk}

    def test_without_the_flag_the_full_catalog_is_listed(self, library_client, world):
        listed = ids(library_client.get("/api/v1/catalog/courses/"))
        assert {world["course"].pk, world["outside_course"].pk} <= listed

    def test_flag_is_ignored_for_other_roles(self, student_client, world):
        listed = ids(student_client.get("/api/v1/catalog/courses/?in_scope=true"))
        assert world["outside_course"].pk in listed


class TestSeedDemo:
    def test_creates_a_consistent_dataset_once(self, settings):
        settings.DEBUG = True
        call_command("seed_demo")
        assert User.objects.filter(email=seed_demo.ADMIN, role="admin").exists()
        assert ContentItem.objects.filter(status="published").count() >= 10
        assert ContentItem.objects.filter(status="pending_review").count() == 1
        assert DeviceChangeRequest.objects.filter(status="pending").count() == 1
        assert not User.objects.filter(must_change_password=True).exists()

        call_command("seed_demo")  # idempotent
        assert User.objects.filter(email=seed_demo.ADMIN).count() == 1

    def test_seeded_student_can_browse(self, settings, api_client):
        settings.DEBUG = True
        call_command("seed_demo")
        login = api_client.post(
            "/api/v1/auth/login/",
            {
                "email": seed_demo.STUDENT,
                "password": seed_demo.PASSWORD,
                "device": {"installation_id": "seed-test-device-0001", "platform": "android"},
            },
            format="json",
        )
        assert login.status_code == 200
        api_client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {login.json()['access']}", HTTP_X_DEVICE_ID="seed-test-device-0001"
        )
        contents = api_client.get("/api/v1/catalog/contents/?kind=lecture&search=التوابع").json()
        assert contents["count"] == 0  # lecture 5 is still a draft
        detail = api_client.get("/api/v1/catalog/contents/?kind=exam&page_size=1").json()["results"][0]
        assert api_client.get(detail["file_endpoint"]).status_code == 200

    def test_refuses_without_debug(self, settings):
        settings.DEBUG = False
        with pytest.raises(CommandError):
            call_command("seed_demo")


def test_admin_user_representation_names_university_and_library(admin_client, student, library_user):
    by_id = {
        row["id"]: row for row in admin_client.get("/api/v1/admin/users/?page_size=100").json()["results"]
    }
    assert by_id[str(student.pk)]["university_name"] == student.university.name
    assert by_id[str(library_user.pk)]["library_name"] == library_user.library.name


def test_device_audit_entries_name_the_student(admin_client, student_client, student):
    logs = admin_client.get("/api/v1/admin/audit-logs/?category=device").json()["results"]
    bound = next(log for log in logs if log["action"] == "device.bound")
    assert bound["metadata"]["student"] == student.email
