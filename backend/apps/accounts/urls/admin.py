from rest_framework.routers import SimpleRouter

from apps.accounts import views

router = SimpleRouter()
router.register("users", views.AdminUserViewSet, basename="admin-user")

urlpatterns = router.urls
