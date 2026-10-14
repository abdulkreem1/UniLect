"""Upload validation (FR-035, FR-043, FR-054, FR-069).

Checks, in order: extension allow-list (admin settings ∩ server whitelist), size, magic bytes
must match the extension, then a structural parse (PDF via pypdf, images via Pillow).
The client-supplied Content-Type is never trusted.
"""

from __future__ import annotations

import hashlib
import warnings
from dataclasses import dataclass
from pathlib import PurePath

import filetype
from django.conf import settings
from django.core.files.uploadedfile import UploadedFile
from django.utils.translation import gettext as _
from PIL import Image
from pypdf import PdfReader
from pypdf.errors import PdfReadError

from apps.config.models import SystemSettings
from apps.core.exceptions import ApiError

MAX_IMAGE_PIXELS = 60_000_000
MAX_PDF_PAGES = 3000  # bounds parsing work per upload; real course material is far below this
OFFICE_EXTENSIONS = {"doc", "docx", "ppt", "pptx", "xls", "xlsx", "odt", "rtf"}
SNIFF_BYTES = 8192


class FileRejected(ApiError):
    default_code = "file_rejected"

    def __init__(self, reason: str, message: str, **extra):
        super().__init__(message, code="file_rejected", details={"reason": reason, **extra})


@dataclass(frozen=True)
class ValidatedFile:
    original_name: str
    extension: str
    mime_type: str
    size_bytes: int
    sha256: str
    page_count: int | None


def allowed_extensions(cfg: SystemSettings) -> list[str]:
    return sorted(set(cfg.allowed_extensions) & set(settings.CONTENT_SUPPORTED_EXTENSIONS))


def validate_upload(upload: UploadedFile, cfg: SystemSettings) -> ValidatedFile:
    original_name = PurePath(upload.name or "").name[:255] or "upload"
    ext = PurePath(original_name).suffix.lower().lstrip(".")
    allowed = allowed_extensions(cfg)

    if ext in OFFICE_EXTENSIONS:
        raise FileRejected(
            "unsupported_format",
            _("Office documents are not supported yet. Please convert the file to PDF and upload it again."),
            allowed_extensions=allowed,
        )
    if ext not in allowed:
        raise FileRejected(
            "extension_not_allowed",
            _("File type '.%(ext)s' is not allowed. Allowed types: %(allowed)s.")
            % {"ext": ext or "?", "allowed": ", ".join(allowed)},
            allowed_extensions=allowed,
        )
    max_bytes = cfg.max_upload_size_mb * 1024 * 1024
    if upload.size == 0:
        raise FileRejected("empty_file", _("The file is empty."))
    if upload.size > max_bytes:
        raise FileRejected(
            "file_too_large",
            _("The file exceeds the maximum size of %(mb)s MB.") % {"mb": cfg.max_upload_size_mb},
            max_size_mb=cfg.max_upload_size_mb,
        )

    upload.seek(0)
    head = upload.read(SNIFF_BYTES)
    upload.seek(0)
    expected_mime = settings.CONTENT_SUPPORTED_EXTENSIONS[ext]
    detected = filetype.guess(head)
    if detected is None or detected.mime != expected_mime:
        raise FileRejected(
            "content_mismatch", _("The file content does not match its extension or the file is damaged.")
        )

    page_count = _inspect_pdf(upload) if expected_mime == "application/pdf" else _inspect_image(upload)

    digest = hashlib.sha256()
    upload.seek(0)
    for chunk in upload.chunks():
        digest.update(chunk)
    upload.seek(0)

    return ValidatedFile(
        original_name=original_name,
        extension=ext,
        mime_type=expected_mime,
        size_bytes=upload.size,
        sha256=digest.hexdigest(),
        page_count=page_count,
    )


def _inspect_pdf(upload: UploadedFile) -> int:
    upload.seek(0)
    try:
        reader = PdfReader(upload)
        if reader.is_encrypted:
            raise FileRejected("encrypted_pdf", _("Password-protected PDF files are not supported."))
        pages = len(reader.pages)
    except FileRejected:
        raise
    except (PdfReadError, ValueError, KeyError, TypeError, OSError) as exc:
        raise FileRejected("corrupt_file", _("The PDF file could not be read.")) from exc
    finally:
        upload.seek(0)
    if pages == 0:
        raise FileRejected("corrupt_file", _("The PDF file has no pages."))
    if pages > MAX_PDF_PAGES:
        raise FileRejected(
            "too_many_pages",
            _("The PDF has too many pages (maximum %(n)s).") % {"n": MAX_PDF_PAGES},
            max_pages=MAX_PDF_PAGES,
        )
    return pages


def _inspect_image(upload: UploadedFile) -> None:
    upload.seek(0)
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(upload) as image:
                width, height = image.size
                if width * height > MAX_IMAGE_PIXELS:
                    raise FileRejected("image_too_large", _("The image dimensions are too large."))
                image.verify()
    except FileRejected:
        raise
    except (Image.DecompressionBombError, Image.DecompressionBombWarning) as exc:
        raise FileRejected("image_too_large", _("The image dimensions are too large.")) from exc
    except Exception as exc:  # Pillow raises many exception types for corrupt input
        raise FileRejected("corrupt_file", _("The image file could not be read.")) from exc
    finally:
        upload.seek(0)
    return None
