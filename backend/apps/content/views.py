import json

from django.conf import settings
from django.db.models import Count, Prefetch, Q
from django.shortcuts import get_object_or_404
from django.utils.translation import gettext as _
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema, inline_serializer
from rest_framework import mixins, serializers, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from apps.accounts.permissions import IsAdmin, IsLibraryOrAdmin, IsStudent
from apps.audit.mixins import AuditedModelViewSetMixin
from apps.core.exceptions import ApiError

from . import selectors, services
from . import serializers as s
from .delivery import file_response
from .filters import ContentFilter, ManageContentFilter
from .models import ContentFile, ContentItem, CourseFollow, ExamType, Favorite, LectureCategory

SEARCH_DOCUMENT = "search_document"  # normalised title/description/course/instructor, trigram-indexed
ORDERING_FIELDS = ["published_at", "title", "lecture_number", "exam_year", "created_at"]


def _not_found():
    return NotFound()


# ============================================================== student catalog (FR-029..033, 050..056, 079)


class CatalogContentViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = s.CatalogContentSerializer
    filterset_class = ContentFilter
    search_document_field = SEARCH_DOCUMENT
    ordering_fields = ORDERING_FIELDS

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return ContentItem.objects.none()
        return selectors.visible_contents(self.request.user)

    def get_throttles(self):
        if self.action == "file":
            self.throttle_scope = "content_file"
            return [*super().get_throttles(), ScopedRateThrottle()]
        return super().get_throttles()

    @extend_schema(
        responses={(200, "application/pdf"): OpenApiTypes.BINARY, (200, "image/*"): OpenApiTypes.BINARY},
        description="Streams the CURRENT file inline for the in-app viewer. Authorisation (role, device, "
        "visibility) is re-checked on every call; there is no public or permanent link (FR-055/056/076).",
    )
    @action(detail=True, methods=["get"], url_path="file", url_name="file")
    def file(self, request, pk=None):
        item = get_object_or_404(self.get_queryset(), pk=pk)
        current = selectors.current_file(item)
        if current is None:
            raise _not_found()
        return file_response(current, request.user)


# ============================================================== student: favorites & follows (FR-034, FR-071)


