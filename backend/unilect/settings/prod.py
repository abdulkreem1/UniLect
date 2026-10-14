"""Production settings. Every value that matters is required from the environment."""

from .base import *  # noqa: F403
from .base import REST_FRAMEWORK, SPECTACULAR_SETTINGS, env

DEBUG = False
ALLOWED_HOSTS = env.list("ALLOWED_HOSTS")  # required

SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = env.bool("SECURE_SSL_REDIRECT", default=True)
SECURE_HSTS_SECONDS = env.int("SECURE_HSTS_SECONDS", default=60 * 60 * 24 * 365)
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = env.bool("SECURE_HSTS_PRELOAD", default=False)
if not SECURE_HSTS_PRELOAD:
    # Preload-list submission is hard to undo; it is an explicit operator decision (README).
    SILENCED_SYSTEM_CHECKS = ["security.W021"]
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_REFERRER_POLICY = "same-origin"
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SESSION_COOKIE_HTTPONLY = True
X_FRAME_OPTIONS = "DENY"

# Number of trusted reverse proxies in front of Django (nginx = 1). Used for client IPs in
# throttling and audit logs; nginx must OVERWRITE X-Forwarded-For (see deploy/nginx.conf).
REST_FRAMEWORK = {**REST_FRAMEWORK, "NUM_PROXIES": env.int("NUM_PROXIES", default=1)}

# API docs are only reachable by administrators in production.
SPECTACULAR_SETTINGS = {
    **SPECTACULAR_SETTINGS,
    "SERVE_PERMISSIONS": ["apps.accounts.permissions.IsAdmin"],
}

# Set LOG_FORMAT=json in the production environment for structured logs.
