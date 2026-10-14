from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from apps.accounts.permissions import IsAdmin
from apps.audit.mixins import AuditedModelViewSetMixin

from . import selectors
from . import serializers as s
from .filters import CourseFilter
from .models import Course, CourseInstructor, Faculty, Instructor, Level, Semester, Specialization, University

# ============================================================== student catalog (read-only, FR-024..028)


class CatalogUniversityViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = s.CatalogUniversitySerializer
    library_scope_path = "faculties__levels__courses"
    search_fields = ["name"]
    ordering_fields = ["name", "sort_order"]

    def get_queryset(self):
        return selectors.visible_universities()


class CatalogFacultyViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = s.CatalogFacultySerializer
    library_scope_path = "levels__courses"
    filterset_fields = ["university"]
    search_fields = ["name"]

    def get_queryset(self):
        return selectors.visible_faculties()


class CatalogLevelViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = s.CatalogLevelSerializer
    library_scope_path = "courses"
    filterset_fields = ["faculty"]

    def get_queryset(self):
        return selectors.visible_levels()


class CatalogSemesterViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = s.CatalogSemesterSerializer
    filterset_fields = ["faculty"]

    def get_queryset(self):
        return selectors.visible_semesters()


class CatalogSpecializationViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = s.CatalogSpecializationSerializer
    filterset_fields = ["faculty"]

    def get_queryset(self):
        return selectors.visible_specializations()


class CatalogCourseViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = s.CatalogCourseSerializer
    filterset_class = CourseFilter
    library_scope_path = ""
    search_fields = ["name", "code"]
    ordering_fields = ["name", "sort_order"]

    def get_queryset(self):
        return (
            selectors.visible_courses().select_related("level__faculty").prefetch_related("specializations")
        )

    @extend_schema(responses=s.CatalogInstructorSerializer(many=True))
    @action(detail=True, methods=["get"])
    def instructors(self, request, pk=None):
        """Instructors linked to the course, in the administrator-defined order (FR-022, FR-028)."""
        course = get_object_or_404(self.get_queryset(), pk=pk)
        instructors = selectors.visible_instructors_for_course(course)
        return Response(s.CatalogInstructorSerializer(instructors, many=True).data)


# ============================================================== administration (FR-016..023)


class _AdminViewSet(AuditedModelViewSetMixin, viewsets.ModelViewSet):
    permission_classes = [IsAdmin]
    ordering_fields = ["sort_order", "name", "created_at"]


class AdminUniversityViewSet(_AdminViewSet):
    queryset = University.objects.all()
    serializer_class = s.AdminUniversitySerializer
    filterset_fields = ["is_active"]
    search_fields = ["name", "code"]


class AdminFacultyViewSet(_AdminViewSet):
    queryset = Faculty.objects.all()
    serializer_class = s.AdminFacultySerializer
    filterset_fields = ["university", "is_active"]
    search_fields = ["name"]


class AdminLevelViewSet(_AdminViewSet):
    queryset = Level.objects.all()
    serializer_class = s.AdminLevelSerializer
    filterset_fields = ["faculty", "is_active"]
    search_fields = ["name"]
    ordering_fields = ["sort_order", "number", "created_at"]


class AdminSemesterViewSet(_AdminViewSet):
    queryset = Semester.objects.all()
    serializer_class = s.AdminSemesterSerializer
    filterset_fields = ["faculty", "is_active"]
    search_fields = ["name"]
    ordering_fields = ["sort_order", "number", "created_at"]


class AdminSpecializationViewSet(_AdminViewSet):
    queryset = Specialization.objects.all()
    serializer_class = s.AdminSpecializationSerializer
    filterset_fields = ["faculty", "is_active"]
    search_fields = ["name"]


class AdminInstructorViewSet(_AdminViewSet):
    queryset = Instructor.objects.all()
    serializer_class = s.AdminInstructorSerializer
    filterset_fields = ["university", "is_active"]
    search_fields = ["full_name"]
    ordering_fields = ["sort_order", "full_name", "created_at"]


class AdminCourseViewSet(_AdminViewSet):
    queryset = Course.objects.select_related("level__faculty").prefetch_related("specializations")
    serializer_class = s.AdminCourseSerializer
    filterset_class = CourseFilter
    search_fields = ["name", "code"]


class AdminCourseInstructorViewSet(_AdminViewSet):
    queryset = CourseInstructor.objects.select_related("instructor", "course__level__faculty")
    serializer_class = s.AdminCourseInstructorSerializer
    filterset_fields = ["course", "instructor"]
    ordering_fields = ["sort_order", "id"]
