from rest_framework.routers import SimpleRouter

from apps.devices import views

router = SimpleRouter()
router.register(
    "device-change-requests",
    views.DeviceChangeRequestFromNewDeviceViewSet,
    basename="auth-device-change-request",
)

urlpatterns = router.urls
