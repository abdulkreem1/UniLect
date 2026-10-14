import itertools

import pytest
from django.core.cache import cache
from rest_framework.test import APIClient

from tests.factories import DEFAULT_PASSWORD, AdminFactory, LibraryUserFactory, StudentFactory

_device_counter = itertools.count(1)


def new_installation_id() -> str:
    return f"install-{next(_device_counter):012d}-abcdef"


@pytest.fixture(autouse=True)
def _clear_cache():
    cache.clear()
    yield
    cache.clear()


@pytest.fixture
def api_client() -> APIClient:
    return APIClient()


def api_login(client: APIClient, user, password: str = DEFAULT_PASSWORD, installation_id: str | None = None):
    payload = {"email": user.email, "password": password}
    if installation_id:
        payload["device"] = {"installation_id": installation_id, "platform": "android", "model": "Pixel"}
    return client.post("/api/v1/auth/login/", payload, format="json")


def authenticate(client: APIClient, user, installation_id: str | None = None) -> dict:
    """Log in through the real API and configure the client with the access token (+ device header)."""
    if user.role == "student" and installation_id is None:
        installation_id = new_installation_id()
    response = api_login(client, user, installation_id=installation_id)
    assert response.status_code == 200, response.content
    headers = {"HTTP_AUTHORIZATION": f"Bearer {response.data['access']}"}
    if installation_id:
        headers["HTTP_X_DEVICE_ID"] = installation_id
    client.credentials(**headers)
    return {**response.data, "installation_id": installation_id}


@pytest.fixture
def admin_user(db):
    return AdminFactory()


@pytest.fixture
def student(db):
    return StudentFactory()


@pytest.fixture
def library_user(db):
    return LibraryUserFactory()


@pytest.fixture
def admin_client(admin_user):
    client = APIClient()
    authenticate(client, admin_user)
    return client


@pytest.fixture
def student_client(student):
    client = APIClient()
    client.session_info = authenticate(client, student)
    return client


@pytest.fixture
def library_client(library_user):
    client = APIClient()
    authenticate(client, library_user)
    return client
