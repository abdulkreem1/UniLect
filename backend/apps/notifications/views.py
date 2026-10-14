import django_filters
from drf_spectacular.utils import OpenApiResponse, extend_schema, inline_serializer
from rest_framework import mixins, serializers, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from . import services
from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    is_read = serializers.SerializerMethodField()

    class Meta:
        model = Notification
        fields = ["id", "type", "title", "body", "data", "is_read", "read_at", "created_at"]

    def get_is_read(self, obj) -> bool:
        return obj.read_at is not None


class NotificationFilter(django_filters.FilterSet):
    unread = django_filters.BooleanFilter(field_name="read_at", lookup_expr="isnull")

    class Meta:
        model = Notification
        fields = ["type", "unread"]


class NotificationViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    """Notification centre: each user only ever sees their own notifications (FR-072)."""

    serializer_class = NotificationSerializer
    filterset_class = NotificationFilter
    ordering_fields = ["created_at"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Notification.objects.none()
        return Notification.objects.filter(recipient=self.request.user)

    @extend_schema(request=None, responses={204: OpenApiResponse(description="Marked as read")})
    @action(detail=True, methods=["post"])
    def read(self, request, pk=None):
        services.mark_read(self.get_object())
        return Response(status=status.HTTP_204_NO_CONTENT)

    @extend_schema(
        request=None, responses=inline_serializer("MarkAllRead", {"updated": serializers.IntegerField()})
    )
    @action(detail=False, methods=["post"], url_path="read-all")
    def read_all(self, request):
        return Response({"updated": services.mark_all_read(request.user)})

    @extend_schema(responses=inline_serializer("UnreadCount", {"unread": serializers.IntegerField()}))
    @action(detail=False, methods=["get"], url_path="unread-count")
    def unread_count(self, request):
        return Response({"unread": self.get_queryset().filter(read_at__isnull=True).count()})
