"""Single-device binding and the device-change workflow (FR-008..015, FR-067, FR-070, FR-075)."""

import pytest
from django.db import IntegrityError
from rest_framework.test import APIClient

from apps.audit.models import AuditLog
from apps.devices.models import DeviceChangeRequest, StudentDevice
from apps.notifications.models import Notification
from conftest import api_login, authenticate, new_installation_id
from tests.factories import StudentFactory

pytestmark = pytest.mark.django_db

ME = "/api/v1/me/"
NEW_DEVICE_REQUESTS = "/api/v1/auth/device-change-requests/"


def error(response):
    return response.json()["error"]


def unbound_login(student, installation_id):
    """Attempt a login from a second device; returns (client configured with restricted token, response)."""
    client = APIClient()
    response = api_login(client, student, installation_id=installation_id)
    assert response.status_code == 403
    token = error(response)["details"]["device_change_token"]
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}", HTTP_X_DEVICE_ID=installation_id)
    return client, response


class TestBinding:
    def test_first_login_binds_device(self, api_client):
        student = StudentFactory()
        authenticate(api_client, student)
        assert StudentDevice.objects.filter(student=student, status="active").count() == 1
        assert AuditLog.objects.filter(action="device.bound", category="device").exists()

    def test_same_device_can_login_again(self):
        student = StudentFactory()
        install = new_installation_id()
        authenticate(APIClient(), student, install)
        authenticate(APIClient(), student, install)
        assert StudentDevice.objects.filter(student=student).count() == 1

    def test_second_device_is_refused_with_explanation(self):
        student = StudentFactory()
        authenticate(APIClient(), student)
        response = api_login(APIClient(), student, installation_id=new_installation_id())
        assert response.status_code == 403
        body = error(response)
        assert body["code"] == "device_not_bound"
        assert "device change request" in body["message"].lower()
        assert body["details"]["device_change_token"]
        assert body["details"]["pending_request"] is None
        assert StudentDevice.objects.filter(student=student, status="active").count() == 1

    def test_installation_id_is_not_stored_in_plaintext(self):
        student = StudentFactory()
        install = new_installation_id()
        authenticate(APIClient(), student, install)
        device = StudentDevice.objects.get(student=student)
        assert install not in device.installation_id_hash
        assert len(device.installation_id_hash) == 64

    def test_token_used_from_another_device_is_rejected(self, student_client):
        student_client.credentials(
            HTTP_AUTHORIZATION=student_client._credentials["HTTP_AUTHORIZATION"],
            HTTP_X_DEVICE_ID=new_installation_id(),
        )
        response = student_client.get(ME)
        assert response.status_code == 403
        assert error(response)["code"] == "device_mismatch"

    def test_token_without_device_header_is_rejected(self, student_client):
        student_client.credentials(HTTP_AUTHORIZATION=student_client._credentials["HTTP_AUTHORIZATION"])
        assert student_client.get(ME).status_code == 403

    def test_database_forbids_two_active_devices(self):
        student = StudentFactory()
        StudentDevice.objects.create(student=student, installation_id_hash="a" * 64, platform="ios")
        with pytest.raises(IntegrityError):
            StudentDevice.objects.create(student=student, installation_id_hash="b" * 64, platform="ios")


