"""Content use-cases: creation, classification, file versions and the publishing workflow.

Workflow (FR-042, FR-066)::

    draft ──submit──► published                      (review not required, or actor is admin)
    draft ──submit──► pending_review ──approve──► published
                      pending_review ──reject───► draft (with review_note)
    draft | pending_review | published ──archive──► archived ──restore──► draft
    draft ──delete──► (removed)                      (library); admin may delete any state
"""

from __future__ import annotations

import logging

from django.db import transaction
from django.db.models import Max
from django.utils import timezone
from django.utils.translation import gettext as _
from rest_framework import serializers

from apps.academics.models import CourseInstructor
from apps.accounts.models import Role
from apps.audit import services as audit
from apps.config.services import get_settings
from apps.core.exceptions import ApiError, InvalidTransition
from apps.libraries.selectors import course_in_scope
from apps.notifications import services as notifications
from apps.notifications.models import Notification

from .models import ContentFile, ContentItem, CourseFollow
from .search import build_document
from .validation import validate_upload

logger = logging.getLogger(__name__)
Status = ContentItem.Status
Kind = ContentItem.Kind

LECTURE_ONLY = ("lecture_number", "category")
EXAM_ONLY = ("exam_year", "exam_type", "semester")
REQUIRED_TO_PUBLISH = {
    Kind.LECTURE: ("instructor", "category"),
    Kind.EXAM: ("exam_year", "exam_type", "semester"),
}


# --------------------------------------------------------------------------- classification rules


def _value(item: ContentItem, field: str):
    """Raw column value (``<fk>_id`` for relations) without loading related objects."""
    return getattr(item, ContentItem._meta.get_field(field).attname)


def validate_classification(item: ContentItem, actor) -> None:
    """Cross-field rules that must hold for every saved item (FR-037, FR-046)."""
    errors: dict[str, str] = {}
    foreign = EXAM_ONLY if item.kind == Kind.LECTURE else LECTURE_ONLY
    for field in foreign:
        if _value(item, field) is not None:
            errors[field] = _("Not applicable to this content type.")

    if actor.role == Role.LIBRARY and not course_in_scope(actor.library, item.course):
        errors["course"] = _("This course is outside your library's scope.")
    if (
        item.instructor_id
        and not CourseInstructor.objects.filter(
            course_id=item.course_id, instructor_id=item.instructor_id
        ).exists()
    ):
        errors["instructor"] = _("This instructor is not linked to the selected course.")
    if item.semester_id and item.semester.faculty_id != item.course.level.faculty_id:
        errors["semester"] = _("Semester must belong to the course faculty.")
    if item.category_id and not item.category.is_active:
        errors["category"] = _("This category is disabled.")
    if item.exam_type_id and not item.exam_type.is_active:
        errors["exam_type"] = _("This exam type is disabled.")
    if errors:
        raise serializers.ValidationError(errors)


def validate_publishable(item: ContentItem) -> None:
    """FR-078: all mandatory fields of the kind + a current file."""
    errors = {
        field: _("Required before publishing.")
        for field in REQUIRED_TO_PUBLISH[item.kind]
        if _value(item, field) in (None, "")
    }
    if not item.files.filter(is_current=True).exists():
        errors["file"] = _("Upload a file before publishing.")
    if errors:
        raise ApiError(
            _("The content is missing required information."), code="incomplete_content", details=errors
        )


# --------------------------------------------------------------------------- create / update / files


def _audit(action: str, item: ContentItem, actor, request=None, **metadata) -> None:
    audit.record(
        action=f"content.{action}",
        category=audit.Category.CONTENT,
        actor=actor,
        target=item,
        metadata={"kind": item.kind, "status": item.status, **metadata},
        request=request,
    )


def create_content(*, actor, data: dict, upload=None, request=None) -> ContentItem:
    """FR-035/036/037/045. Library staff only; content belongs to the actor's library."""
    if actor.role != Role.LIBRARY:
        raise ApiError(_("Only library accounts can upload content."), code="library_only", status_code=403)
    cfg = get_settings()
    validated = validate_upload(upload, cfg) if upload is not None else None
    stored_name = None
    try:
        with transaction.atomic():
            item = ContentItem(**data, library=actor.library, created_by=actor, updated_by=actor)
            validate_classification(item, actor)
            item.search_document = build_document(item)
            item.save()
            if validated is not None:
                stored_name = _store_file(item, upload, validated, actor).file.name
            _audit("created", item, actor, request, with_file=validated is not None)
    except Exception:
        _delete_stored(stored_name)
        raise
    return item


