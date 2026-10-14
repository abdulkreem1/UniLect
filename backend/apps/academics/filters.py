import django_filters
from django.db.models import Q

from .models import Course


class CourseFilter(django_filters.FilterSet):
    university = django_filters.NumberFilter(field_name="level__faculty__university")
    faculty = django_filters.NumberFilter(field_name="level__faculty")
    level = django_filters.NumberFilter(field_name="level")
    semester = django_filters.NumberFilter(field_name="semester")
    specialization = django_filters.NumberFilter(method="filter_specialization")
    is_active = django_filters.BooleanFilter()

    class Meta:
        model = Course
        fields = ["university", "faculty", "level", "semester", "specialization", "is_active"]

    def filter_specialization(self, queryset, name, value):
        # A course without specializations is common to every specialization (assumption A-9).
        return queryset.filter(Q(specializations=value) | Q(specializations__isnull=True)).distinct()
