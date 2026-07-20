# From question to cited answer — the research server, demystified

One page on how `research_server/` works, what the jargon means, and where
the CPU actually goes.

## What the server is

A thin, stateless TypeScript service (Cloudflare Workers; also runs on plain
Node). It owns **no data** — no SQLite, no table of sutta names, nothing.
Everything it knows arrives either in the request or in Gemini's response.

Hard constraint: **10ms CPU per request** (Workers free plan, permanent).
Waiting on Gemini costs zero CPU — only our own compute counts.

## The normal flow

1. App sends `POST /research` — `{question, history, mode}`.
2. **Detect language** — one regex for Sinhala characters.
3. **Rewrite** — only if the question is Sinhala or has history: a fast-tier
   Gemini call turns it into one standalone English search query
   (File Search retrieves poorly on Sinhala; pronouns need resolving).
   Always the Fast ladder even in Thinking mode — rewriting is throwaway, so
   it never spends throttled thinking quota. `RESEARCH_REWRITE_MODEL` pins just
   this step's model (default `fastModels[0]`), independent of the answer model.
4. **One Gemini call with the File Search tool.** We search nothing ourselves.
   Gemini searches the store, writes an answer grounded in what it found, and
   returns *both* the answer and the retrieved texts.
5. **Post-processing** — the CPU our own code spends: build citations +
   snippets, place chips (below).
6. Respond. One log line:
   `research[a1d26f] POST /research mode=fast lang=en model=… rung=1 citations=2 200 in 6.2s cpu=3.4ms build=0.3ms body=780KB`

Response shape (one citation shown):

```json
{
  "answer": "…the tears shed exceed the four great oceans [[cite:sn15.3]].",
  "lang": "en",
  "model": "gemini-2.5-flash",
  "citations": [{
    "uid": "sn15.3", "ref": "SN 15.3", "title": "Tears", "kind": "canon",
    "snippet": "… the **tears** you have shed are greater than the water in the four great **oceans** …"
  }]
}
```

## Fast vs Thinking — which tier does what

Retrieval isn't a separate step: File Search is a **tool on the answer call**, so
whichever tier answers also retrieves. The rewrite is the *only* always-Fast
stage, and it fires only on Sinhala or a follow-up (history). Consequences:

- **English + Thinking, first turn** = purest path — rewrite skipped entirely,
  the high model does retrieval *and* answer.
- **Sinhala** = the fast-tier rewrite does the whole translation, so it shapes
  the English search terms; that's the one case where retrieval quality is
  pinned to Fast (the price of a Sinhala-language answer).
- Mode is **per-turn**, captured at send time; flipping mid-chat only affects
  later turns, and prior Fast answers ride along as plain-text context.
- The whole request (rewrite + answer, all ladder rungs) shares one per-mode
  deadline — 55s Fast / 290s Thinking, just inside the app's HTTP timeouts —
  so the server never keeps burning quota after the client has hung up; a
  rung that starts late gets only the time that's left.

## Jargon, translated

- **store** — Gemini File Search index of the canon. Ingest uploads one
  document per sutta, formatted `"<heading>\n<body>"`.
- **chunk** — a retrieved *piece* of a stored document, with its full text.
  Server-side raw material only; the client never sees one. A small sutta is
  one chunk (= the whole sutta); a long sutta arrives as several chunks
  sharing one uid.
- **citation** — one record in the `citations` array = one card in the
  Sources sheet. The unit everything else hangs off.
- **uid / ref** — the same identity twice: machine form `sn15.3`, human form
  `SN 15.3`. The uid is also all the client needs to build links itself
  (BJT deep link via the SC↔BJT concordance, SuttaCentral URL by concat) —
  which is why a `deeplink` wire field was removed (2026-07-18): the
  stateless server could never resolve anything the client can't.
- **title** — the sutta's name, read off the chunk's first line (the heading
  ingest put there). Verified by ref-number match, so a mid-sutta chunk's
  first line is never mistaken for a heading (`title: null` instead). The
  server has no name table — this peel is the only way it can know a title.
- **snippet** — a ~220-char **verbatim quote** from the source with the
  user's question terms bolded. The card's proof line.
- **marker / chip** — `[[cite:sn15.3]]` inside the answer text is a marker;
  the client renders it as a tappable 📖 chip that points at the citation
  with that uid. Marker = where it's relevant; citation = what it is.
- **groundingChunks** — Gemini's "what did I read": the retrieved texts.
  Used on **every** request (cards + snippets come from it).
- **groundingSupports** — Gemini's "which answer sentence came from which
  chunk": `{segment.endIndex, groundingChunkIndices}`. Offsets are **UTF-8
  bytes**, not characters (matters for Sinhala). Used **only** as a fallback
  for chip placement.
