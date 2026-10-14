from django.core.cache import cache
from django.db import transaction

from apps.audit import services as audit

from .models import SystemSettings

CACHE_KEY = "system-settings:v1"
CACHE_TTL = 60


def get_settings() -> SystemSettings:
    cached = cache.get(CACHE_KEY)
    if cached is not None:
        return cached
    obj, _ = SystemSettings.objects.get_or_create(pk=SystemSettings.SINGLETON_PK)
    cache.set(CACHE_KEY, obj, CACHE_TTL)
    return obj


def update_settings(data: dict, admin, request=None) -> SystemSettings:
    with transaction.atomic():
        obj, _ = SystemSettings.objects.select_for_update().get_or_create(pk=SystemSettings.SINGLETON_PK)
        before = {k: getattr(obj, k) for k in data}
        for key, value in data.items():
            setattr(obj, key, value)
        if "allowed_extensions" in data:
            obj.allowed_extensions = sorted({e.lower() for e in obj.allowed_extensions})
        obj.full_clean()
        obj.updated_by = admin
        obj.save()
        audit.record(
            action="settings.updated",
            category=audit.Category.SETTINGS,
            actor=admin,
            target=obj,
            metadata={"before": before, "after": data},
            request=request,
        )
        # Invalidate now (this request sees the new values) and again after commit (a concurrent
        # reader may have re-cached the old row before our transaction became visible).
        cache.delete(CACHE_KEY)
        transaction.on_commit(lambda: cache.delete(CACHE_KEY))
    return obj
