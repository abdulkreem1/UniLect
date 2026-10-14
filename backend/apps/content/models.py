"""Lectures and past exam papers (FR-035..050, FR-078, FR-079).

Both kinds live in ONE table (``ContentItem.kind``) because search, filtering, favorites,
reports, statistics, review and protected delivery all treat them uniformly. Kind-specific
columns are few and are guarded by database check constraints.
"""

import uuid

from django.conf import settings
from django.contrib.postgres.indexes import GinIndex
from django.core.files.storage import storages
from django.db import models
from django.db.models import Q

from apps.core.models import OrderedActiveModel, TimeStampedModel

EXAM_YEAR_MIN = 1950
EXAM_YEAR_MAX = 2100


def private_storage():
    """Callable so the backend can be swapped (filesystem/S3) via settings without migrations."""
    return storages["private"]


def content_file_path(instance, filename: str) -> str:
    # Never reuse the client's filename on disk: random, unguessable key.
    return f"content/{instance.content_id}/{uuid.uuid4().hex}.{instance.extension}"


class LectureCategory(OrderedActiveModel):
    """Admin-managed lecture classification, e.g. theory / practical / summary (assumption A-17)."""

    name = models.CharField(max_length=100, unique=True)

    class Meta:
        ordering = ["sort_order", "name"]
        verbose_name_plural = "lecture categories"

    def __str__(self) -> str:
        return self.name


class ExamType(OrderedActiveModel):
    """Admin-managed exam session type, e.g. first / second / supplementary (FR-048)."""

    name = models.CharField(max_length=100, unique=True)

    class Meta:
        ordering = ["sort_order", "name"]

    def __str__(self) -> str:
        return self.name


class ContentItem(TimeStampedModel):
    class Kind(models.TextChoices):
        LECTURE = "lecture", "Lecture"
        EXAM = "exam", "Exam paper"

    class Status(models.TextChoices):
        DRAFT = "draft", "Draft"
        PENDING_REVIEW = "pending_review", "Pending review"
        PUBLISHED = "published", "Published"
        ARCHIVED = "archived", "Archived"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    kind = models.CharField(max_length=10, choices=Kind.choices)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)
    library = models.ForeignKey("libraries.Library", on_delete=models.PROTECT, related_name="contents")
    course = models.ForeignKey("academics.Course", on_delete=models.PROTECT, related_name="contents")
    instructor = models.ForeignKey(
        "academics.Instructor", on_delete=models.PROTECT, null=True, blank=True, related_name="contents"
    )
    title = models.CharField(max_length=300)
    description = models.TextField(blank=True, max_length=5000)

    # lecture-only
    lecture_number = models.PositiveIntegerField(null=True, blank=True)
    category = models.ForeignKey(
        LectureCategory, on_delete=models.PROTECT, null=True, blank=True, related_name="contents"
    )
    # exam-only
    exam_year = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text="Academic year start, e.g. 2024"
    )
    exam_type = models.ForeignKey(
        ExamType, on_delete=models.PROTECT, null=True, blank=True, related_name="contents"
    )
    semester = models.ForeignKey(
        "academics.Semester", on_delete=models.PROTECT, null=True, blank=True, related_name="exam_contents"
    )

    # Normalised (Arabic-aware) concatenation of title, description, course and instructor names,
    # maintained by content.search.refresh_*; trigram-indexed for fast keyword search (FR-031).
    search_document = models.TextField(blank=True, default="", editable=False)

    review_note = models.TextField(blank=True, max_length=1000)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="+"
    )
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="+"
    )
    published_at = models.DateTimeField(null=True, blank=True)
    archived_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]
        constraints = [
            models.CheckConstraint(
                condition=(
                    Q(kind="lecture", exam_year__isnull=True, exam_type__isnull=True, semester__isnull=True)
                    | Q(kind="exam", lecture_number__isnull=True, category__isnull=True)
                ),
                name="content_kind_specific_fields",
            ),
            # FR-078: nothing is published without its kind's mandatory classification.
            models.CheckConstraint(
                condition=~Q(status="published")
                | Q(kind="lecture", instructor__isnull=False, category__isnull=False)
                | Q(kind="exam", exam_year__isnull=False, exam_type__isnull=False, semester__isnull=False),
                name="published_content_has_required_fields",
            ),
            models.CheckConstraint(
                condition=~Q(status="published") | Q(published_at__isnull=False),
                name="published_content_has_published_at",
            ),
            models.CheckConstraint(condition=~Q(title=""), name="content_title_not_empty"),
            models.CheckConstraint(
                condition=Q(exam_year__isnull=True)
                | Q(exam_year__gte=EXAM_YEAR_MIN, exam_year__lte=EXAM_YEAR_MAX),
                name="content_exam_year_range",
            ),
        ]
        indexes = [
            models.Index(fields=["status", "course"]),
            models.Index(fields=["library", "status"]),
            models.Index(fields=["kind", "status", "-published_at"]),
            models.Index(fields=["course", "instructor", "lecture_number"]),
            GinIndex(fields=["search_document"], name="content_search_trgm", opclasses=["gin_trgm_ops"]),
        ]

    def __str__(self) -> str:
        return self.title


class ContentFile(models.Model):
    """A stored file version. Exactly one version per item is current (FR-041)."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    content = models.ForeignKey(ContentItem, on_delete=models.CASCADE, related_name="files")
    version = models.PositiveIntegerField()
    file = models.FileField(storage=private_storage, upload_to=content_file_path, max_length=255)
    original_name = models.CharField(max_length=255)
    extension = models.CharField(max_length=10)
    mime_type = models.CharField(max_length=100)
    size_bytes = models.PositiveBigIntegerField()
    sha256 = models.CharField(max_length=64)
    page_count = models.PositiveIntegerField(null=True, blank=True)
    is_current = models.BooleanField(default=True)
    uploaded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="+"
    )
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-version"]
        constraints = [
            models.UniqueConstraint(fields=["content", "version"], name="uniq_content_file_version"),
            models.UniqueConstraint(
                fields=["content"], condition=Q(is_current=True), name="one_current_file_per_content"
            ),
        ]

    def __str__(self) -> str:
        return f"{self.content_id} v{self.version}"


class Favorite(models.Model):
    student = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="favorites")
    content = models.ForeignKey(ContentItem, on_delete=models.CASCADE, related_name="favorited_by")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        constraints = [models.UniqueConstraint(fields=["student", "content"], name="uniq_favorite")]

    def __str__(self) -> str:
        return f"{self.student_id} ♥ {self.content_id}"


class CourseFollow(models.Model):
    """Student opts in to new-content notifications for a course (FR-071)."""

    student = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="followed_courses"
    )
    course = models.ForeignKey("academics.Course", on_delete=models.CASCADE, related_name="followers")
    notify_new_content = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        constraints = [models.UniqueConstraint(fields=["student", "course"], name="uniq_course_follow")]

    def __str__(self) -> str:
        return f"{self.student_id} follows {self.course_id}"
