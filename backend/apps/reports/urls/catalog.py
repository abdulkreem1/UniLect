from django.urls import path

from apps.reports import views

urlpatterns = [
    path(
        "contents/<uuid:content_id>/reports/",
        views.ContentReportCreateView.as_view(),
        name="content-report-create",
    ),
]
