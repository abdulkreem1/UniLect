from django.utils.translation import gettext_lazy as _
from rest_framework import serializers

from .models import Course, CourseInstructor, Faculty, Instructor, Level, Semester, Specialization, University

# ---------------------------------------------------------------- student catalog (read-only)


class CatalogUniversitySerializer(serializers.ModelSerializer):
    class Meta:
        model = University
        fields = ["id", "name", "code"]


class CatalogFacultySerializer(serializers.ModelSerializer):
    class Meta:
        model = Faculty
        fields = ["id", "name", "university"]


class CatalogLevelSerializer(serializers.ModelSerializer):
    class Meta:
        model = Level
        fields = ["id", "name", "number", "faculty"]


class CatalogSemesterSerializer(serializers.ModelSerializer):
    class Meta:
        model = Semester
        fields = ["id", "name", "number", "faculty"]


class CatalogSpecializationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Specialization
        fields = ["id", "name", "faculty"]


class CatalogCourseSerializer(serializers.ModelSerializer):
    faculty = serializers.IntegerField(source="level.faculty_id", read_only=True)
    university = serializers.IntegerField(source="level.faculty.university_id", read_only=True)

    class Meta:
        model = Course
        fields = [
            "id",
            "name",
            "code",
            "description",
            "university",
            "faculty",
            "level",
            "semester",
            "specializations",
        ]


class CatalogInstructorSerializer(serializers.ModelSerializer):
    class Meta:
        model = Instructor
        fields = ["id", "full_name", "title"]


# ---------------------------------------------------------------- administration (read/write)

_COMMON = ["is_active", "sort_order", "created_at", "updated_at"]
_READ_ONLY = ["created_at", "updated_at"]


class AdminUniversitySerializer(serializers.ModelSerializer):
    class Meta:
        model = University
        fields = ["id", "name", "code", *_COMMON]
        read_only_fields = _READ_ONLY


class AdminFacultySerializer(serializers.ModelSerializer):
    class Meta:
        model = Faculty
        fields = ["id", "university", "name", *_COMMON]
        read_only_fields = _READ_ONLY


class AdminLevelSerializer(serializers.ModelSerializer):
    class Meta:
        model = Level
        fields = ["id", "faculty", "name", "number", *_COMMON]
        read_only_fields = _READ_ONLY


class AdminSemesterSerializer(serializers.ModelSerializer):
    class Meta:
        model = Semester
        fields = ["id", "faculty", "name", "number", *_COMMON]
        read_only_fields = _READ_ONLY


class AdminSpecializationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Specialization
        fields = ["id", "faculty", "name", *_COMMON]
        read_only_fields = _READ_ONLY


class AdminInstructorSerializer(serializers.ModelSerializer):
    class Meta:
        model = Instructor
        fields = ["id", "full_name", "title", "university", *_COMMON]
        read_only_fields = _READ_ONLY


class AdminCourseSerializer(serializers.ModelSerializer):
    specializations = serializers.PrimaryKeyRelatedField(
        many=True, queryset=Specialization.objects.all(), required=False
    )
    faculty = serializers.IntegerField(source="level.faculty_id", read_only=True)

    class Meta:
        model = Course
        fields = [
            "id",
            "faculty",
            "level",
            "semester",
            "specializations",
            "name",
            "code",
            "description",
            *_COMMON,
        ]
        read_only_fields = _READ_ONLY

    def validate(self, attrs):
        level = attrs.get("level") or self.instance.level
        semester = attrs["semester"] if "semester" in attrs else getattr(self.instance, "semester", None)
        faculty_id = level.faculty_id
        if semester is not None and semester.faculty_id != faculty_id:
            raise serializers.ValidationError({"semester": _("Semester must belong to the course faculty.")})
        if "specializations" in attrs:
            specs = attrs["specializations"]
        elif self.instance is not None:
            specs = list(self.instance.specializations.all())
        else:
            specs = []
        if any(s.faculty_id != faculty_id for s in specs):
            raise serializers.ValidationError(
                {"specializations": _("Specializations must belong to the course faculty.")}
            )
        return attrs


class AdminCourseInstructorSerializer(serializers.ModelSerializer):
    instructor_name = serializers.CharField(source="instructor.__str__", read_only=True)

    class Meta:
        model = CourseInstructor
        fields = ["id", "course", "instructor", "instructor_name", "sort_order"]
        validators = []  # uniqueness reported by validate() with a clear message

    def validate(self, attrs):
        course = attrs.get("course") or self.instance.course
        instructor = attrs.get("instructor") or self.instance.instructor
        university_id = course.level.faculty.university_id
        if instructor.university_id and instructor.university_id != university_id:
            raise serializers.ValidationError(
                {"instructor": _("Instructor belongs to a different university.")}
            )
        duplicates = CourseInstructor.objects.filter(course=course, instructor=instructor)
        if self.instance is not None:
            duplicates = duplicates.exclude(pk=self.instance.pk)
        if duplicates.exists():
            raise serializers.ValidationError(
                {"instructor": _("Instructor is already linked to this course.")}
            )
        return attrs
