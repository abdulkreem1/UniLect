from django.apps import AppConfig


class ContentConfig(AppConfig):
    name = "apps.content"
    label = "content"

    def ready(self) -> None:
        from . import signals  # noqa: F401  (registers search-document maintenance)
