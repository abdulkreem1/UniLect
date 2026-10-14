from django.urls import path

from apps.accounts import views

urlpatterns = [
    path("login/", views.LoginView.as_view(), name="auth-login"),
    path("refresh/", views.RefreshView.as_view(), name="auth-refresh"),
    path("logout/", views.LogoutView.as_view(), name="auth-logout"),
    path("password/change/", views.PasswordChangeView.as_view(), name="auth-password-change"),
    path("password/reset/", views.PasswordResetRequestView.as_view(), name="auth-password-reset"),
    path(
        "password/reset/confirm/",
        views.PasswordResetConfirmView.as_view(),
        name="auth-password-reset-confirm",
    ),
]
