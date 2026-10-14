"""Consistent error envelope for every API error.

Every error response has the shape::

    {"error": {"code": "<stable_machine_code>", "message": "<human message>", "details": {...}}}

Clients must branch on ``code``; ``message`` is localised and may change.
"""

import logging

from django.core.exceptions import PermissionDenied as DjangoPermissionDenied
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db.models import ProtectedError, RestrictedError
from django.http import Http404
from django.utils.translation import gettext_lazy as _
from rest_framework import exceptions, status
from rest_framework.response import Response
from rest_framework.views import exception_handler

logger = logging.getLogger(__name__)


class ApiError(exceptions.APIException):
    """Domain error raised by services. Carries a stable code and optional details."""

    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "error"
    default_detail = _("The request could not be processed.")

    def __init__(self, detail=None, code=None, details: dict | None = None, status_code: int | None = None):
        super().__init__(detail=detail, code=code)
        self.details = details or {}
        if status_code is not None:
            self.status_code = status_code


class Conflict(ApiError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "conflict"
    default_detail = _("The request conflicts with the current state of the resource.")


class InvalidTransition(Conflict):
    default_code = "invalid_transition"
    default_detail = _("This action is not allowed in the current state.")


def _first_code(codes):
    if isinstance(codes, str):
        return codes
    if isinstance(codes, list) and codes:
        return _first_code(codes[0])
    if isinstance(codes, dict) and codes:
        return _first_code(next(iter(codes.values())))
    return "error"


def api_exception_handler(exc, context):
    if isinstance(exc, (ProtectedError, RestrictedError)):
        exc = Conflict(
            _("This item is referenced by other records and cannot be deleted. Deactivate it instead."),
            code="protected",
        )
    elif isinstance(exc, Http404):
        exc = exceptions.NotFound()
    elif isinstance(exc, DjangoPermissionDenied):
        exc = exceptions.PermissionDenied()
    elif isinstance(exc, DjangoValidationError):
        # e.g. password validators or model.full_clean() inside services
        exc = exceptions.ValidationError(
            exc.message_dict if hasattr(exc, "error_dict") else {"non_field_errors": exc.messages}
        )

    response = exception_handler(exc, context)
    if response is None:
        return None  # unhandled -> 500 via Django (logged, no internals leaked when DEBUG=False)

    details: dict = {}
    if isinstance(exc, exceptions.ValidationError):
        code = "validation_error"
        message = str(_("Invalid input."))
        details = {"fields": exc.detail} if isinstance(exc.detail, dict) else {"non_field_errors": exc.detail}
    else:
        detail = exc.detail if isinstance(exc, exceptions.APIException) else str(exc)
        code = _first_code(exc.get_codes()) if isinstance(exc, exceptions.APIException) else "error"
        message = str(detail if not isinstance(detail, (list, dict)) else _("Request failed."))
        if isinstance(exc, ApiError):
            details = exc.details
        if isinstance(exc, exceptions.Throttled) and exc.wait is not None:
            details = {"retry_after_seconds": int(exc.wait)}

    response.data = {"error": {"code": code, "message": message, "details": details}}
    return response


def error_response(code: str, message: str, http_status: int, details: dict | None = None) -> Response:
    return Response(
        {"error": {"code": code, "message": str(message), "details": details or {}}}, status=http_status
    )
