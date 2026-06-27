"""Canned answer for stub mode — the keyless local bridge.

Lets the Flutter app point `askBaseUrlProvider` at a really-running HTTP service
(proving the §7 round-trip end to end) before any Gemini key or File Search store
exists. The reply echoes the received question and is written in the DETECTED
language, so Sinhala detection + Unicode round-tripping are visible over the wire
— even though no real translation/answering happens until live mode (design §5.4).
"""
from __future__ import annotations

from .contracts import AskResponse, Citation
from .lang import detect_lang

# Canned reply text per detected language. The real "answer in the same language"
# behaviour is live-mode; here we just mirror the language so the round-trip is
# visibly language-aware (this is what makes a Sinhala question look different).
_REPLY = {
    "en": (
        "[stub] ask_server received your question:\n\n"
        "  “{q}”\n\n"
        "This is a canned reply — no Gemini call yet (detected language: English). "
        "Set ASK_STUB=0 with GEMINI_API_KEY + ASK_STORE for real answers."
    ),
    "si": (
        "[stub] ඔබගේ ප්‍රශ්නය ask_server වෙත ලැබුණා:\n\n"
        "  “{q}”\n\n"
        "මෙය පූර්ව-සැකසූ පිළිතුරකි — තවම Gemini ඇමතුමක් නැත (හඳුනාගත් භාෂාව: සිංහල). "
        "සැබෑ පිළිතුරු සඳහා ASK_STUB=0, GEMINI_API_KEY සහ ASK_STORE සකසන්න."
    ),
}


def canned_answer(question: str) -> AskResponse:
    lang = detect_lang(question)
    return AskResponse(
        answer=_REPLY[lang].format(q=question),
        lang=lang,
        # Snippets stay English on purpose: even a Sinhala answer cites the
        # English source span (design §5.5) — this models that.
        citations=[
            Citation(
                uid="sn15.3",
                ref="SN 15.3",
                snippet=(
                    "The stream of tears you have shed… is more than the water "
                    "in the four oceans."
                ),
            ),
            Citation(
                uid="mn10",
                ref="MN 10",
                snippet="The four kinds of mindfulness meditation.",
            ),
        ],
    )
