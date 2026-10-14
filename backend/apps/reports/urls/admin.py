from rest_framework.routers import SimpleRouter

from apps.reports import views

router = SimpleRouter()
router.register("reports", views.AdminReportViewSet, basename="admin-report")

urlpatterns = router.urls
