"""Maintenance of ``ContentItem.search_document`` (normalised, indexed search text).

The document is rebuilt when the item is saved through the services, and when a course or
instructor is renamed (signal receivers in ``content.signals``).
"""

from collections.abc import Iterable

from apps.core.text import normalize

from .models import ContentItem

BATCH_SIZE = 500


def build_document(item: ContentItem) -> str:
    course = item.course
    parts = [item.title, item.description, course.name, course.code]
    if item.instructor_id:
        parts.append(item.instructor.full_name)
    return normalize(" ".join(p for p in parts if p))


def refresh_items(items: Iterable[ContentItem]) -> int:
    changed = []
    for item in items:
        document = build_document(item)
        if document != item.search_document:
            item.search_document = document
            changed.append(item)
    ContentItem.objects.bulk_update(changed, ["search_document"], batch_size=BATCH_SIZE)
    return len(changed)


def refresh_for(**filters) -> int:
    qs = ContentItem.objects.filter(**filters).select_related("course", "instructor")
    return refresh_items(qs.iterator(chunk_size=BATCH_SIZE))
