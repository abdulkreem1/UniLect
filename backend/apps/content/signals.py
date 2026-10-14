"""Keep content search documents in sync when catalog names change."""

from django.db import transaction
from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.academics.models import Course, Instructor

from . import search


@receiver(post_save, sender=Course, dispatch_uid="content-search-course")
def _course_saved(sender, instance: Course, created: bool, **kwargs) -> None:
    if not created:
        transaction.on_commit(lambda: search.refresh_for(course=instance.pk))


@receiver(post_save, sender=Instructor, dispatch_uid="content-search-instructor")
def _instructor_saved(sender, instance: Instructor, created: bool, **kwargs) -> None:
    if not created:
        transaction.on_commit(lambda: search.refresh_for(instructor=instance.pk))
