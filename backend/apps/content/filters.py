import django_filters
from django.db.models import Q

from .models import ContentItem


class ContentFilter(django_filters.FilterSet):
    """FR-032 / FR-050: filter by academic path, instructor, type and exam attributes."""

    university = django_filters.NumberFilter(field_name="course__level__faculty__university")
    faculty = django_filters.NumberFilter(field_name="course__level__faculty")
    level = django_filters.NumberFilter(field_name="course__level")
    course = django_filters.NumberFilter(field_name="course")
    instructor = django_filters.NumberFilter(field_name="instructor")
    semester = django_filters.NumberFilter(method="filter_semester")
    exam_year = django_filters.NumberFilter()
    exam_year_min = django_filters.NumberFilter(field_name="exam_year", lookup_expr="gte")
    exam_year_max = django_filters.NumberFilter(field_name="exam_year", lookup_expr="lte")
    exam_type = django_filters.NumberFilter()
    category = django_filters.NumberFilter()
    kind = django_filters.ChoiceFilter(choices=ContentItem.Kind.choices)

    class Meta:
        model = ContentItem
        fields = [
            "kind",
            "university",
            "faculty",
            "level",
            "course",
            "instructor",
            "semester",
            "exam_year",
            "exam_type",
            "category",
        ]

    def filter_semester(self, queryset, name, value):
        # Exams carry their own semester; lectures inherit the course semester.
        return queryset.filter(Q(semester=value) | Q(semester__isnull=True, course__semester=value))


class ManageContentFilter(ContentFilter):
    status = django_filters.ChoiceFilter(choices=ContentItem.Status.choices)
    library = django_filters.NumberFilter()

    class Meta(ContentFilter.Meta):
        fields = [*ContentFilter.Meta.fields, "status", "library"]
