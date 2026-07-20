# Plan: Shorten the AI Q&A "Sources" to a relevant snippet

**Branch:** `feat/ai-qa`
**Status:** implemented (2026-06-28) — shipped with an extension; see the note below.
**Scope:** mostly `ask_server/`, plus a small Flutter rendering change.

> **Implemented with an extension.** Beyond shortening the snippet, the heading is
> split off into a separate `title` field (`snippet.split_heading`) shown bold above
> the body-only snippet — which *did* require a Flutter change in
> `ask_chat_dialog.dart` (so the "No Flutter change" note in §5 no longer holds).
> `make_snippet` also lost its `ref` arg; ref-stripping moved into `split_heading`,
> which guards against mis-reading a long sutta's tail chunk as a heading (the
> SN 15.20 colophon case). Contract + examples live in the README response and
> design §7.

Related:
- Backend: [`../../todo/wisdom-project-rag-qa-design.md`](../../todo/wisdom-project-rag-qa-design.md) (§5.5 citations)
- Feature plan: [`../../todo/ai-qa-and-suttacentral-reference-resolver-plan.md`](../../todo/ai-qa-and-suttacentral-reference-resolver-plan.md)

---

## 1. Problem

The SN 15 (Anamatagga) pilot works: the top answer is good, and each answer
lists its sources. But every source prints the **entire sutta**, so the
"Sources" panel is a wall of text (see the SN 15.6 / SN 15.5 blocks the user
flagged). We want a short, on-target snippet per source — like an FTS
`snippet()` — because deep-links will let the user open the full sutta anyway.

## 2. Why it's long: what `grounding_metadata` actually is

RAG (Retrieval-Augmented Generation) runs in three stages, all inside Gemini
File Search:

```
question ─▶ [1 RETRIEVE few relevant chunks] ─▶ [2 AUGMENT: feed them as context]
         ─▶ [3 GENERATE answer from only those chunks] ─▶ answer + grounding_metadata
```

`grounding_metadata` is the **receipt** returned *after* generation — not the raw
input fed to the model. It has two parts:

| Field | Meaning |
|---|---|
| `grounding_chunks[]` | the **sources** used. Each: `retrieved_context.title` (= our uid, `sn15.3`) + `retrieved_context.text` (**the chunk text**). |
| `grounding_supports[]` | the **map** "answer-sentence X ← chunk #N". Offsets point into the *answer*, **not** into the chunk. |

Today the pipeline forwards the chunk text verbatim
(`pipeline.py` → `snippet=getattr(rc, "text", None)`).

**Why the chunk is huge:** a "chunk" is whatever slice File Search cut at ingest
time. Our suttas are short, so File Search keeps a whole sutta as ~one chunk →
`rc.text` ≈ the whole sutta. So "use the chunk itself" (what we already do) =
"show the whole sutta". And Gemini gives **no character offset** for where inside
the chunk the answer was grounded, so "just the matched line" must be derived by
us.

## 3. Two levers (and why we pick display-time slicing)

**Lever A — smaller chunks at ingest** (File Search `chunking_config`, fewer
tokens/chunk). Then `rc.text` is naturally short.
- ✗ Smaller chunks give the *model* less context per source → can hurt answer
  quality; the boundary still won't line up with the relevant sentence; tuning
  it means a costly full re-ingest.

**Lever B — keep rich chunks for the model, slice a window for the human**
(this plan).
- ✓ Model still reads the full sutta (good answers); the *Sources* list shows an
  FTS-style window around the match. Pure function, **no re-ingest, no extra
  Gemini call** → zero added cost/latency.

Decision: **Lever B.** Decouple "what the model reads" (rich) from "what the
human sees" (short, on-target). The chunk stays the source of truth; we show a
smart excerpt of it.

## 4. The window strategy (the core choice)

`make_snippet(text, query, max_chars)` turns a long chunk into one short span.
Two candidate algorithms:

### Option 1 — Keyword window  (recommended)
Mimics SQLite's `snippet()`:
1. Split the chunk into sentences.
2. Lowercase + tokenize the **search query**; drop stopwords.
3. Score each sentence by the count of *distinct* query terms it contains;
   pick the best (earliest wins ties), extend to a neighbour sentence if room.
4. Trim to `max_chars` on word boundaries; add leading/trailing `…` when not at
   the chunk's edges.
5. **Fallback:** no query term present → first `~max_chars` chars + `…`.

> e.g. *"…a league long, a league wide … by this means the huge heap of mustard
> seeds would come to an end. That's how long an eon is…"*

- ✓ Shows the part that actually answers the question.
- ✗ A little more code; relies on the query terms appearing in the (English)
  chunk — true here, since retrieval is over Sujato's English and the Sinhala
  path is rewritten to English before search.

### Option 2 — First sentences + ellipsis
Just the opening `~max_chars` of the chunk + `…`.

> e.g. *"At Sāvatthī. Then a mendicant went up to the Buddha … and asked him,
> 'Sir, how long is an eon?'…"*

- ✓ Dead simple, deterministic, no query needed.
- ✗ Always shows the framing line ("At Sāvatthī. Then a mendicant…"), which is
  near-identical across suttas and often *not* the matched part.

**Recommendation: Option 1.** It's the difference between "a snippet of the
exact match" (what was asked for) and "the first line of every sutta". Option 2
is the cheap fallback baked into Option 1 anyway.

## 5. Implementation

1. **New pure module `ask_server/app/snippet.py`** — `make_snippet(text, query,
   max_chars) -> str` per §4 Option 1 (with the Option-2 fallback). No SDK
   import; unit-testable in isolation.
2. **Wire into `pipeline.py`** — thread the search query into
   `_to_citations(text, resp, search_q)` and replace
   `snippet=rc.text` with `make_snippet(rc.text, search_q, cfg.snippet_chars)`.
   Linkifier-only citations (refs named in prose) keep `snippet=None` —
   unchanged.
3. **Config knob `app/config.py`** — `snippet_chars` from env
   `ASK_SNIPPET_CHARS`, default **220** (≈ 3–4 lines in the 420px chat bubble).
4. **Docs** — `ask_server/README.md` response example + design §5.5: the snippet
   is now a *windowed preview span*, not the full chunk.

**Flutter (changed from the original plan):** the shipped version renders
`citation.title` (bold) above `citation.snippet` on its own line in
`ask_chat_dialog.dart` — see the implementation note at the top. The windowing
itself stays server-side, keeping the payload small and the client thin.

## 6. Tests

`snippet.py` is a pure function → easy `pytest` (keyword hit, ties, no-match
fallback, max_chars trim on word boundary, ellipsis edges). Per project rule,
tests are **not** auto-generated — add on request.

## 7. Optional follow-ups (not in this pass)

- **Highlight** matched terms in the snippet — reuse the app's existing
  `SearchMatchFinder` / `HighlightedFtsSearchText` over the (now short) snippet
  using the user's question terms.
- **Drop uncited chunks** — use `grounding_supports` to emit only chunks the
  answer actually leaned on (File Search sometimes returns retrieved-but-unused
  chunks).
- **Snippet language** (design §15 open decision) — stays the English source
  span; orthogonal to length.
