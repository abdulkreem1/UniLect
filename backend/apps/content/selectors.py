"""Single source of truth for who may see/manage which content (FR-039, 049, 056, 061, 079)."""

from django.db.models import Exists, F, OuterRef, Prefetch, Q, QuerySet

from apps.accounts.models import Role
from apps.libraries.selectors import scope_course_q

from .models import ContentFile, ContentItem, Favorite

STUDENT_VISIBLE = {
    "status": ContentItem.Status.PUBLISHED,
    "course__is_active": True,
    "course__level__is_active": True,
    "course__level__faculty__is_active": True,
    "course__level__faculty__university__is_active": True,
}

_RELATED = (
    "course__level__faculty__university",
    "course__semester",
    "instructor",
    "category",
    "exam_type",
    "semester",
)


def with_current_file(qs: QuerySet[ContentItem]) -> QuerySet[ContentItem]:
    return qs.prefetch_related(
        Prefetch("files", queryset=ContentFile.objects.filter(is_current=True), to_attr="current_files")
    )


# Content of a deactivated instructor is hidden too: the browse path (course → instructor → lectures,
# FR-028/029) no longer shows that instructor, so search must not expose it either.
# Deactivated lookups (category / exam type) only block NEW use; they never hide existing content.
ACTIVE_INSTRUCTOR = Q(instructor__isnull=True) | Q(instructor__is_active=True)


def visible_contents(user=None) -> QuerySet[ContentItem]:
    """Published content in an active academic path, as seen in the student catalog."""
    qs = ContentItem.objects.filter(ACTIVE_INSTRUCTOR, **STUDENT_VISIBLE).select_related(*_RELATED)
    if user is not None and user.role == Role.STUDENT:
        qs = qs.annotate(is_favorite=Exists(Favorite.objects.filter(student=user, content=OuterRef("pk"))))
    return with_current_file(qs).order_by(F("lecture_number").asc(nulls_last=True), "-published_at")


def manageable_contents(user) -> QuerySet[ContentItem]:
    """Admin: everything. Library staff: own library's content that is inside its current scope."""
    qs = ContentItem.objects.select_related(*_RELATED, "library", "created_by")
    if user.role == Role.ADMIN:
        pass
    elif user.role == Role.LIBRARY and user.library_id:
        qs = qs.filter(scope_course_q(user.library, prefix="course__"), library=user.library)
    else:
        qs = qs.none()
    return with_current_file(qs)


def current_file(item: ContentItem) -> ContentFile | None:
    prefetched = getattr(item, "current_files", None)
    if prefetched is not None:
        return prefetched[0] if prefetched else None
    return item.files.filter(is_current=True).first()
