"""Password change and reset (FR-004)."""

from __future__ import annotations

from django.conf import settings
from django.contrib.auth.password_validation import validate_password
from django.contrib.auth.tokens import default_token_generator
from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.mail import send_mail
from django.db import transaction
from django.utils.encoding import force_bytes, force_str
from django.utils.http import urlsafe_base64_decode, urlsafe_base64_encode
from django.utils.translation import gettext as _
from django.utils.translation import override

from apps.audit import services as audit
from apps.core.exceptions import ApiError

from ..models import AuthSession, User
from .sessions import revoke_all_sessions


def change_password(user: User, current_password: str, new_password: str, session, request=None) -> None:
    if not user.check_password(current_password):
        raise ApiError(_("Current password is incorrect."), code="invalid_current_password")
    validate_password(new_password, user)
    with transaction.atomic():
        user.set_password(new_password)
        user.must_change_password = False
        user.save(update_fields=["password", "must_change_password", "updated_at"])
        revoke_all_sessions(user, AuthSession.RevokeReason.PASSWORD_CHANGED, keep=session)
        audit.record(
            action="account.password_changed",
            category=audit.Category.ACCOUNT,
            actor=user,
            target=user,
            request=request,
        )


def _reset_email(link: str) -> tuple[str, str]:
    minutes = settings.PASSWORD_RESET_TIMEOUT // 60
    subject = _("UniLect password reset")
    body = _(
        "A password reset was requested for your UniLect account.\n\n"
        "Open this link to choose a new password (valid for %(minutes)s minutes):\n%(link)s\n\n"
        "If you did not request this, ignore this email."
    ) % {"minutes": minutes, "link": link}
    return str(subject), body


def request_password_reset(email: str, request=None) -> None:
    """Always behaves identically whether or not the email exists (no enumeration)."""
    user = User.objects.filter(email__iexact=email.strip(), is_active=True).first()
    if user is None:
        return
    uid = urlsafe_base64_encode(force_bytes(user.pk))
    token = default_token_generator.make_token(user)
    link = settings.PASSWORD_RESET_URL_TEMPLATE.format(uid=uid, token=token)
    with override(settings.LANGUAGE_CODE):  # emails use the site language, not the request's
        subject, body = _reset_email(link)
    transaction.on_commit(lambda: send_mail(subject, body, settings.DEFAULT_FROM_EMAIL, [user.email]))
    audit.record(
        action="account.password_reset_requested",
        category=audit.Category.ACCOUNT,
        target=user,
        request=request,
    )


def confirm_password_reset(uid: str, token: str, new_password: str, request=None) -> User:
    invalid = ApiError(_("The reset link is invalid or has expired."), code="invalid_reset_token")
    try:
        user = User.objects.get(pk=force_str(urlsafe_base64_decode(uid)), is_active=True)
    except (User.DoesNotExist, ValueError, TypeError, OverflowError, DjangoValidationError) as exc:
        raise invalid from exc  # unknown user or malformed uid (not base64 / not a UUID)
    if not default_token_generator.check_token(user, token):  # single-use: hash includes password
        raise invalid
    validate_password(new_password, user)
    with transaction.atomic():
        user.set_password(new_password)
        user.must_change_password = False
        user.save(update_fields=["password", "must_change_password", "updated_at"])
        revoke_all_sessions(user, AuthSession.RevokeReason.PASSWORD_CHANGED)
        audit.record(
            action="account.password_reset_completed",
            category=audit.Category.ACCOUNT,
            actor=user,
            target=user,
            request=request,
        )
    return user
