from django.db.models import Q, QuerySet

from apps.academics.models import Course

from .models import Library


def scope_course_q(library: Library, prefix: str = "") -> Q:
    """Q object matching courses inside the library scope.

    ``prefix`` lets the same rule be applied from related models, e.g. ``"course__"`` on content.
    Uses subqueries so it composes into one SQL statement.
    """
    return (
        Q(**{f"{prefix}level__faculty__university__in": library.scope_universities.values("pk")})
        | Q(**{f"{prefix}level__faculty__in": library.scope_faculties.values("pk")})
        | Q(**{f"{prefix}pk__in": library.scope_courses.values("pk")})
    )


def courses_in_scope(library: Library) -> QuerySet[Course]:
    return Course.objects.filter(scope_course_q(library))


def course_in_scope(library: Library, course: Course) -> bool:
    return courses_in_scope(library).filter(pk=course.pk).exists()