def update_content(*, item: ContentItem, actor, data: dict, request=None) -> ContentItem:
    """FR-039/065. Published items must stay complete (FR-078)."""
    if "kind" in data and data["kind"] != item.kind:
        raise serializers.ValidationError({"kind": _("The content type cannot be changed.")})
    with transaction.atomic():
        item = ContentItem.objects.select_for_update().get(pk=item.pk)
        changed = sorted(k for k, v in data.items() if getattr(item, k) != v)
        for key, value in data.items():
            setattr(item, key, value)
        item.updated_by = actor
        validate_classification(item, actor)
        if item.status == Status.PUBLISHED:
            validate_publishable(item)
            if changed:
                _requeue_for_review_if_required(item, actor)
        item.search_document = build_document(item)
        item.save()
        _audit("updated", item, actor, request, changed_fields=changed)
    return item


def _requeue_for_review_if_required(item: ContentItem, actor) -> bool:
    """With review enabled (FR-066), a library change to PUBLISHED content goes back to review.

    The item is hidden from students until an administrator approves it again, so unreviewed
    changes never reach students. Administrators' own edits apply immediately.
    """
    if actor.role != Role.LIBRARY or not get_settings().require_content_review:
        return False
    item.status = Status.PENDING_REVIEW
    return True


def _store_file(item: ContentItem, upload, validated, actor) -> ContentFile:
    next_version = (item.files.aggregate(v=Max("version"))["v"] or 0) + 1
    item.files.filter(is_current=True).update(is_current=False)
    content_file = ContentFile(
        content=item,
        version=next_version,
        original_name=validated.original_name,
        extension=validated.extension,
        mime_type=validated.mime_type,
        size_bytes=validated.size_bytes,
        sha256=validated.sha256,
        page_count=validated.page_count,
        uploaded_by=actor,
        is_current=True,
    )
    content_file.file.save(f"upload.{validated.extension}", upload, save=False)
    try:
        content_file.save()
    except Exception:
        _delete_stored(content_file.file.name)  # never leave an orphan if the row cannot be written
        raise
    return content_file


def _delete_stored(name: str | None) -> None:
    if name:
        try:
            ContentFile.file.field.storage.delete(name)
        except OSError:
            logger.warning("Could not delete orphaned file %s", name)


def replace_file(*, item: ContentItem, actor, upload, request=None) -> ContentFile:
    """FR-041: a new version becomes current; old versions are kept for history.

    The student-facing endpoint always serves the current version.
    """
    validated = validate_upload(upload, get_settings())
    stored_name = None
    try:
        with transaction.atomic():
            item = ContentItem.objects.select_for_update().get(pk=item.pk)
            if item.status == Status.ARCHIVED:
                raise InvalidTransition(_("Restore the content before replacing its file."))
            content_file = _store_file(item, upload, validated, actor)
            stored_name = content_file.file.name
            item.updated_by = actor
            requeued = item.status == Status.PUBLISHED and _requeue_for_review_if_required(item, actor)
            item.save(update_fields=["status", "updated_by", "updated_at"])
            if requeued:
                _audit("resubmitted_for_review", item, actor, request)
            _audit(
                "file_replaced", item, actor, request, version=content_file.version, sha256=validated.sha256
            )
    except Exception:
        _delete_stored(stored_name)
        raise
    return content_file


# --------------------------------------------------------------------------- workflow


def _lock(item: ContentItem, allowed_from: set[str]) -> ContentItem:
    locked = ContentItem.objects.select_for_update().get(pk=item.pk)
    if locked.status not in allowed_from:
        raise InvalidTransition(
            _("Not allowed while the content is '%(status)s'.") % {"status": locked.get_status_display()},
            details={"status": locked.status},
        )
    return locked


