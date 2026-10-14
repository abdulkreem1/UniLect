"""Real concurrency: parallel requests on separate DB connections, released together by a barrier.

These exercise the row locks and partial unique indexes that unit tests can't (FR-008, 010, 012, 075).
"""

import threading

import pytest
from django.db import connection, connections
from rest_framework.test import APIClient

from apps.devices import services as device_services
from apps.devices.models import DeviceChangeRequest, StudentDevice
from conftest import api_login, authenticate, new_installation_id
from tests.factories import AdminFactory, StudentFactory

pytestmark = pytest.mark.django_db(transaction=True)
ROUNDS = 5


def run_parallel(*jobs):
    """Run callables simultaneously; return their results (exceptions are returned, not raised)."""
    barrier = threading.Barrier(len(jobs))
    results = [None] * len(jobs)

    def worker(i, job):
        try:
            barrier.wait(timeout=10)
            results[i] = job()
        except Exception as exc:  # surfaced to the assertion, e.g. a deadlock
            results[i] = exc
        finally:
            connections.close_all()

    threads = [threading.Thread(target=worker, args=(i, job)) for i, job in enumerate(jobs)]
    for t in threads:
        t.start()
    for t in threads:
        t.join(timeout=30)
    return results


@pytest.fixture(autouse=True)
def _require_postgres():
    assert connection.vendor == "postgresql"


def test_simultaneous_first_logins_bind_exactly_one_device():
    for _ in range(ROUNDS):
        student = StudentFactory()
        statuses = run_parallel(
            lambda s=student: api_login(APIClient(), s, installation_id=new_installation_id()).status_code,
            lambda s=student: api_login(APIClient(), s, installation_id=new_installation_id()).status_code,
            lambda s=student: api_login(APIClient(), s, installation_id=new_installation_id()).status_code,
        )
        assert sorted(statuses) == [200, 403, 403], statuses
        assert StudentDevice.objects.filter(student=student, status="active").count() == 1


def test_duplicate_change_requests_yield_one_pending():
    for _ in range(ROUNDS):
        student = StudentFactory()
        authenticate(APIClient(), student)
        info = device_services.DeviceInfo(installation_id_hash="f" * 64, platform="ios")
        results = run_parallel(
            lambda s=student, i=info: device_services.create_change_request(s, i),
            lambda s=student, i=info: device_services.create_change_request(s, i),
        )
        created = [r for r in results if isinstance(r, DeviceChangeRequest)]
        conflicts = [r for r in results if getattr(r, "default_code", "") == "conflict"]
        assert len(created) == 1 and len(conflicts) == 1, results
        assert DeviceChangeRequest.objects.filter(student=student, status="pending").count() == 1


def test_approve_and_reset_racing_never_deadlock():
    """Regression: approve locked request→student while reset locked student→request."""
    admin = AdminFactory()
    for _ in range(ROUNDS):
        student = StudentFactory()
        authenticate(APIClient(), student)
        change = device_services.create_change_request(
            student, device_services.DeviceInfo(installation_id_hash="e" * 64, platform="android")
        )
        results = run_parallel(
            lambda c=change: device_services.approve_change_request(c, admin),
            lambda s=student: device_services.reset_student_device(s, admin),
        )
        unexpected = [
            r
            for r in results
            if isinstance(r, Exception) and getattr(r, "default_code", "") != "invalid_transition"
        ]
        assert not unexpected, unexpected
        assert StudentDevice.objects.filter(student=student, status="active").count() <= 1


def test_parallel_refresh_with_same_token_issues_at_most_one_pair():
    for _ in range(ROUNDS):
        admin = AdminFactory()
        tokens = authenticate(APIClient(), admin)

        def refresh(tokens=tokens):
            return (
                APIClient()
                .post("/api/v1/auth/refresh/", {"refresh": tokens["refresh"]}, format="json")
                .status_code
            )

        statuses = run_parallel(refresh, refresh, refresh)
        assert all(s in (200, 401) for s in statuses), statuses
        assert statuses.count(200) <= 1
