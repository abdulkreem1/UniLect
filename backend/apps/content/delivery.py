"""Protected file delivery (FR-051..057, FR-076).

Files are only ever served through an authorised API call. There is no public or permanent URL:
- development: streamed by Django from private storage;
- production behind nginx: Django authorises, then hands the transfer to an ``internal`` nginx
  location via ``X-Accel-Redirect`` (efficient, supports range requests for large PDFs).
"""

import hashlib
import hmac
import logging

from django.conf import settings
from django.http import FileResponse, HttpResponse

from .models import ContentFile

logger = logging.getLogger("unilect.security")


def watermark_text(user) -> str:
    """Stable, non-reversible viewer code for on-screen watermarking (FR-057).

    Contains no name, email or student number.
    """
    digest = hmac.new(settings.SECRET_KEY.encode(), f"wm:{user.pk}".encode(), hashlib.sha256).hexdigest()
    return f"UL-{digest[:10].upper()}"


def file_response(content_file: ContentFile, user) -> HttpResponse:
    name = content_file.file.name
    if settings.PRIVATE_MEDIA_ACCEL_PREFIX:
        response = HttpResponse(content_type=content_file.mime_type)
        response["X-Accel-Redirect"] = f"{settings.PRIVATE_MEDIA_ACCEL_PREFIX.rstrip('/')}/{name}"
    else:
        response = FileResponse(
            content_file.file.storage.open(name, "rb"), content_type=content_file.mime_type
        )
        response["Content-Length"] = str(content_file.size_bytes)
    # inline + neutral filename: viewing, not downloading; no original name/path leaked.
    response["Content-Disposition"] = f'inline; filename="{content_file.content_id}.{content_file.extension}"'
    response["Cache-Control"] = "private, no-store, max-age=0"
    response["Pragma"] = "no-cache"
    response["X-Content-Type-Options"] = "nosniff"
    response["X-Robots-Tag"] = "noindex, nofollow"
    response["X-Watermark-Text"] = watermark_text(user)
    logger.info(
        "content file served",
        extra={"event": "content_view", "content_id": str(content_file.content_id), "user_id": str(user.pk)},
    )
    return response
