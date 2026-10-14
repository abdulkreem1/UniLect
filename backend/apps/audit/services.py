"""Audit recording. Metadata is scrubbed so secrets never reach the database (FR-080)."""

from __future__ import annotations

import ipaddress
import logging
from typing import Any

from django.conf import settings
from django.db import models

from apps.core.logging import request_id_var

from .models import AuditLog

logger = logging.getLogger(__name__)

SENSITIVE_KEY_FRAGMENTS = (
    "password",
    "token",
    "secret",
    "authorization",
    "installation_id",  # the device secret (device record UUIDs are not sensitive)
    "api_key",
    "otp",
    "cookie",
)
REDACTED = "[REDACTED]"
Category = AuditLog.Category


def scrub(value: Any) -> Any:
    """Recursively replace values whose key looks sensitive."""
    if isinstance(value, dict):
        return {
            k: (REDACTED if any(f in str(k).lower() for f in SENSITIVE_KEY_FRAGMENTS) else scrub(v))
            for k, v in value.items()
        }
    if isinstance(value, (list, tuple)):
        return [scrub(v) for v in value]
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    return str(value)


def client_ip(request) -> str | None:
    """Client address, honouring X-Forwarded-For only for the configured number of trusted proxies.

    Mirrors DRF's throttling identity (``NUM_PROXIES``) so audit logs and rate limits agree,
    and a client cannot spoof its address when no proxy is configured.
    """
    if request is None:
        return None
    candidate = request.META.get("REMOTE_ADDR", "")
    num_proxies = settings.REST_FRAMEWORK.get("NUM_PROXIES")
    forwarded = request.META.get("HTTP_X_FORWARDED_FOR", "")
    if num_proxies and forwarded:
        addresses = [a.strip() for a in forwarded.split(",") if a.strip()]
        if addresses:
            candidate = addresses[-min(num_proxies, len(addresses))]
    try:
        return str(ipaddress.ip_address(candidate))
    except ValueError:
        return None


def record(
    *,
    action: str,
    category: str,
    actor=None,
    target: models.Model | None = None,
    metadata: dict | None = None,
    request=None,
) -> AuditLog:
    actor = actor if (actor is not None and getattr(actor, "is_authenticated", False)) else None
    return AuditLog.objects.create(
        actor=actor,
        actor_repr=(actor.email if actor else ""),
        category=category,
        action=action,
        target_type=(target._meta.label_lower if target is not None else ""),
        target_id=(str(target.pk) if target is not None else ""),
        target_repr=(str(target)[:255] if target is not None else ""),
        metadata=scrub(metadata or {}),
        ip_address=client_ip(request),
        request_id=request_id_var.get() if request_id_var.get() != "-" else "",
    )
