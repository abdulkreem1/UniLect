import django_filters
from rest_framework import serializers, viewsets
from rest_framework.routers import SimpleRouter

from apps.accounts.permissions import IsAdmin

from .models import AuditLog


class AuditLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = AuditLog
        fields = [
            "id",
            "created_at",
            "category",
            "action",
            "actor",
            "actor_repr",
            "target_type",
            "target_id",
            "target_repr",
            "metadata",
            "ip_address",
            "request_id",
        ]


class AuditLogFilter(django_filters.FilterSet):
    created_after = django_filters.IsoDateTimeFilter(field_name="created_at", lookup_expr="gte")
    created_before = django_filters.IsoDateTimeFilter(field_name="created_at", lookup_expr="lte")
    action_prefix = django_filters.CharFilter(field_name="action", lookup_expr="startswith")

    class Meta:
        model = AuditLog
        fields = ["category", "action", "actor", "target_type", "target_id"]


class AuditLogViewSet(viewsets.ReadOnlyModelViewSet):
    """FR-015 / FR-068: read-only audit trail. Device history: ``?category=device``."""

    permission_classes = [IsAdmin]
    serializer_class = AuditLogSerializer
    queryset = AuditLog.objects.all()
    filterset_class = AuditLogFilter
    search_fields = ["actor_repr", "target_repr", "action"]
    ordering_fields = ["created_at"]


router = SimpleRouter()
router.register("audit-logs", AuditLogViewSet, basename="admin-audit-log")
