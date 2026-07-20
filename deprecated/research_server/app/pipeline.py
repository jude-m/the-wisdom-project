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

import contextvars
import logging
import re
import time
import uuid
from functools import lru_cache

from .config import (
    RUNG_TIMEOUT_SECONDS,
    Settings,
    THINKING_BUDGET_TOKENS,
    THINKING_LEVEL,
)
from .contracts import ResearchRequest, ResearchResponse, Citation, HistoryTurn
from .errors import CANNOT_ANSWER_MSG, SERVER_ERROR_MSG, ResearchError
from .lang import is_sinhala
from .refs import REF_IN_PROSE, known_uid, ref_from_uid, uid_from_ref
from .snippet import make_snippet, split_heading

# Locked Sinhala renderings fed into the system prompt (design §5.3). Extend as
# the glossary is finalised (design §14, open decision).
GLOSSARY = "saṁsāra→සංසාරය; transmigration→සංසරණය; charnel ground→සොහොන් බිම"

log = logging.getLogger("research.pipeline")

# A short tag repeated on every line of one question, e.g. research[a1b2c3].
#
# uvicorn prints its access line ("POST /research ... 200 OK") only when a request
# FINISHES, so two questions in flight interleave: the slower one's lines appear
# UNDER the faster one's access line, and the request logged last may well be the
# one that started first. Without a tag the only way to attribute a line is the
# ephemeral port number, which is not something anyone should have to read. Set
# per request in `answer()`; a ContextVar because FastAPI gives each request its
# own context (and a copy to the threadpool it runs sync handlers in).
_req_id: contextvars.ContextVar[str] = contextvars.ContextVar(
    "research_req_id", default="-"
)

