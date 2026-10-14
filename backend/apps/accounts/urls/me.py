from django.urls import path

from apps.accounts import views

urlpatterns = [path("", views.MeView.as_view(), name="me")]
