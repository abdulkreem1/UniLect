"""Settings for the automated test suite (isolated from any production service)."""

import tempfile
from pathlib import Path

from .base import *  # noqa: F403
from .base import REST_FRAMEWORK, STORAGES

DEBUG = False
ALLOWED_HOSTS = ["testserver", "localhost"]
PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]  # speed only
EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
CACHES = {"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache"}}
LANGUAGE_CODE = "en"

PRIVATE_MEDIA_ROOT = Path(tempfile.mkdtemp(prefix="unilect-test-media-"))
STORAGES = {
    **STORAGES,
    "private": {
        "BACKEND": "django.core.files.storage.FileSystemStorage",
        "OPTIONS": {"location": str(PRIVATE_MEDIA_ROOT), "base_url": None},
    },
}
PRIVATE_MEDIA_ACCEL_PREFIX = ""

# Throttling is exercised explicitly in dedicated tests.
REST_FRAMEWORK = {
    **REST_FRAMEWORK,
    "DEFAULT_THROTTLE_RATES": dict.fromkeys(REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"], "10000/min"),
}
