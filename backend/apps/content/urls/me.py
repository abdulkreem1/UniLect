from rest_framework.routers import SimpleRouter

from apps.content import views

router = SimpleRouter()
router.register("favorites", views.FavoriteViewSet, basename="favorite")
router.register("followed-courses", views.CourseFollowViewSet, basename="course-follow")

urlpatterns = router.urls
