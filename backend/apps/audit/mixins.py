from django.db import transaction

from . import services


class AuditedModelViewSetMixin:
    """Records create/update/delete performed through a ModelViewSet."""

    audit_category: str = services.Category.CATALOG

    def _audit(self, action: str, instance, metadata=None) -> None:
        services.record(
            action=f"{instance._meta.model_name}.{action}",
            category=self.audit_category,
            actor=self.request.user,
            target=instance,
            metadata=metadata,
            request=self.request,
        )

    def perform_create(self, serializer):
        with transaction.atomic():
            instance = serializer.save()
            self._audit("created", instance, {"fields": sorted(serializer.validated_data.keys())})

    def perform_update(self, serializer):
        with transaction.atomic():
            instance = serializer.save()
            self._audit("updated", instance, {"fields": sorted(serializer.validated_data.keys())})

    def perform_destroy(self, instance):
        with transaction.atomic():
            self._audit("deleted", instance)
            instance.delete()
