"""Language detection — free, by Unicode block (design §5.3).

Sinhala occupies U+0D80–U+0DFF. If any Sinhala codepoint appears we treat the
question as Sinhala; otherwise English. No LLM call on the critical path.
"""
from __future__ import annotations

import re

# Sinhala block U+0D80–U+0DFF, built from codepoints so the source stays ASCII.
_SINHALA = re.compile("[%c-%c]" % (0x0D80, 0x0DFF))


def is_sinhala(text: str) -> bool:
    return bool(_SINHALA.search(text))


def detect_lang(text: str) -> str:
    """Return the contract's two-letter code: "si" or "en"."""
    return "si" if is_sinhala(text) else "en"
