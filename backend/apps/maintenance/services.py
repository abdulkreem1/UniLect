"""Retention policies. Every function is idempotent and safe to run repeatedly (e.g. daily cron)."""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.db.models import Q
from django.utils import timezone

from apps.accounts.models import AuthSession
from apps.audit.models import AuditLog
from apps.content.models import ContentFile
from apps.notifications.models import Notification

logger = logging.getLogger(__name__)


@dataclass
class PurgeReport:
    counts: dict[str, int] = field(default_factory=dict)


def purge_ended_sessions(days: int, now=None) -> int:
    """Sessions revoked or expired more than ``days`` ago (they can never be used again)."""
    if days <= 0:
        return 0
    cutoff = (now or timezone.now()) - timedelta(days=days)
    deleted, _ = AuthSession.objects.filter(Q(revoked_at__lt=cutoff) | Q(expires_at__lt=cutoff)).delete()
    return deleted


def purge_read_notifications(days: int, now=None) -> int:
    if days <= 0:
        return 0
    cutoff = (now or timezone.now()) - timedelta(days=days)
    deleted, _ = Notification.objects.filter(read_at__lt=cutoff).delete()
    return deleted


def purge_audit_logs(days: int, now=None) -> int:
    """Disabled by default (0): audit history is usually kept; ship it elsewhere before pruning."""
    if days <= 0:
        return 0
    cutoff = (now or timezone.now()) - timedelta(days=days)
    deleted, _ = AuditLog.objects.filter(created_at__lt=cutoff).delete()
    return deleted


def prune_old_file_versions(keep: int) -> int:
    """Keep the current version plus the ``keep`` most recent previous versions of every item."""
    if keep <= 0:
        return 0
    stale = []
    content_ids = ContentFile.objects.filter(is_current=False).values_list("content_id", flat=True).distinct()
    for content_id in content_ids.iterator():
        old = ContentFile.objects.filter(content_id=content_id, is_current=False).order_by("-version")
        stale.extend(old[keep:].values_list("pk", "file"))
    if not stale:
        return 0
    ids = [pk for pk, _ in stale]
    names = [name for _, name in stale]
    with transaction.atomic():
        ContentFile.objects.filter(pk__in=ids, is_current=False).delete()
        transaction.on_commit(lambda: _delete_files(names))
    return len(ids)


def _delete_files(names: list[str]) -> None:
    storage = ContentFile.file.field.storage
    for name in names:
        try:
            storage.delete(name)
        except OSError:
            logger.warning("Could not delete pruned file %s", name)


def run_all(retention: dict | None = None) -> PurgeReport:
    policy = {**settings.RETENTION, **(retention or {})}
    return PurgeReport(
        counts={
            "ended_sessions": purge_ended_sessions(policy["ended_sessions_days"]),
            "read_notifications": purge_read_notifications(policy["read_notifications_days"]),
            "audit_logs": purge_audit_logs(policy["audit_logs_days"]),
            "old_file_versions": prune_old_file_versions(policy["old_file_versions"]),
        }
    )
