from django.apps import AppConfig


class MaintenanceConfig(AppConfig):
    """Operational jobs (retention/purge). Depends on domain apps; nothing depends on it."""

    name = "apps.maintenance"
    label = "maintenance"
