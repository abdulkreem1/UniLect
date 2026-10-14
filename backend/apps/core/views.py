from django.db import connection
from drf_spectacular.utils import extend_schema
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView


class HealthView(APIView):
    """Liveness/readiness probe for load balancers. Reveals nothing sensitive."""

    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = []

    @extend_schema(exclude=True)
    def get(self, request):
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
        return Response({"status": "ok"})


def server_error(request, *args, **kwargs):
    """JSON 500 in the standard error envelope; internals are only in server logs (FR-080)."""
    from django.http import JsonResponse

    return JsonResponse(
        {"error": {"code": "server_error", "message": "An unexpected error occurred.", "details": {}}},
        status=500,
    )
