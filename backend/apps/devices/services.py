"""Device binding business rules (FR-008, 010..015, 070, 075).

Concurrency: every operation that may change a student's active device first locks the
student's user row (SELECT ... FOR UPDATE). Combined with the partial unique index
``one_active_device_per_student`` this guarantees a single active device even under
simultaneous logins or approvals.
"""

from __future__ import annotations

from dataclasses import dataclass

from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.utils import timezone
from django.utils.translation import gettext as _
from rest_framework import status

from apps.accounts.models import AuthSession
from apps.audit import services as audit
from apps.core.exceptions import ApiError, Conflict, InvalidTransition
from apps.notifications import services as notifications
from apps.notifications.models import Notification

from .models import DeviceChangeRequest, StudentDevice

User = get_user_model()


@dataclass(frozen=True)
class DeviceInfo:
    installation_id_hash: str
    platform: str
    model_name: str = ""
    app_version: str = ""


class DeviceNotBound(ApiError):
    status_code = status.HTTP_403_FORBIDDEN
    default_code = "device_not_bound"


def _lock_student_id(student_id) -> None:
    list(User.objects.select_for_update().filter(pk=student_id).values_list("pk", flat=True))


def _lock_student(student) -> None:
    _lock_student_id(student.pk)


def active_device(student) -> StudentDevice | None:
    return StudentDevice.objects.filter(student=student, status=StudentDevice.Status.ACTIVE).first()


def pending_request(student) -> DeviceChangeRequest | None:
    return DeviceChangeRequest.objects.filter(
        student=student, status=DeviceChangeRequest.Status.PENDING
    ).first()


def resolve_login_device(student, info: DeviceInfo, request=None) -> StudentDevice:
    """Return the student's device for this login, binding it if this is the first device (FR-008).

    Raises DeviceNotBound when another device is already active (FR-010, FR-075).
    """
    with transaction.atomic():
        _lock_student(student)
        device = active_device(student)
        if device is None:
            device = StudentDevice.objects.create(
                student=student,
                installation_id_hash=info.installation_id_hash,
                platform=info.platform,
                model_name=info.model_name,
                app_version=info.app_version,
                last_seen_at=timezone.now(),
            )
            audit.record(
                action="device.bound",
                category=audit.Category.DEVICE,
                actor=student,
                target=device,
                metadata={
                    "student_id": str(student.pk),
                    "student": student.email,
                    "platform": info.platform,
                    "first_device": True,
                },
                request=request,
            )
            return device
        if device.installation_id_hash == info.installation_id_hash:
            device.last_seen_at = timezone.now()
            device.model_name = info.model_name or device.model_name
            device.app_version = info.app_version or device.app_version
            device.save(update_fields=["last_seen_at", "model_name", "app_version"])
            return device
    raise DeviceNotBound(
        _(
            "This account is already linked to another device. You can submit a device change "
            "request from this device; an administrator will review it."
        )
    )


def _revoke_device_and_sessions(student, reason: str) -> StudentDevice | None:
    device = active_device(student)
    now = timezone.now()
    if device is not None:
        device.status = StudentDevice.Status.REVOKED
        device.revoked_at = now
        device.save(update_fields=["status", "revoked_at"])
    AuthSession.objects.filter(user=student, revoked_at__isnull=True).update(
        revoked_at=now, revoke_reason=reason
    )
    return device


def create_change_request(student, info: DeviceInfo, reason: str = "", request=None) -> DeviceChangeRequest:
    """FR-011: submitted from the NEW device using the restricted device-change token."""
    with transaction.atomic():
        _lock_student(student)
        current = active_device(student)
        if current is None:
            raise Conflict(
                _("No device is currently linked to this account. Sign in again to link this device."),
                code="no_device_bound",
            )
        if current.installation_id_hash == info.installation_id_hash:
            raise Conflict(_("This device is already linked to the account."), code="device_already_bound")
        if pending_request(student) is not None:
            raise Conflict(_("A device change request is already pending."), code="request_already_pending")
        try:
            with transaction.atomic():
                change_request = DeviceChangeRequest.objects.create(
                    student=student,
                    current_device=current,
                    new_installation_id_hash=info.installation_id_hash,
                    new_platform=info.platform,
                    new_model_name=info.model_name,
                    new_app_version=info.app_version,
                    reason=reason,
                )
        except IntegrityError as exc:  # concurrent duplicate submit
            raise Conflict(
                _("A device change request is already pending."), code="request_already_pending"
            ) from exc
        audit.record(
            action="device.change_requested",
            category=audit.Category.DEVICE,
            actor=student,
            target=change_request,
            metadata={"student_id": str(student.pk), "student": student.email, "new_platform": info.platform},
            request=request,
        )
    return change_request


