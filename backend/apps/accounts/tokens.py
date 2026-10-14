"""JWT issuance. Every token is bound to an AuthSession through the ``sid`` claim."""

from django.conf import settings
from rest_framework_simplejwt.settings import api_settings
from rest_framework_simplejwt.tokens import RefreshToken, Token

from .models import AuthSession

SESSION_CLAIM = "sid"


class DeviceChangeToken(Token):
    """Short-lived, restricted token issued when a student logs in from an unbound device (FR-010).

    It can ONLY be used on the device-change-request endpoints and is rejected everywhere else
    (its ``token_type`` differs from ``access``).
    """

    token_type = "device_change"  # noqa: S105 (a token kind, not a secret)
    lifetime = settings.DEVICE_CHANGE_TOKEN_LIFETIME


def new_refresh_for_session(session: AuthSession) -> RefreshToken:
    refresh = RefreshToken.for_user(session.user)
    refresh[SESSION_CLAIM] = str(session.pk)
    return refresh


def token_pair(refresh: RefreshToken) -> dict:
    access = refresh.access_token  # copies the sid claim
    return {
        "access": str(access),
        "refresh": str(refresh),
        "token_type": "Bearer",
        "access_expires_in": int(api_settings.ACCESS_TOKEN_LIFETIME.total_seconds()),
        "refresh_expires_in": int(api_settings.REFRESH_TOKEN_LIFETIME.total_seconds()),
    }


def issue_device_change_token(
    user, device_hash: str, platform: str, model_name: str, app_version: str
) -> str:
    token = DeviceChangeToken.for_user(user)
    token["dev"] = device_hash
    token["platform"] = platform
    token["model"] = model_name[:100]
    token["app_version"] = app_version[:30]
    return str(token)
