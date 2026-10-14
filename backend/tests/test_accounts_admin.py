"""Account administration, roles and profile (FR-001, FR-005..007, FR-059)."""

import pytest
from rest_framework.test import APIClient

from apps.accounts.models import Role, User
from apps.audit.models import AuditLog
from conftest import api_login, authenticate
from tests.factories import AdminFactory, LibraryFactory, StudentFactory, UniversityFactory

pytestmark = pytest.mark.django_db

USERS = "/api/v1/admin/users/"


def code(response):
    return response.json()["error"]["code"]


class TestCreateUsers:
    def test_create_student(self, admin_client):
        uni = UniversityFactory()
        response = admin_client.post(
            USERS,
            {
                "email": "New.Student@Example.com",
                "full_name": "New Student",
                "role": "student",
                "student_number": "S-1",
                "university": uni.pk,
                "password": "Temp-Password-123",
            },
            format="json",
        )
        assert response.status_code == 201, response.json()
        body = response.json()
        assert body["email"] == "new.student@example.com"
        assert body["must_change_password"] is True
        assert "password" not in body
        user = User.objects.get(pk=body["id"])
        assert user.check_password("Temp-Password-123")
        assert AuditLog.objects.filter(action="account.created", target_id=str(user.pk)).exists()

    def test_student_requires_number_and_university(self, admin_client):
        response = admin_client.post(
            USERS,
            {"email": "s@example.com", "full_name": "S", "role": "student", "password": "Temp-Password-123"},
            format="json",
        )
        assert response.status_code == 400
        fields = response.json()["error"]["details"]["fields"]
        assert {"student_number", "university"} <= fields.keys()

    def test_student_number_unique_per_university(self, admin_client):
        existing = StudentFactory(student_number="DUP")
        payload = {
            "email": "x@example.com",
            "full_name": "X",
            "role": "student",
            "student_number": "DUP",
            "password": "Temp-Password-123",
        }
        same_uni = admin_client.post(USERS, {**payload, "university": existing.university_id}, format="json")
        assert same_uni.status_code == 400
        other_uni = admin_client.post(USERS, {**payload, "university": UniversityFactory().pk}, format="json")
        assert other_uni.status_code == 201

    def test_duplicate_email_case_insensitive(self, admin_client):
        AdminFactory(email="taken@example.com")
        response = admin_client.post(
            USERS,
            {
                "email": "TAKEN@example.com",
                "full_name": "T",
                "role": "admin",
                "password": "Temp-Password-123",
            },
            format="json",
        )
        assert response.status_code == 400

    def test_library_account_requires_library(self, admin_client):
        payload = {
            "email": "lib@example.com",
            "full_name": "L",
            "role": "library",
            "password": "Temp-Password-123",
        }
        assert admin_client.post(USERS, payload, format="json").status_code == 400
        library = LibraryFactory()
        ok = admin_client.post(USERS, {**payload, "library": library.pk}, format="json")
        assert ok.status_code == 201
        assert ok.json()["library"] == library.pk

    def test_role_irrelevant_fields_are_cleared(self, admin_client):
        response = admin_client.post(
            USERS,
            {
                "email": "a2@example.com",
                "full_name": "A",
                "role": "admin",
                "library": LibraryFactory().pk,
                "student_number": "zzz",
                "password": "Temp-Password-123",
            },
            format="json",
        )
        assert response.status_code == 201
        assert response.json()["library"] is None
        assert response.json()["student_number"] is None

    def test_weak_password_rejected(self, admin_client):
        response = admin_client.post(
            USERS,
            {"email": "w@example.com", "full_name": "W", "role": "admin", "password": "123"},
            format="json",
        )
        assert response.status_code == 400

    def test_delete_not_allowed(self, admin_client):
        user = AdminFactory()
        assert admin_client.delete(f"{USERS}{user.pk}/").status_code == 405


class TestRoleEnforcement:
    @pytest.mark.parametrize("fixture", ["student_client", "library_client"])
    def test_non_admins_cannot_manage_accounts(self, request, fixture):
        client = request.getfixturevalue(fixture)
        assert client.get(USERS).status_code == 403
        response = client.post(
            USERS,
            {"email": "h@example.com", "full_name": "H", "role": "admin", "password": "Temp-Password-123"},
            format="json",
        )
        assert response.status_code == 403

    def test_admin_cannot_change_own_role(self, admin_client, admin_user):
        response = admin_client.patch(f"{USERS}{admin_user.pk}/", {"role": "student"}, format="json")
        assert response.status_code == 400

    def test_admin_cannot_deactivate_self(self, admin_client, admin_user):
        response = admin_client.post(f"{USERS}{admin_user.pk}/deactivate/")
        assert response.status_code == 400
        assert code(response) == "cannot_deactivate_self"

    def test_role_change_revokes_sessions(self, admin_client):
        other = AdminFactory()
        other_client = APIClient()
        authenticate(other_client, other)
        response = admin_client.patch(
            f"{USERS}{other.pk}/", {"role": "library", "library": LibraryFactory().pk}, format="json"
        )
        assert response.status_code == 200
        assert other_client.get("/api/v1/me/").status_code == 401

    def test_deactivate_then_reactivate(self, admin_client):
        other = AdminFactory()
        assert admin_client.post(f"{USERS}{other.pk}/deactivate/").json()["is_active"] is False
        assert api_login(APIClient(), other).status_code == 403
        assert admin_client.post(f"{USERS}{other.pk}/activate/").json()["is_active"] is True
        assert api_login(APIClient(), other).status_code == 200

    def test_admin_set_password_forces_change(self, admin_client):
        other = AdminFactory()
        response = admin_client.post(
            f"{USERS}{other.pk}/set-password/", {"password": "Admin-Chosen-987"}, format="json"
        )
        assert response.status_code == 204
        other.refresh_from_db()
        assert other.must_change_password and other.check_password("Admin-Chosen-987")

    def test_filter_and_search(self, admin_client):
        StudentFactory(full_name="Unique Findable Name")
        response = admin_client.get(f"{USERS}?role=student&search=Findable")
        assert response.json()["count"] == 1


class TestProfile:
    def test_get_profile(self, student_client, student):
        body = student_client.get("/api/v1/me/").json()
        assert body["email"] == student.email
        assert body["role"] == Role.STUDENT

    def test_student_can_update_phone(self, student_client, student):
        response = student_client.patch("/api/v1/me/", {"phone": "+963 900 000"}, format="json")
        assert response.status_code == 200
        student.refresh_from_db()
        assert student.phone == "+963 900 000"

    @pytest.mark.parametrize(
        "payload",
        [{"role": "admin"}, {"email": "x@example.com"}, {"student_number": "1"}, {"full_name": "Me"}],
    )
    def test_protected_fields_rejected(self, student_client, student, payload):
        response = student_client.patch("/api/v1/me/", payload, format="json")
        assert response.status_code == 400
        student.refresh_from_db()
        assert student.role == Role.STUDENT

    def test_library_staff_can_update_name(self, library_client, library_user):
        assert library_client.patch("/api/v1/me/", {"full_name": "New"}, format="json").status_code == 200

    def test_put_not_allowed(self, student_client):
        assert student_client.put("/api/v1/me/", {"phone": "1"}, format="json").status_code == 405
