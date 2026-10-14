from rest_framework import serializers, viewsets
from rest_framework.routers import SimpleRouter

from apps.academics.models import Course, Faculty, University
from apps.accounts.permissions import IsAdmin
from apps.audit.mixins import AuditedModelViewSetMixin
from apps.audit.services import Category

from .models import Library


class LibrarySerializer(serializers.ModelSerializer):
    scope_universities = serializers.PrimaryKeyRelatedField(
        many=True, queryset=University.objects.all(), required=False
    )
    scope_faculties = serializers.PrimaryKeyRelatedField(
        many=True, queryset=Faculty.objects.all(), required=False
    )
    scope_courses = serializers.PrimaryKeyRelatedField(
        many=True, queryset=Course.objects.all(), required=False
    )
    staff_count = serializers.IntegerField(source="staff.count", read_only=True)

    class Meta:
        model = Library
        fields = [
            "id",
            "name",
            "contact_email",
            "contact_phone",
            "is_active",
            "scope_universities",
            "scope_faculties",
            "scope_courses",
            "staff_count",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["created_at", "updated_at"]


class AdminLibraryViewSet(AuditedModelViewSetMixin, viewsets.ModelViewSet):
    """Administrators create libraries and define their academic scope (FR-059, FR-060)."""

    audit_category = Category.LIBRARY
    permission_classes = [IsAdmin]
    serializer_class = LibrarySerializer
    queryset = Library.objects.prefetch_related(
        "scope_universities", "scope_faculties", "scope_courses", "staff"
    )
    filterset_fields = ["is_active"]
    search_fields = ["name"]
    ordering_fields = ["name", "created_at"]


router = SimpleRouter()
router.register("libraries", AdminLibraryViewSet, basename="admin-library")
