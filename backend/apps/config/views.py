from django.core.exceptions import ValidationError as DjangoValidationError
from drf_spectacular.utils import extend_schema
from rest_framework import serializers
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.permissions import IsAdmin

from . import services
from .models import SystemSettings


class SystemSettingsSerializer(serializers.ModelSerializer):
    allowed_extensions = serializers.ListField(child=serializers.CharField(max_length=10), allow_empty=False)

    class Meta:
        model = SystemSettings
        fields = [
            "max_upload_size_mb",
            "allowed_extensions",
            "require_content_review",
            "notify_followers_on_publish",
            "updated_at",
            "updated_by",
        ]
        read_only_fields = ["updated_at", "updated_by"]


class ClientConfigSerializer(serializers.ModelSerializer):
    class Meta:
        model = SystemSettings
        fields = ["max_upload_size_mb", "allowed_extensions", "require_content_review"]
        read_only_fields = fields


class ClientConfigView(APIView):
    """Settings the apps need before acting (upload limits, review workflow). Any authenticated role."""

    @extend_schema(responses=ClientConfigSerializer)
    def get(self, request):
        return Response(ClientConfigSerializer(services.get_settings()).data)


class SystemSettingsView(APIView):
    """FR-069: global settings. New values apply to subsequent operations only."""

    permission_classes = [IsAdmin]

    @extend_schema(responses=SystemSettingsSerializer)
    def get(self, request):
        return Response(SystemSettingsSerializer(services.get_settings()).data)

    @extend_schema(request=SystemSettingsSerializer, responses=SystemSettingsSerializer)
    def patch(self, request):
        serializer = SystemSettingsSerializer(services.get_settings(), data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        try:
            obj = services.update_settings(dict(serializer.validated_data), request.user, request=request)
        except DjangoValidationError as exc:
            raise serializers.ValidationError(exc.message_dict) from exc
        return Response(SystemSettingsSerializer(obj).data)
