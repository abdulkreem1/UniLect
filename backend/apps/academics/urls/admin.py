from rest_framework.routers import SimpleRouter

from apps.academics import views

router = SimpleRouter()
router.register("universities", views.AdminUniversityViewSet, basename="admin-university")
router.register("faculties", views.AdminFacultyViewSet, basename="admin-faculty")
router.register("levels", views.AdminLevelViewSet, basename="admin-level")
router.register("semesters", views.AdminSemesterViewSet, basename="admin-semester")
router.register("specializations", views.AdminSpecializationViewSet, basename="admin-specialization")
router.register("instructors", views.AdminInstructorViewSet, basename="admin-instructor")
router.register("courses", views.AdminCourseViewSet, basename="admin-course")
router.register("course-instructors", views.AdminCourseInstructorViewSet, basename="admin-course-instructor")

urlpatterns = router.urls
