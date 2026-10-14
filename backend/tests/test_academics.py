"""Catalog administration and student browsing (FR-016..028)."""

import pytest
from django.db import IntegrityError

from apps.academics.models import Level
from apps.audit.models import AuditLog
from tests.factories import (
    CourseFactory,
    CourseInstructorFactory,
    FacultyFactory,
    InstructorFactory,
    LevelFactory,
    SemesterFactory,
    SpecializationFactory,
    UniversityFactory,
)

pytestmark = pytest.mark.django_db


def ids(response):
    return {row["id"] for row in response.json()["results"]}


class TestAdminCatalog:
    def test_create_hierarchy(self, admin_client):
        uni = admin_client.post("/api/v1/admin/universities/", {"name": "Damascus University"}, format="json")
        assert uni.status_code == 201
        fac = admin_client.post(
            "/api/v1/admin/faculties/", {"name": "Medicine", "university": uni.json()["id"]}, format="json"
        )
        assert fac.status_code == 201
        lvl = admin_client.post(
            "/api/v1/admin/levels/",
            {"name": "First year", "number": 1, "faculty": fac.json()["id"]},
            format="json",
        )
        assert lvl.status_code == 201
        course = admin_client.post(
            "/api/v1/admin/courses/", {"name": "Anatomy", "level": lvl.json()["id"]}, format="json"
        )
        assert course.status_code == 201
        assert AuditLog.objects.filter(action="university.created").exists()

    def test_faculty_requires_valid_university(self, admin_client):
        response = admin_client.post(
            "/api/v1/admin/faculties/", {"name": "X", "university": 999999}, format="json"
        )
        assert response.status_code == 400

    def test_duplicate_level_number_in_faculty(self, admin_client):
        level = LevelFactory(number=1)
        response = admin_client.post(
            "/api/v1/admin/levels/", {"name": "dup", "number": 1, "faculty": level.faculty_id}, format="json"
        )
        assert response.status_code == 400

    def test_course_semester_must_match_faculty(self, admin_client):
        level = LevelFactory()
        foreign_semester = SemesterFactory()
        response = admin_client.post(
            "/api/v1/admin/courses/",
            {"name": "C", "level": level.pk, "semester": foreign_semester.pk},
            format="json",
        )
        assert response.status_code == 400
        assert "semester" in response.json()["error"]["details"]["fields"]

    def test_course_specialization_must_match_faculty(self, admin_client):
        level = LevelFactory()
        response = admin_client.post(
            "/api/v1/admin/courses/",
            {"name": "C", "level": level.pk, "specializations": [SpecializationFactory().pk]},
            format="json",
        )
        assert response.status_code == 400

    def test_deleting_parent_with_children_is_conflict(self, admin_client):
        faculty = FacultyFactory()
        response = admin_client.delete(f"/api/v1/admin/universities/{faculty.university_id}/")
        assert response.status_code == 409
        assert response.json()["error"]["code"] == "protected"

    def test_delete_leaf(self, admin_client):
        uni = UniversityFactory()
        assert admin_client.delete(f"/api/v1/admin/universities/{uni.pk}/").status_code == 204

    def test_link_instructor_once(self, admin_client):
        link = CourseInstructorFactory()
        response = admin_client.post(
            "/api/v1/admin/course-instructors/",
            {"course": link.course_id, "instructor": link.instructor_id},
            format="json",
        )
        assert response.status_code == 400

    def test_instructor_from_other_university_rejected(self, admin_client):
        course = CourseFactory()
        instructor = InstructorFactory(university=UniversityFactory())
        response = admin_client.post(
            "/api/v1/admin/course-instructors/",
            {"course": course.pk, "instructor": instructor.pk},
            format="json",
        )
        assert response.status_code == 400

    def test_students_cannot_administer(self, student_client):
        assert student_client.post("/api/v1/admin/universities/", {"name": "x"}).status_code == 403

    def test_level_number_check_constraint(self):
        with pytest.raises(IntegrityError):
            Level.objects.create(faculty=FacultyFactory(), name="zero", number=0)


class TestStudentBrowsing:
    def test_only_active_universities_visible(self, student_client):
        visible = UniversityFactory()
        hidden = UniversityFactory(is_active=False)
        result = ids(student_client.get("/api/v1/catalog/universities/"))
        assert visible.pk in result and hidden.pk not in result

    def test_faculties_filtered_by_university_and_parent_activity(self, student_client):
        f1 = FacultyFactory()
        f2 = FacultyFactory()
        hidden_parent = FacultyFactory(university__is_active=False)
        result = ids(student_client.get(f"/api/v1/catalog/faculties/?university={f1.university_id}"))
        assert result == {f1.pk}
        all_result = ids(student_client.get("/api/v1/catalog/faculties/"))
        assert f2.pk in all_result and hidden_parent.pk not in all_result

    def test_levels_of_faculty(self, student_client):
        level = LevelFactory()
        LevelFactory()
        assert ids(student_client.get(f"/api/v1/catalog/levels/?faculty={level.faculty_id}")) == {level.pk}

    def test_courses_of_level_hide_inactive_chain(self, student_client):
        course = CourseFactory()
        CourseFactory(level=course.level, is_active=False)
        CourseFactory(level__is_active=False)
        assert ids(student_client.get(f"/api/v1/catalog/courses/?level={course.level_id}")) == {course.pk}
        hidden = CourseFactory(level__faculty__university__is_active=False)
        assert student_client.get(f"/api/v1/catalog/courses/{hidden.pk}/").status_code == 404

    def test_specialization_filter_includes_common_courses(self, student_client):
        level = LevelFactory()
        spec = SpecializationFactory(faculty=level.faculty)
        other_spec = SpecializationFactory(faculty=level.faculty)
        common = CourseFactory(level=level)
        specific = CourseFactory(level=level)
        specific.specializations.add(spec)
        excluded = CourseFactory(level=level)
        excluded.specializations.add(other_spec)
        result = ids(
            student_client.get(f"/api/v1/catalog/courses/?level={level.pk}&specialization={spec.pk}")
        )
        assert result == {common.pk, specific.pk}

    def test_order_follows_sort_order(self, student_client):
        b = UniversityFactory(name="B", sort_order=1)
        a = UniversityFactory(name="A", sort_order=2)
        rows = student_client.get("/api/v1/catalog/universities/").json()["results"]
        assert [r["id"] for r in rows if r["id"] in (a.pk, b.pk)] == [b.pk, a.pk]

    def test_course_instructors_in_defined_order(self, student_client):
        course = CourseFactory()
        second = CourseInstructorFactory(course=course, sort_order=2).instructor
        first = CourseInstructorFactory(course=course, sort_order=1).instructor
        CourseInstructorFactory(course=course, instructor__is_active=False)
        rows = student_client.get(f"/api/v1/catalog/courses/{course.pk}/instructors/").json()
        assert [r["id"] for r in rows] == [first.pk, second.pk]

    def test_catalog_read_only_for_students(self, student_client):
        assert student_client.post("/api/v1/catalog/universities/", {"name": "x"}).status_code == 405
