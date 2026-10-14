"""Administrator dashboard summary (FR-064). Computed live with a handful of aggregate queries."""

from django.db.models import Count, Q
from drf_spectacular.utils import extend_schema, inline_serializer
from rest_framework import serializers
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import Role, User
from apps.accounts.permissions import IsAdmin
from apps.content.models import ContentItem
from apps.devices.models import DeviceChangeRequest
from apps.reports.models import ContentReport


def _counts(qs, field: str, values) -> dict:
    row = qs.order_by().aggregate(**{v: Count("pk", filter=Q(**{field: v})) for v in values})
    return {k: row[k] for k in values}


class AdminDashboardView(APIView):
    permission_classes = [IsAdmin]

    @extend_schema(
        responses=inline_serializer(
            "AdminDashboard",
            {
                "accounts": serializers.DictField(),
                "content": serializers.DictField(),
                "pending_actions": serializers.DictField(child=serializers.IntegerField()),
            },
        )
    )
    def get(self, request):
        users = User.objects.all()
        accounts = _counts(users, "role", Role.values)
        accounts["inactive"] = users.filter(is_active=False).count()
        content = {
            "by_status": _counts(ContentItem.objects.all(), "status", ContentItem.Status.values),
            "by_kind": _counts(ContentItem.objects.all(), "kind", ContentItem.Kind.values),
        }
        pending = {
            "device_change_requests": DeviceChangeRequest.objects.filter(
                status=DeviceChangeRequest.Status.PENDING
            ).count(),
            "content_pending_review": content["by_status"][ContentItem.Status.PENDING_REVIEW],
            "open_reports": ContentReport.objects.filter(status__in=ContentReport.OPEN_STATES).count(),
        }
        return Response({"accounts": accounts, "content": content, "pending_actions": pending})
