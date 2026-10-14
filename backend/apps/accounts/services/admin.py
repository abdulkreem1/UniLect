"""Administrator account management (FR-001, FR-005, FR-006, FR-059)."""

from __future__ import annotations

from django.contrib.auth.password_validation import validate_password
from django.db import transaction
from django.utils.translation import gettext as _

from apps.audit import services as audit
from apps.core.exceptions import ApiError
from apps.devices import services as device_services

from ..models import AuthSession, Role, User
from .sessions import revoke_all_sessions

# Changing any of these invalidates the user's sessions (their authorisation context changed).
SESSION_SENSITIVE_FIELDS = {"role", "library", "email", "university", "student_number"}


def admin_create_user(*, data: dict, password: str, admin: User, request=None) -> User:
    with transaction.atomic():
        user = User(**data)
        user.email = user.email.lower()
        user.set_password(password)
        user.save()
        audit.record(
            action="account.created",
            category=audit.Category.ACCOUNT,
            actor=admin,
            target=user,
            metadata={"role": user.role},
            request=request,
        )
    return user


def admin_update_user(user: User, data: dict, admin: User, request=None) -> User:
    previous_role = user.role
    changed = sorted(k for k, v in data.items() if getattr(user, k) != v)
    with transaction.atomic():
        for key, value in data.items():
            setattr(user, key, value)
        if "email" in data:
            user.email = user.email.lower()
        user.save()
        if SESSION_SENSITIVE_FIELDS & set(changed):
            revoke_all_sessions(user, AuthSession.RevokeReason.ROLE_CHANGED)
        if previous_role == Role.STUDENT and user.role != Role.STUDENT:
            # A former student must not keep a device binding (or a pending request) around.
            device_services.release_student_devices(user, admin, request=request)
        audit.record(
            action="account.updated",
            category=audit.Category.ACCOUNT,
            actor=admin,
            target=user,
            metadata={"changed_fields": changed},
            request=request,
        )
    return user


def admin_set_active(user: User, active: bool, admin: User, request=None) -> User:
    if user.pk == admin.pk and not active:
        raise ApiError(_("You cannot deactivate your own account."), code="cannot_deactivate_self")
    with transaction.atomic():
        user.is_active = active
        user.save(update_fields=["is_active", "updated_at"])
        if not active:
            revoke_all_sessions(user, AuthSession.RevokeReason.ACCOUNT_DISABLED)
        audit.record(
            action="account.activated" if active else "account.deactivated",
            category=audit.Category.ACCOUNT,
            actor=admin,
            target=user,
            request=request,
        )
    return user


def admin_set_password(
    user: User, password: str, admin: User, must_change: bool = True, request=None
) -> None:
    validate_password(password, user)
    with transaction.atomic():
        user.set_password(password)
        user.must_change_password = must_change
        user.save(update_fields=["password", "must_change_password", "updated_at"])
        revoke_all_sessions(user, AuthSession.RevokeReason.ADMIN)
        audit.record(
            action="account.password_set_by_admin",
            category=audit.Category.ACCOUNT,
            actor=admin,
            target=user,
            request=request,
        )


def admin_revoke_sessions(user: User, admin: User, request=None) -> int:
    with transaction.atomic():
        count = revoke_all_sessions(user, AuthSession.RevokeReason.ADMIN)
        audit.record(
            action="account.sessions_revoked",
            category=audit.Category.ACCOUNT,
            actor=admin,
            target=user,
            metadata={"count": count},
            request=request,
        )
    return count
