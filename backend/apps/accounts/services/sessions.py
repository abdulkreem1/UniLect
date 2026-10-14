"""Credentials, sessions and token rotation (FR-002, 003, 008..010, 014).

Session lifetime: each refresh slides ``expires_at`` forward by the refresh-token lifetime, but never
beyond ``created_at + SESSION_ABSOLUTE_LIFETIME``. After that the user must sign in again.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from django.conf import settings
from django.db import transaction
from django.utils import timezone
from django.utils.translation import gettext as _
from rest_framework import exceptions, status
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.settings import api_settings as jwt_settings
from rest_framework_simplejwt.tokens import RefreshToken

from apps.audit import services as audit
from apps.audit.services import client_ip
from apps.core.exceptions import ApiError
from apps.core.logging import security_logger
from apps.devices import services as device_services
from apps.devices.models import StudentDevice
from apps.devices.utils import device_hash_from_request

from ..models import AuthSession, Role, User
from ..tokens import SESSION_CLAIM, issue_device_change_token, new_refresh_for_session, token_pair


class InvalidCredentials(exceptions.AuthenticationFailed):
    default_code = "invalid_credentials"


class AccountDisabled(ApiError):
    status_code = status.HTTP_403_FORBIDDEN
    default_code = "account_disabled"


def _invalid_credentials() -> InvalidCredentials:
    return InvalidCredentials(_("The email/student number or password is incorrect."))


def _session_ended() -> exceptions.AuthenticationFailed:
    return exceptions.AuthenticationFailed(
        _("Your session has ended. Please sign in again."), code="session_revoked"
    )


# --------------------------------------------------------------------------- credentials


def find_user_for_login(*, email: str | None, student_number: str | None, university_id: int | None):
    if email:
        return User.objects.select_related("library").filter(email__iexact=email.strip()).first()
    return (
        User.objects.select_related("library")
        .filter(role=Role.STUDENT, student_number=student_number.strip(), university_id=university_id)
        .first()
    )


def check_credentials(user: User | None, password: str) -> User:
    if user is None:
        User().set_password(password)  # equalise timing to hinder account enumeration
        raise _invalid_credentials()
    if not user.check_password(password):
        raise _invalid_credentials()
    if not user.is_active:
        # Only revealed after a correct password, so it does not enable enumeration (FR-005).
        raise AccountDisabled(_("This account is disabled. Contact the administrator."))
    if user.role == Role.LIBRARY and not user.library.is_active:
        raise AccountDisabled(_("This library account is disabled. Contact the administrator."))
    return user


# --------------------------------------------------------------------------- sessions


@dataclass
class LoginResult:
    session: AuthSession
    tokens: dict


def _session_expiry(created_at: datetime) -> datetime:
    sliding = timezone.now() + jwt_settings.REFRESH_TOKEN_LIFETIME
    return min(sliding, created_at + settings.SESSION_ABSOLUTE_LIFETIME)


def _open_session(user: User, device: StudentDevice | None, request) -> LoginResult:
    now = timezone.now()
    session = AuthSession(
        user=user,
        device=device,
        expires_at=_session_expiry(now),
        ip_address=client_ip(request),
        user_agent=(request.META.get("HTTP_USER_AGENT", "")[:255] if request else ""),
    )
    refresh = new_refresh_for_session(session)
    session.refresh_jti = refresh[jwt_settings.JTI_CLAIM]
    session.save()
    return LoginResult(session=session, tokens=token_pair(refresh))


def login(user: User, device_info: device_services.DeviceInfo | None, request=None) -> LoginResult:
    """Open a session for verified credentials, enforcing device binding for students."""
    device = None
    if user.role == Role.STUDENT:
        if device_info is None:
            raise ApiError(_("Device information is required for students."), code="device_info_required")
        try:
            device = device_services.resolve_login_device(user, device_info, request=request)
        except device_services.DeviceNotBound as exc:
            security_logger.warning(
                "Student login from unbound device",
                extra={"event": "unbound_device_login", "user_id": str(user.pk)},
            )
            audit.record(
                action="auth.login_unbound_device",
                category=audit.Category.SECURITY,
                actor=user,
                target=user,
                request=request,
            )
            pending = device_services.pending_request(user)
            exc.details = {
                "device_change_token": issue_device_change_token(
                    user,
                    device_info.installation_id_hash,
                    device_info.platform,
                    device_info.model_name,
                    device_info.app_version,
                ),
                "device_change_token_expires_in": int(settings.DEVICE_CHANGE_TOKEN_LIFETIME.total_seconds()),
                "pending_request": (
                    {"id": str(pending.pk), "created_at": pending.created_at.isoformat()} if pending else None
                ),
            }
            raise
    result = _open_session(user, device, request)
    User.objects.filter(pk=user.pk).update(last_login=timezone.now())
    audit.record(action="auth.login", category=audit.Category.AUTH, actor=user, target=user, request=request)
    return result


def refresh_session(raw_refresh: str, request) -> dict:
    """Rotate the refresh token. Re-use of an already rotated token revokes the whole session."""
    try:
        token = RefreshToken(raw_refresh)
    except TokenError as exc:
        raise exceptions.AuthenticationFailed(
            _("Token is invalid or expired."), code="token_not_valid"
        ) from exc

    reused = False
    with transaction.atomic():
        session = (
            AuthSession.objects.select_for_update(of=("self",))
            .select_related("user", "device")
            .filter(pk=token.get(SESSION_CLAIM))
            .first()
        )
        if session is None or not session.is_active or str(session.user_id) != str(token.get("user_id")):
            raise _session_ended()
        if session.refresh_jti != token[jwt_settings.JTI_CLAIM]:
            # Commit the revocation BEFORE raising (raising inside atomic() would roll it back).
            session.revoked_at = timezone.now()
            session.revoke_reason = AuthSession.RevokeReason.TOKEN_REUSE
            session.save(update_fields=["revoked_at", "revoke_reason"])
            audit.record(
                action="auth.refresh_reuse",
                category=audit.Category.SECURITY,
                target=session.user,
                request=request,
            )
            reused = True
    if reused:
        security_logger.warning(
            "Refresh token reuse detected; session revoked",
            extra={"event": "refresh_reuse", "user_id": str(session.user_id)},
        )
        raise _session_ended()

    with transaction.atomic():
        session = (
            AuthSession.objects.select_for_update(of=("self",))
            .select_related("user", "device")
            .get(pk=session.pk)
        )
        if not session.is_active or session.refresh_jti != token[jwt_settings.JTI_CLAIM]:
            raise _session_ended()  # lost a race with a concurrent refresh/revocation
        user = session.user
        if not user.is_active:
            raise exceptions.AuthenticationFailed(_("This account is disabled."), code="account_disabled")
        if user.role == Role.STUDENT:
            device = session.device
            if device is None or device.status != StudentDevice.Status.ACTIVE:
                raise _session_ended()
            if device_hash_from_request(request) != device.installation_id_hash:
                raise exceptions.PermissionDenied(
                    _("This account is bound to another device."), code="device_mismatch"
                )

        refresh = new_refresh_for_session(session)
        session.refresh_jti = refresh[jwt_settings.JTI_CLAIM]
        session.expires_at = _session_expiry(session.created_at)
        session.last_used_at = timezone.now()
        session.save(update_fields=["refresh_jti", "expires_at", "last_used_at"])
    return token_pair(refresh)


def revoke_session(session: AuthSession, reason: str) -> None:
    AuthSession.objects.filter(pk=session.pk, revoked_at__isnull=True).update(
        revoked_at=timezone.now(), revoke_reason=reason
    )


def revoke_all_sessions(user: User, reason: str, keep: AuthSession | None = None) -> int:
    qs = AuthSession.objects.filter(user=user, revoked_at__isnull=True)
    if keep is not None:
        qs = qs.exclude(pk=keep.pk)
    return qs.update(revoked_at=timezone.now(), revoke_reason=reason)


def logout(session: AuthSession, request=None) -> None:
    revoke_session(session, AuthSession.RevokeReason.LOGOUT)
    audit.record(
        action="auth.logout",
        category=audit.Category.AUTH,
        actor=session.user,
        target=session.user,
        request=request,
    )
