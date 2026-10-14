"""Base settings shared by every environment.

All secrets and deployment-specific values come from the environment (or a local
``.env`` file that is never committed). See ``.env.example``.
"""

from datetime import timedelta
from pathlib import Path

import environ

BASE_DIR = Path(__file__).resolve().parent.parent.parent

env = environ.Env()
environ.Env.read_env(BASE_DIR / ".env", overwrite=False)

SECRET_KEY = env("SECRET_KEY")
DEBUG = env.bool("DEBUG", default=False)
ALLOWED_HOSTS = env.list("ALLOWED_HOSTS", default=[])

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.postgres",
    # third party
    "rest_framework",
    "django_filters",
    "drf_spectacular",
    "corsheaders",
    # local
    "apps.core",
    "apps.academics",
    "apps.libraries",
    "apps.accounts",
    "apps.devices",
    "apps.audit",
    "apps.config",
    "apps.notifications",
    "apps.content",
    "apps.reports",
    "apps.dashboard",
    "apps.maintenance",
]

MIDDLEWARE = [
    "apps.core.middleware.RequestIDMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.locale.LocaleMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "unilect.urls"
WSGI_APPLICATION = "unilect.wsgi.application"
ASGI_APPLICATION = "unilect.asgi.application"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

DATABASES = {"default": env.db("DATABASE_URL")}
DATABASES["default"]["ATOMIC_REQUESTS"] = False
DATABASES["default"]["CONN_MAX_AGE"] = env.int("DB_CONN_MAX_AGE", default=60)
DATABASES["default"]["CONN_HEALTH_CHECKS"] = True

CACHES = {"default": env.cache("CACHE_URL", default="locmemcache://")}

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
AUTH_USER_MODEL = "accounts.User"

PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.PBKDF2PasswordHasher",
    "django.contrib.auth.hashers.PBKDF2SHA1PasswordHasher",
    "django.contrib.auth.hashers.ScryptPasswordHasher",
]
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
        "OPTIONS": {"min_length": 10},
    },
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]
PASSWORD_RESET_TIMEOUT = 60 * 60  # 1 hour
PASSWORD_RESET_URL_TEMPLATE = env(
    "PASSWORD_RESET_URL_TEMPLATE",
    default="unilect://app/reset-password?uid={uid}&token={token}",
)

LANGUAGE_CODE = env("LANGUAGE_CODE", default="ar")
LANGUAGES = [("ar", "العربية"), ("en", "English")]
LOCALE_PATHS = [BASE_DIR / "locale"]
TIME_ZONE = env("TIME_ZONE", default="UTC")
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = Path(env("STATIC_ROOT", default=str(BASE_DIR / "staticfiles")))

# ---------------------------------------------------------------------------
# Storage. Uploaded content is NEVER stored under a public MEDIA_URL: the
# "private" storage has no base URL and files are only delivered through the
# authorised streaming endpoint (FR-055/056/076).
# ---------------------------------------------------------------------------
PRIVATE_MEDIA_ROOT = Path(env("PRIVATE_MEDIA_ROOT", default=str(BASE_DIR / "var" / "private_media")))
PRIVATE_MEDIA_ACCEL_PREFIX = env("PRIVATE_MEDIA_ACCEL_PREFIX", default="")
STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "private": {
        "BACKEND": "django.core.files.storage.FileSystemStorage",
        "OPTIONS": {"location": str(PRIVATE_MEDIA_ROOT), "base_url": None},
    },
    "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
}

# Hard, code-level upper bounds. Admin-editable SystemSettings may only narrow these.
CONTENT_SUPPORTED_EXTENSIONS = {
    "pdf": "application/pdf",
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "webp": "image/webp",
}
CONTENT_MAX_UPLOAD_MB_HARD_LIMIT = 200
CONTENT_BULK_UPLOAD_MAX_ITEMS = 20
FILE_UPLOAD_MAX_MEMORY_SIZE = 5 * 1024 * 1024
DATA_UPLOAD_MAX_MEMORY_SIZE = 5 * 1024 * 1024

EMAIL_CONFIG = env.email_url("EMAIL_URL", default="consolemail://")
vars().update(EMAIL_CONFIG)
DEFAULT_FROM_EMAIL = env("DEFAULT_FROM_EMAIL", default="UniLect <no-reply@example.com>")

