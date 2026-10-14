from django.urls import reverse
from django.utils.translation import gettext_lazy as _
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.academics.models import Course, Instructor, Semester

from . import selectors
from .delivery import watermark_text
from .models import (
    EXAM_YEAR_MAX,
    EXAM_YEAR_MIN,
    ContentFile,
    ContentItem,
    CourseFollow,
    ExamType,
    Favorite,
    LectureCategory,
)


class RefSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()


class InstructorRefSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    full_name = serializers.CharField()
    title = serializers.CharField()


class FileInfoSerializer(serializers.ModelSerializer):
    class Meta:
        model = ContentFile
        fields = ["id", "version", "extension", "mime_type", "size_bytes", "page_count", "uploaded_at"]


class ManageFileInfoSerializer(FileInfoSerializer):
    uploaded_by = serializers.EmailField(source="uploaded_by.email", default=None, read_only=True)

    class Meta(FileInfoSerializer.Meta):
        fields = [*FileInfoSerializer.Meta.fields, "original_name", "sha256", "is_current", "uploaded_by"]


class _ContentReadBase(serializers.ModelSerializer):
    course = RefSerializer()
    level = RefSerializer(source="course.level")
    faculty = RefSerializer(source="course.level.faculty")
    university = RefSerializer(source="course.level.faculty.university")
    instructor = InstructorRefSerializer(allow_null=True)
    category = RefSerializer(allow_null=True)
    exam_type = RefSerializer(allow_null=True)
    semester = RefSerializer(allow_null=True)

    common_fields = [
        "id",
        "kind",
        "title",
        "description",
        "university",
        "faculty",
        "level",
        "course",
        "instructor",
        "lecture_number",
        "category",
        "exam_year",
        "exam_type",
        "semester",
        "published_at",
    ]


class CatalogContentSerializer(_ContentReadBase):
    """Student view (FR-029, 030, 033): metadata shown before opening the file. No storage URLs."""

    file = serializers.SerializerMethodField()
    file_endpoint = serializers.SerializerMethodField()
    is_favorite = serializers.BooleanField(read_only=True, default=False)
    watermark_text = serializers.SerializerMethodField()

    class Meta:
        model = ContentItem
        fields = [*_ContentReadBase.common_fields, "file", "file_endpoint", "is_favorite", "watermark_text"]

    @extend_schema_field(FileInfoSerializer(allow_null=True))
    def get_file(self, obj) -> FileInfoSerializer | None:
        current = selectors.current_file(obj)
        return FileInfoSerializer(current).data if current else None

    def get_file_endpoint(self, obj) -> str:
        """Authorised viewer endpoint (requires the bearer token + device header). Not a storage link."""
        return reverse("catalog-content-file", kwargs={"pk": obj.pk})

    def get_watermark_text(self, obj) -> str:
        return watermark_text(self.context["request"].user)


class ManageContentSerializer(_ContentReadBase):
    """Library/admin view, including workflow state and file versions metadata (FR-044, 061)."""

    library = RefSerializer()
    current_file = serializers.SerializerMethodField()
    created_by = serializers.EmailField(source="created_by.email", default=None, read_only=True)

    class Meta:
        model = ContentItem
        fields = [
            *_ContentReadBase.common_fields,
            "status",
            "review_note",
            "library",
            "current_file",
            "created_by",
            "created_at",
            "updated_at",
            "archived_at",
        ]

    @extend_schema_field(ManageFileInfoSerializer(allow_null=True))
    def get_current_file(self, obj) -> ManageFileInfoSerializer | None:
        current = selectors.current_file(obj)
        return ManageFileInfoSerializer(current).data if current else None


class ContentWriteSerializer(serializers.ModelSerializer):
    """Input for create/update. Business rules (scope, instructor↔course, kind fields) live in services."""

    course = serializers.PrimaryKeyRelatedField(queryset=Course.objects.select_related("level"))
    instructor = serializers.PrimaryKeyRelatedField(
        queryset=Instructor.objects.all(), required=False, allow_null=True
    )
    category = serializers.PrimaryKeyRelatedField(
        queryset=LectureCategory.objects.all(), required=False, allow_null=True
    )
    exam_type = serializers.PrimaryKeyRelatedField(
        queryset=ExamType.objects.all(), required=False, allow_null=True
    )
    semester = serializers.PrimaryKeyRelatedField(
        queryset=Semester.objects.all(), required=False, allow_null=True
    )
    exam_year = serializers.IntegerField(
        min_value=EXAM_YEAR_MIN, max_value=EXAM_YEAR_MAX, required=False, allow_null=True
    )
    lecture_number = serializers.IntegerField(min_value=1, max_value=10000, required=False, allow_null=True)
    file = serializers.FileField(
        write_only=True, required=False, help_text="Optional on create (draft without file)."
    )

    class Meta:
        model = ContentItem
        fields = [
            "kind",
            "title",
            "description",
            "course",
            "instructor",
            "lecture_number",
            "category",
            "exam_year",
            "exam_type",
            "semester",
            "file",
        ]
        extra_kwargs = {"title": {"allow_blank": False}}

    def validate(self, attrs):
        if self.instance is not None and "file" in attrs:
            raise serializers.ValidationError({"file": _("Use the /file/ endpoint to replace the file.")})
        return attrs


class FileUploadSerializer(serializers.Serializer):
    file = serializers.FileField()


class ReviewDecisionSerializer(serializers.Serializer):
    note = serializers.CharField(required=False, allow_blank=True, max_length=1000, default="")


class BulkItemResultSerializer(serializers.Serializer):
    index = serializers.IntegerField()
    ok = serializers.BooleanField()
    id = serializers.UUIDField(required=False)
    error = serializers.DictField(required=False)


class BulkUploadSerializer(serializers.Serializer):
    items = serializers.CharField(
        help_text='JSON array; each element has the create fields plus "file_field": the multipart '
        "field name holding that item's file."
    )


class FavoriteSerializer(serializers.ModelSerializer):
    content = serializers.PrimaryKeyRelatedField(queryset=ContentItem.objects.none())
    content_detail = CatalogContentSerializer(source="content", read_only=True)

    class Meta:
        model = Favorite
        fields = ["id", "content", "content_detail", "created_at"]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request is not None:
            self.fields["content"].queryset = selectors.visible_contents()


class CourseFollowSerializer(serializers.ModelSerializer):
    course_name = serializers.CharField(source="course.name", read_only=True)

    class Meta:
        model = CourseFollow
        fields = ["id", "course", "course_name", "notify_new_content", "created_at"]
        validators = []

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        from apps.academics.selectors import visible_courses

        self.fields["course"].queryset = visible_courses()


class LookupSerializer(serializers.ModelSerializer):
    class Meta:
        fields = ["id", "name", "is_active", "sort_order"]


class LectureCategorySerializer(LookupSerializer):
    class Meta(LookupSerializer.Meta):
        model = LectureCategory


class ExamTypeSerializer(LookupSerializer):
    class Meta(LookupSerializer.Meta):
        model = ExamType
