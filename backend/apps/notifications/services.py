from collections.abc import Iterable

from django.conf import settings
from django.utils import timezone
from django.utils.translation import override

from .models import Notification

BULK_BATCH_SIZE = 1000


def site_language():
    """Render stored notification text in the site language, not the language of whoever
    triggered it (e.g. an admin browsing in English must not send English notices to students)."""
    return override(settings.LANGUAGE_CODE)


def notify(recipient, type_: str, title: str, body: str = "", data: dict | None = None) -> Notification:
    return Notification.objects.create(
        recipient=recipient, type=type_, title=title, body=body, data=data or {}
    )


def notify_many(
    recipient_ids: Iterable, type_: str, title: str, body: str = "", data: dict | None = None
) -> int:
    rows = [
        Notification(recipient_id=rid, type=type_, title=title, body=body, data=data or {})
        for rid in recipient_ids
    ]
    Notification.objects.bulk_create(rows, batch_size=BULK_BATCH_SIZE)
    return len(rows)


def mark_read(notification: Notification) -> None:
    if notification.read_at is None:
        notification.read_at = timezone.now()
        notification.save(update_fields=["read_at"])


def mark_all_read(user) -> int:
    return Notification.objects.filter(recipient=user, read_at__isnull=True).update(read_at=timezone.now())
