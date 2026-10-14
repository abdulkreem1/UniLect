from rest_framework.routers import SimpleRouter

from apps.academics import views

router = SimpleRouter()
router.register("universities", views.CatalogUniversityViewSet, basename="catalog-university")
router.register("faculties", views.CatalogFacultyViewSet, basename="catalog-faculty")
router.register("levels", views.CatalogLevelViewSet, basename="catalog-level")
router.register("semesters", views.CatalogSemesterViewSet, basename="catalog-semester")
router.register("specializations", views.CatalogSpecializationViewSet, basename="catalog-specialization")
router.register("courses", views.CatalogCourseViewSet, basename="catalog-course")

urlpatterns = router.urls
