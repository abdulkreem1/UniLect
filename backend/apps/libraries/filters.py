"""``?in_scope=true``: narrow catalog lists to the caller's library scope (FR-060).

Library staff pick the academic path of new content from the catalog; offering only nodes that
contain at least one in-scope course spares them choices the server would reject anyway. The
server still validates scope on every write. Views opt in with ``library_scope_path``: the lookup
path from the listed model to ``Course`` (``""`` when the view lists courses itself).
"""

from django.utils.translation import gettext_lazy as _
from rest_framework.filters import BaseFilterBackend

from apps.accounts.models import Role

from .selectors import courses_in_scope

IN_SCOPE_PARAM = "in_scope"


class LibraryScopeFilter(BaseFilterBackend):
    def filter_queryset(self, request, queryset, view):
        path = getattr(view, "library_scope_path", None)
        user = request.user
        if (
            path is None
            or request.query_params.get(IN_SCOPE_PARAM) != "true"
            or getattr(user, "role", None) != Role.LIBRARY
            or not user.library_id
        ):
            return queryset
        courses = courses_in_scope(user.library).values("pk")
        if not path:
            return queryset.filter(pk__in=courses)
        return queryset.filter(**{f"{path}__in": courses}).distinct()

    def get_schema_operation_parameters(self, view):
        if getattr(view, "library_scope_path", None) is None:
            return []
        return [
            {
                "name": IN_SCOPE_PARAM,
                "required": False,
                "in": "query",
                "description": str(
                    _("Library staff: only items containing courses inside the library's scope.")
                ),
                "schema": {"type": "boolean"},
            }
        ]
