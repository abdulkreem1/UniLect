"""Libraries (content providers) and their academic scope (FR-059, FR-060)."""

from django.db import models

from apps.academics.models import Course, Faculty, University
from apps.core.models import TimeStampedModel


class Library(TimeStampedModel):
    """A content provider. Staff accounts (role=LIBRARY) belong to exactly one library.

    Scope is the union of whole universities, whole faculties and individual courses
    (assumption A-11). A library may only manage content it owns that lies inside its scope.
    """

    name = models.CharField(max_length=200, unique=True)
    contact_email = models.EmailField(blank=True)
    contact_phone = models.CharField(max_length=30, blank=True)
    is_active = models.BooleanField(default=True, db_index=True)
    scope_universities = models.ManyToManyField(University, blank=True, related_name="libraries")
    scope_faculties = models.ManyToManyField(Faculty, blank=True, related_name="libraries")
    scope_courses = models.ManyToManyField(Course, blank=True, related_name="libraries")

    class Meta:
        ordering = ["name"]
        verbose_name_plural = "libraries"

    def __str__(self) -> str:
        return self.name
