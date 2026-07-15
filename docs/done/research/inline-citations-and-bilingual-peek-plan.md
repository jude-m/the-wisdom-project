# Inline Citations + Bilingual Peek for the Research (Dhamma AI) feature

> **Status: IMPLEMENTED (2026-07-13).** Backend verified end-to-end (stub route +
> unit checks); Flutter compiles clean; live macOS click-through done by the user.
> Two changes landed during build from user testing — see **Revisions** at the end.
> The most important delta from the original plan: **inline chips are placed from
> the refs the model writes in prose (`(SN 15.11)`), not primarily from
> `grounding_supports`** — the live model often returns no supports, but reliably
> writes refs (§1 below reflects as-built).

## Context

Today the research answer renders as **plain text** (`SelectableText`, `research_chat_dialog.dart:332`) followed by a **separate "Sources" list**, and tapping a source opens a bottom sheet that just re-shows the same ref + title + snippet the list already shows — redundant (the user's original complaint).

We are moving to **embedded inline citations**: citation chips placed *inside* the answer prose (like `…conditioning of the saṅkhāras 📖 SN 12.2`), and the **separate Sources list is removed**. Tapping a chip opens the **peek sheet** (which stays) showing:
- **English (SuttaCentral)** — the `make_snippet` window, matched terms bolded → *why this sutta was cited* (provenance).
- **Sinhala (BJT), from the beginning** — the openable text preview, under its own Sinhala title → *what "Open in reader" will show*.
- **Open in reader** → BJT (the only full text we have).

This is feasible because Gemini already returns the placement data (`grounding_supports`) — the pipeline currently **discards** it (`pipeline.py:196-232`). Key facts established during exploration:
- The RAG corpus is **SuttaCentral English** (Sujato/Brahmali), ingested into a Gemini File Search store (`ingest.py:35-38`); the pipeline **never** reads app content (`pipeline.py:177-183`). It's a *different edition* than the reader.
- The reader holds **only BJT Pali (Sinhala script) + Sinhala** — no English (`content_language.dart:12-18`, `text_layer.dart:174-200`). So the peek's English can only come from the RAG side; the Pali/Sinhala only from the app. They are not aligned → we show the English *matched window* and the Sinhala *opening* (different jobs, no alignment needed).
- `grounding_supports.segment` indexes the **answer**, not the source; `retrieved_context.text` is the **whole sutta** (English). Gemini gives **no source offset**, so a *relevance-centered* highlight of the BJT passage is a genuine **v2** (needs a segment-level SC↔BJT concordance we don't have).

**Migration note (durability):** the chat dialog will soon become a full-screen tab with multi-chat. Everything here (backend, contract, the answer renderer, the peek) is **shell-agnostic and survives**; the only throwaway is the thin `Dialog` wrapper. So the new answer renderer is built as its **own widget file**, not buried in the dialog, and the dialog shell gets **no polish investment**.

---

## How it works (end-to-end data flow)

Mental model: a **research librarian who may only quote from a fixed shelf**
(our SuttaCentral-English corpus in a Gemini File Search store). We send a
question; Gemini searches the shelf, writes an answer, and hands back the answer
text **plus a "receipts" packet** proving which suttas it used. The server turns
those receipts into tappable citations; the app renders them as inline chips.

```
  ┌──────────────┐   "Why compare saṁsāra to tears?"
  │  Flutter app │ ──────────────────────────────────────┐
  │  chat dialog │                                        │
  └──────────────┘                                        ▼
         ▲                          ┌───────────────────────────────────┐
         │                          │   research_server (Python)        │
         │                          │   1. detect language (si / en)    │
         │                          │   2. rewrite → standalone EN query │
         │                          └─────────────────┬─────────────────┘
         │                                            │  EN query + system rules
         │                                            ▼
         │                          ┌───────────────────────────────────┐
         │                          │   Gemini  +  File Search tool     │
         │                          │   (SuttaCentral English corpus)   │
         │                          └─────────────────┬─────────────────┘
         │                                            │  response:
         │                                            │  • answer text
         │                                            │  • grounding_chunks[]   (sources)
         │                                            │  • grounding_supports[] (placement)
         │                                            ▼
         │  answer w/ [[cite:uid]]   ┌───────────────────────────────────┐
         │  + List<Citation>         │   Transform  (pipeline.py)        │
         └───────────────────────────│   A. chunks   → Citations         │
                                     │      (make_snippet + **bold**)    │
                                     │   B. linkify prose refs           │
                                     │      "(SN 15.3)" → [[cite:sn15.3]] │
                                     │   C. no refs? fall back to supports│
                                     └───────────────────────────────────┘
```

### What we send / get / transform

| Stage | Data | How |
|---|---|---|
| **Send** | question (si or en) | detect language → rewrite/translate into one standalone **English** search query (our shelf is English-only) |
| **Get** | answer text + `grounding_chunks` (sources) + `grounding_supports` (placement) | one `generate_content` call with the File Search tool |
| **A** | each source sutta → a trimmed, bolded `Citation` | `split_heading` peels the title; `make_snippet` windows ~220 chars around the query terms and wraps matches in `**…**` |
| **B** | refs the model typed, `(SN 15.3)`, → hidden `[[cite:sn15.3]]` markers | `_linkify_prose_refs` (known uids only; chip-only parens dropped) |
| **C** | markers → tappable book-chips inside the sentence | `research_answer_view.dart` find-and-replace on the answer string |

### The "hidden marker" trick

The key idea: **`[[cite:uid]]` is a placeholder baked *into the answer string
itself*** — a "put a chip here" instruction. This is why the contract needs **no
new structural field**: placement rides inside `answer`, and the client just
tokenises the string. Server-side we insert markers **back-to-front** so earlier
character offsets stay valid.

The answer string is transformed like this:

```
  Gemini answer text:
    "...more than the water in the four oceans (SN 15.3). This illustrates..."
                                │  B. linkify (server)
                                ▼
  Wire `answer` field:
    "...more than the water in the four oceans [[cite:sn15.3]]. This illustrates..."
                                │  C. render (app)
                                ▼
  On screen:
    "...more than the water in the four oceans [📖 SN 15.3]. This illustrates..."
                                                └─ tappable chip → peek sheet
```

### Which Gemini return fields we actually consume

Every **source** is surfaced (each `grounding_chunk` → a `Citation`, shown inline
or under "Other sources" — nothing is lost). `grounding_supports` is **placement
only**; because the live model usually writes refs in prose (path B) but often
returns **no supports**, supports are consumed **only as the fallback** (path C).

| Array · field | Used? | Where / why |
|---|---|---|
| `grounding_chunks[].retrieved_context.title` (= uid) | ✅ | `Citation.uid`/`ref`; chunk→uid for inline placement |
| `grounding_chunks[].retrieved_context.text` (whole sutta) | ✅ | `split_heading` → title; `make_snippet` → snippet |
| `grounding_chunks[].retrieved_context.uri` | ❌ | deep link stays null in v1 (resolver Part D) |
| `grounding_supports[].segment.end_index` | ✅ (fallback) | marker insert point (byte→char via `_byte_to_char`) |
| `grounding_supports[].grounding_chunk_indices` | ✅ (fallback) | maps a span to its source uid(s) |
| `grounding_supports[].segment.start_index` | ❌ | we mark only the *end* of a claim (chip sits after it) |
| `grounding_supports[].segment.part_index` | ❌ | ⚠️ offsets assume a single content part — see risks |
| `grounding_supports[].confidence_scores` | ❌ | no low-confidence filtering (acceptable) |

> **Latent risk (fallback path only):** `_byte_to_char` maps against
> `resp.text` (all parts concatenated) while `segment.end_index` is relative to
> its `part_index`. Single-part File-Search answers make this a non-issue today;
> revisit if multi-part answers appear.

---

## Backend (`research_server/`)

### 1. Place inline `[[cite:uid]]` chips (`app/pipeline.py`) — as built

Both mechanisms produce the same in-band marker `[[cite:<uid>]]` in the `answer`
string (the client parses these into chips). Precedence, decided from live
testing:

1. **PRIMARY — linkify refs the model wrote in prose** (`_linkify_prose_refs`):
   `REF_IN_PROSE` (`refs.py:28`) finds `SN 15.11`-style refs; each **known** uid
   (`known_uid`) is replaced in place by `[[cite:uid]]`. Parentheses that end up
   wrapping only chips are dropped (`_PARENS_OF_CITES`), so `…දේශනා කර ඇත
   (SN 15.11).` → `…දේශනා කර ඇත 📖SN 15.11.`; parens with other text are kept
   (`(see SN 15.4 for context)`). This is a ref the model *chose* to write — where
   the reader expects a tappable chip — and it survives Gemini returning no
   supports (common in live File Search).
2. **FALLBACK — `grounding_supports`** (`_inject_citation_tokens`): only when the
   prose named no linkable ref. For each support, `grounding_chunk_indices` →
   `retrieved_context.title` (= uid), inserted at `segment.end_index`. The
   **byte→string offset conversion is done server-side** (`_byte_to_char`; Gemini
   indices are UTF-8 bytes) so there is no client-side offset math; insert
   back-to-front so earlier offsets stay valid.

`_to_citations` still builds the full `citations` list from `grounding_chunks` +
the prose linkifier, and drops hallucinated refs (`known_uid`). Any grounded
source **not** named inline surfaces in the client's "Other sources" section
(Flutter §5) — never duplicated with an inline chip.

### 2. Constrain the answer's markdown (`app/pipeline.py` `SYSTEM`)
Add one line asking for a **small markdown subset** — bold, italic, simple `-` bullets, short paragraphs; **no tables, no nested lists, no headings** — so the client renderer stays small. Keep the existing "cite by ref" instruction (feeds the fallback linkifier).

### 3. `make_snippet` fixes — items 1/2/3 (`app/snippet.py`)
1. **ASCII-fold before tokenizing** (`_query_terms`, `_words`): normalize NFKD + strip combining marks so diacritic proper nouns (`Sāvatthī`, `Anāthapiṇḍika`) and future Bodhi-style Pali terms match. Pure, no deps.
2. **Highlight matched terms**: wrap the matched query-term spans in the returned window with **`**…**`** so the app renders them bold via its existing marker path. Wrap after windowing; don't let wrapping break the `…` affixes.
3. **Respect `max_chars`**: reserve the `… `/` …` affix budget so output never exceeds `max_chars`.
- Item 4 (sentence splitter) = **no-op**, left as-is. `make_snippet` already runs only on the SuttaCentral chunk (`pipeline.py:211`) — nothing else to scope.

### 4. Stub (`app/stub.py`)
Update canned responses to include `[[cite:...]]` tokens in `answer` and a `**`-bolded `snippet`, so the whole UI (chips → peek) is exercisable with `RESEARCH_STUB=1`, no live key.

### Contract (`app/contracts.py` + `lib/domain/entities/research/`)
No structural change required: tokens ride inside `answer`; `Citation` keeps `{uid, ref, title, snippet, deeplink, kind}` (snippet reframed as "SC English, matched-term bolded"). Update the docstrings to document the `[[cite:uid]]` convention. `ResearchAnswer`/`chat_message` shapes unchanged.

---

## Flutter (`lib/presentation/widgets/research/`)

### 5. New shell-agnostic answer renderer — `research_answer_view.dart` (NEW)
A widget taking `(String answer, List<Citation> citations)` → `Text.rich`:
- **Block pass:** split into paragraphs / `-` bullet lines (small, matches the constrained subset).
- **Inline pass:** tokenize each block for `**bold**`, `*italic*`, and `[[cite:uid]]`. Emit `TextSpan`s for text and a **`WidgetSpan` chip** (pill: book icon + `citation.ref`, per mock) for each token, looked up by uid in `citations`; chip `onTap` → `CitationSourceSheet.show(context, citation)`.
- Reuse the span-composition approach from `text_entry_widget.dart` (`_buildSpansWithMarkedStyle`, `_isInMarkedRange`) — adapt, don't import (that widget is Pali-dictionary-tap specific). (The English peek block uses a small local `_boldSpans`; both handle only `**` — kept separate rather than over-shared.)
- **"Other sources" section (as built):** compute the uids already rendered inline (from the `[[cite:]]` markers), then show any *remaining* citations — grounded by retrieval but not named in the prose — at the bottom under a small **"Other sources"** heading (`researchOtherSources`). A source shown inline is **never** repeated below; if all are inline the section is omitted. (This replaced the earlier "trailing chip row of everything", which duplicated inline refs — see Revisions.)

### 6. Restructure the peek — `citation_source_sheet.dart`
Keep the sheet; swap the single English snippet for the bilingual layout:
- **Header:** `ref · title` (SuttaCentral naming — unchanged).
- **English block** ("Matched passage · SuttaCentral"): `citation.snippet` rendered with **bold** on the `**…**` spans (shared helper from §5).
- **Sinhala block:** resolve `uid → nodeKey` (existing `suttaCentralRefResolverProvider.nodeKeyForUid`), then `nodeByKeyProvider(nodeKey)` → node → its **Sinhala title** + load the document via `document_provider` / `bjt_document_repository`, taking the **first N Sinhala entries** from the node's page (`entryPageIndex`/`entryIndexInPage`). Label with that Sinhala title so "Open in reader" is unambiguous.
- **Actions:** existing *Open in reader* (BJT) + *Copy link*.
- **Unresolved uid:** no Sinhala block, keep the existing "not linked yet" note; English block still shows.

### 7. Wire into the bubble — `research_chat_dialog.dart`
- Assistant bubble uses `ResearchAnswerView` instead of `SelectableText`; **deleted** the old separate "Sources" list (`_CitationRow` + block). User turns stay plain `SelectableText`. The bubble passes `onCitationOpenedInReader: () { if (context.mounted) Navigator.pop(); }` so choosing "Open in reader" in a chip's peek dismisses the dialog.
- Leave the `Dialog` shell otherwise untouched (throwaway on the tab migration).
- l10n keys added (`app_en.arb` / `app_si.arb`): `researchMatchedPassage` (English peek block label) and `researchOtherSources` (bottom heading).

### v2 (explicitly deferred)
Relevance-centered highlight of the **BJT** passage in the peek/reader — needs a segment-level SC↔BJT concordance (today's resolver is sutta-level). Design doc already scopes this as "segment-level v2."

---

## Verification (done)
- **Backend (verified):** `make_snippet` unit-checked — `Sāvatthī`/`saṁsāra` fold + match + bold, output within `max_chars`. Token injection unit-checked incl. a **Sinhala multibyte** answer (byte→char offset) and the no-supports path. `_linkify_prose_refs` checked on the live screenshot strings (`(SN 15.11)` → chip, parens dropped; multi-ref groups; bare refs; parens-with-text kept). Full `POST /research` route (`RESEARCH_STUB=1`, FastAPI TestClient) → 200 with inline tokens + `**`-bolded snippets + titles.
- **App (macOS, verified by user):** inline chips render in the prose; tapping opens the bilingual peek (SC English + bold matches / BJT Sinhala opening under its Sinhala title / Open in reader → BJT); unresolved uid → snippet-only + "not linked yet"; grounded-but-unnamed sources appear under **Other sources** with no duplication.
- Per project convention, **no new tests were written** — a separate pass/agent handles tests.
- Run recipe: `cd research_server && RESEARCH_STUB=1 .venv/bin/uvicorn app.main:app --port 8081` + `flutter run -d macos --dart-define=RESEARCH_BASE_URL=http://localhost:8081`.

## Revisions during build (from user testing)
1. **Chip source flipped to prose refs (+ trailing row removed).** A live answer
   returned **no `grounding_supports`**, so the original design fell to the
   trailing chip row — while the model had written the refs inline as `(SN 15.11)`
   (plain text). Result: the same refs shown twice. Fix: `_linkify_prose_refs`
   became the **primary** chip source (grounding_supports demoted to fallback),
   parentheses around chip-only groups dropped, and the client's blanket trailing
   chip row removed. (§1, §5.)
2. **"Other sources" section added back, de-duplicated.** Removing the trailing
   row dropped grounded sources the model didn't name inline (e.g. `SN 15.3` in
   the test answer). Fix: the client now shows *only the citations not already
   inline* under an **Other sources** heading — bringing missing sources back
   without reintroducing the duplication of revision 1. (§5.)

3. **Review hardening.** From a code review: (a) grounding-supports injection now
   **skips multi-part answers** — `segment.end_index` is per-part but we map against
   the concatenated `resp.text`, so a >1-part answer would mis-place markers; it
   degrades to "Other sources" instead. (b) `_SinhalaSourcePreview` guards an
   empty slice (no lone title). (c) removed the now-dead `researchSources` l10n
   key. (d) minor: hoisted the peek's `**` regex, `_to_citations` uses the
   `_grounding_chunks` helper. Known-and-deferred: a cite marker landing *inside*
   a `**bold**` run renders literally — only reachable via the rare fallback
   injector, not worth churn.

## Notes
- Plan copied here from the plan-mode scratch path per the project's convention.
- Renderer approach = **small custom parser** (recommended: zero new deps, exact control over chip-offset insertion, reuses the app's marker idiom). Fallback if the model's markdown proves richer than the subset: a maintained package (e.g. `gpt_markdown`) — but the constrained system prompt (§2) is designed to avoid needing it.
