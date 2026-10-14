"""Student reports about wrong / duplicate / inappropriate content (FR-073, FR-074)."""

import uuid

from django.conf import settings
from django.db import models
from django.db.models import Q


class ContentReport(models.Model):
    class Reason(models.TextChoices):
        WRONG = "wrong", "Wrong or incorrect file"
        DUPLICATE = "duplicate", "Duplicate"
        INAPPROPRIATE = "inappropriate", "Inappropriate"
        OTHER = "other", "Other"

    class Status(models.TextChoices):
        OPEN = "open", "Open"
        IN_REVIEW = "in_review", "In review"
        RESOLVED = "resolved", "Resolved"
        REJECTED = "rejected", "Rejected"

    OPEN_STATES = (Status.OPEN, Status.IN_REVIEW)
    TRANSITIONS = {
        Status.OPEN: {Status.IN_REVIEW, Status.RESOLVED, Status.REJECTED},
        Status.IN_REVIEW: {Status.RESOLVED, Status.REJECTED},
        Status.RESOLVED: set(),
        Status.REJECTED: set(),
    }

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    content = models.ForeignKey("content.ContentItem", on_delete=models.CASCADE, related_name="reports")
    reporter = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="content_reports"
    )
    reason = models.CharField(max_length=20, choices=Reason.choices)
    message = models.TextField(blank=True, max_length=2000)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.OPEN)
    handled_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["content", "reporter"],
                condition=Q(status__in=["open", "in_review"]),
                name="one_open_report_per_reporter_and_content",
            )
        ]
        indexes = [models.Index(fields=["status", "-created_at"])]

    def __str__(self) -> str:
        return f"Report {self.pk} ({self.status})"


class ReportAction(models.Model):
    """History of status changes and notes on a report (FR-074)."""

    report = models.ForeignKey(ContentReport, on_delete=models.CASCADE, related_name="actions")
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="+"
    )
    from_status = models.CharField(max_length=20, choices=ContentReport.Status.choices)
    to_status = models.CharField(max_length=20, choices=ContentReport.Status.choices)
    note = models.TextField(blank=True, max_length=2000)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]

    def __str__(self) -> str:
        return f"{self.from_status} → {self.to_status}"
