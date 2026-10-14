from rest_framework.routers import SimpleRouter

from apps.content import views

router = SimpleRouter()
router.register("lecture-categories", views.AdminLectureCategoryViewSet, basename="admin-lecture-category")
router.register("exam-types", views.AdminExamTypeViewSet, basename="admin-exam-type")

urlpatterns = router.urls