# ---------------------------------------------------------------------------
# REST framework
# ---------------------------------------------------------------------------
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": ["apps.accounts.authentication.SessionJWTAuthentication"],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"],
    "DEFAULT_PARSER_CLASSES": [
        "rest_framework.parsers.JSONParser",
        "rest_framework.parsers.MultiPartParser",
        "rest_framework.parsers.FormParser",
    ],
    "DEFAULT_FILTER_BACKENDS": [
        "django_filters.rest_framework.DjangoFilterBackend",
        "apps.core.filters.ArabicSearchFilter",
        "apps.libraries.filters.LibraryScopeFilter",
        "rest_framework.filters.OrderingFilter",
    ],
    "DEFAULT_PAGINATION_CLASS": "apps.core.pagination.StandardPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "EXCEPTION_HANDLER": "apps.core.exceptions.api_exception_handler",
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {
        "anon": "120/min",
        "user": "600/min",
        "auth_login": "20/min",  # per IP
        "auth_login_identifier": "10/hour",  # per account identifier (brute force)
        "auth_refresh": "60/min",
        "password_reset": "5/hour",
        "device_change": "10/hour",
        "content_file": "300/hour",
    },
    "UNAUTHENTICATED_USER": "django.contrib.auth.models.AnonymousUser",
    "TEST_REQUEST_DEFAULT_FORMAT": "json",
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=env.int("JWT_ACCESS_MINUTES", default=10)),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=env.int("JWT_REFRESH_DAYS", default=30)),
    "ALGORITHM": "HS256",
    "SIGNING_KEY": env("JWT_SIGNING_KEY", default="") or SECRET_KEY,
    "AUTH_HEADER_TYPES": ("Bearer",),
    "USER_ID_FIELD": "id",
    "USER_ID_CLAIM": "user_id",
    "UPDATE_LAST_LOGIN": False,
}
# Hard cap on a session's total age regardless of refreshes; then the user must sign in again.
SESSION_ABSOLUTE_LIFETIME = timedelta(days=env.int("SESSION_MAX_DAYS", default=90))
DEVICE_CHANGE_TOKEN_LIFETIME = timedelta(minutes=15)

# Retention used by `manage.py purge_expired` (0 = keep forever).
RETENTION = {
    "ended_sessions_days": env.int("RETAIN_ENDED_SESSIONS_DAYS", default=30),
    "read_notifications_days": env.int("RETAIN_READ_NOTIFICATIONS_DAYS", default=180),
    "audit_logs_days": env.int("RETAIN_AUDIT_LOGS_DAYS", default=0),
    "old_file_versions": env.int("RETAIN_OLD_FILE_VERSIONS", default=5),
}
DEVICE_ID_HASH_KEY = env("DEVICE_ID_HASH_KEY", default="") or f"device-id:{SECRET_KEY}"
DEVICE_ID_HEADER = "HTTP_X_DEVICE_ID"

SPECTACULAR_SETTINGS = {
    "TITLE": "UniLect API",
    "DESCRIPTION": "Protected academic content platform (students, libraries, administrators).",
    "VERSION": "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,
    "SCHEMA_PATH_PREFIX": r"/api/v1",
    "COMPONENT_SPLIT_REQUEST": True,
    "SERVE_PERMISSIONS": ["rest_framework.permissions.AllowAny"],
    "ENUM_NAME_OVERRIDES": {
        "ContentStatusEnum": "apps.content.models.ContentItem.Status",
        "DeviceChangeRequestStatusEnum": "apps.devices.models.DeviceChangeRequest.Status",
        "ReportStatusEnum": "apps.reports.models.ContentReport.Status",
        "DeviceStatusEnum": "apps.devices.models.StudentDevice.Status",
        "PlatformEnum": "apps.devices.models.Platform",
    },
}

CORS_ALLOWED_ORIGINS = env.list("CORS_ALLOWED_ORIGINS", default=[])
CORS_ALLOW_HEADERS = (
    "accept",
    "authorization",
    "content-type",
    "accept-language",
    "x-device-id",
    "x-request-id",
)
CSRF_TRUSTED_ORIGINS = env.list("CSRF_TRUSTED_ORIGINS", default=[])

DJANGO_ADMIN_URL = env("DJANGO_ADMIN_URL", default="django-admin/")

LOG_LEVEL = env("LOG_LEVEL", default="INFO")
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "filters": {"request_id": {"()": "apps.core.logging.RequestIDFilter"}},
    "formatters": {
        "json": {"()": "apps.core.logging.JSONFormatter"},
        "plain": {"format": "%(asctime)s %(levelname)s [%(request_id)s] %(name)s: %(message)s"},
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": env("LOG_FORMAT", default="plain"),
            "filters": ["request_id"],
        },
    },
    "root": {"handlers": ["console"], "level": LOG_LEVEL},
    "loggers": {
        "django.request": {"level": "WARNING"},
        "unilect.security": {"level": "INFO"},
    },
}
