"""Failed-login limiter (brute-force protection on top of per-IP request throttling).

Two tiers, counting only *failed* attempts so normal use never locks anyone out:

- per (identifier, client IP): ``MAX_FAILURES_PER_SOURCE`` in the window — stops a single attacker quickly
  and, crucially, does NOT lock the real user out when they sign in from another network;
- per identifier, any IP: ``MAX_FAILURES_PER_ACCOUNT`` — a much higher ceiling that still stops
  distributed guessing against one account.

A successful sign-in clears both counters for that identifier/source.
"""

import hashlib

from django.core.cache import cache

MAX_FAILURES_PER_SOURCE = 10
MAX_FAILURES_PER_ACCOUNT = 100
WINDOW_SECONDS = 15 * 60


def _digest(identifier: str) -> str:
    return hashlib.sha256(identifier.strip().lower().encode()).hexdigest()


def _keys(identifier: str, ip: str | None) -> tuple[str, str]:
    digest = _digest(identifier)
    return f"login-failures:{digest}:{ip or '-'}", f"login-failures:{digest}:*"


def is_locked(identifier: str, ip: str | None) -> bool:
    source_key, account_key = _keys(identifier, ip)
    counts = cache.get_many([source_key, account_key])
    return (
        counts.get(source_key, 0) >= MAX_FAILURES_PER_SOURCE
        or counts.get(account_key, 0) >= MAX_FAILURES_PER_ACCOUNT
    )


def _incr(key: str) -> None:
    if cache.add(key, 1, WINDOW_SECONDS):
        return
    try:
        cache.incr(key)
    except ValueError:  # expired between add() and incr()
        cache.set(key, 1, WINDOW_SECONDS)


def register_failure(identifier: str, ip: str | None) -> None:
    for key in _keys(identifier, ip):
        _incr(key)


def reset(identifier: str, ip: str | None) -> None:
    cache.delete_many(list(_keys(identifier, ip)))
