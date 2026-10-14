"""Append-only audit trail of administrative and security-relevant operations (FR-015, FR-068, FR-080)."""

import uuid

from django.conf import settings
from django.db import models


class AuditLog(models.Model):
    class Category(models.TextChoices):
        ACCOUNT = "account", "Account"
        AUTH = "auth", "Authentication"
        DEVICE = "device", "Device"
        CATALOG = "catalog", "Catalog"
        LIBRARY = "library", "Library"
        CONTENT = "content", "Content"
        REPORT = "report", "Report"
        SETTINGS = "settings", "Settings"
        SECURITY = "security", "Security"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    actor_repr = models.CharField(max_length=255, blank=True)
    category = models.CharField(max_length=20, choices=Category.choices)
    action = models.CharField(max_length=64)
    target_type = models.CharField(max_length=64, blank=True)
    target_id = models.CharField(max_length=64, blank=True)
    target_repr = models.CharField(max_length=255, blank=True)
    metadata = models.JSONField(default=dict, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    request_id = models.CharField(max_length=64, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["category", "-created_at"]),
            models.Index(fields=["target_type", "target_id"]),
            models.Index(fields=["actor", "-created_at"]),
            models.Index(fields=["action"]),
        ]

    def __str__(self) -> str:
        return f"{self.created_at:%Y-%m-%d %H:%M} {self.action} {self.target_repr}"
