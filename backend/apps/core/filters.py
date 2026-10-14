"""Arabic-aware keyword search backend (replaces DRF's SearchFilter).

Each whitespace-separated term must match (AND). Two strategies:

- ``search_document_field`` on the view: match against a pre-normalised, trigram-indexed column
  (used for content — fast at scale, one indexed column instead of OR across joins);
- otherwise ``search_fields``: normalise those columns in SQL on the fly (small catalog tables).
"""

from django.db.models import Q
from django.utils.translation import gettext_lazy as _
from rest_framework.filters import BaseFilterBackend

from .text import normalized_sql, search_terms

SEARCH_PARAM = "search"


class ArabicSearchFilter(BaseFilterBackend):
    def filter_queryset(self, request, queryset, view):
        terms = search_terms(request.query_params.get(SEARCH_PARAM))
        if not terms:
            return queryset
        document_field = getattr(view, "search_document_field", None)
        if document_field:
            for term in terms:
                queryset = queryset.filter(**{f"{document_field}__contains": term})
            return queryset

        fields = getattr(view, "search_fields", None) or []
        if not fields:
            return queryset
        aliases = {f"_search_{i}": normalized_sql(field) for i, field in enumerate(fields)}
        queryset = queryset.alias(**aliases)
        for term in terms:
            condition = Q()
            for alias in aliases:
                condition |= Q(**{f"{alias}__contains": term})
            queryset = queryset.filter(condition)
        return queryset  # search_fields only follow forward relations, so no duplicate rows

    def get_schema_operation_parameters(self, view):
        if not (getattr(view, "search_document_field", None) or getattr(view, "search_fields", None)):
            return []
        return [
            {
                "name": SEARCH_PARAM,
                "required": False,
                "in": "query",
                "description": str(
                    _("Keywords (all must match). Arabic letter variants and diacritics are ignored.")
                ),
                "schema": {"type": "string"},
            }
        ]
