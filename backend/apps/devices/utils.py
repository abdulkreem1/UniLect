import hashlib
import hmac
import re

from django.conf import settings

INSTALLATION_ID_RE = re.compile(r"^[A-Za-z0-9_\-]{16,128}$")


def hash_installation_id(installation_id: str) -> str:
    """Keyed hash so a database leak does not reveal usable device identifiers."""
    return hmac.new(
        settings.DEVICE_ID_HASH_KEY.encode(), installation_id.encode(), hashlib.sha256
    ).hexdigest()


def device_hash_from_request(request) -> str | None:
    """Hash of the ``X-Device-ID`` header, or None if missing/malformed."""
    raw = request.META.get(settings.DEVICE_ID_HEADER, "")
    if not raw or not INSTALLATION_ID_RE.match(raw):
        return None
    return hash_installation_id(raw)