class TestChangeRequestFlow:
    def test_full_approval_flow(self, admin_client):
        student = StudentFactory()
        old_client = APIClient()
        old = authenticate(old_client, student)
        new_install = new_installation_id()

        restricted, _ = unbound_login(student, new_install)
        created = restricted.post(NEW_DEVICE_REQUESTS, {"reason": "Phone broke"}, format="json")
        assert created.status_code == 201
        assert created.json()["status"] == "pending"

        # appears in the admin dashboard list (FR-011, FR-067)
        listing = admin_client.get("/api/v1/admin/device-change-requests/?status=pending")
        assert listing.json()["count"] == 1
        request_id = created.json()["id"]

        approved = admin_client.post(
            f"/api/v1/admin/device-change-requests/{request_id}/approve/", {"note": "ok"}, format="json"
        )
        assert approved.status_code == 200
        body = approved.json()
        assert body["status"] == "approved"
        assert body["decided_by"] is not None and body["decided_at"] is not None  # FR-012

        # FR-013/014: the old device and its tokens are dead
        assert old_client.get(ME).status_code == 401
        old_refresh = APIClient()
        old_refresh.credentials(HTTP_X_DEVICE_ID=old["installation_id"])
        assert (
            old_refresh.post("/api/v1/auth/refresh/", {"refresh": old["refresh"]}, format="json").status_code
            == 401
        )
        assert api_login(APIClient(), student, installation_id=old["installation_id"]).status_code == 403

        # the new device can now sign in normally
        new_client = APIClient()
        authenticate(new_client, student, new_install)
        assert new_client.get(ME).status_code == 200
        assert StudentDevice.objects.filter(student=student, status="active").count() == 1

        # FR-070 + FR-015
        assert Notification.objects.filter(recipient=student, type="device_change_approved").exists()
        actions = set(AuditLog.objects.filter(category="device").values_list("action", flat=True))
        assert {"device.bound", "device.change_requested", "device.change_approved"} <= actions

    def test_rejection_keeps_old_device_and_notifies(self, admin_client):
        student = StudentFactory()
        old_client = APIClient()
        authenticate(old_client, student)
        restricted, _ = unbound_login(student, new_installation_id())
        request_id = restricted.post(NEW_DEVICE_REQUESTS, {}, format="json").json()["id"]

        rejected = admin_client.post(
            f"/api/v1/admin/device-change-requests/{request_id}/reject/",
            {"note": "Suspicious"},
            format="json",
        )
        assert rejected.status_code == 200
        assert rejected.json()["decision_note"] == "Suspicious"
        assert old_client.get(ME).status_code == 200
        notification = Notification.objects.get(recipient=student, type="device_change_rejected")
        assert "Suspicious" in notification.body
        # Student sees the outcome from the new device
        assert restricted.get(NEW_DEVICE_REQUESTS).json()[0]["status"] == "rejected"

    def test_cannot_decide_twice(self, admin_client):
        student = StudentFactory()
        authenticate(APIClient(), student)
        restricted, _ = unbound_login(student, new_installation_id())
        request_id = restricted.post(NEW_DEVICE_REQUESTS, {}, format="json").json()["id"]
        admin_client.post(f"/api/v1/admin/device-change-requests/{request_id}/reject/")
        again = admin_client.post(f"/api/v1/admin/device-change-requests/{request_id}/approve/")
        assert again.status_code == 409
        assert error(again)["code"] == "invalid_transition"

    def test_only_one_pending_request(self):
        student = StudentFactory()
        authenticate(APIClient(), student)
        restricted, _ = unbound_login(student, new_installation_id())
        assert restricted.post(NEW_DEVICE_REQUESTS, {}, format="json").status_code == 201
        duplicate = restricted.post(NEW_DEVICE_REQUESTS, {}, format="json")
        assert duplicate.status_code == 409
        assert error(duplicate)["code"] == "request_already_pending"

    def test_login_reports_pending_request(self):
        student = StudentFactory()
        authenticate(APIClient(), student)
        install = new_installation_id()
        restricted, _ = unbound_login(student, install)
        restricted.post(NEW_DEVICE_REQUESTS, {}, format="json")
        response = api_login(APIClient(), student, installation_id=install)
        assert error(response)["details"]["pending_request"] is not None

    def test_student_can_cancel(self):
        student = StudentFactory()
        authenticate(APIClient(), student)
        restricted, _ = unbound_login(student, new_installation_id())
        request_id = restricted.post(NEW_DEVICE_REQUESTS, {}, format="json").json()["id"]
        response = restricted.post(f"{NEW_DEVICE_REQUESTS}{request_id}/cancel/")
        assert response.status_code == 200
        assert response.json()["status"] == "cancelled"

    def test_restricted_token_cannot_access_anything_else(self):
        student = StudentFactory()
        authenticate(APIClient(), student)
        restricted, _ = unbound_login(student, new_installation_id())
        assert restricted.get(ME).status_code == 401
        assert restricted.get("/api/v1/catalog/universities/").status_code == 401

    def test_restricted_token_bound_to_requesting_device(self):
        student = StudentFactory()
        authenticate(APIClient(), student)
        restricted, _ = unbound_login(student, new_installation_id())
        restricted.credentials(
            HTTP_AUTHORIZATION=restricted._credentials["HTTP_AUTHORIZATION"],
            HTTP_X_DEVICE_ID=new_installation_id(),
        )
        response = restricted.post(NEW_DEVICE_REQUESTS, {}, format="json")
        assert response.status_code == 403

    def test_access_token_not_accepted_on_restricted_endpoint(self, student_client):
        assert student_client.post(NEW_DEVICE_REQUESTS, {}, format="json").status_code == 401

    def test_students_cannot_decide_requests(self, student_client):
        assert student_client.get("/api/v1/admin/device-change-requests/").status_code == 403

    def test_students_only_see_their_own_requests(self):
        a, b = StudentFactory(), StudentFactory()
        for s in (a, b):
            authenticate(APIClient(), s)
        restricted_a, _ = unbound_login(a, new_installation_id())
        restricted_b, _ = unbound_login(b, new_installation_id())
        id_a = restricted_a.post(NEW_DEVICE_REQUESTS, {}, format="json").json()["id"]
        assert restricted_b.get(f"{NEW_DEVICE_REQUESTS}{id_a}/").status_code == 404
        assert restricted_b.post(f"{NEW_DEVICE_REQUESTS}{id_a}/cancel/").status_code == 404


class TestAdminReset:
    def test_reset_unbinds_and_next_login_binds_new_device(self, admin_client):
        student = StudentFactory()
        old_client = APIClient()
        authenticate(old_client, student)
        restricted, _ = unbound_login(student, new_installation_id())
        restricted.post(NEW_DEVICE_REQUESTS, {}, format="json")

        assert admin_client.post(f"/api/v1/admin/users/{student.pk}/reset-device/").status_code == 204
        assert old_client.get(ME).status_code == 401
        assert DeviceChangeRequest.objects.get(student=student).status == "cancelled"

        new_client = APIClient()
        authenticate(new_client, student, new_installation_id())
        assert new_client.get(ME).status_code == 200

    def test_device_history(self, admin_client):
        student = StudentFactory()
        authenticate(APIClient(), student)
        response = admin_client.get(f"/api/v1/admin/users/{student.pk}/devices/")
        assert response.status_code == 200
        assert len(response.json()) == 1

    def test_my_device(self, student_client):
        response = student_client.get("/api/v1/me/device/")
        assert response.status_code == 200
        assert response.json()["status"] == "active"
        assert "installation_id_hash" not in response.json()
