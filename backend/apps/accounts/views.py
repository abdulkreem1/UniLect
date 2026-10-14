from django.db.models import Prefetch
from django.utils.translation import gettext as _
from drf_spectacular.utils import OpenApiResponse, extend_schema, inline_serializer
from rest_framework import mixins, serializers, status, viewsets
from rest_framework.decorators import action
from rest_framework.generics import RetrieveUpdateAPIView
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from apps.accounts.permissions import IsAdmin
from apps.audit.services import client_ip
from apps.core.exceptions import ApiError
from apps.devices import services as device_services
from apps.devices.models import StudentDevice

from . import serializers as s
from . import throttling
from .models import User
from .services import admin as admin_services
from .services import passwords, sessions


def current_session(request):
    return getattr(request._request, "auth_session", None)


class PublicAuthView(APIView):
    """Unauthenticated endpoint that can still answer 401 (DRF downgrades 401→403 without a challenge)."""

    authentication_classes = []
    permission_classes = [AllowAny]

    def get_authenticate_header(self, request):
        return 'Bearer realm="api"'


class LoginView(PublicAuthView):
    """FR-002 / FR-008 / FR-010. Students must send ``device``; first login binds it."""

    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "auth_login"

    @extend_schema(
        request=s.LoginSerializer,
        responses={
            200: s.LoginResponseSerializer,
            401: OpenApiResponse(description="invalid_credentials"),
            403: OpenApiResponse(
                description="account_disabled | device_not_bound (details contain device_change_token)"
            ),
            429: OpenApiResponse(description="too_many_failed_attempts / throttled"),
        },
    )
    def post(self, request):
        serializer = s.LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        identifier = serializer.identifier
        ip = client_ip(request)
        if throttling.is_locked(identifier, ip):
            raise ApiError(
                _("Too many failed sign-in attempts. Try again later."),
                code="too_many_failed_attempts",
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            )
        data = serializer.validated_data
        user = sessions.find_user_for_login(
            email=data.get("email"),
            student_number=data.get("student_number"),
            university_id=data.get("university"),
        )
        try:
            user = sessions.check_credentials(user, data["password"])
        except sessions.InvalidCredentials:
            throttling.register_failure(identifier, ip)
            raise
        throttling.reset(identifier, ip)
        result = sessions.login(user, serializer.device_info(), request=request)
        return Response({**result.tokens, "user": s.UserSummarySerializer(user).data})


class RefreshView(PublicAuthView):
    """Rotates the refresh token. Students must send X-Device-ID."""

    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "auth_refresh"

    @extend_schema(request=s.RefreshSerializer, responses=s.TokenPairSerializer)
    def post(self, request):
        serializer = s.RefreshSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(sessions.refresh_session(serializer.validated_data["refresh"], request))


class LogoutView(APIView):
    """FR-003: ends the current session; its access and refresh tokens stop working immediately."""

    @extend_schema(request=None, responses={204: OpenApiResponse(description="Logged out")})
    def post(self, request):
        sessions.logout(current_session(request), request=request)
        return Response(status=status.HTTP_204_NO_CONTENT)


class PasswordChangeView(APIView):
    @extend_schema(
        request=s.PasswordChangeSerializer, responses={204: OpenApiResponse(description="Changed")}
    )
    def post(self, request):
        serializer = s.PasswordChangeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        passwords.change_password(
            request.user,
            serializer.validated_data["current_password"],
            serializer.validated_data["new_password"],
            current_session(request),
            request=request,
        )
        return Response(status=status.HTTP_204_NO_CONTENT)


class PasswordResetRequestView(PublicAuthView):
    """FR-004 step 1. Always 202 to avoid revealing which emails exist."""

    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "password_reset"

    @extend_schema(
        request=s.PasswordResetRequestSerializer, responses={202: OpenApiResponse(description="Accepted")}
    )
    def post(self, request):
        serializer = s.PasswordResetRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        passwords.request_password_reset(serializer.validated_data["email"], request=request)
        return Response(status=status.HTTP_202_ACCEPTED)


