"""Users, roles and server-side authentication sessions (FR-001..007, FR-014)."""

import uuid

from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.contrib.auth.models import PermissionsMixin
from django.db import models
from django.db.models import Q
from django.db.models.functions import Lower
from django.utils import timezone


class Role(models.TextChoices):
    STUDENT = "student", "Student"
    LIBRARY = "library", "Library"
    ADMIN = "admin", "Administrator"


class UserManager(BaseUserManager):
    use_in_migrations = True

    def _create_user(self, email: str, password: str | None, **extra):
        if not email:
            raise ValueError("Email is required")
        user = self.model(email=self.normalize_email(email).lower(), **extra)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, email: str, password: str | None = None, **extra):
        extra.setdefault("role", Role.STUDENT)
        return self._create_user(email, password, **extra)

    def create_superuser(self, email: str, password: str | None = None, **extra):
        extra.update(role=Role.ADMIN, is_staff=True, is_superuser=True)
        return self._create_user(email, password, **extra)

    def get_by_natural_key(self, username):
        return self.get(email__iexact=username)


class User(AbstractBaseUser, PermissionsMixin):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(max_length=254, unique=True)  # stored lower-cased; CI index below
    full_name = models.CharField(max_length=200)
    phone = models.CharField(max_length=30, blank=True)
    role = models.CharField(max_length=20, choices=Role.choices, db_index=True)

    # Students
    # NULL (not "") for non-students so the per-university unique constraint ignores them.
    student_number = models.CharField(max_length=50, null=True, blank=True)  # noqa: DJ001
    university = models.ForeignKey(
        "academics.University", on_delete=models.PROTECT, null=True, blank=True, related_name="students"
    )
    # Library staff
    library = models.ForeignKey(
        "libraries.Library", on_delete=models.PROTECT, null=True, blank=True, related_name="staff"
    )

    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False, help_text="Access to the internal Django admin site.")
    must_change_password = models.BooleanField(default=False)
    date_joined = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    objects = UserManager()

    USERNAME_FIELD = "email"
    EMAIL_FIELD = "email"
    REQUIRED_FIELDS = ["full_name"]

    class Meta:
        ordering = ["-date_joined"]
        constraints = [
            models.UniqueConstraint(Lower("email"), name="uniq_user_email_ci"),
            models.UniqueConstraint(
                fields=["university", "student_number"],
                condition=Q(student_number__isnull=False),
                name="uniq_student_number_per_university",
            ),
            # Students must have a university and a student number.
            models.CheckConstraint(
                condition=~Q(role="student") | Q(university__isnull=False, student_number__isnull=False),
                name="student_requires_university_and_number",
            ),
            # Only students carry student data.
            models.CheckConstraint(
                condition=Q(role="student") | Q(student_number__isnull=True),
                name="student_number_only_for_students",
            ),
            # Library staff belong to exactly one library; nobody else does.
            models.CheckConstraint(
                condition=(Q(role="library") & Q(library__isnull=False))
                | (~Q(role="library") & Q(library__isnull=True)),
                name="library_iff_library_role",
            ),
        ]
        indexes = [models.Index(fields=["role", "is_active"])]

    def __str__(self) -> str:
        return self.email

    @property
    def is_student(self) -> bool:
        return self.role == Role.STUDENT

    @property
    def is_admin(self) -> bool:
        return self.role == Role.ADMIN

    @property
    def is_library(self) -> bool:
        return self.role == Role.LIBRARY


class AuthSession(models.Model):
    """One login. Every issued JWT carries this id (``sid``) and is only valid while it is active.

    Revoking the session immediately invalidates both access and refresh tokens (FR-003, FR-005, FR-014).
    """

    class RevokeReason(models.TextChoices):
        LOGOUT = "logout", "Logout"
        PASSWORD_CHANGED = "password_changed", "Password changed"
        ACCOUNT_DISABLED = "account_disabled", "Account disabled"
        DEVICE_CHANGED = "device_changed", "Device changed"
        ADMIN = "admin", "Revoked by administrator"
        TOKEN_REUSE = "token_reuse", "Refresh token reuse detected"
        ROLE_CHANGED = "role_changed", "Role changed"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="auth_sessions")
    device = models.ForeignKey(
        "devices.StudentDevice", on_delete=models.SET_NULL, null=True, blank=True, related_name="sessions"
    )
    refresh_jti = models.CharField(max_length=64)
    created_at = models.DateTimeField(auto_now_add=True)
    last_used_at = models.DateTimeField(default=timezone.now)
    expires_at = models.DateTimeField()
    revoked_at = models.DateTimeField(null=True, blank=True)
    revoke_reason = models.CharField(max_length=32, choices=RevokeReason.choices, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=255, blank=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [models.Index(fields=["user", "revoked_at"])]

    def __str__(self) -> str:
        return f"session {self.pk} of {self.user_id}"

    @property
    def is_active(self) -> bool:
        return self.revoked_at is None and self.expires_at > timezone.now()