def _publish(item: ContentItem, actor) -> None:
    first_publication = item.published_at is None
    item.status = Status.PUBLISHED
    item.published_at = item.published_at or timezone.now()
    item.archived_at = None
    item.review_note = ""
    item.updated_by = actor
    item.save()
    if first_publication:
        transaction.on_commit(lambda: notify_followers(item.pk))


def submit(*, item: ContentItem, actor, request=None) -> ContentItem:
    """Library submits a draft; it is published directly unless review is required (FR-066)."""
    with transaction.atomic():
        item = _lock(item, {Status.DRAFT})
        validate_classification(item, actor)
        validate_publishable(item)
        if actor.role == Role.LIBRARY and get_settings().require_content_review:
            item.status = Status.PENDING_REVIEW
            item.updated_by = actor
            item.save(update_fields=["status", "updated_by", "updated_at"])
            _audit("submitted_for_review", item, actor, request)
        else:
            _publish(item, actor)
            _audit("published", item, actor, request)
    return item


def approve(*, item: ContentItem, actor, request=None) -> ContentItem:
    with transaction.atomic():
        item = _lock(item, {Status.PENDING_REVIEW})
        validate_publishable(item)
        _publish(item, actor)
        _audit("approved", item, actor, request)
        _notify_creator(item, _("Your content was approved and published."))
    return item


def reject(*, item: ContentItem, actor, note: str, request=None) -> ContentItem:
    with transaction.atomic():
        item = _lock(item, {Status.PENDING_REVIEW})
        item.status = Status.DRAFT
        item.review_note = note
        item.updated_by = actor
        item.save(update_fields=["status", "review_note", "updated_by", "updated_at"])
        _audit("rejected", item, actor, request, note=note)
        _notify_creator(item, note or _("Your content was returned for changes."))
    return item


def archive(*, item: ContentItem, actor, request=None) -> ContentItem:
    """FR-040/049/065: archived content disappears from the student catalog immediately."""
    with transaction.atomic():
        item = _lock(item, {Status.DRAFT, Status.PENDING_REVIEW, Status.PUBLISHED})
        item.status = Status.ARCHIVED
        item.archived_at = timezone.now()
        item.updated_by = actor
        item.save(update_fields=["status", "archived_at", "updated_by", "updated_at"])
        _audit("archived", item, actor, request)
    return item


def restore(*, item: ContentItem, actor, request=None) -> ContentItem:
    with transaction.atomic():
        item = _lock(item, {Status.ARCHIVED})
        item.status = Status.DRAFT
        item.archived_at = None
        item.updated_by = actor
        item.save(update_fields=["status", "archived_at", "updated_by", "updated_at"])
        _audit("restored", item, actor, request)
    return item


def delete(*, item: ContentItem, actor, request=None) -> None:
    """Library: drafts only (published content is archived instead). Admin: any state."""
    with transaction.atomic():
        allowed = set(Status.values) if actor.role == Role.ADMIN else {Status.DRAFT}
        item = _lock(item, allowed)
        names = list(item.files.values_list("file", flat=True))
        _audit("deleted", item, actor, request, title=item.title)
        item.delete()
        transaction.on_commit(lambda: [_delete_stored(n) for n in names])


# --------------------------------------------------------------------------- notifications


def _notify_creator(item: ContentItem, body: str) -> None:
    if item.created_by_id:
        with notifications.site_language():
            notifications.notify(
                item.created_by,
                Notification.Type.CONTENT_REVIEW,
                _("Content review: %(title)s") % {"title": item.title[:150]},
                body,
                {"content_id": str(item.pk), "status": item.status},
            )


def notify_followers(content_id) -> int:
    """FR-071: notify students who follow the course and opted in."""
    if not get_settings().notify_followers_on_publish:
        return 0
    item = ContentItem.objects.select_related("course").filter(pk=content_id, status=Status.PUBLISHED).first()
    if item is None:
        return 0
    recipients = CourseFollow.objects.filter(
        course=item.course, notify_new_content=True, student__is_active=True, student__role=Role.STUDENT
    ).values_list("student_id", flat=True)
    with notifications.site_language():
        return notifications.notify_many(
            recipients,
            Notification.Type.NEW_CONTENT,
            _("New content in %(course)s") % {"course": item.course.name[:150]},
            item.title,
            {"content_id": str(item.pk), "course_id": item.course_id, "kind": item.kind},
        )
