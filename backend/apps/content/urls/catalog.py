from rest_framework.routers import SimpleRouter

from apps.content import views

router = SimpleRouter()
router.register("contents", views.CatalogContentViewSet, basename="catalog-content")
router.register(
    "lecture-categories", views.CatalogLectureCategoryViewSet, basename="catalog-lecture-category"
)
router.register("exam-types", views.CatalogExamTypeViewSet, basename="catalog-exam-type")

urlpatterns = router.urls
