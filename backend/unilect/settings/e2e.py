"""Server for the mobile app's live API tests (``flutter test test/live``). Development only.

Same as ``dev`` but with throttling relaxed, because the suite signs in far more often than a
person would. Rate limiting itself is covered by the backend's own tests. Point it at its own
database (``DATABASE_URL``) and load ``manage.py seed_demo`` first.
"""

from .base import REST_FRAMEWORK
from .dev import *  # noqa: F403

REST_FRAMEWORK = {
    **REST_FRAMEWORK,
    "DEFAULT_THROTTLE_RATES": dict.fromkeys(REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"], "10000/min"),
}
