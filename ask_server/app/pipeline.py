"""The live /ask pipeline (design §6 + reference implementation §9).

    detect → rewrite/translate → generate (file_search tool) → citations

The google-genai SDK is imported lazily inside `_client()`, so stub mode runs with
only fastapi+uvicorn installed. Shapes here follow the design doc's reference code;
confirm SDK specifics (model names, `grounding_metadata` fields, metadata-filter
syntax) at build time — design Appendix A.

Scope kept to the prototype (design §13, build-order item 2): single-shot
generation, empty history. The "intelligent" retrieval-breadth / fan-out work
(design §5.9b) is left as a clearly marked seam — see `_search_queries`.
"""
from __future__ import annotations

from functools import lru_cache

from .config import Settings
from .contracts import AskRequest, AskResponse, Citation, HistoryTurn
from .lang import is_sinhala
from .refs import REF_IN_PROSE, known_uid, ref_from_uid, uid_from_ref

# Locked Sinhala renderings fed into the system prompt (design §5.3). Extend as
# the glossary is finalised (design §14, open decision).
GLOSSARY = "saṁsāra→සංසාරය; transmigration→සංසරණය; charnel ground→සොහොන් බිම"

SYSTEM = (
    "Answer questions about the Pali Canon using ONLY the retrieved passages.\n"
    "Cite the text by standard reference (e.g. SN 15.3) for every claim.\n"
    "If the passages don't contain the answer, say so. Never invent a reference.\n"
    "If coverage may be partial, say so. For disputed meanings, present the range "
    "of readings rather than a verdict.\n"
    "Answer in {lang}.{glossary_hint}"
)


@lru_cache(maxsize=1)
def _client():
    # Imported here (not at module load) so stub mode needs no google-genai.
    from google import genai  # type: ignore

    return genai.Client()  # reads GEMINI_API_KEY from the environment


def _system_instruction(is_si: bool) -> str:
    return SYSTEM.format(
        lang="Sinhala" if is_si else "English",
        glossary_hint=(
            f"\nPrefer these Sinhala renderings: {GLOSSARY}" if is_si else ""
        ),
    )


def _rewrite(
    cfg: Settings, question: str, history: list[HistoryTurn], to_english: bool
) -> str:
    """Contextualise (+ translate if Sinhala) into a standalone English query.

    English with no history passes straight through (design §5.3) — no call, no
    cost. The prototype sends empty history, so this only fires for Sinhala.
    """
    if not to_english and not history:
        return question

    lines = [
        "Rewrite the user's latest question as a single standalone English "
        "search query for a Pali Canon corpus. Resolve pronouns and references "
        "using the conversation. Output ONLY the query, nothing else.",
        "",
    ]
    if history:
        lines.append("Conversation:")
        lines.extend(f"{turn.role}: {turn.content}" for turn in history)
        lines.append("")
    lines.append(f"Latest question: {question}")

    resp = _client().models.generate_content(
        model=cfg.rewrite_model, contents="\n".join(lines)
    )
    return (getattr(resp, "text", None) or question).strip()


def _search_queries(search_q: str) -> list[str]:
    """Where retrieval-breadth / fan-out would live (design §5.9b).

    Prototype: a single query. To widen thematic coverage later, classify the
    question type and decompose into sub-queries here, then union the chunks in
    `_generate`. Returning a list keeps that change local to this function.
    """
    return [search_q]


def _generate(cfg: Settings, search_q: str, is_si: bool, basket: str | None):
    file_search: dict = {"file_search_store_names": [cfg.store]}
    if basket:
        # Hard metadata scope when the user names a basket (design §5.9c).
        # Filter syntax varies by SDK version — confirm at build time (Appendix A).
        file_search["metadata_filter"] = f'basket="{basket}"'

    return _client().models.generate_content(
        model=cfg.model,
        contents=search_q,
        config={
            "system_instruction": _system_instruction(is_si),
            "tools": [{"file_search": file_search}],
        },
    )


def _deeplink_for(uid: str) -> str | None:
    # Seam for resolver plan Part D. Null in v1 — the app does not render links
    # yet, and the SuttaCentral→BJT resolver that fills this lands later.
    return None


def _to_citations(answer_text: str, resp) -> list[Citation]:
    """Synthesise citations from grounding_metadata + linkify refs in prose."""
    cites: dict[str, Citation] = {}

    # 1) Passages actually used to ground the answer (grounding_metadata).
    candidates = getattr(resp, "candidates", None) or []
    gm = getattr(candidates[0], "grounding_metadata", None) if candidates else None
    for chunk in getattr(gm, "grounding_chunks", None) or []:
        rc = getattr(chunk, "retrieved_context", None)
        uid = getattr(rc, "title", None) if rc else None
        if not uid:
            continue
        cites[uid] = Citation(
            uid=uid,
            ref=ref_from_uid(uid),
            snippet=getattr(rc, "text", None),
            deeplink=_deeplink_for(uid),
        )

    # 2) Refs named verbatim in the prose — resolve, drop the unknown (§11.9).
    for match in REF_IN_PROSE.finditer(answer_text):
        uid = uid_from_ref(match.group())
        if uid and known_uid(uid) and uid not in cites:
            cites[uid] = Citation(
                uid=uid,
                ref=match.group(),
                deeplink=_deeplink_for(uid),
            )

    return list(cites.values())


def answer(cfg: Settings, req: AskRequest) -> AskResponse:
    """Run the full pipeline for one question. Raises on SDK/config errors."""
    if not cfg.store:
        raise RuntimeError(
            "ASK_STORE is not set — run the ingest job and set the store name "
            "(or use ASK_STUB=1 for canned answers)."
        )

    is_si = is_sinhala(req.question)
    search_q = _rewrite(cfg, req.question, req.history, to_english=is_si)
    basket = req.filters.basket if req.filters else None

    # Prototype: single query. _search_queries is the fan-out seam (§5.9b).
    resp = _generate(cfg, _search_queries(search_q)[0], is_si, basket)

    text = getattr(resp, "text", "") or ""
    return AskResponse(
        answer=text,
        lang="si" if is_si else "en",
        citations=_to_citations(text, resp),
    )
