"""Arabic-aware search (FR-031): normalisation rules, indexed content search, catalog search."""

import pytest
from django.db import connection
from django.test.utils import CaptureQueriesContext

from apps.academics.models import University
from apps.content.models import ContentItem
from apps.core.text import normalize, normalized_sql, search_terms
from tests.content_helpers import build_world
from tests.factories import UniversityFactory

CATALOG = "/api/v1/catalog/contents/"


class TestNormalize:
    @pytest.mark.parametrize(
        ("raw", "expected"),
        [
            ("أحمد", "احمد"),
            ("إبراهيم", "ابراهيم"),
            ("آمنة", "امنه"),
            ("مُحَاضَرَةٌ", "محاضره"),  # diacritics + taa marbuta
            ("مستشفى", "مستشفي"),  # alef maqsura
            ("مؤتمر", "موتمر"),
            ("رئيس", "رييس"),
            ("الكــيمياء", "الكيمياء"),  # tatweel
            ("محاضرة ٣", "محاضره 3"),  # Arabic-Indic digit
            ("  Anatomy   101 ", "anatomy 101"),
            ("", ""),
            (None, ""),
        ],
    )
    def test_rules(self, raw, expected):
        assert normalize(raw) == expected

    def test_terms_are_normalised_deduplicated_and_bounded(self):
        assert search_terms("أحمد احمد  تشريح") == ["احمد", "تشريح"]
        assert len(search_terms(" ".join(f"w{i}" for i in range(50)))) == 8

    @pytest.mark.django_db
    def test_sql_and_python_normalisation_agree(self):
        samples = ["أحمد", "مُحَاضَرَةٌ", "مستشفى", "مؤتمر رئيس", "الكــيمياء ٣", "ABC"]
        for sample in samples:
            UniversityFactory(name=sample)
        rows = University.objects.annotate(n=normalized_sql("name")).values_list("name", "n")
        for name, sql_value in rows:
            assert sql_value == normalize(name), name


@pytest.mark.django_db
class TestContentSearch:
    @pytest.fixture
    def world(self, db):
        return build_world()

    @pytest.mark.parametrize("query", ["احمد", "أحمد", "إحمد", "اَحْمَد"])
    def test_hamza_and_diacritics_insensitive(self, world, student_client, query):
        content_id = world.create_published(world.lecture_payload(title="محاضرة الدكتور أحمد"))
        assert [r["id"] for r in student_client.get(f"{CATALOG}?search={query}").json()["results"]] == [
            content_id
        ]

    def test_taa_marbuta_and_multi_term_and(self, world, student_client):
        hit = world.create_published(world.lecture_payload(title="مقدمة في علم التشريح"))
        world.create_published(world.lecture_payload(title="مقدمة في الفيزيولوجيا"))
        rows = student_client.get(f"{CATALOG}?search=مقدمه التشريح").json()["results"]
        assert [r["id"] for r in rows] == [hit]

    def test_matches_course_and_instructor_names(self, world, student_client):
        content_id = world.create_published()
        course_hits = student_client.get(f"{CATALOG}?search={world.course.name}").json()["count"]
        instructor_hits = student_client.get(f"{CATALOG}?search={world.instructor.full_name}").json()["count"]
        assert course_hits == instructor_hits == 1
        assert ContentItem.objects.get(pk=content_id).search_document

    def test_renaming_course_or_instructor_refreshes_documents(
        self, world, student_client, django_capture_on_commit_callbacks
    ):
        world.create_published()
        with django_capture_on_commit_callbacks(execute=True):
            world.course.name = "علم الأدوية"
            world.course.save()
            world.instructor.full_name = "سامر"
            world.instructor.save()
        assert student_client.get(f"{CATALOG}?search=الادويه").json()["count"] == 1
        assert student_client.get(f"{CATALOG}?search=سامر").json()["count"] == 1

    def test_title_edit_refreshes_document(self, world, student_client):
        content_id = world.create_published()
        world.library_client.patch(
            f"/api/v1/manage/contents/{content_id}/", {"title": "عنوان جديد"}, format="json"
        )
        assert student_client.get(f"{CATALOG}?search=جديد").json()["count"] == 1

    def test_search_uses_single_indexed_column(self, world, student_client):
        world.create_published()
        with CaptureQueriesContext(connection) as ctx:
            student_client.get(f"{CATALOG}?search=intro")
        sql = " ".join(q["sql"] for q in ctx.captured_queries)
        assert '"search_document"::text LIKE' in sql
        assert "UPPER(" not in sql  # no unindexable case-folding on joined columns

    def test_manage_search_is_scoped_too(self, world):
        world.create(world.lecture_payload(title="أحمد"))
        assert world.library_client.get("/api/v1/manage/contents/?search=احمد").json()["count"] == 1


@pytest.mark.django_db
class TestCatalogSearch:
    def test_university_search_normalised(self, student_client):
        target = UniversityFactory(name="جامعة الأندلس")
        UniversityFactory(name="Other")
        rows = student_client.get("/api/v1/catalog/universities/?search=الاندلس").json()["results"]
        assert [r["id"] for r in rows] == [target.pk]

    def test_admin_user_search_across_relation_fields(self, admin_client):
        from tests.factories import StudentFactory

        StudentFactory(full_name="إيمان")
        assert admin_client.get("/api/v1/admin/users/?search=ايمان").json()["count"] == 1