- **kind** — what type of source a card is: `"canon"` today; `"note"`
  reserved for translator notes if they're ever ingested. NOT the
  sutta/vinaya split — that's the `basket` metadata filter at retrieval
  time (vinaya texts are just canon with a different uid shape,
  e.g. `pli-tv-bu-vb-np18`).

## Chips: two paths, one gate

**Primary:** the system prompt makes the model cite refs in prose —
"(SN 15.3)" — and a regex turns each known ref into a marker. Pure string
substitution; the model already placed each ref where it belongs.

**Fallback:** runs only if the primary produced **zero** markers. Transcribe
`groundingSupports`: chunk index → uid, byte offset → char position (one
counting walk), splice markers at the end of supported sentences. No
guessing anywhere — Gemini made every connection; we transcribe it.

## The snippet situation

**Why it exists.** The card must prove — without a tap — that the answer
stands on real canonical text containing the user's own words. Gemini gives
everything *except* that: it points at whole chunks and says "somewhere in
here". Only the server can cut the quote (the client would need the full
chunk texts — megabytes per request).

**Why it was the hotspot.** It is the only stage whose input is books, not
pages. Question ~100 chars, answer ~5k — but one chunk can be 100k+ chars,
times ~14 distinct sources. Finding terms also means *folding* first
(lowercase + strip diacritics, so "savatthi" matches "Sāvatthī") — a pass
over every character before any searching starts. Done naively this cost
27ms (Python) — nearly 3× the whole budget.

**How it was bounded** (current worst case: **6.7ms cold / 3.5ms warm**):
cut each chunk to 12k chars *before* touching it; fold once with native
string ops; search with `indexOf`; snippet once per source (dedupe by uid
first — this also auto-selects the highest-scoring chunk of a long sutta);
whitespace-normalize only the final 220-char window. Cost is now a constant
per source, not a function of sutta length.

**What's guaranteed vs. heuristic.** Guaranteed, structurally: **right
source** (cut from the chunk Gemini retrieved under that uid) and **verbatim
text** (a literal slice — never a paraphrase). Heuristic: *which* 220 chars —
the window where the most distinct question terms cluster (same idea as a
search-engine result snippet). Gemini offers no finer signal: supports map
sentences to whole chunks, never to a sentence inside one. Every failure
mode is therefore "a genuine but less pointed quote from the right source" —
never wrong-source, never invented. No-term-match fallback = the opening of
the retrieved chunk, which retrieval already aimed at the relevant region.

**The kill switch.** Two rungs, if the 10ms budget is ever threatened —
and live-store measurements say it isn't (`build=0.2–0.4ms` warm; a bigger
store changes *which* chunks come back, not how many or how large, so
per-request cost doesn't grow with the store):

- **Rung 1 — snippets for chipped sources only.** Reorder `buildResponse`
  so the answer text is finalized first, then snippet only the uids that
  got a `[[cite:]]` chip (typically 2–5 of ~14). The un-chipped "other
  sources" carry the broadest, least-read snippets and most of the cost.
  Edge case: an answer with zero chips (multi-part answers skip injection)
  keeps all snippets — otherwise no card would carry any quote.
- **Rung 2 — skip `makeSnippet` entirely.** Worst case drops to ~1–2ms.

`snippet: null` is contract-legal (prose-only cards already ship it), so
both rungs are server-only — the client just renders cards without preview
lines. (Note in `src/snippet.ts` header.)

## CPU map of one live request

| Stage | Scales with | Today | Kill switch (rung 2) |
|---|---|---|---|
| Parse client request | ~1 KB | ~0 | ~0 |
| Await Gemini | I/O — free | 0 | 0 |
| `JSON.parse` upstream payload | total chunk text | **~1–12ms live** | ~1–12ms |
| Snippets | sources × 12k bound | ~3–6ms bench; 0.2–0.4ms live | **0** |
| Titles (`splitHeading`) | first lines | ~free | ~free |
| Chip placement (either path) | answer ~5k | ~0.1ms | ~0.1ms |
| Stringify response | few KB | ~0 | ~0 |
| **Worst case (our stages, bench)** | | **~6.7ms** | **~1–2ms** |

The one cost that survives the kill switch is parsing Gemini's response —
native-speed and unavoidable (the answer lives in the same JSON as the chunk
texts). **Live data (2026-07-18) says this is the real driver**: totals
ranged 3–14ms across calls while `build=` stayed sub-ms, uncorrelated with
citation count — what varies is how much chunk text Gemini ships back, plus
cold-isolate noise (calls minutes apart each wake a cold Worker). The log's
`body=` field records the payload size per request to track this. One 14ms
call completed fine — Cloudflare tolerates occasional spikes past 10ms;
sustained overage is what draws 1102 errors. If that ever happens, the kill
switch won't help (it trims a sub-ms stage): the levers are a smaller
payload from Gemini (fewer/smaller retrieved chunks) or the paid tier.
Bench: `npm run bench` rebuilds the paranoid worst case (chunk = entire
123k-char sutta) and fails the build at ≥10ms.