def _lock_for_decision(change_request: DeviceChangeRequest) -> DeviceChangeRequest:
    """Lock in the global order used everywhere in this module: student row FIRST, then the request.

    Every function that touches a student's devices or requests takes the student lock first,
    so concurrent approve/reject/cancel/reset/login operations serialise instead of deadlocking.
    """
    _lock_student_id(change_request.student_id)
    locked = (
        DeviceChangeRequest.objects.select_for_update().select_related("student").get(pk=change_request.pk)
    )
    if locked.status != DeviceChangeRequest.Status.PENDING:
        raise InvalidTransition(_("This request has already been processed."))
    return locked


def _decide(locked: DeviceChangeRequest, status: str, admin, note: str) -> None:
    locked.status = status
    locked.decided_by = admin
    locked.decided_at = timezone.now()
    locked.decision_note = note
    locked.save(update_fields=["status", "decided_by", "decided_at", "decision_note"])


def approve_change_request(change_request: DeviceChangeRequest, admin, note: str = "", request=None):
    """FR-012/013/014: revoke old device + all sessions, bind the requested device, notify the student."""
    with transaction.atomic():
        locked = _lock_for_decision(change_request)
        student = locked.student
        old = _revoke_device_and_sessions(student, AuthSession.RevokeReason.DEVICE_CHANGED)
        new_device = StudentDevice.objects.create(
            student=student,
            installation_id_hash=locked.new_installation_id_hash,
            platform=locked.new_platform,
            model_name=locked.new_model_name,
            app_version=locked.new_app_version,
        )
        _decide(locked, DeviceChangeRequest.Status.APPROVED, admin, note)
        audit.record(
            action="device.change_approved",
            category=audit.Category.DEVICE,
            actor=admin,
            target=locked,
            metadata={
                "student_id": str(student.pk),
                "student": student.email,
                "old_device_id": str(old.pk) if old else None,
                "new_device_id": str(new_device.pk),
            },
            request=request,
        )
        with notifications.site_language():
            notifications.notify(
                student,
                Notification.Type.DEVICE_CHANGE_APPROVED,
                _("Device change approved"),
                _("Your new device has been linked. Please sign in on it."),
                {"request_id": str(locked.pk)},
            )
    return locked


def reject_change_request(change_request: DeviceChangeRequest, admin, note: str = "", request=None):
    with transaction.atomic():
        locked = _lock_for_decision(change_request)
        _decide(locked, DeviceChangeRequest.Status.REJECTED, admin, note)
        audit.record(
            action="device.change_rejected",
            category=audit.Category.DEVICE,
            actor=admin,
            target=locked,
            metadata={"student_id": str(locked.student_id), "student": locked.student.email, "note": note},
            request=request,
        )
        with notifications.site_language():
            notifications.notify(
                locked.student,
                Notification.Type.DEVICE_CHANGE_REJECTED,
                _("Device change rejected"),
                note or _("Your device change request was rejected."),
                {"request_id": str(locked.pk)},
            )
    return locked


def cancel_change_request(change_request: DeviceChangeRequest, student, request=None):
    with transaction.atomic():
        locked = _lock_for_decision(change_request)
        locked.status = DeviceChangeRequest.Status.CANCELLED
        locked.decided_at = timezone.now()
        locked.save(update_fields=["status", "decided_at"])
        audit.record(
            action="device.change_cancelled",
            category=audit.Category.DEVICE,
            actor=student,
            target=locked,
            metadata={"student_id": str(student.pk), "student": student.email},
            request=request,
        )
    return locked


def _unbind(student, admin, reason: str, action: str, request=None) -> None:
    with transaction.atomic():
        _lock_student(student)
        old = _revoke_device_and_sessions(student, reason)
        DeviceChangeRequest.objects.filter(student=student, status=DeviceChangeRequest.Status.PENDING).update(
            status=DeviceChangeRequest.Status.CANCELLED, decided_by=admin, decided_at=timezone.now()
        )
        audit.record(
            action=action,
            category=audit.Category.DEVICE,
            actor=admin,
            target=student,
            metadata={
                "student_id": str(student.pk),
                "student": student.email,
                "old_device_id": str(old.pk) if old else None,
            },
            request=request,
        )


def reset_student_device(student, admin, request=None) -> None:
    """Administrative unbinding (e.g. lost phone): the next successful login binds a new device."""
    _unbind(student, admin, AuthSession.RevokeReason.ADMIN, "device.reset", request)


def release_student_devices(user, admin, request=None) -> None:
    """Called when an account stops being a student: drop its binding and any pending request."""
    _unbind(user, admin, AuthSession.RevokeReason.ROLE_CHANGED, "device.released_on_role_change", request)
