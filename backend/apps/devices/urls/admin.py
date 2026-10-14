from rest_framework.routers import SimpleRouter

from apps.devices import views

router = SimpleRouter()
router.register(
    "device-change-requests", views.AdminDeviceChangeRequestViewSet, basename="admin-device-change-request"
)

urlpatterns = router.urls
