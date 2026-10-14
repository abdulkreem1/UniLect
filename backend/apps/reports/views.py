from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import mixins, serializers, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.permissions import IsAdmin, IsStudent
from apps.content.selectors import visible_contents

from . import services
from .models import ContentReport, ReportAction


class ReportCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = ContentReport
        fields = ["id", "reason", "message", "status", "created_at"]
        read_only_fields = ["id", "status", "created_at"]


class ReportActionSerializer(serializers.ModelSerializer):
    actor = serializers.EmailField(source="actor.email", default=None, read_only=True)

    class Meta:
        model = ReportAction
        fields = ["id", "actor", "from_status", "to_status", "note", "created_at"]


class AdminReportSerializer(serializers.ModelSerializer):
    reporter_email = serializers.EmailField(source="reporter.email", read_only=True)
    content_title = serializers.CharField(source="content.title", read_only=True)
    content_status = serializers.CharField(source="content.status", read_only=True)
    actions = ReportActionSerializer(many=True, read_only=True)

    class Meta:
        model = ContentReport
        fields = [
            "id",
            "content",
            "content_title",
            "content_status",
            "reporter",
            "reporter_email",
            "reason",
            "message",
            "status",
            "handled_by",
            "actions",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields


class TransitionSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=ContentReport.Status.choices)
    note = serializers.CharField(required=False, allow_blank=True, max_length=2000, default="")


class NoteSerializer(serializers.Serializer):
    note = serializers.CharField(max_length=2000)


class ContentReportCreateView(APIView):
    """FR-073: a student reports visible content as wrong / duplicate / inappropriate."""

    permission_classes = [IsStudent]

    @extend_schema(request=ReportCreateSerializer, responses={201: ReportCreateSerializer})
    def post(self, request, content_id):
        content = get_object_or_404(visible_contents(), pk=content_id)
        serializer = ReportCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        report = services.create_report(
            content=content, reporter=request.user, request=request, **serializer.validated_data
        )
        return Response(ReportCreateSerializer(report).data, status=status.HTTP_201_CREATED)


class AdminReportViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    """FR-074: review reports, change status, keep a history of actions and notes."""

    permission_classes = [IsAdmin]
    serializer_class = AdminReportSerializer
    queryset = ContentReport.objects.select_related("reporter", "content").prefetch_related("actions__actor")
    filterset_fields = ["status", "reason", "content"]
    ordering_fields = ["created_at", "updated_at"]

    @extend_schema(request=TransitionSerializer, responses=AdminReportSerializer)
    @action(detail=True, methods=["post"])
    def transition(self, request, pk=None):
        data = TransitionSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        services.transition(
            report=self.get_object(),
            actor=request.user,
            to_status=data.validated_data["status"],
            note=data.validated_data["note"],
            request=request,
        )
        return Response(self.get_serializer(self.get_queryset().get(pk=pk)).data)

    @extend_schema(request=NoteSerializer, responses={201: ReportActionSerializer})
    @action(detail=True, methods=["post"])
    def notes(self, request, pk=None):
        data = NoteSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        note = services.add_note(
            report=self.get_object(), actor=request.user, note=data.validated_data["note"], request=request
        )
        return Response(ReportActionSerializer(note).data, status=status.HTTP_201_CREATED)
