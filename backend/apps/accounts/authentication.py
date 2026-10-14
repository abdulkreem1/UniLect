"""Authentication enforcing session revocation and device binding on every request (FR-009, FR-014).

Flow per request:
  1. Verify the JWT signature, expiry and type (``access``).
  2. Load the AuthSession referenced by the ``sid`` claim; reject if revoked/expired.
  3. Reject inactive users (FR-005) — even with an otherwise valid token.
  4. Students: the session's device must still be the ACTIVE bound device, and the
     ``X-Device-ID`` header must hash to that device (a copied token is useless elsewhere).
  5. Users flagged ``must_change_password`` may only reach a small allow-list of endpoints.
"""

from datetime import timedelta

from django.utils import timezone
from django.utils.translation import gettext_lazy as _
from drf_spectacular.extensions import OpenApiAuthenticationExtension
from rest_framework import exceptions
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import AccessToken

from apps.core.logging import security_logger
from apps.devices.models import StudentDevice
from apps.devices.utils import device_hash_from_request

from .models import AuthSession, Role
from .tokens import SESSION_CLAIM, DeviceChangeToken

LAST_USED_WRITE_INTERVAL = timedelta(minutes=5)
PASSWORD_CHANGE_ALLOWED_URL_NAMES = {"auth-password-change", "auth-logout", "me"}


class DeviceMismatch(exceptions.PermissionDenied):
    default_code = "device_mismatch"
    default_detail = _("This account is bound to another device. Submit a device change request.")


class PasswordChangeRequired(exceptions.PermissionDenied):
    default_code = "password_change_required"
    default_detail = _("You must change your password before continuing.")


def _invalid(code: str, message) -> exceptions.AuthenticationFailed:
    return exceptions.AuthenticationFailed(message, code=code)


class SessionJWTAuthentication(JWTAuthentication):
    def authenticate(self, request):
        header = self.get_header(request)
        if header is None:
            return None
        raw = self.get_raw_token(header)
        if raw is None:
            return None
        try:
            token = AccessToken(raw)
        except TokenError as exc:
            raise _invalid("token_not_valid", _("Token is invalid or expired.")) from exc

        sid = token.get(SESSION_CLAIM)
        session = (
            AuthSession.objects.select_related("user", "user__library", "device").filter(pk=sid).first()
            if sid
            else None
        )
        if session is None or not session.is_active or str(session.user_id) != str(token.get("user_id")):
            raise _invalid("session_revoked", _("Your session has ended. Please sign in again."))

        user = session.user
        if not user.is_active:
            raise _invalid("account_disabled", _("This account is disabled."))

        if user.role == Role.STUDENT:
            self._check_device(request, session)

        self._check_password_change(request, user)
        self._touch(session)
        request._request.auth_session = session
        return user, token

    @staticmethod
    def _check_device(request, session: AuthSession) -> None:
        device = session.device
        header_hash = device_hash_from_request(request)
        if device is None or device.status != StudentDevice.Status.ACTIVE:
            # Device was replaced/reset after this session was created.
            raise _invalid("session_revoked", _("Your session has ended. Please sign in again."))
        if header_hash != device.installation_id_hash:
            security_logger.warning(
                "Device mismatch on authenticated request",
                extra={"event": "device_mismatch", "user_id": str(session.user_id)},
            )
            raise DeviceMismatch()

    @staticmethod
    def _check_password_change(request, user) -> None:
        if not user.must_change_password:
            return
        match = getattr(request._request, "resolver_match", None)
        if match is None or match.url_name not in PASSWORD_CHANGE_ALLOWED_URL_NAMES:
            raise PasswordChangeRequired()

    @staticmethod
    def _touch(session: AuthSession) -> None:
        now = timezone.now()
        if now - session.last_used_at > LAST_USED_WRITE_INTERVAL:
            AuthSession.objects.filter(pk=session.pk).update(last_used_at=now)


class DeviceChangeTokenAuthentication(JWTAuthentication):
    """Accepts only the restricted device-change token, and only from the device it was issued to."""

    def authenticate(self, request):
        header = self.get_header(request)
        raw = self.get_raw_token(header) if header else None
        if raw is None:
            return None
        try:
            token = DeviceChangeToken(raw)
        except TokenError as exc:
            raise _invalid("token_not_valid", _("Token is invalid or expired.")) from exc
        try:
            user = self.get_user(token)
        except exceptions.AuthenticationFailed as exc:
            raise _invalid("token_not_valid", _("Token is invalid or expired.")) from exc
        if not user.is_active or user.role != Role.STUDENT:
            raise _invalid("token_not_valid", _("Token is invalid or expired."))
        if device_hash_from_request(request) != token.get("dev"):
            raise DeviceMismatch()
        return user, token


class SessionJWTAuthenticationScheme(OpenApiAuthenticationExtension):
    target_class = "apps.accounts.authentication.SessionJWTAuthentication"
    name = "BearerAuth"

    def get_security_definition(self, auto_schema):
        return {
            "type": "http",
            "scheme": "bearer",
            "bearerFormat": "JWT",
            "description": "Access token from /auth/login. Students must also send the X-Device-ID header.",
        }


class DeviceChangeTokenAuthenticationScheme(OpenApiAuthenticationExtension):
    target_class = "apps.accounts.authentication.DeviceChangeTokenAuthentication"
    name = "DeviceChangeToken"

    def get_security_definition(self, auto_schema):
        return {
            "type": "http",
            "scheme": "bearer",
            "description": "Restricted token returned with the device_not_bound login error.",
        }
