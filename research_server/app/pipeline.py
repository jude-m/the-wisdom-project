"""The live /research pipeline (design §6 + reference implementation §9).

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

import logging
from functools import lru_cache

from .config import Settings
from .contracts import ResearchRequest, ResearchResponse, Citation, HistoryTurn
from .errors import CANNOT_ANSWER_MSG, SERVER_ERROR_MSG, ResearchError
from .lang import is_sinhala
from .refs import REF_IN_PROSE, known_uid, ref_from_uid, uid_from_ref
from .snippet import make_snippet, split_heading

# Locked Sinhala renderings fed into the system prompt (design §5.3). Extend as
# the glossary is finalised (design §14, open decision).
GLOSSARY = "saṁsāra→සංසාරය; transmigration→සංසරණය; charnel ground→සොහොන් බිම"

log = logging.getLogger("research.pipeline")

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
    prompt = "\n".join(lines)

    # Give the rewrite the same fallback ladder as generation (Finding #5): lead
    # with the (optionally cheaper) rewrite model, then fall through to the
    # generation rungs on a transient error. A throttled rewrite model must not
    # fail the whole Sinhala request while generation would have recovered — and
    # we never silently fall back to the raw Sinhala query (it retrieves poorly
    # against an English corpus). Both an exhausted ladder AND an empty rewrite
    # surface a clear error instead of degrading.
    rewrite_ladder = (cfg.rewrite_model,) + tuple(
        m for m in cfg.models if m != cfg.rewrite_model
    )
    resp = _call_with_ladder(
        rewrite_ladder,
        lambda model: _client().models.generate_content(model=model, contents=prompt),
        label="rewrite",
    )
    rewritten = (getattr(resp, "text", None) or "").strip()
    if not rewritten:
        # The model returned no query text (a blank completion or a safety block
        # on the rewrite prompt). Using the raw Sinhala query would retrieve
        # poorly, so surface a clear retriable error rather than degrade quietly.
        log.warning("research: rewrite produced empty text; not falling back to raw query")
        raise ResearchError(502, "server_error", SERVER_ERROR_MSG, retriable=True)
    return rewritten


def _search_queries(search_q: str) -> list[str]:
    """Where retrieval-breadth / fan-out would live (design §5.9b).

    Prototype: a single query. To widen thematic coverage later, classify the
    question type and decompose into sub-queries here, then union the chunks in
    `_generate`. Returning a list keeps that change local to this function.
    """
    return [search_q]


def _is_retryable(exc: Exception) -> bool:
    """True for transient server-side errors worth retrying on the NEXT model rung:
    429 RESOURCE_EXHAUSTED (rate limit / quota) and 503 UNAVAILABLE (the model is
    "experiencing high demand" — common on the popular free flash tiers). Any other
    error (400 / 404 / auth / malformed request) fails fast: a different model
    won't fare better.

    The google-genai SDK raises ClientError/ServerError(APIError) with
    `.code`/`.status`; we also string-match as a version-proof backstop."""
    if getattr(exc, "code", None) in (429, 503):
        return True
    if (getattr(exc, "status", "") or "").upper() in ("RESOURCE_EXHAUSTED", "UNAVAILABLE"):
        return True
    text = str(exc).upper()
    return any(s in text for s in ("RESOURCE_EXHAUSTED", "UNAVAILABLE", "429", "503"))


def _call_with_ladder(models, make_call, label: str):
    """Walk a model ladder, retrying the NEXT rung only on a transient error
    (429 rate limit / 503 high demand). Any other error fails fast — a malformed
    request won't fare better on a different model.

    Shared by BOTH `_generate` and `_rewrite` (Finding #5): before this, the
    rewrite call — which every Sinhala question hits first — had no fallback, so a
    throttled rewrite model failed the whole request while generation would have
    happily fallen back. Extracting the loop makes robustness symmetric; when all
    rungs are exhausted it raises the last exception (classified upstream into a
    rateLimited / serviceBusy envelope) rather than silently degrading.
    """
    last_exc: Exception | None = None
    for i, model in enumerate(models):
        try:
            return make_call(model)
        except Exception as exc:  # noqa: BLE001 — re-raised unless it's transient
            is_last = i == len(models) - 1
            if not _is_retryable(exc) or is_last:
                raise
            log.warning(
                "research: %s model %s unavailable (%s); falling back to %s",
                label, model, getattr(exc, "code", "?"), models[i + 1],
            )
            last_exc = exc
    raise last_exc  # pragma: no cover — the last rung always raises above


def _generate(cfg: Settings, search_q: str, is_si: bool, basket: str | None):
    file_search: dict = {"file_search_store_names": [cfg.store]}
    if basket:
        # Hard metadata scope when the user names a basket (design §5.9c).
        # Filter syntax varies by SDK version — confirm at build time (Appendix A).
        file_search["metadata_filter"] = f'basket="{basket}"'

    config = {
        "system_instruction": _system_instruction(is_si),
        "tools": [{"file_search": file_search}],
    }

    # Walk the generation ladder (cfg.models / config.DEFAULT_MODELS), falling
    # through on transient errors only — see `_call_with_ladder`.
    return _call_with_ladder(
        cfg.models,
        lambda model: _client().models.generate_content(
            model=model, contents=search_q, config=config
        ),
        label="generate",
    )


def _deeplink_for(uid: str) -> str | None:
    # Seam for resolver plan Part D. Null in v1 — the app does not render links
    # yet, and the SuttaCentral→BJT resolver that fills this lands later.
    return None


def _to_citations(answer_text: str, resp, search_q: str, snippet_chars: int) -> list[Citation]:
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
        # The chunk text is "<heading>\n<whole sutta>". Split off the heading as
        # a consistent bold `title` (shown on its own line), then window only the
        # body around the query for the snippet — the deep link opens the full
        # text. Passing ref drops the heading's spelled-out reference so it isn't
        # duplicated next to the citation's own ref.
        ref = ref_from_uid(uid)
        title, body = split_heading(getattr(rc, "text", "") or "", ref)
        snippet = make_snippet(body, search_q, snippet_chars)
        cites[uid] = Citation(
            uid=uid,
            ref=ref,
            title=title,
            kind="canon",
            snippet=snippet or None,
            deeplink=_deeplink_for(uid),
        )

    # 2) Refs named verbatim in the prose — resolve, drop the unknown (§11.9).
    for match in REF_IN_PROSE.finditer(answer_text):
        uid = uid_from_ref(match.group())
        if uid and known_uid(uid) and uid not in cites:
            cites[uid] = Citation(
                uid=uid,
                ref=match.group(),
                kind="canon",
                deeplink=_deeplink_for(uid),
            )

    return list(cites.values())


def answer(cfg: Settings, req: ResearchRequest) -> ResearchResponse:
    """Run the full pipeline for one question. Raises on SDK/config errors."""
    if not cfg.store:
        raise RuntimeError(
            "RESEARCH_STORE is not set — run the ingest job and set the store name "
            "(or use RESEARCH_STUB=1 for canned answers)."
        )

    is_si = is_sinhala(req.question)
    search_q = _rewrite(cfg, req.question, req.history, to_english=is_si)
    basket = req.filters.basket if req.filters else None

    # Prototype: single query. _search_queries is the fan-out seam (§5.9b).
    resp = _generate(cfg, _search_queries(search_q)[0], is_si, basket)

    text = getattr(resp, "text", "") or ""
    if not text.strip():
        # Blank generation or a safety block with no candidates — a 200 with an
        # empty answer would surface as an empty chat bubble. Treat it as a
        # non-200 "rephrase" error instead (plan §3.4: errors stay non-200).
        raise ResearchError(422, "cannot_answer", CANNOT_ANSWER_MSG, retriable=False)

    return ResearchResponse(
        answer=text,
        lang="si" if is_si else "en",
        citations=_to_citations(text, resp, search_q, cfg.snippet_chars),
    )
