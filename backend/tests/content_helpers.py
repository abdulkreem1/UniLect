import io
from dataclasses import dataclass

from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image
from pypdf import PdfWriter
from rest_framework.test import APIClient

from apps.content.models import ExamType, LectureCategory
from conftest import authenticate
from tests.factories import (
    CourseFactory,
    CourseInstructorFactory,
    LibraryUserFactory,
    SemesterFactory,
)


def pdf_bytes(pages: int = 2) -> bytes:
    writer = PdfWriter()
    for _ in range(pages):
        writer.add_blank_page(width=200, height=200)
    buffer = io.BytesIO()
    writer.write(buffer)
    return buffer.getvalue()


def png_bytes() -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (20, 20), "red").save(buffer, format="PNG")
    return buffer.getvalue()


def upload(name: str = "lecture.pdf", data: bytes | None = None, content_type: str = "application/pdf"):
    return SimpleUploadedFile(name, pdf_bytes() if data is None else data, content_type=content_type)


@dataclass
class World:
    course: object
    instructor: object
    semester: object
    category: object
    exam_type: object
    library_user: object
    library_client: APIClient

    def lecture_payload(self, **overrides) -> dict:
        payload = {
            "kind": "lecture",
            "title": "Lecture 1 - Introduction",
            "description": "Basics",
            "course": self.course.pk,
            "instructor": self.instructor.pk,
            "category": self.category.pk,
            "lecture_number": 1,
        }
        payload.update(overrides)
        return payload

    def exam_payload(self, **overrides) -> dict:
        payload = {
            "kind": "exam",
            "title": "Final exam 2023",
            "course": self.course.pk,
            "exam_year": 2023,
            "exam_type": self.exam_type.pk,
            "semester": self.semester.pk,
        }
        payload.update(overrides)
        return payload

    def create(self, payload: dict | None = None, file=True, client: APIClient | None = None):
        data = {k: v for k, v in (payload or self.lecture_payload()).items() if v is not None}
        if file:
            data["file"] = upload() if file is True else file
        return (client or self.library_client).post("/api/v1/manage/contents/", data, format="multipart")

    def create_published(self, payload: dict | None = None) -> str:
        response = self.create(payload)
        assert response.status_code == 201, response.json()
        content_id = response.json()["id"]
        submitted = self.library_client.post(f"/api/v1/manage/contents/{content_id}/submit/")
        assert submitted.status_code == 200, submitted.json()
        return content_id


def build_world() -> World:
    semester = SemesterFactory()
    course = CourseFactory(level__faculty=semester.faculty, semester=semester)
    instructor = CourseInstructorFactory(course=course).instructor
    category = LectureCategory.objects.create(name="Theory")
    exam_type = ExamType.objects.create(name="First session")
    library_user = LibraryUserFactory()
    library_user.library.scope_faculties.add(course.level.faculty)
    client = APIClient()
    authenticate(client, library_user)
    return World(course, instructor, semester, category, exam_type, library_user, client)
