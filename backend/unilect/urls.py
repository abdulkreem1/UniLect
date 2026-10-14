from django.conf import settings
from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

from apps.config.views import ClientConfigView
from apps.core.views import HealthView

api_v1 = [
    path("auth/", include("apps.accounts.urls.auth")),
    path("auth/", include("apps.devices.urls.auth")),
    path("me/", include("apps.accounts.urls.me")),
    path("me/", include("apps.devices.urls.me")),
    path("me/", include("apps.notifications.urls")),
    path("me/", include("apps.content.urls.me")),
    path("catalog/", include("apps.academics.urls.catalog")),
    path("catalog/", include("apps.content.urls.catalog")),
    path("manage/", include("apps.content.urls.manage")),
    path("admin/", include("apps.accounts.urls.admin")),
    path("admin/", include("apps.devices.urls.admin")),
    path("admin/", include("apps.academics.urls.admin")),
    path("admin/", include("apps.libraries.urls")),
    path("admin/", include("apps.content.urls.admin")),
    path("admin/", include("apps.reports.urls.admin")),
    path("admin/", include("apps.audit.urls")),
    path("admin/", include("apps.config.urls")),
    path("admin/", include("apps.dashboard.urls")),
    path("catalog/", include("apps.reports.urls.catalog")),
    path("config/", ClientConfigView.as_view(), name="client-config"),
    path("schema/", SpectacularAPIView.as_view(), name="schema"),
    path("docs/", SpectacularSwaggerView.as_view(url_name="schema"), name="swagger-ui"),
]

urlpatterns = [
    path("health/", HealthView.as_view(), name="health"),
    path("api/v1/", include(api_v1)),
    path(settings.DJANGO_ADMIN_URL, admin.site.urls),
]

handler500 = "apps.core.views.server_error"
