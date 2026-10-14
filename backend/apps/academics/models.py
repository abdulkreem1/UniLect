"""Academic catalog: University → Faculty → Level → Course, plus Semester, Specialization, Instructor.

Deletion of catalog nodes that still have children/content is blocked (PROTECT);
administrators deactivate nodes instead, which hides them from students (FR-016, FR-024).
"""

from django.core.exceptions import ValidationError
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.core.models import OrderedActiveModel


class University(OrderedActiveModel):
    name = models.CharField(max_length=200, unique=True)
    code = models.CharField(max_length=30, blank=True)

    class Meta:
        ordering = ["sort_order", "name"]
        verbose_name_plural = "universities"

    def __str__(self) -> str:
        return self.name


class Faculty(OrderedActiveModel):
    university = models.ForeignKey(University, on_delete=models.PROTECT, related_name="faculties")
    name = models.CharField(max_length=200)

    class Meta:
        ordering = ["sort_order", "name"]
        verbose_name_plural = "faculties"
        constraints = [
            models.UniqueConstraint(fields=["university", "name"], name="uniq_faculty_name_per_university")
        ]

    def __str__(self) -> str:
        return self.name


class Level(OrderedActiveModel):
    """Study year / level inside a faculty (FR-018)."""

    faculty = models.ForeignKey(Faculty, on_delete=models.PROTECT, related_name="levels")
    name = models.CharField(max_length=100)
    number = models.PositiveSmallIntegerField()

    class Meta:
        ordering = ["sort_order", "number"]
        constraints = [
            models.UniqueConstraint(fields=["faculty", "number"], name="uniq_level_number_per_faculty"),
            models.CheckConstraint(condition=models.Q(number__gte=1), name="level_number_gte_1"),
        ]

    def __str__(self) -> str:
        return self.name


class Semester(OrderedActiveModel):
    """Semester/term defined per faculty (FR-019, assumption A-8)."""

    faculty = models.ForeignKey(Faculty, on_delete=models.PROTECT, related_name="semesters")
    name = models.CharField(max_length=100)
    number = models.PositiveSmallIntegerField()

    class Meta:
        ordering = ["sort_order", "number"]
        constraints = [
            models.UniqueConstraint(fields=["faculty", "number"], name="uniq_semester_number_per_faculty"),
            models.CheckConstraint(condition=models.Q(number__gte=1), name="semester_number_gte_1"),
        ]

    def __str__(self) -> str:
        return self.name


class Specialization(OrderedActiveModel):
    faculty = models.ForeignKey(Faculty, on_delete=models.PROTECT, related_name="specializations")
    name = models.CharField(max_length=200)

    class Meta:
        ordering = ["sort_order", "name"]
        constraints = [
            models.UniqueConstraint(fields=["faculty", "name"], name="uniq_specialization_name_per_faculty")
        ]

    def __str__(self) -> str:
        return self.name


class Instructor(OrderedActiveModel):
    """A lecturer ("الدكتور") (FR-022). Linked to courses through CourseInstructor."""

    full_name = models.CharField(max_length=200)
    title = models.CharField(max_length=50, blank=True)
    university = models.ForeignKey(
        University, on_delete=models.PROTECT, null=True, blank=True, related_name="instructors"
    )

    class Meta:
        ordering = ["sort_order", "full_name"]
        indexes = [models.Index(fields=["full_name"])]

    def __str__(self) -> str:
        return f"{self.title} {self.full_name}".strip()


class Course(OrderedActiveModel):
    """A subject ("المادة"). University/faculty are derived from ``level`` (normalised, FR-021)."""

    level = models.ForeignKey(Level, on_delete=models.PROTECT, related_name="courses")
    semester = models.ForeignKey(
        Semester, on_delete=models.PROTECT, null=True, blank=True, related_name="courses"
    )
    specializations = models.ManyToManyField(Specialization, blank=True, related_name="courses")
    instructors = models.ManyToManyField(Instructor, through="CourseInstructor", related_name="courses")
    name = models.CharField(max_length=200)
    code = models.CharField(max_length=30, blank=True)
    description = models.TextField(blank=True)

    class Meta:
        ordering = ["sort_order", "name"]
        constraints = [models.UniqueConstraint(fields=["level", "name"], name="uniq_course_name_per_level")]

    def __str__(self) -> str:
        return self.name

    def clean(self) -> None:
        if self.semester_id and self.level_id and self.semester.faculty_id != self.level.faculty_id:
            raise ValidationError({"semester": _("Semester must belong to the course's faculty.")})


class CourseInstructor(models.Model):
    course = models.ForeignKey(Course, on_delete=models.CASCADE, related_name="course_instructors")
    instructor = models.ForeignKey(Instructor, on_delete=models.PROTECT, related_name="course_links")
    sort_order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ["sort_order", "id"]
        constraints = [
            models.UniqueConstraint(fields=["course", "instructor"], name="uniq_course_instructor")
        ]

    def __str__(self) -> str:
        return f"{self.course} / {self.instructor}"
