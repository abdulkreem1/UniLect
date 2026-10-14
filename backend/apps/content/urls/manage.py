from django.urls import path
from rest_framework.routers import SimpleRouter

from apps.content import views

router = SimpleRouter()
router.register("contents", views.ManageContentViewSet, basename="manage-content")

urlpatterns = [path("stats/", views.ManageStatsView.as_view(), name="manage-stats"), *router.urls]
