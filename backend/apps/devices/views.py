from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import mixins, serializers, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from apps.accounts.authentication import DeviceChangeTokenAuthentication
from apps.accounts.permissions import IsAdmin, IsStudent

from . import services
from .models import DeviceChangeRequest, StudentDevice


class DeviceSerializer(serializers.ModelSerializer):
    class Meta:
        model = StudentDevice
        fields = ["id", "platform", "model_name", "app_version", "status", "bound_at", "last_seen_at"]


class StudentChangeRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeviceChangeRequest
        fields = [
            "id",
            "new_platform",
            "new_model_name",
            "reason",
            "status",
            "decision_note",
            "decided_at",
            "created_at",
        ]
        read_only_fields = [f for f in fields if f != "reason"]


class AdminChangeRequestSerializer(serializers.ModelSerializer):
    student_email = serializers.EmailField(source="student.email", read_only=True)
    student_name = serializers.CharField(source="student.full_name", read_only=True)
    student_number = serializers.CharField(source="student.student_number", read_only=True)
    current_device = DeviceSerializer(read_only=True)
    decided_by_email = serializers.EmailField(source="decided_by.email", read_only=True, default=None)

    class Meta:
        model = DeviceChangeRequest
        fields = [
            "id",
            "student",
            "student_email",
            "student_name",
            "student_number",
            "current_device",
            "new_platform",
            "new_model_name",
            "new_app_version",
            "reason",
            "status",
            "decided_by",
            "decided_by_email",
            "decided_at",
            "decision_note",
            "created_at",
        ]
        read_only_fields = fields


class DecisionSerializer(serializers.Serializer):
    note = serializers.CharField(required=False, allow_blank=True, max_length=1000, default="")


# ------------------------------------------------------------------ student, from the NEW device (FR-011)


class DeviceChangeRequestFromNewDeviceViewSet(
    mixins.ListModelMixin, mixins.RetrieveModelMixin, mixins.CreateModelMixin, viewsets.GenericViewSet
):
    """Usable only with the restricted ``device_change_token`` returned by a ``device_not_bound`` login."""

    authentication_classes = [DeviceChangeTokenAuthentication]
    permission_classes = [IsStudent]
    serializer_class = StudentChangeRequestSerializer
    throttle_scope = "device_change"
    pagination_class = None

    def get_throttles(self):
        return [ScopedRateThrottle()] if self.action == "create" else super().get_throttles()

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return DeviceChangeRequest.objects.none()
        return DeviceChangeRequest.objects.filter(student=self.request.user)

    def perform_create(self, serializer):
        token = self.request.auth
        info = services.DeviceInfo(
            installation_id_hash=token["dev"],
            platform=token["platform"],
            model_name=token.get("model", ""),
            app_version=token.get("app_version", ""),
        )
        serializer.instance = services.create_change_request(
            self.request.user, info, serializer.validated_data.get("reason", ""), request=self.request
        )

    @extend_schema(request=None, responses=StudentChangeRequestSerializer)
    @action(detail=True, methods=["post"])
    def cancel(self, request, pk=None):
        obj = services.cancel_change_request(self.get_object(), request.user, request=request)
        return Response(self.get_serializer(obj).data)


# ------------------------------------------------------------------ student, from the bound device


class MyDeviceView(APIView):
    permission_classes = [IsStudent]

    @extend_schema(responses=DeviceSerializer)
    def get(self, request):
        device = get_object_or_404(StudentDevice, student=request.user, status=StudentDevice.Status.ACTIVE)
        return Response(DeviceSerializer(device).data)


class MyDeviceChangeRequestsViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    permission_classes = [IsStudent]
    serializer_class = StudentChangeRequestSerializer

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return DeviceChangeRequest.objects.none()
        return DeviceChangeRequest.objects.filter(student=self.request.user)


# ------------------------------------------------------------------ administration (FR-012, FR-067)


class AdminDeviceChangeRequestViewSet(
    mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet
):
    permission_classes = [IsAdmin]
    serializer_class = AdminChangeRequestSerializer
    queryset = DeviceChangeRequest.objects.select_related("student", "current_device", "decided_by")
    filterset_fields = ["status", "student"]
    search_fields = ["student__email", "student__full_name", "student__student_number"]
    ordering_fields = ["created_at", "decided_at", "status"]
    ordering = ["-created_at"]

    @extend_schema(request=DecisionSerializer, responses=AdminChangeRequestSerializer)
    @action(detail=True, methods=["post"])
    def approve(self, request, pk=None):
        data = self._decision(request)
        obj = services.approve_change_request(self.get_object(), request.user, data["note"], request=request)
        return Response(self.get_serializer(obj).data)

    @extend_schema(request=DecisionSerializer, responses=AdminChangeRequestSerializer)
    @action(detail=True, methods=["post"])
    def reject(self, request, pk=None):
        data = self._decision(request)
        obj = services.reject_change_request(self.get_object(), request.user, data["note"], request=request)
        return Response(self.get_serializer(obj).data, status=status.HTTP_200_OK)

    @staticmethod
    def _decision(request) -> dict:
        serializer = DecisionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return serializer.validated_data
