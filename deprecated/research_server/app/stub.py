"""Canned answer for stub mode — the keyless local bridge.

Lets the Flutter app point `researchBaseUrlProvider` at a really-running HTTP service
(proving the §7 round-trip end to end) before any Gemini key or File Search store
exists. The reply echoes the received question and is written in the DETECTED
language, so Sinhala detection + Unicode round-tripping are visible over the wire
— even though no real translation/answering happens until live mode (design §5.4).
"""
from __future__ import annotations

from .contracts import ResearchResponse, Citation
from .lang import detect_lang

# Canned reply text per detected language. The real "answer in the same language"
# behaviour is live-mode; here we just mirror the language so the round-trip is
# visibly language-aware (this is what makes a Sinhala question look different).
#
# Each reply carries two inline `[[cite:uid]]` markers so the app's answer
# renderer + peek sheet are fully exercisable with no Gemini key. Deliberately
# one RESOLVABLE uid (`sn15.3`, in the SN-15 seed concordance → shows the Sinhala
# block + "Open in reader") and one UNRESOLVED (`mn10`, outside the seed → shows
# the snippet-only "not linked yet" path).
_REPLY = {
    "en": (
        "[stub] research_server received your question:\n\n"
        "  “{q}”\n\n"
        "The canon addresses this in the Anamatagga Saṁyutta[[cite:sn15.3]] and "
        "in the discourse on mindfulness meditation[[cite:mn10]]. This is a canned "
        "reply — no Gemini call yet (detected language: English). "
        "Set RESEARCH_STUB=0 with GEMINI_API_KEY + RESEARCH_STORE for real answers."
    ),
    "si": (
        "[stub] ඔබගේ ප්‍රශ්නය research_server වෙත ලැබුණා:\n\n"
        "  “{q}”\n\n"
        "මෙය අනමතග්ග සංයුත්තයේ[[cite:sn15.3]] සහ සතිපට්ඨාන සූත්‍රයේ[[cite:mn10]] "
        "සඳහන් වේ. මෙය පූර්ව-සැකසූ පිළිතුරකි — තවම Gemini ඇමතුමක් නැත (හඳුනාගත් භාෂාව: "
        "සිංහල). සැබෑ පිළිතුරු සඳහා RESEARCH_STUB=0, GEMINI_API_KEY සහ RESEARCH_STORE සකසන්න."
    ),
}


def canned_answer(question: str) -> ResearchResponse:
    lang = detect_lang(question)
    return ResearchResponse(
        answer=_REPLY[lang].format(q=question),
        lang=lang,
        # Snippets stay English on purpose: even a Sinhala answer cites the
        # English source span (design §5.5). The `**…**` marks the matched terms,
        # rendered bold in the peek — same as live make_snippet output.
        citations=[
            Citation(
                uid="sn15.3",
                ref="SN 15.3",
                title="Tears",
                snippet=(
                    "The stream of **tears** you have shed… is more than the water "
                    "in the four **oceans**."
                ),
            ),
            Citation(
                uid="mn10",
                ref="MN 10",
                title="Satipaṭṭhāna",
                snippet="The four kinds of **mindfulness** meditation.",
            ),
        ],
    )
