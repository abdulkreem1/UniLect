"""Student ↔ device binding and device-change workflow (FR-008..015, FR-075)."""

import uuid

from django.conf import settings
from django.db import models
from django.db.models import Q


class Platform(models.TextChoices):
    ANDROID = "android", "Android"
    IOS = "ios", "iOS"


class StudentDevice(models.Model):
    """A device bound to a student. At most one ACTIVE device per student, enforced by the database.

    The installation id is a client-generated secret; only its keyed hash is stored.
    """

    class Status(models.TextChoices):
        ACTIVE = "active", "Active"
        REVOKED = "revoked", "Revoked"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    student = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="devices")
    installation_id_hash = models.CharField(max_length=64)
    platform = models.CharField(max_length=10, choices=Platform.choices)
    model_name = models.CharField(max_length=100, blank=True)
    app_version = models.CharField(max_length=30, blank=True)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.ACTIVE)
    bound_at = models.DateTimeField(auto_now_add=True)
    last_seen_at = models.DateTimeField(null=True, blank=True)
    revoked_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-bound_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["student"], condition=Q(status="active"), name="one_active_device_per_student"
            ),
        ]
        indexes = [models.Index(fields=["student", "status"])]

    def __str__(self) -> str:
        return f"{self.get_platform_display()} {self.model_name}".strip()


class DeviceChangeRequest(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending review"
        APPROVED = "approved", "Approved"
        REJECTED = "rejected", "Rejected"
        CANCELLED = "cancelled", "Cancelled"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    student = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="device_change_requests"
    )
    current_device = models.ForeignKey(
        StudentDevice, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    new_installation_id_hash = models.CharField(max_length=64)
    new_platform = models.CharField(max_length=10, choices=Platform.choices)
    new_model_name = models.CharField(max_length=100, blank=True)
    new_app_version = models.CharField(max_length=30, blank=True)
    reason = models.TextField(blank=True, max_length=1000)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    decided_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    decided_at = models.DateTimeField(null=True, blank=True)
    decision_note = models.TextField(blank=True, max_length=1000)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["student"],
                condition=Q(status="pending"),
                name="one_pending_device_request_per_student",
            ),
            models.CheckConstraint(
                condition=Q(status="pending") | Q(decided_at__isnull=False),
                name="decided_request_has_decided_at",
            ),
        ]
        indexes = [models.Index(fields=["status", "-created_at"])]

    def __str__(self) -> str:
        return f"Device change request {self.pk} ({self.status})"
