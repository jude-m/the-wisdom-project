"""Slice a long retrieved chunk down to one short, on-target snippet.

Gemini File Search keeps a whole sutta as ~one chunk, so the grounding chunk's
text is essentially the full sutta. For the human-facing "Sources" list we want a
short window around the matched terms — SQLite `snippet()`-style — not the whole
thing (the deep link opens the full text). This is pure: no SDK, no extra Gemini
call, so it adds no cost or latency.

Plan: docs/done/research/source-snippet-shortening-plan.md (§4, Option 1).
"""
from __future__ import annotations

import re

# Tiny English stopword set so scoring keys on content words ("eon", "mustard"),
# not glue ("the", "of", "is"). Deliberately small — the corpus is English
# (Sujato), and short words (<3 chars) are dropped anyway.
_STOPWORDS = frozenset(
    "and are but for from how its not that the their them then there these they "
    "this was were what when where which who why will with you your".split()
)

_WORD = re.compile(r"[A-Za-z]+")
# Sentence-ish split: end punctuation followed by whitespace. Pali prose is full
# of '.' '?' '"' so this is plenty to pick a window from.
_SENT_SPLIT = re.compile(r"(?<=[.?!])\s+")
_WS = re.compile(r"\s+")

# How far we'll nudge a cut to land on a word boundary instead of mid-word.
_SNAP = 24


def make_snippet(text: str, query: str, max_chars: int = 220) -> str:
    """Return a ~`max_chars` window of `text` around the `query` terms, with `…`.

    Falls back to the head of `text` when the query has no usable terms or none
    of them appear in the chunk. Returns "" only for empty input. The chunk's
    leading heading is split off upstream by `split_heading`, so `text` here is
    the sutta body — there's no reference prefix left to strip.
    """
    text = _WS.sub(" ", (text or "").strip())
    if not text:
        return ""
    if len(text) <= max_chars:
        return text

    terms = _query_terms(query)
    if not terms:
        return _head(text, max_chars)

    sentences = _SENT_SPLIT.split(text)
    best_i, best_score = 0, 0
    for i, sentence in enumerate(sentences):
        score = len(_words(sentence) & terms)
        if score > best_score:  # first sentence wins ties (>, not >=)
            best_i, best_score = i, score
    if best_score == 0:
        return _head(text, max_chars)

    # Grow a window of whole sentences around the best one, forward-biased.
    lo = hi = best_i
    length = len(sentences[best_i])
    while True:
        grew = False
        if hi + 1 < len(sentences) and length + 1 + len(sentences[hi + 1]) <= max_chars:
            hi += 1
            length += 1 + len(sentences[hi])
            grew = True
        if lo - 1 >= 0 and length + 1 + len(sentences[lo - 1]) <= max_chars:
            lo -= 1
            length += 1 + len(sentences[lo])
            grew = True
        if not grew:
            break

    window = " ".join(sentences[lo : hi + 1])
    left, right = lo > 0, hi < len(sentences) - 1
    # A single sentence can still exceed max_chars → trim around the first term.
    if len(window) > max_chars:
        window, tl, tr = _trim_around_terms(window, terms, max_chars)
        left, right = left or tl, right or tr
    return _wrap(window, left=left, right=right)


def split_heading(text: str, ref: str | None = None) -> tuple[str | None, str]:
    """Split a chunk at the ingest head/body boundary → (title, body).

    `ingest.load_unit` writes each unit as "<heading>\\n<body>", where the
    heading is the title segments (uid:0.*): collection name + number + chapter +
    sutta name, e.g. "Linked Discourses 15.6 Chapter One A Mustard Seed". We
    surface that as the citation's bold `title` (shown on its own line) and window
    only the body for the snippet — so every source shows a consistent heading
    instead of one that appears only when the match lands up top.

    `ref` (e.g. "SN 15.6") lets us drop just the number from the heading — it's
    already shown as the citation's `ref` — while keeping the collection name:
    "Linked Discourses Chapter One A Mustard Seed".

    Only the FIRST chunk of a sutta carries the ingest heading, which always leads
    with the collection ref number (e.g. "Linked Discourses 15.20 …"). Long suttas
    get split by File Search, so a grounding chunk can be a mid/tail slice that
    merely contains a newline; if the text before the first newline doesn't carry
    the ref number, it isn't a heading (it'd be e.g. a closing verse — see
    SN 15.20), so we keep the whole text as the body and emit no title. Returns
    (None, text) in that case and when there's no newline at all.
    """
    head, sep, body = text.partition("\n")
    num = _ref_number(ref)
    if not sep or not num or not re.search(rf"\b{re.escape(num)}\b", head):
        return None, text
    # Drop just the number (the citation already shows it as `ref`), keeping the
    # collection name: "Linked Discourses 15.6 Chapter One A Mustard Seed" ->
    # "Linked Discourses Chapter One A Mustard Seed". Group 1 = text before the
    # number; the number and its clinging space/punct are removed.
    title = re.sub(
        rf"^(.{{0,40}}?)\b{re.escape(num)}\b[\s.,:–—-]*", r"\1", head.strip(), count=1
    )
    return (_WS.sub(" ", title).strip() or None), body


def _ref_number(ref: str | None) -> str | None:
    """The numeric part of a display ref ("SN 15.20" -> "15.20"), else None."""
    m = re.search(r"\d+(?:[.\-]\d+)*", ref or "")
    return m.group() if m else None


def _query_terms(query: str) -> set[str]:
    return {
        w for w in _WORD.findall((query or "").lower())
        if len(w) > 2 and w not in _STOPWORDS
    }


def _words(text: str) -> set[str]:
    return set(_WORD.findall(text.lower()))


def _head(text: str, max_chars: int) -> str:
    """The opening of the chunk, word-boundary trimmed — the no-match fallback."""
    cut = text.rfind(" ", 0, max_chars)
    return _wrap(text[: cut if cut > 0 else max_chars], left=False, right=True)


def _trim_around_terms(s: str, terms: set[str], max_chars: int) -> tuple[str, bool, bool]:
    """Trim an over-long string to a `max_chars` window centred on the first term."""
    pos = next(
        (m.start() for m in _WORD.finditer(s.lower()) if m.group() in terms),
        0,
    )
    start = max(0, pos - max_chars // 2)
    end = min(len(s), start + max_chars)
    start = max(0, end - max_chars)  # re-pull start if we hit the right edge

    if start > 0:  # snap forward to a word start
        space = s.find(" ", start)
        if 0 <= space - start <= _SNAP:
            start = space + 1
    if end < len(s):  # snap back to a word end
        space = s.rfind(" ", start, end)
        if space != -1 and end - space <= _SNAP:
            end = space
    return s[start:end].strip(), start > 0, end < len(s)


def _wrap(window: str, *, left: bool, right: bool) -> str:
    window = window.strip()
    if left:
        window = "… " + window
    if right:
        window = window.rstrip(".,;:— ") + " …"
    return window