class PasswordResetConfirmView(PublicAuthView):
    """FR-004 step 2. Verifies the emailed one-time token, sets the password, revokes all sessions."""

    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "password_reset"

    @extend_schema(
        request=s.PasswordResetConfirmSerializer, responses={204: OpenApiResponse(description="Reset")}
    )
    def post(self, request):
        serializer = s.PasswordResetConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        d = serializer.validated_data
        passwords.confirm_password_reset(d["uid"], d["token"], d["new_password"], request=request)
        return Response(status=status.HTTP_204_NO_CONTENT)


class MeView(RetrieveUpdateAPIView):
    """FR-007: view own profile; PATCH only allowed fields (others → 400 protected_field)."""

    serializer_class = s.MeSerializer
    http_method_names = ["get", "patch", "head", "options"]

    def get_object(self):
        return User.objects.select_related("university", "library").get(pk=self.request.user.pk)


class AdminUserViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.CreateModelMixin,
    mixins.UpdateModelMixin,
    viewsets.GenericViewSet,
):
    """FR-001, FR-005, FR-006, FR-059. Accounts are deactivated, never deleted (keeps audit history)."""

    permission_classes = [IsAdmin]
    serializer_class = s.AdminUserSerializer
    filterset_fields = ["role", "is_active", "university", "library"]
    search_fields = ["email", "full_name", "student_number"]
    ordering_fields = ["date_joined", "full_name", "email", "last_login"]

    def get_queryset(self):
        return User.objects.select_related("university", "library").prefetch_related(
            Prefetch(
                "devices",
                queryset=StudentDevice.objects.filter(status=StudentDevice.Status.ACTIVE),
                to_attr="active_devices",
            )
        )

    def perform_create(self, serializer):
        data = dict(serializer.validated_data)
        password = data.pop("password")
        serializer.instance = admin_services.admin_create_user(
            data=data, password=password, admin=self.request.user, request=self.request
        )

    def perform_update(self, serializer):
        serializer.instance = admin_services.admin_update_user(
            serializer.instance, dict(serializer.validated_data), self.request.user, request=self.request
        )

    def _reload(self, user):
        return Response(self.get_serializer(self.get_queryset().get(pk=user.pk)).data)

    @extend_schema(request=None, responses=s.AdminUserSerializer)
    @action(detail=True, methods=["post"])
    def activate(self, request, pk=None):
        return self._reload(
            admin_services.admin_set_active(self.get_object(), True, request.user, request=request)
        )

    @extend_schema(request=None, responses=s.AdminUserSerializer)
    @action(detail=True, methods=["post"])
    def deactivate(self, request, pk=None):
        return self._reload(
            admin_services.admin_set_active(self.get_object(), False, request.user, request=request)
        )

    @extend_schema(
        request=s.AdminSetPasswordSerializer, responses={204: OpenApiResponse(description="Password set")}
    )
    @action(detail=True, methods=["post"], url_path="set-password")
    def set_password(self, request, pk=None):
        serializer = s.AdminSetPasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        admin_services.admin_set_password(
            self.get_object(),
            serializer.validated_data["password"],
            request.user,
            must_change=serializer.validated_data["must_change_password"],
            request=request,
        )
        return Response(status=status.HTTP_204_NO_CONTENT)

    @extend_schema(
        request=None, responses=inline_serializer("RevokedSessions", {"revoked": serializers.IntegerField()})
    )
    @action(detail=True, methods=["post"], url_path="revoke-sessions")
    def revoke_sessions(self, request, pk=None):
        return Response(
            {
                "revoked": admin_services.admin_revoke_sessions(
                    self.get_object(), request.user, request=request
                )
            }
        )

    @extend_schema(request=None, responses={204: OpenApiResponse(description="Device unbound")})
    @action(detail=True, methods=["post"], url_path="reset-device")
    def reset_device(self, request, pk=None):
        user = self.get_object()
        if not user.is_student:
            raise ApiError(_("Only student accounts are bound to devices."), code="not_a_student")
        device_services.reset_student_device(user, request.user, request=request)
        return Response(status=status.HTTP_204_NO_CONTENT)

    @extend_schema(responses=s.AdminDeviceSerializer(many=True))
    @action(detail=True, methods=["get"])
    def devices(self, request, pk=None):
        """Device history of a student (FR-015)."""
        return Response(s.AdminDeviceSerializer(self.get_object().devices.all(), many=True).data)
