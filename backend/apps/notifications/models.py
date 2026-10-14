"""In-app notifications (FR-070..072). Push delivery can be added as an extra channel later."""

import uuid

from django.conf import settings
from django.db import models


class Notification(models.Model):
    class Type(models.TextChoices):
        DEVICE_CHANGE_APPROVED = "device_change_approved", "Device change approved"
        DEVICE_CHANGE_REJECTED = "device_change_rejected", "Device change rejected"
        NEW_CONTENT = "new_content", "New content"
        CONTENT_REVIEW = "content_review", "Content review decision"
        REPORT_UPDATE = "report_update", "Report update"
        SYSTEM = "system", "System"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    recipient = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="notifications"
    )
    type = models.CharField(max_length=40, choices=Type.choices)
    title = models.CharField(max_length=200)
    body = models.TextField(blank=True)
    data = models.JSONField(default=dict, blank=True)
    read_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [models.Index(fields=["recipient", "read_at", "-created_at"])]

    def __str__(self) -> str:
        return self.title
