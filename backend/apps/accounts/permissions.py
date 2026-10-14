"""Role-based permission classes (FR-006, FR-077).

These are coarse, role-level gates. Object-level access is enforced by always
resolving objects through scoped querysets (selectors), so an out-of-scope id
results in 404 rather than leaking existence.
"""

from rest_framework.permissions import BasePermission

from .models import Role


def _authenticated(request) -> bool:
    return bool(request.user and request.user.is_authenticated)


class IsAdmin(BasePermission):
    def has_permission(self, request, view) -> bool:
        return _authenticated(request) and request.user.role == Role.ADMIN


class IsStudent(BasePermission):
    def has_permission(self, request, view) -> bool:
        return _authenticated(request) and request.user.role == Role.STUDENT


class IsActiveLibrary(BasePermission):
    """Library staff whose library is itself active."""

    def has_permission(self, request, view) -> bool:
        user = request.user
        return (
            _authenticated(request)
            and user.role == Role.LIBRARY
            and user.library_id is not None
            and user.library.is_active
        )


class IsLibraryOrAdmin(BasePermission):
    def has_permission(self, request, view) -> bool:
        return IsAdmin().has_permission(request, view) or IsActiveLibrary().has_permission(request, view)
