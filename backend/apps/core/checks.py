"""Deployment system checks (run by `manage.py check --deploy`)."""

from django.conf import settings
from django.core.checks import Tags, Warning, register

PROCESS_LOCAL_CACHES = (
    "django.core.cache.backends.locmem.LocMemCache",
    "django.core.cache.backends.dummy.DummyCache",
)


@register(Tags.security, deploy=True)
def shared_cache_check(app_configs, **kwargs):
    """Throttles, login lockouts and settings invalidation need a cache shared by all workers."""
    backend = settings.CACHES["default"]["BACKEND"]
    if backend in PROCESS_LOCAL_CACHES:
        return [
            Warning(
                "The default cache is process-local.",
                hint="Set CACHE_URL=redis://... so rate limits, login lockouts and settings changes "
                "are shared by every worker. Silence unilect.W001 only for a single-process deployment.",
                id="unilect.W001",
            )
        ]
    return []
