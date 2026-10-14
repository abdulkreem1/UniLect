"""Student-facing visibility of the catalog: a node is visible only if it and all its ancestors are active."""

from django.db.models import Q, QuerySet

from .models import Course, Faculty, Instructor, Level, Semester, Specialization, University

ACTIVE_FACULTY = Q(faculty__is_active=True, faculty__university__is_active=True)
ACTIVE_COURSE_CHAIN = Q(
    is_active=True,
    level__is_active=True,
    level__faculty__is_active=True,
    level__faculty__university__is_active=True,
)


def visible_universities() -> QuerySet[University]:
    return University.objects.filter(is_active=True)


def visible_faculties() -> QuerySet[Faculty]:
    return Faculty.objects.filter(is_active=True, university__is_active=True)


def visible_levels() -> QuerySet[Level]:
    return Level.objects.filter(ACTIVE_FACULTY, is_active=True)


def visible_semesters() -> QuerySet[Semester]:
    return Semester.objects.filter(ACTIVE_FACULTY, is_active=True)


def visible_specializations() -> QuerySet[Specialization]:
    return Specialization.objects.filter(ACTIVE_FACULTY, is_active=True)


def visible_courses() -> QuerySet[Course]:
    return Course.objects.filter(ACTIVE_COURSE_CHAIN)


def visible_instructors_for_course(course: Course) -> QuerySet[Instructor]:
    return Instructor.objects.filter(is_active=True, course_links__course=course).order_by(
        "course_links__sort_order", "sort_order", "full_name"
    )
