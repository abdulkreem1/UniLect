"""Arabic-aware text normalisation for search (FR-031).

The same rules exist in two forms that MUST stay equivalent:
- ``normalize`` (Python) builds stored search documents and normalises user queries;
- ``normalized_sql`` (SQL) normalises columns on the fly for small catalog tables.

Rules: lower-case; unify alef forms (أ إ آ ٱ → ا), taa marbuta (ة → ه), alef maqsura (ى → ي),
hamza carriers (ؤ → و, ئ → ي); drop diacritics (tashkeel, superscript alef) and tatweel;
Arabic-Indic and Persian digits → ASCII digits; collapse whitespace.
"""

import re

from django.db.models import F, Func, Value
from django.db.models.functions import Lower

_CHAR_MAP_FROM = "أإآٱةىؤئ٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹"
_CHAR_MAP_TO = "ااااهيوي01234567890123456789"
_STRIP_CLASS = "[ً-ٰٟـ]"  # tashkeel, superscript alef, tatweel

# أ→ا إ→ا آ→ا ٱ→ا ة→ه ى→ي ؤ→و ئ→ي, then two digit sets → 0-9 (pairs are positional)
assert len(_CHAR_MAP_FROM) == len(_CHAR_MAP_TO)
_TRANSLATION = str.maketrans(_CHAR_MAP_FROM, _CHAR_MAP_TO)
_STRIP_RE = re.compile(_STRIP_CLASS)
_SPACE_RE = re.compile(r"\s+")


def normalize(text: str | None) -> str:
    if not text:
        return ""
    text = _STRIP_RE.sub("", text.lower()).translate(_TRANSLATION)
    return _SPACE_RE.sub(" ", text).strip()


def search_terms(query: str | None, max_terms: int = 8) -> list[str]:
    """Normalised, de-duplicated terms of a user query (bounded to keep queries cheap)."""
    seen: list[str] = []
    for term in normalize(query).split(" "):
        if term and term not in seen:
            seen.append(term)
    return seen[:max_terms]


class _Translate(Func):
    function = "TRANSLATE"


class _RegexpReplace(Func):
    function = "REGEXP_REPLACE"


def normalized_sql(field: str):
    """SQL expression equivalent to ``normalize`` (except whitespace collapsing) for ``field``."""
    stripped = _RegexpReplace(Lower(F(field)), Value(_STRIP_CLASS), Value(""), Value("g"))
    return _Translate(stripped, Value(_CHAR_MAP_FROM), Value(_CHAR_MAP_TO))