SYSTEM = (
    "Answer questions about the Pali Canon using ONLY the retrieved passages.\n"
    "Cite the text by standard reference (e.g. SN 15.3) for every claim.\n"
    "If the passages don't contain the answer, say so. Never invent a reference.\n"
    "If coverage may be partial, say so. For disputed meanings, present the range "
    "of readings rather than a verdict.\n"
    # Keep the markup within the small subset the app's answer renderer handles
    # (research_answer_view.dart): short paragraphs, **bold**, *italic*, '- '
    # bullets. Headings/tables/nested lists would render as raw text.
    "Format with simple Markdown only: short paragraphs, **bold**, *italic*, and "
    "'- ' bullets. Do not use headings, tables, or nested lists.\n"
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
    cost. Everything else pays for a rewrite: every Sinhala question, and every
    follow-up in either language now that the app sends prior turns as history.
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

    # Give the rewrite a fallback ladder (Finding #5): lead with the (optionally
    # cheaper) rewrite model, then fall through to the FAST-tier rungs on a
    # transient error. A throttled rewrite model must not fail the request while
    # it could have recovered — and we never silently fall back to the raw
    # Sinhala query (it retrieves poorly against an English corpus). Both an
    # exhausted ladder AND an empty rewrite surface a clear error rather than
    # degrading.
    #
    # Deliberate trade: the ladder is the FAST tier only, never the Thinking one,
    # even when the answer will run in Thinking mode. Rewriting is cheap and
    # mode-independent, so spending the scarce (throttled) Thinking quota on it
    # would starve the answer it precedes. The cost is a shorter ladder on a step
    # that — per the docstring — every follow-up pays for: if the whole flash-lite
    # family is throttled at once, the request fails where a cross-tier ladder
    # would have recovered. Revisit if flash-lite 429s show up in the logs.
    rewrite_ladder = (cfg.rewrite_model,) + tuple(
        m for m in cfg.fast_models if m != cfg.rewrite_model
    )
    resp = _call_with_ladder(
        rewrite_ladder,
        lambda model: _client().models.generate_content(
            model=model, contents=prompt, config={"http_options": _http_options()}
        ),
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


def _is_timeout(exc: Exception) -> bool:
    """True when a request ran out of time — including the per-rung ceiling we impose
    ourselves (config.RUNG_TIMEOUT_SECONDS).

    Kept separate because a timeout is invisible to every other check in
    `_is_retryable`: it carries no `.code` or `.status`, and httpx's timeouts often
    have an EMPTY message, so the string backstop can't see them either.

    httpx is imported lazily — it arrives with google-genai, and the module docstring
    promises stub mode needs neither.
    """
    if isinstance(exc, TimeoutError):
        return True
    try:
        import httpx  # type: ignore
    except ImportError:  # pragma: no cover — live mode always has it
        return False
    # Covers ReadTimeout / ConnectTimeout / WriteTimeout / PoolTimeout.
    return isinstance(exc, httpx.TimeoutException)


def _is_retryable(exc: Exception) -> bool:
    """True for transient server-side errors worth retrying on the NEXT model rung:
    429 RESOURCE_EXHAUSTED (rate limit / quota) and 503 UNAVAILABLE (the model is
    "experiencing high demand" — common on the popular free flash tiers). Any other
    error (400 / 404 / auth / malformed request) fails fast: a different model
    won't fare better.

    The google-genai SDK raises ClientError/ServerError(APIError) with
    `.code`/`.status`; we also string-match as a version-proof backstop."""
    # Our own per-rung ceiling. This MUST come first and MUST be retryable: the whole
    # point of timing a rung out is to reach the next one, and a rung that is merely
    # slow is exactly the case the ladder exists for. Treated as fail-fast (the
    # default for anything unrecognised), a timeout would stop the ladder dead on the
    # first slow rung — strictly worse than having no timeout at all.
    if _is_timeout(exc):
        return True
    if getattr(exc, "code", None) in (429, 503):
        return True
    if (getattr(exc, "status", "") or "").upper() in ("RESOURCE_EXHAUSTED", "UNAVAILABLE"):
        return True
    text = str(exc).upper()
    return any(s in text for s in ("RESOURCE_EXHAUSTED", "UNAVAILABLE", "429", "503"))


def _why(exc: Exception) -> str:
    """Short cause for the log. A timeout carries no `.code`, so it would otherwise
    print as a bare "?" and read like an unknown error — when in fact it is OUR
    ceiling firing. The distinction is the whole point of the per-rung timings: "the
    model refused after 370s" and "we cut it off at 210s" are different diagnoses.
    """
    if _is_timeout(exc):
        return f"our {RUNG_TIMEOUT_SECONDS}s ceiling"
    return str(getattr(exc, "code", "?"))


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
    total = len(models)
    for i, model in enumerate(models):
        rung = f"rung {i + 1}/{total}"
        # Logged BEFORE the call, not after: a rung that is slow (or hangs) is
        # otherwise indistinguishable from a request that never arrived, because
        # nothing reaches the console until the call returns.
        log.info("research[%s]: %s %s → %s", _req_id.get(), label, rung, model)
        started = time.monotonic()
        try:
            result = make_call(model)
        except Exception as exc:  # noqa: BLE001 — re-raised unless it's transient
            secs = time.monotonic() - started
            is_last = i == total - 1
            if not _is_retryable(exc) or is_last:
                # Name WHY we stopped — an exhausted ladder and a fail-fast error
                # look identical from the client's side (both just fail).
                log.warning(
                    "research[%s]: %s %s %s failed after %.1fs (%s) — %s",
                    _req_id.get(), label, rung, model, secs, _why(exc),
                    "ladder exhausted" if is_last else "not retriable, no fallback",
                )
                raise
            log.warning(
                "research[%s]: %s %s %s unavailable after %.1fs (%s); falling back to %s",
                _req_id.get(), label, rung, model, secs, _why(exc), models[i + 1],
            )
            last_exc = exc
        else:
            log.info(
                "research[%s]: %s %s %s OK in %.1fs",
                _req_id.get(), label, rung, model, time.monotonic() - started,
            )
            return result
    raise last_exc  # pragma: no cover — the last rung always raises above


def _http_options() -> dict:
    """The per-rung ceiling, in the SDK's milliseconds. Applied to EVERY model call
    (rewrite and generate alike) — without it the SDK sends `timeout=None` and httpx
    waits forever, so a wedged rung hangs the request rather than falling through."""
    return {"timeout": RUNG_TIMEOUT_SECONDS * 1000}


def _thinking_config(model: str) -> dict | None:
    """The reasoning cap for one THINKING-tier rung, or None to leave the model's
    own default alone (config.THINKING_LEVEL / THINKING_BUDGET_TOKENS).

    Keyed on model generation because the knob changed between them: Gemini 3.x
    takes `thinking_level`, Gemini 2.5 takes `thinking_budget` in tokens. The SDK
    validates BOTH shapes client-side whatever the model — it will happily accept
    them together — so it offers no protection against sending a combination the
    API rejects with a 400. And a 400 fails fast by design (`_is_retryable`:
    rightly, a malformed request won't fare better on the next rung), meaning a
    wrong knob here takes the whole tier down instead of degrading. Hence the
    explicit per-generation mapping, and None for anything unrecognised: a new
    model runs uncapped (slow, but working) rather than guessed-at and broken.
    """
    if model.startswith("gemini-3") and THINKING_LEVEL:
        return {"thinking_level": THINKING_LEVEL}
    if model.startswith("gemini-2.5") and THINKING_BUDGET_TOKENS is not None:
        return {"thinking_budget": THINKING_BUDGET_TOKENS}
    return None


def _generate(cfg: Settings, search_q: str, is_si: bool, basket: str | None, mode: str):
    file_search: dict = {"file_search_store_names": [cfg.store]}
    if basket:
        # Hard metadata scope when the user names a basket (design §5.9c).
        # Filter syntax varies by SDK version — confirm at build time (Appendix A).
        file_search["metadata_filter"] = f'basket="{basket}"'

    def _config_for(model: str) -> dict:
        # Built per rung rather than once: the reasoning cap depends on which model
        # the ladder has actually fallen to, and the tier spans two generations.
        config: dict = {
            "system_instruction": _system_instruction(is_si),
            "tools": [{"file_search": file_search}],
            "http_options": _http_options(),
        }
        # Thinking tier only. Fast already answers in ~10s, so there is nothing to
        # win there and a cap could only break a working path.
        if mode == "thinking":
            thinking = _thinking_config(model)
            if thinking:
                config["thinking_config"] = thinking
                # Worded as a cap WE applied, not a property of the model. The
                # earlier phrasing ("capping X reasoning with {'thinking_level':
                # 'LOW'}") read as though the model itself were low-grade; LOW is
                # a deliberation budget, and the model is unchanged.
                log.info(
                    "research[%s]: %s reasoning effort capped to %s",
                    _req_id.get(), model,
                    "/".join(f"{k}={v}" for k, v in thinking.items()),
                )
        return config

    # Walk the selected tier's ladder (cfg.models_for_mode: fast vs thinking),
    # falling through on transient errors only — see `_call_with_ladder`.
    return _call_with_ladder(
        cfg.models_for_mode(mode),
        lambda model: _client().models.generate_content(
            model=model, contents=search_q, config=_config_for(model)
        ),
        label="generate",
    )


def _deeplink_for(uid: str) -> str | None:
    # Seam for resolver plan Part D. Null in v1 — the app does not render links
    # yet, and the SuttaCentral→BJT resolver that fills this lands later.
    return None


# In-band inline-citation marker baked into the answer prose at each grounded
# span, e.g. "…abandons[[cite:mn9]], while…". The app parses these out and
# renders a tappable chip in place (research_answer_view.dart). Kept lowercase
# (uid form) so it never collides with the prose linkifier's uppercase refs.
CITE_TOKEN = "[[cite:{uid}]]"


def _grounding_metadata(resp):
    """The first candidate's grounding_metadata, or None."""
    candidates = getattr(resp, "candidates", None) or []
    return getattr(candidates[0], "grounding_metadata", None) if candidates else None


def _grounding_chunks(resp) -> list:
    return list(getattr(_grounding_metadata(resp), "grounding_chunks", None) or [])


def _chunk_uid(chunks: list, index: int) -> str | None:
    """The uid (retrieved_context.title) of grounding chunk `index`, if any."""
    if not 0 <= index < len(chunks):
        return None
    rc = getattr(chunks[index], "retrieved_context", None)
    return getattr(rc, "title", None) if rc else None


def _byte_to_char(text: str, byte_index: int) -> int:
    """Map a UTF-8 byte offset (Gemini reports segment indices in bytes) to a
    Python str index. Clamps to the ends; tolerates a split multibyte boundary."""
    if byte_index <= 0:
        return 0
    encoded = text.encode("utf-8")
    if byte_index >= len(encoded):
        return len(text)
    return len(encoded[:byte_index].decode("utf-8", errors="ignore"))


def _inject_citation_tokens(text: str, resp) -> str:
    """Insert `[[cite:uid]]` markers at each grounding support's end offset, so
    the app renders an inline chip exactly where the model grounded a claim.

    Fallback only (used when the prose named no linkable ref). No
    `grounding_supports` → text unchanged; the client then surfaces the sources
    under its "Other sources" heading instead (design §5.5).
    """
    gm = _grounding_metadata(resp)
    supports = getattr(gm, "grounding_supports", None) or []
    if not supports:
        return text

    # `segment.end_index` is relative to the part named by `segment.part_index`,
    # but we map offsets against `resp.text` (all parts concatenated). Those agree
    # only for a single-part answer; for multi-part, skip injection (degrades to
    # "Other sources") rather than place markers at the wrong offset.
    candidates = getattr(resp, "candidates", None) or []
    content = getattr(candidates[0], "content", None) if candidates else None
    if len(getattr(content, "parts", None) or []) > 1:
        return text

    chunks = _grounding_chunks(resp)

    # Collect (char_pos, [uids]); insert back-to-front so earlier offsets stay
    # valid. A support citing several chunks yields several adjacent chips.
    insertions: list[tuple[int, list[str]]] = []
    for sup in supports:
        seg = getattr(sup, "segment", None)
        end = getattr(seg, "end_index", None) if seg else None
        if end is None:
            continue
        uids: list[str] = []
        for idx in getattr(sup, "grounding_chunk_indices", None) or []:
            uid = _chunk_uid(chunks, idx)
            if uid and uid not in uids:
                uids.append(uid)
        if uids:
            insertions.append((_byte_to_char(text, end), uids))

    for char_pos, uids in sorted(insertions, key=lambda pair: pair[0], reverse=True):
        token = "".join(CITE_TOKEN.format(uid=uid) for uid in uids)
        text = text[:char_pos] + token + text[char_pos:]
    return text


# A parenthesis group that, after linkifying, wraps ONLY chip tokens and their
# separators (comma / "and" / "&" / ";") — we drop those parens so the chip reads
# cleanly ("…දේශනා කර ඇත 📖SN 15.11.") instead of "(📖SN 15.11)".
_PARENS_OF_CITES = re.compile(
    r"\(\s*((?:\[\[cite:[^\]]+\]\](?:\s*(?:,|;|&|and)\s*)?)+)\)"
)


def _linkify_prose_refs(text: str) -> str:
    """Turn the canonical refs the model wrote in prose (e.g. "(SN 15.11)") into
    inline `[[cite:uid]]` chips, for known uids only.

    This is the PRIMARY chip source: a ref the model chose to write is exactly
    where the reader expects a tappable citation, and it survives even when
    Gemini returns no `grounding_supports`. Unknown refs are left as plain text
    (the linkifier already drops hallucinations from the citation list).
    """
    def _repl(m: "re.Match[str]") -> str:
        uid = uid_from_ref(m.group())
        return CITE_TOKEN.format(uid=uid) if uid and known_uid(uid) else m.group()

    linked = REF_IN_PROSE.sub(_repl, text)
    return _PARENS_OF_CITES.sub(lambda m: m.group(1).strip(), linked)


def _to_citations(answer_text: str, resp, search_q: str, snippet_chars: int) -> list[Citation]:
    """Synthesise citations from grounding_metadata + linkify refs in prose."""
    cites: dict[str, Citation] = {}

    # 1) Passages actually used to ground the answer (grounding_metadata).
    for chunk in _grounding_chunks(resp):
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

    token = _req_id.set(uuid.uuid4().hex[:6])
    started = time.monotonic()
    try:
        is_si = is_sinhala(req.question)

        # The FIRST line of a request, and the one whose absence reads as "the call
        # never arrived": on the Thinking tier the top rung alone can take ~45s, and
        # until now nothing was logged until something went wrong. Naming the whole
        # ladder up front also makes the mode switch auditable at a glance — you can
        # see Thinking really did get the thinking tier.
        log.info(
            "research[%s]: START mode=%s lang=%s history=%d ladder=%s",
            _req_id.get(), req.mode, "si" if is_si else "en", len(req.history),
            " → ".join(cfg.models_for_mode(req.mode)),
        )

        search_q = _rewrite(cfg, req.question, req.history, to_english=is_si)
        basket = req.filters.basket if req.filters else None

        # Prototype: single query. _search_queries is the fan-out seam (§5.9b).
        resp = _generate(cfg, _search_queries(search_q)[0], is_si, basket, req.mode)

        text = getattr(resp, "text", "") or ""
        if not text.strip():
            # Blank generation or a safety block with no candidates — a 200 with an
            # empty answer would surface as an empty chat bubble. Treat it as a
            # non-200 "rephrase" error instead (plan §3.4: errors stay non-200).
            log.warning(
                "research[%s]: empty answer after %.1fs — surfacing cannot_answer",
                _req_id.get(), time.monotonic() - started,
            )
            raise ResearchError(422, "cannot_answer", CANNOT_ANSWER_MSG, retriable=False)

        # Build citations from the ORIGINAL text, then produce the display answer with
        # inline `[[cite:uid]]` chips. PREFER the refs the model wrote in prose
        # ("(SN 15.11)") — that's what the reader sees and expects to tap, and it
        # works even when Gemini returns no grounding_supports. Only when the model
        # named no linkable ref do we fall back to grounding-support placement.
        citations = _to_citations(text, resp, search_q, cfg.snippet_chars)
        answer_text = _linkify_prose_refs(text)
        if "[[cite:" not in answer_text:
            answer_text = _inject_citation_tokens(text, resp)
        # Pairs with START: the total is what the user actually waited, so a slow
        # question can be blamed on a rung (see the per-rung timings) rather than guessed at.
        log.info(
            "research[%s]: DONE in %.1fs (%d citations)",
            _req_id.get(), time.monotonic() - started, len(citations),
        )
        return ResearchResponse(
            answer=answer_text,
            lang="si" if is_si else "en",
            citations=citations,
        )
    finally:
        _req_id.reset(token)
