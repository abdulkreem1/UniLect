import re
import uuid

from .logging import request_id_var

_VALID_REQUEST_ID = re.compile(r"^[A-Za-z0-9\-]{8,64}$")


class RequestIDMiddleware:
    """Attach a correlation id to every request/response and to log records."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        incoming = request.headers.get("X-Request-ID", "")
        request_id = incoming if _VALID_REQUEST_ID.match(incoming) else uuid.uuid4().hex
        request.request_id = request_id
        token = request_id_var.set(request_id)
        try:
            response = self.get_response(request)
        finally:
            request_id_var.reset(token)
        response["X-Request-ID"] = request_id
        return response