class FavoriteViewSet(mixins.ListModelMixin, mixins.CreateModelMixin, viewsets.GenericViewSet):
    permission_classes = [IsStudent]
    serializer_class = s.FavoriteSerializer

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Favorite.objects.none()
        # Content that became invisible (archived, deactivated path) silently drops out.
        visible = selectors.visible_contents(self.request.user)
        return (
            Favorite.objects.filter(student=self.request.user, content__in=visible.values("pk"))
            .select_related(
                "content__course__level__faculty__university",
                "content__instructor",
                "content__category",
                "content__exam_type",
                "content__semester",
            )
            .prefetch_related(
                Prefetch(
                    "content__files",
                    queryset=ContentFile.objects.filter(is_current=True),
                    to_attr="current_files",
                )
            )
        )

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        favorite, created = Favorite.objects.get_or_create(
            student=request.user, content=serializer.validated_data["content"]
        )
        return Response(
            self.get_serializer(favorite).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )

    @extend_schema(responses={204: None})
    @action(detail=False, methods=["delete"], url_path=r"(?P<content_id>[0-9a-f-]{36})")
    def remove(self, request, content_id=None):
        Favorite.objects.filter(student=request.user, content_id=content_id).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class CourseFollowViewSet(viewsets.ModelViewSet):
    permission_classes = [IsStudent]
    serializer_class = s.CourseFollowSerializer
    http_method_names = ["get", "post", "patch", "delete", "head", "options"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return CourseFollow.objects.none()
        return CourseFollow.objects.filter(student=self.request.user).select_related("course")

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        follow, created = CourseFollow.objects.update_or_create(
            student=request.user,
            course=serializer.validated_data["course"],
            defaults={"notify_new_content": serializer.validated_data.get("notify_new_content", True)},
        )
        return Response(
            self.get_serializer(follow).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )

    def perform_update(self, serializer):
        serializer.save(course=serializer.instance.course)  # the followed course itself is immutable


# ======================================================= library/admin management (FR-035..049, 061..066)


class ManageContentViewSet(viewsets.ModelViewSet):
    """Library staff manage their own in-scope content; administrators manage everything.

    Objects outside the caller's scope resolve to 404 (no existence leak).
    """

    permission_classes = [IsLibraryOrAdmin]
    filterset_class = ManageContentFilter
    search_document_field = SEARCH_DOCUMENT
    ordering_fields = [*ORDERING_FIELDS, "updated_at", "status"]
    parser_classes = [JSONParser, MultiPartParser, FormParser]
    http_method_names = ["get", "post", "patch", "delete", "head", "options"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return ContentItem.objects.none()
        return selectors.manageable_contents(self.request.user).order_by("-updated_at")

    def get_serializer_class(self):
        return (
            s.ContentWriteSerializer
            if self.action in ("create", "partial_update")
            else s.ManageContentSerializer
        )

    def _read(self, item, status_code=status.HTTP_200_OK):
        fresh = self.get_queryset().get(pk=item.pk)
        return Response(
            s.ManageContentSerializer(fresh, context=self.get_serializer_context()).data, status=status_code
        )

    @extend_schema(request=s.ContentWriteSerializer, responses={201: s.ManageContentSerializer})
    def create(self, request, *args, **kwargs):
        serializer = s.ContentWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = dict(serializer.validated_data)
        upload = data.pop("file", None)
        item = services.create_content(actor=request.user, data=data, upload=upload, request=request)
        return self._read(item, status.HTTP_201_CREATED)

    @extend_schema(request=s.ContentWriteSerializer, responses=s.ManageContentSerializer)
    def partial_update(self, request, *args, **kwargs):
        item = self.get_object()
        serializer = s.ContentWriteSerializer(item, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        item = services.update_content(
            item=item, actor=request.user, data=dict(serializer.validated_data), request=request
        )
        return self._read(item)

    def destroy(self, request, *args, **kwargs):
        services.delete(item=self.get_object(), actor=request.user, request=request)
        return Response(status=status.HTTP_204_NO_CONTENT)

    # ---------------------------------------------------------------- file versions (FR-041, FR-044)

    @extend_schema(
        methods=["GET"],
        responses={(200, "application/pdf"): OpenApiTypes.BINARY},
        description="Preview the current file (including drafts) before publishing (FR-044).",
    )
    @extend_schema(
        methods=["POST"], request=s.FileUploadSerializer, responses={201: s.ManageFileInfoSerializer}
    )
    @action(detail=True, methods=["get", "post"], url_path="file", parser_classes=[MultiPartParser])
    def file(self, request, pk=None):
        item = self.get_object()
        if request.method == "GET":
            current = selectors.current_file(item)
            if current is None:
                raise _not_found()
            return file_response(current, request.user)
        serializer = s.FileUploadSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        content_file = services.replace_file(
            item=item, actor=request.user, upload=serializer.validated_data["file"], request=request
        )
        return Response(s.ManageFileInfoSerializer(content_file).data, status=status.HTTP_201_CREATED)

    @extend_schema(responses=s.ManageFileInfoSerializer(many=True))
    @action(detail=True, methods=["get"])
    def versions(self, request, pk=None):
        item = self.get_object()
        return Response(s.ManageFileInfoSerializer(item.files.select_related("uploaded_by"), many=True).data)

    # ---------------------------------------------------------------- workflow (FR-042, FR-066)

    def _transition(self, func, **kwargs):
        item = func(item=self.get_object(), actor=self.request.user, request=self.request, **kwargs)
        return self._read(item)

    @extend_schema(request=None, responses=s.ManageContentSerializer)
    @action(detail=True, methods=["post"])
    def submit(self, request, pk=None):
        return self._transition(services.submit)

    @extend_schema(request=None, responses=s.ManageContentSerializer)
    @action(detail=True, methods=["post"])
    def archive(self, request, pk=None):
        return self._transition(services.archive)

    @extend_schema(request=None, responses=s.ManageContentSerializer)
    @action(detail=True, methods=["post"])
    def restore(self, request, pk=None):
        return self._transition(services.restore)

    @extend_schema(request=None, responses=s.ManageContentSerializer)
    @action(detail=True, methods=["post"], permission_classes=[IsAdmin])
    def approve(self, request, pk=None):
        return self._transition(services.approve)

    @extend_schema(request=s.ReviewDecisionSerializer, responses=s.ManageContentSerializer)
    @action(detail=True, methods=["post"], permission_classes=[IsAdmin])
    def reject(self, request, pk=None):
        decision = s.ReviewDecisionSerializer(data=request.data)
        decision.is_valid(raise_exception=True)
        return self._transition(services.reject, note=decision.validated_data["note"])

    # ---------------------------------------------------------------- bulk upload (FR-063)

    @extend_schema(
        request={"multipart/form-data": s.BulkUploadSerializer},
        responses=inline_serializer("BulkUploadResult", {"results": s.BulkItemResultSerializer(many=True)}),
    )
    @action(detail=False, methods=["post"], parser_classes=[MultiPartParser])
    def bulk(self, request):
        """Each item is validated and saved independently; the response reports success/failure per item."""
        try:
            items = json.loads(request.data.get("items", ""))
        except (TypeError, ValueError) as exc:
            raise ValidationError({"items": _("Must be a JSON array.")}) from exc
        if not isinstance(items, list) or not items:
            raise ValidationError({"items": _("Must be a non-empty JSON array.")})
        if len(items) > settings.CONTENT_BULK_UPLOAD_MAX_ITEMS:
            raise ValidationError(
                {
                    "items": _("At most %(n)s items per request.")
                    % {"n": settings.CONTENT_BULK_UPLOAD_MAX_ITEMS}
                }
            )

        results = []
        for index, raw in enumerate(items):
            results.append(self._bulk_one(index, raw))
        return Response({"results": results})

    def _bulk_one(self, index: int, raw) -> dict:
        if not isinstance(raw, dict):
            return {
                "index": index,
                "ok": False,
                "error": {"code": "validation_error", "details": str(_("Item must be an object."))},
            }
        payload = {k: v for k, v in raw.items() if k != "file_field"}
        upload = self.request.FILES.get(str(raw.get("file_field", "")))
        if upload is not None:
            payload["file"] = upload
        serializer = s.ContentWriteSerializer(data=payload)
        try:
            serializer.is_valid(raise_exception=True)
            data = dict(serializer.validated_data)
            file_obj = data.pop("file", None)
            item = services.create_content(
                actor=self.request.user, data=data, upload=file_obj, request=self.request
            )
        except ValidationError as exc:
            return {"index": index, "ok": False, "error": {"code": "validation_error", "details": exc.detail}}
        except ApiError as exc:
            return {
                "index": index,
                "ok": False,
                "error": {"code": exc.get_codes(), "message": str(exc.detail), "details": exc.details},
            }
        return {"index": index, "ok": True, "id": str(item.pk)}


class ManageStatsView(APIView):
    """FR-062: counts per status and kind, limited to the caller's manageable scope."""

    permission_classes = [IsLibraryOrAdmin]

    @extend_schema(
        responses=inline_serializer(
            "ContentStats",
            {
                "total": serializers.IntegerField(),
                "by_status": serializers.DictField(child=serializers.IntegerField()),
                "by_kind": serializers.DictField(child=serializers.IntegerField()),
            },
        )
    )
    def get(self, request):
        qs = selectors.manageable_contents(request.user).order_by()
        aggregates = {f"status_{v}": Count("pk", filter=Q(status=v)) for v in ContentItem.Status.values}
        aggregates.update({f"kind_{v}": Count("pk", filter=Q(kind=v)) for v in ContentItem.Kind.values})
        row = qs.aggregate(total=Count("pk"), **aggregates)
        return Response(
            {
                "total": row["total"],
                "by_status": {v: row[f"status_{v}"] for v in ContentItem.Status.values},
                "by_kind": {v: row[f"kind_{v}"] for v in ContentItem.Kind.values},
            }
        )


# ============================================================== lookups (FR-048)


class CatalogLectureCategoryViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = s.LectureCategorySerializer
    queryset = LectureCategory.objects.filter(is_active=True)
    pagination_class = None


class CatalogExamTypeViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = s.ExamTypeSerializer
    queryset = ExamType.objects.filter(is_active=True)
    pagination_class = None


class AdminLectureCategoryViewSet(AuditedModelViewSetMixin, viewsets.ModelViewSet):
    permission_classes = [IsAdmin]
    serializer_class = s.LectureCategorySerializer
    queryset = LectureCategory.objects.all()


class AdminExamTypeViewSet(AuditedModelViewSetMixin, viewsets.ModelViewSet):
    permission_classes = [IsAdmin]
    serializer_class = s.ExamTypeSerializer
    queryset = ExamType.objects.all()
