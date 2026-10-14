from django.apps import AppConfig


class DashboardConfig(AppConfig):
    """Read-only cross-domain summaries. Depends on other apps; nothing depends on it."""

    name = "apps.dashboard"
    label = "dashboard"
