"""Administrator-editable system settings (FR-069).

Values are validated against hard, code-level bounds in ``settings.py`` so an administrator
can tighten but never widen what the server accepts (e.g. cannot allow executable uploads).
"""

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import MinValueValidator
from django.db import models
from django.utils.translation import gettext_lazy as _


def default_allowed_extensions() -> list[str]:
    return sorted(settings.CONTENT_SUPPORTED_EXTENSIONS)


class SystemSettings(models.Model):
    SINGLETON_PK = 1

    max_upload_size_mb = models.PositiveIntegerField(default=50, validators=[MinValueValidator(1)])
    allowed_extensions = models.JSONField(default=default_allowed_extensions)
    require_content_review = models.BooleanField(
        default=False, help_text="FR-066: library submissions wait for administrator approval."
    )
    notify_followers_on_publish = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )

    class Meta:
        verbose_name_plural = "system settings"
        constraints = [models.CheckConstraint(condition=models.Q(pk=1), name="system_settings_singleton")]

    def __str__(self) -> str:
        return "System settings"

    def clean(self) -> None:
        if self.max_upload_size_mb > settings.CONTENT_MAX_UPLOAD_MB_HARD_LIMIT:
            raise ValidationError(
                {
                    "max_upload_size_mb": _("Cannot exceed %(n)s MB.")
                    % {"n": settings.CONTENT_MAX_UPLOAD_MB_HARD_LIMIT}
                }
            )
        exts = self.allowed_extensions
        if not isinstance(exts, list) or not exts:
            raise ValidationError({"allowed_extensions": _("Provide at least one extension.")})
        unsupported = sorted({str(e).lower() for e in exts} - set(settings.CONTENT_SUPPORTED_EXTENSIONS))
        if unsupported:
            raise ValidationError(
                {"allowed_extensions": _("Unsupported extensions: %(e)s") % {"e": ", ".join(unsupported)}}
            )
