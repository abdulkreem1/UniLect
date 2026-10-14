"""Cross-cutting security behaviour (FR-077, FR-080)."""

import pytest
from django.test import override_settings
from django.urls import path
from rest_framework.test import APIClient

from apps.accounts.models import Role
from tests.factories import AdminFactory

pytestmark = pytest.mark.django_db


def _boom(request):
    raise RuntimeError("secret internal detail")


urlpatterns = [path("boom/", _boom)]
handler500 = "apps.core.views.server_error"


@override_settings(ROOT_URLCONF=__name__, DEBUG=False)
def test_unhandled_error_returns_json_without_internals():
    client = APIClient(raise_request_exception=False)
    response = client.get("/boom/")
    assert response.status_code == 500
    assert response.json()["error"]["code"] == "server_error"
    assert b"secret internal detail" not in response.content


ADMIN_ONLY = [
    ("get", "/api/v1/admin/users/"),
    ("get", "/api/v1/admin/device-change-requests/"),
    ("get", "/api/v1/admin/audit-logs/"),
    ("get", "/api/v1/admin/dashboard/"),
    ("get", "/api/v1/admin/reports/"),
    ("get", "/api/v1/admin/libraries/"),
    ("post", "/api/v1/admin/universities/"),
    ("patch", "/api/v1/admin/settings/"),
]
LIBRARY_OR_ADMIN = [("get", "/api/v1/manage/contents/"), ("get", "/api/v1/manage/stats/")]
STUDENT_ONLY = [
    ("get", "/api/v1/me/favorites/"),
    ("get", "/api/v1/me/followed-courses/"),
    ("get", "/api/v1/me/device/"),
]


@pytest.mark.parametrize(("method", "url"), ADMIN_ONLY + LIBRARY_OR_ADMIN + STUDENT_ONLY)
def test_anonymous_is_rejected_everywhere(method, url):
    assert getattr(APIClient(), method)(url, {}, format="json").status_code == 401


@pytest.mark.parametrize(("method", "url"), ADMIN_ONLY)
@pytest.mark.parametrize("client_fixture", ["student_client", "library_client"])
def test_admin_endpoints_reject_other_roles(request, client_fixture, method, url):
    client = request.getfixturevalue(client_fixture)
    assert getattr(client, method)(url, {}, format="json").status_code == 403


@pytest.mark.parametrize(("method", "url"), LIBRARY_OR_ADMIN)
def test_management_rejects_students(student_client, method, url):
    assert getattr(student_client, method)(url).status_code == 403


@pytest.mark.parametrize(("method", "url"), STUDENT_ONLY)
def test_student_endpoints_reject_staff(library_client, method, url):
    assert getattr(library_client, method)(url).status_code == 403


def test_privilege_escalation_via_profile_is_blocked(library_client, library_user):
    response = library_client.patch("/api/v1/me/", {"role": "admin"}, format="json")
    assert response.status_code == 400
    library_user.refresh_from_db()
    assert library_user.role == Role.LIBRARY


def test_superuser_command_creates_admin_role():
    from django.contrib.auth import get_user_model

    user = get_user_model().objects.create_superuser(
        "root@example.com", "Very-Strong-Root-1", full_name="Root"
    )
    assert user.role == Role.ADMIN and user.is_staff and user.is_superuser
    assert AdminFactory._meta.model is type(user)
