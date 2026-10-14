from django.urls import path
from rest_framework.routers import SimpleRouter

from apps.devices import views

router = SimpleRouter()
router.register(
    "device-change-requests", views.MyDeviceChangeRequestsViewSet, basename="my-device-change-request"
)

urlpatterns = [path("device/", views.MyDeviceView.as_view(), name="my-device"), *router.urls]
