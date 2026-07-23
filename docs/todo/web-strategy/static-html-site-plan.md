# Static HTML Site — Build Plan (per-sutta SEO, Tree Navigator, 4 Layouts, no JS framework)

> Status: **Plan / not started — the real build spec, not a throwaway prototype.**
> Captured 2026-06-12 (revised after field research into tipitaka.lk, buddhadust,
> and SuttaCentral; grouping model refined 2026-07-20).
> Scope: the honest static-HTML surface of the Tipitaka content from
> [`static-web-hosting.md`](./static-web-hosting.md) (Option A′) — **built
> incrementally, smallest subtree first** (§5). Covers static page generation + a
> zero-JS tree navigator + **all 4 reading layouts** + the **per-sutta-page /
> formulaic-range grouping model**. Search is **out of scope here** (deferred).

---

## 1. Goal

Turn the existing content assets into a pile of honest, crawlable, framework-free
HTML pages that:

1. **Generate statically** (SSG) from the same assets the app already ships.
2. Give **every distinct sutta its own indexable page** (SuttaCentral-grade
   name-search SEO), while **grouping only the formulaic micro-sutta runs**.
3. Carry a **static `<details>` tree navigator** (zero JavaScript).
4. Render **all 4 reading layouts** — Pali-only, Sinhala-only, side-by-side,
   stacked (CSS-only, §7).
5. Are produced by a **Flutter-free, clean-architecture** generator that *reuses*
   the existing parsing logic rather than forking it (§8).
6. **Regenerate cleanly when the source JSON is corrected** — the source stays
   canonical; the generator is a pure, deterministic, incremental transform.

No app shell, no flashy interactivity. The build starts on one small subtree (§5)
and scales to the whole canon unchanged — same code, more input.

> **Edition scope (locked 2026-07-21): this static site renders BJT only.** Its job
> is BJT-based discoverability / SEO / fast reading — not an edition browser.
> **Multi-edition** (SuttaCentral, A.P. de Zoysa) lives in the **app** (Flutter web
> on `app.<domain>` + native — subdomain topology decided 2026-07-23), never here —
> so the static pages never emit an `?edition=` param and need no
> `hreflang`/`canonical` edition handling. The URL grammar is shared with the app
> (identical path on the `app.` host, plus `?edition=`); full
> model in the deep-linking plan's *"Editions & the two web surfaces"*
> ([deep-linking-and-shareable-urls.md](./deep-linking-and-shareable-urls.md)).

---

## 2. Constraints (the bar to clear)

These are the maintainer's non-negotiables. Every design choice below is in
service of them; where two pull against each other, the resolution is called out.

| # | Constraint | Why it matters |
|---|---|---|
| **C1** | **Source JSON is the single source of truth.** The generator never edits it. Corrections land in `assets/text/*.json` over time; the build must re-sync and regenerate **only the affected HTML**, deterministically and idempotently. | Corrections arrive regularly; re-sync must be trivial and safe for a solo maintainer. |
| **C2** | **SuttaCentral-grade SEO.** Searching a sutta by name — even a small one like "AN 1.4.5" — should surface our page. | This is the whole point of the static surface. |
| **C3** | **Every sutta, even tiny, has a correct, stable shareable link** to the right place. Whether the link opens the **app (deep link)** or the **web page** is *deferred* — but the URL must be stable now. | Sharing a single sutta must "just work" and not break when the app/web routing is decided later. |
| **C4** | **Per-sutta single view.** A reader can open one small sutta on its own page, not only as part of a group. | SuttaCentral has this; we want it. |
| **C5** | **All 4 reading layouts** (Pali-only / Sinhala-only / side-by-side / stacked) are a **hard requirement**. | Parity with the app's core reading modes. |
| **C6** | **Logical grouping.** Don't shatter the canon into thousands of near-empty pages — group the formulaic micro-sutta runs. | UX + avoids Google's thin/duplicate-content penalty. |
| **C7** | **Continuous reading where natural**, with the URL reflecting position. | The tipitaka.lk reading feel, on static pages. |
| **C8** | **No JS framework, no flashy stuff.** Static navigator now, basic search later. Zero-JS baseline; optional progressive enhancement only. | Slowest connections, all bots/LLMs, low maintenance. |
| **C9** | **Single maintainer.** Prefer simplicity and bounded, mechanical effort. | Sustainability. |
| **C10** | **Keep Flutter web as the interactive app.** The static site is the discoverability/reading surface that *links into* the app. | Don't rebuild the app; route around Flutter's SEO gap. |

> **The central tension is C2 vs C6**: per-sutta SEO wants a page per sutta;
> logical grouping wants to collapse the tiny ones. §6 resolves it **without
> duplicating text**: distinct suttas get their own file; micro-suttas are grouped
> into one chapter file and shown singly via a URL filter — a sutta's text never
> lives in two files.

---

## 3. What we learned from the field (verified 2026-06-12)

We studied the three closest precedents before deciding granularity.

| Site | Stack | Grouping unit | SEO mechanism | Lesson for us |
|---|---|---|---|---|
| **tipitaka.lk** (same BJT data) | Vue SPA, SQLite at runtime | the **content file** — URL `/<key>/<entryIndex>/<lang>`, continuous scroll, position in URL | **none real**; `prerender`/`prerender-node` serves rendered HTML to bots only (the *hacky Option A* we rejected) | the file is a *proven reading unit*; but a SPA gives no honest SEO |
| **buddhadust** | 100% hand-authored static HTML; **no framework, no build** | logical sections + **TOC index pages**; never one page per micro-sutta | plain static HTML → natively crawlable | static + grouping + TOC is a complete, durable model |
| **SuttaCentral** | Lit/Polymer **SPA** (app shell; sutta text **not** in raw HTML) | **curated size/distinctness hybrid**: distinct suttas get their own page; formulaic runs become ranges (`an1.1-10` … `an1.394-574`); `structure/child_range.json` is **committed grouping data** | **bets on Googlebot executing its JS** and indexing the rendered **HTML DOM** — a dev's words: "generated in a different way… but google indexes it just fine" | the hybrid is *why* name-search hits land; and **we can one-up it** |

### The key insight
- SuttaCentral's **per-sutta view** is the SPA loading a *range* file and slicing
  it by segment ID (`an1.5:1.1`…) to show one sutta — storage is ranges,
  addressing is per-sutta.
- SuttaCentral's **per-sutta SEO** depends on Google rendering its JavaScript.
  That only works because the rendered output is **HTML text**. **Flutter web
  cannot ride this** — it paints to `<canvas>`, so there is no text for a crawler
  to read even after JS runs. (This is the core reason we route around Flutter.)
- **We beat both** by putting the text directly in static HTML: no JS-render
  dependency, indexable by *every* bot and LLM (not just Google), fast on slow
  links. We get SuttaCentral's grouping wisdom without its SPA fragility.

### Sizing reality on our data (decides §6)
- **AN** has **1,849 suttas across 28 files**; `an-1` alone holds **243
  micro-suttas** (e.g. `an-1-1-2` spans **3 entries**). One page per micro-sutta
  is absurd and would be thin/duplicate content.
- **File sizes**: min 117 KB, **median ~996 KB**, p90 2.3 MB, max 3.9 MB JSON.
- **Rendered DOM weight** (~3 nodes per text row): median ~2,100 nodes, p90
  ~4,400; only **9 files (3%)** exceed ~6,000 nodes — almost all **commentaries /
  Abhidhamma** (`atta-*`, `ap-*`, `anya-vm`), *not* core suttas. Worst:
  ap-paṭṭhāna ~12,000.
- **The size heuristic works**: in `kn-khp` the famous suttas are the big ones —
  Maṅgala 1,228 / Ratana 2,429 / Mettā 1,056 chars — vs trivial lists (<500).
  "Searched by name" correlates strongly with "substantial."

---

## 4. What the data looks like (verified 2026-06-12)

### 4a. The navigation tree — `assets/data/tree.json`
A **flat parent-pointer map**: `nodeKey → [pali, sinhala, level, [pageIdx, entryIdx], parentKey, contentFileId]`.

```jsonc
"kn-iti":     ["ඉතිවුත්තකපාළි", "ඉතිවුත්තක පෙළ", 4, [0,0], "kn",        "kn-iti"], // container
"kn-iti-1":   ["එකකනිපාතො",     "...",          3, [0,0], "kn-iti",    "kn-iti"], // container
"kn-iti-1-1-1":["ලොභසුත්තං",    "...",          1, [p, e], "kn-iti-1-1","kn-iti"] // leaf (readable)
```

Field order confirmed by `lib/data/datasources/tree_local_datasource.dart:36-42`:

| idx | field | meaning |
|---|---|---|
| 0 | `paliName` | display name, **Sinhala script** |
| 1 | `sinhalaName` | display name |
| 2 | `hierarchyLevel` | depth/type hint |
| 3 | `[entryPageIndex, entryIndexInPage]` | **where this node's content starts** in its file |
| 4 | `parentNodeKey` (`"root"` → null) | builds the tree |
| 5 | `contentFileId` | which `assets/text/<id>.json` holds the text |

- **Children** = nodes whose `parentNodeKey == thisKey` (same as `_buildTreeStructure`).
- **Readable** node = leaf (no children); containers are folders.
- Domain entity exists: `lib/domain/entities/navigation/tipitaka_tree_node.dart`.

### 4b. The content — `assets/text/<fileId>.json`
One file holds **many printed pages and many suttas**:

```jsonc
{
  "filename": "kn-khp",
  "pages": [
    { "pageNum": 2,
      "pali": { "entries": [ {"type":"heading","text":"1. සරණගමනං{1}","level":1}, … ],
                "footnotes": [ … ] },
      "sinh": { "entries": [ … ], "footnotes": [ … ] } },
    …
  ]
}
```

- Side keys are **`pali` and `sinh`** (not `sinhala`).
- Entry = `{ type, text, level? }`; `type ∈ {heading, paragraph, centered, gatha}`.
- **Footnotes are per-page** (`pages[i].pali.footnotes`).
- Inline **markers**: `**bold**`, `__underline__`, `{n}` footnote refs.

### 4c. The crucial relationship
A leaf points at `(contentFileId, entryPageIndex, entryIndexInPage)` — the
**start** of its text. A sutta's text runs from its own start up to **the next
readable sibling's start** in the same file. Slicing is a deterministic transform
over the tree + the file's flattened entries.

---

## 5. Build order — start with a small subtree

1. **`kn-khp`** (ඛුද්දකපාඨපාළි) — 1 parent + **9 flat suttas**, 11 pages. The
   base-pipeline smoke test; all 9 are distinct (each gets its own page).
2. **`kn-iti-1`** (ඉතිවුත්තක → එකකනිපාතො) — **a parent with 3 sub-vaggas**,
   7–10 leaves each. Exercises nested containers + content slicing.
3. **`an-1`** (the 243-micro-sutta Ekaka Nipāta) — used in **P5** to exercise
   **grouping → chapter files + the CSS `:has()` single-view filter** (the C6
   case). Not needed earlier.

Build (1) first, then (2) for nesting, then (3) for grouping. No code changes
between (1) and (2); (3) turns on the grouping manifest.

---

## 6. Page-generation strategy — per-sutta by default, group only formulaic runs

> **Model LOCKED 2026-07-21 — per-container *binary*** (the SuttaCentral model,
> refined). A vagga is **wholly exploded** (every leaf → its own
> `/tipitaka/<nodeKey>` page) **or wholly grouped** (whole vagga → one chapter file,
> single-view via `#<nodeKey>`), **never split** — the per-leaf "hoist substantial
> siblings" mechanism is **retired**. The *threshold value* + *famous-sutta
> allowlist* still tune on real data (P5); the **shareable-link target (app vs web)
> is resolved** (both, per visitor — §13.2 + the deep-linking plan). Rationale +
> numbers in **§13.1**.
> **Threshold LOCKED 2026-07-22 (full-corpus classifier run):** group iff
> **≥ 6 leaves AND max leaf < 1,500 *combined* (pali+sinh) chars** → 145 vaggas /
> 1,593 leaves group; 12,758 suttas explode; site = **14,763 files**. Nothing
> famous groups (kn-khp's smallest famous sutta = 3,544c combined; SN 15 fully
> explodes). ⚠️ §3's kn-khp char figures are *pali-only* — the threshold is
> always **combined**. Verified: no grouped vagga spans a content file; tree
> order == print order in all 285 files.

**In plain words:** *exploded* = the normal case — every sutta in the vagga gets
its **own** HTML file; the vagga page is just a TOC of links. *Grouped* = the
exception for BJT's own repetition-runs (peyyāla, Apadāna/Jātaka verse runs) —
the vagga becomes ONE file and each tiny sutta inside it is a `#anchor`. The
file boundary is **always an existing BJT tree node** (sutta or vagga), never a
unit we invent — the grouped leaves are ones BJT itself prints as ranges (their
BJT labels are literally "1. 15. 14-16").

We considered three uniform rules and rejected both extremes:

| Model | Famous suttas (Mettā, mn10…) | Micro-suttas (AN1) | Re-sync | Verdict |
|---|---|---|---|---|
| **Per content-file (1:1)** | ❌ buried (kn-khp hides Maṅgala+Ratana+Mettā on one page) | ✅ fine | ✅ simplest | loses name-search SEO (fails C2) |
| **Per vagga (uniform)** | ❌ buried (mn10 inside a vagga page) | ✅ ideal | ✅ deterministic | still fails C2 for DN/MN |
| **Hybrid — per-container binary (chosen)** | ✅ own page → **ranks** | ✅ ranged | ✅ via manifest | wins both — the SuttaCentral model, refined |

### The rules — a sutta's text lives in exactly one file
Inspection corrects the model: `/an2.64` is **not** a second file — watch it load
and the **whole chapter (`an2.64-76`) flashes first, then the SPA filters to one
sutta**. SuttaCentral has **one data unit (the range)** and renders two routes
from it with JavaScript. We get the single-sutta view **without duplicating text
and without a SPA**:

1. **Leaf of an *exploded* vagga → its own file** `/tipitaka/<nodeKey>`: full text,
   `<title>` = sutta name, canonical self → full per-sutta SEO (C2), shareable
   (C3), single view (C4); mirrors the app's `/tipitaka/<id>`. Its container is a
   **TOC** (links only); continuous reading via prev/next.
2. **Leaf of a *grouped* vagga → lives *only* in its chapter file** `/tipitaka/<vaggaKey>`:
   one page holding the whole run, each sutta `<section class="sutta" id="<nodeKey>">`.
   The navigator's deepest link, the continuous-reading surface (C7), and the SEO
   unit for the run.
3. **Single view of a micro-sutta = a URL filter on that chapter file** (next
   subsection) — no second file.
4. **Higher containers** → TOC pages (links only, no full text). *(94 mixed
   containers hold leaf **and** sub-container children — all commentary /
   Abhidhamma / Vinaya; the TOC template lists both. None of them group.)*

> **The duplication rule (your call):** every sutta's text exists in **exactly one
> file** — either its own single file (distinct) or its chapter file (grouped),
> **never both**. No content is rendered twice.

### Single-sutta view from a chapter file — CSS `:has(:target)`, zero JS
The chapter renders each sutta as `<section class="sutta" id="<nodeKey>">`. One CSS
rule turns the URL fragment into a filter:
```css
/* no #fragment → show all (chapter);  #an-2-64 → show only that sutta */
.chapter:has(.sutta:target) .sutta:not(:target) { display: none; }
```
- `/tipitaka/an-2-64-76`          → whole chapter (continuous reading).
- `/tipitaka/an-2-64-76#an-2-64`  → just AN 2.64 (single view) — shareable (C3/C4).
- In single view, render a "↩ whole chapter" link (drops `#`) + prev/next (swap
  `#`) — plain anchors, no script.
- **Graceful degradation:** browsers without `:has()` (pre-2023) show the whole
  chapter scrolled to the anchor — still correct, just unfiltered.
- This filter is **only for grouped suttas**; distinct suttas are already their own
  file.

**App-parity URL (LOCKED 2026-07-22 as standard P5 output; mechanism gated
2026-07-23).** The app uses `/tipitaka/<id>` for *every* sutta, so a grouped
sutta's clean `/tipitaka/<nodeKey>` must resolve via a **content-free redirect**
→ `…/<vaggaKey>#<nodeKey>`. No text, so no duplication. Never Pages `_redirects`
(static-rule cap 2,000, verified 2026-07-22, vs 1,593 grouped leaves — too
tight). Two viable mechanisms — **the pick is a P5 decision gate: ask the
maintainer before generating stubs**:
- **Stub HTML files** (meta-refresh-0 + canonical → chapter): in-repo, portable,
  work on `*.pages.dev` previews; +1,593 files (14,763 + 1,593 ≈ 16.4K < 20K).
- **Cloudflare Bulk Redirects**: real edge 301s; targets may carry `#fragment`;
  free quota 10,000 (verify in dashboard — some accounts still show the legacy
  20); needs the custom-domain zone. Details in
  [`static-web-hosting.md`](./static-web-hosting.md) → "Grouped-leaf clean URLs".

**SEO consequence (honest, your trade).** A micro-sutta's text is in the chapter
file only, so the **chapter is its SEO unit** — searching "AN 2.64" lands on the
chapter (the text + heading are there; Google may offer a jump-to anchor). Grouped
suttas get **no separately-ranked clean URL** — that needs the text in a second
file, which you've ruled out. The cost is ~nil: grouped suttas are exactly the ones
nobody searches by individual name. **Distinct / famous suttas keep full per-sutta
SEO** via their own files (the `/an2.64`-style #1 result lands on those).

### Classifying explode vs group — per container (vagga), not per leaf
Decide **per deepest container (vagga)**; every leaf inherits the verdict — a vagga
is wholly **exploded** or wholly **grouped**, never split.
- **Group iff the vagga is a uniform micro run** — heuristic **≥ ~6 leaves AND
  max leaf < ~1500 combined chars**; else **explode**. The `< 1500` clause is the
  SEO guard: the moment a vagga holds one substantial sutta it fails → explodes →
  that sutta keeps its own rankable page (never buried). Threshold locked
  2026-07-22 (§13.1); P5 just regenerates + reviews.
- **~49 "awkward" vaggas** (mostly-micro + one buried substantial sutta, e.g.
  `sn-1-1-2` = 9 micro + a 12K sutta) are the only editorial calls → decided by
  hand, **leaning explode** (never bury the big one; the thin micro pages are
  harmless — nobody name-searches them). A small **allowlist** likewise forces a
  famous-but-short sutta to explode.
- **Persist to committed `grouping.json`** (curated, stable → no URL drift); a text
  correction never re-buckets. Re-grouping is an explicit edit.
- **Why per-container, not per-leaf hoist:** on real data big & micro suttas
  interleave (119/184 AN, 142/243 SN vaggas size-mixed; `an-4-2-3` = `..D..D.DDD`),
  so hoisting the big ones out leaves non-contiguous chapter files. Whole-or-nothing
  keeps every chapter a real contiguous tree range. Full numbers: §13.1.

### Re-sync — the `source → [outputs]` manifest (satisfies C1)
- The generator records, per source `assets/text/<fileId>.json`, the **list** of
  HTML files it produces (distinct sutta pages + range pages + the TOC fragments
  it feeds) plus a content hash.
- A correction to `an-1.json` → hash changes → regenerate **exactly that file's
  output list**. Deterministic + idempotent ⇒ the git diff shows only the suttas
  whose rendered HTML actually changed. The same hashes feed per-URL `<lastmod>`
  in `sitemap.xml` (hosting doc) — corrections get recrawled fast.
- `grouping.json` changes **only** on deliberate re-grouping, never from a content
  correction. → You keep the trivial re-sync you liked about 1:1; you just emit
  *N* files per source instead of 1.

### Continuous reading (satisfies C7)
- **Chapter files** are continuous by nature — the whole run in one scroll; an
  optional ~15-line scroll-spy updates the `#anchor` as you read (progressive
  enhancement; works without JS).
- **Distinct sutta files** use prev/next (`<link rel="prev|next">` + buttons).

### Content-slicing algorithm (pure, no Flutter)
1. Load `<contentFileId>.json`; flatten `pages[]` into one ordered list of
   `(pageIndex, entryIndex, side, entry)` + per-page footnotes.
2. Collect the file's readable nodes, sorted by `(entryPageIndex, entryIndexInPage)`.
3. Each node owns entries from **its start** up to **the next readable node's
   start**. Pair `pali[i]` ↔ `sinh[i]` by index for the dual layouts (alignment
   risk — see §7).
4. For a **range page**, concatenate the slices of every sutta in the run, each in
   its own `<section id="<nodeKey>">`.
5. Collect footnotes referenced by `{n}` in the slice. **Numbering restarts on
   every printed page** (verified corpus-wide 2026-07-22), so a multi-page slice
   holds two *different* `{1}`s: anchor ids must carry the printed page
   (`#fn-p4-1`); displayed numbers stay as printed. In **chapter files**, render
   each sutta's footnotes *inside its own `<section>`* — else the
   `:has(:target)` single view shows one sutta with every other sutta's notes.
6. **Preamble rule (verified 2026-07-22: 258/285 files):** entries before the
   first readable node's start (pitaka/nikāya headings, *namo tassa*, vagga
   heading) belong to **the container** — rendered on its TOC page (exploded
   vagga) or at the top of the chapter file (grouped vagga), never in a leaf
   file (preserves the no-duplication rule). The naive start→next-start slice
   silently drops them.

> **Why not per printed page?** `pageNum`/`pageOffset` are print provenance,
> useful as in-page anchors (`<span id="pg-4">` for citations) but wrong as the
> web unit. The *document* is the sutta (or the formulaic run), never the book page.

---

## 7. The 4 layouts in HTML — CSS-only (hard requirement C5)

Both `pali` and `sinh` are in the JSON, so each page renders **both** and toggles
with **zero JavaScript** via the radio-button `:checked` sibling trick.

### Markup — one radio set **per page** (committed 2026-07-23)

Never per `<section>`: duplicated `id="L-*"`s are invalid HTML and every label
would bind to the first set only. One page-level set precedes the content; the
sibling selectors below reach all sections.
```html
<input type="radio" name="layout" id="L-pali"  checked>
<input type="radio" name="layout" id="L-si">
<input type="radio" name="layout" id="L-sbs">
<input type="radio" name="layout" id="L-stack">

<nav class="layouts" aria-label="Reading layout">
  <label for="L-pali">පාළි</label>
  <label for="L-si">සිංහල</label>
  <label for="L-sbs">පාළි + සිංහල</label>   <!-- side by side -->
  <label for="L-stack">තට්ටු</label>          <!-- stacked -->
</nav>

<article class="sutta">
  <div class="row"><div class="pali">…</div><div class="si">…</div></div>
  …
</article>
```

### CSS — the whole layout engine
```css
.row { display: grid; gap: 1rem; }
/* paliOnly   */ #L-pali:checked  ~ .sutta .si   { display: none; }
/* sinhalaOnly*/ #L-si:checked    ~ .sutta .pali { display: none; }
/* sideBySide */ #L-sbs:checked   ~ .sutta .row  { grid-template-columns: 1fr 1fr; }
/* stacked    */ #L-stack:checked ~ .sutta .row  { grid-template-columns: 1fr; }
```
Four declarative rules, no script, fully crawlable (all text in the DOM).

### Honoring `?layout=…` from a shared link
CSS can't read query strings, so a pure-CSS page opens in its baked default and
the reader toggles via the radios. To open *directly* in a layout from a link:

| Option | How | Verdict |
|---|---|---|
| **A. Default + radios only** | no URL state | ✅ v1 default; zero JS |
| **B. `:target` via hash** | CSS `:target` | ⚠️ steals the fragment from sutta anchors; skip |
| **C. ~8-line enhancement script** | read `?layout=<ReaderLayout.name>`, check the radio once | ✅ **the locked shareable-link contract** (2026-07-20) — token = the app's `ReaderLayout.name` (`paliOnly`/`sinhalaOnly`/`sideBySide`/`stacked`); page still works 100% without JS (baked default). **Also persists the last-picked layout (+3 lines, added 2026-07-23):** on radio change write `localStorage`; on load apply it when the URL has no `?layout=`. Precedence `?layout=` > stored > baked default — the site remembers your layout across pages like the app (`last_reader_layout_provider`) does |

> **Layout in the URL is view state** → it rides in the query (`?layout=`), never
> the path, matching the app's URL grammar (see
> [`./deep-linking-and-shareable-urls.md`](./deep-linking-and-shareable-urls.md)).
> `?layout=` and a grouped sutta's single-view fragment compose cleanly:
> `…/tipitaka/an-2-64-76?layout=stacked#an-2-64`.

> **Hidden-side notes (2026-07-22):** the non-default language side is
> `display:none` at load — Google's mobile-first indexing fully indexes tabbed/
> hidden content, so the Sinhala text still indexes on a Pali-default page
> (don't ever "optimize" the hidden side away). Browser find-in-page skips
> hidden content — correct for the single view, just know it. Mark sides with
> `lang="si"` / `lang="pi-Sinh"` (Pali in Sinhala script) — screen readers +
> language detection, zero cost.

> **Risk — entry alignment (QUANTIFIED 2026-07-22, full-corpus scan).**
> Side-by-side/stacked pair `pali[i]` with `sinh[i]`. **All 1,660 misaligned
> pages (of 28,967) sit in the 7 `ap-pat*` (Paṭṭhāna) files — every other file
> aligns perfectly.** Mitigation unchanged (pad the short side + warn), and
> `ap-pat*` can simply ship last. Open-Q #6 is answered; no measurement phase
> needed.

---

## 8. Clean-architecture prerequisites (do these to avoid hacks)

The biggest "don't fork logic later" item: the marker→display logic lives in a
Flutter widget. Fix the seam first.

### PREREQ-1 — Pure-Dart marker parser into `wisdom_shared`
- **Today:** `**…**`/`__…__`/`{n}` handling is computed inside
  `lib/presentation/widgets/reader/text_entry_widget.dart` (`markedRanges` +
  `TapGestureRecognizer`) — fused with Flutter `TextSpan` rendering.
- **Do:** add `packages/wisdom_shared/lib/src/text/content_markers.dart`:
  ```dart
  /// Splits raw entry text into ordered, typed segments. No Flutter.
  List<ContentSegment> parseContentMarkers(String raw);
  // ContentSegment = { String text; bool bold; bool underline; int? footnoteRef; }
  ```
- Flutter builds `TextSpan`s from the segments; the generator emits
  `<strong>`/`<u>`/`<sup><a>` from the **same** segments. One parser, two
  renderers. Pays back the extraction tracked in [[project_web_rewrite_reuse_calculus]].

### PREREQ-2 — Extract the tree decode from the Flutter datasource
- `tree_local_datasource.dart` mixes asset load (`rootBundle`, Flutter) with the
  **pure** array-decode + parent→child assembly. Move the pure parts into
  `wisdom_shared` (or make `TipitakaTreeNode` Flutter-free — it imports
  `core/constants` + `content_language`; verify those are pure). Generator and app
  then share the decode; only the *byte source* differs.

### PREREQ-3 — Generator is a standalone, Flutter-free Dart package
- New `static_site_generator/` (sibling of `web_client_prototype/`), plain Dart
  console app. **No `flutter` dependency** — only `wisdom_shared` + `dart:io`.
  Compiling without Flutter is the proof that no UI logic leaked in.
- Reads `../assets/...` at build time; writes HTML to `static_site_generator/build/`.

### PREREQ-4 — Clean layering inside the generator
```
static_site_generator/
  bin/generate.dart      # entrypoint: args (root key), orchestrate
  lib/
    domain/              # pure models: SiteNode, SuttaDoc, ContentSegment*
    data/                # asset readers: tree.json, file-map.json, text/<id>.json
    grouping/            # distinct-vs-formulaic classifier + grouping.json I/O
    render/              # pure string→HTML: page template, navigator, entry
    manifest/            # source→[outputs] + content hashes (incremental builds)
    sitegen.dart         # use-case: classify → slice → render → write
  grouping.json          # committed, curated grouping data (analogue of child_range.json)
  build/                 # OUTPUT (gitignored)
```
- `render/` is pure (domain → `String`), unit-testable. `data/` is the only layer
  touching the filesystem. `ContentSegment` is **imported from `wisdom_shared`**.

---

## 9. The tree navigator (pruned static core + one shared full tree)

> **Revised 2026-07-22.** The full tree as HTML is ~2 MB; embedding it in every
> page ≈ 30 GB of build output — not viable. Two layers instead (**plain JS
> approved by the maintainer 2026-07-22** — still framework-free, still a pure
> static deploy; fits C8's "optional progressive enhancement"):

- **Layer 1 — baked-in pruned nav (zero-JS baseline):** ancestors + each
  ancestor's direct children only (a few KB per page). Works with JS off;
  crawlers reach every node via its parent's TOC page. Native
  `<details>`/`<summary>`, `<a>` per node — same `tree.json` the app's
  `navigation_tree_provider` consumes.
- **Layer 2 — full tree on demand (~20 lines of plain JS):** fetch one shared
  `/nav.html` fragment (~2 MB raw, ~200–400 KB gzipped, browser-cached once for
  the whole site), swap it into the nav, re-open the current branch. Pages work
  100% without it. Bonus: a tree correction regenerates `/nav.html` + nearby
  pruned navs only — far smaller C1 blast radius than a full tree in every page.
- Names via `getDisplayName(ContentLanguage)` (Pali in Sinhala script by default),
  reusing the entity's fallback rule.

```html
<nav class="tree">
  <details open><summary>ඉතිවුත්තකපාළි</summary>
    <details open><summary>එකකනිපාතො</summary>
      <details><summary>පඨමො වග්ගො</summary>
        <a href="/tipitaka/kn-iti-1-1-1">ලොභසුත්තං</a> …
      </details>
    </details>
  </details>
</nav>
```

---

## 10. Output & URLs

```
build/
  index.html                         # root TOC of the chosen subtree
  tipitaka/
    kn-khp.html                      # container TOC — FLAT file like every node
    kn-khp-5.html  kn-khp-9.html …   # DISTINCT sutta files (text lives ONLY here)
    an-2-64-76.html                  # CHAPTER file (grouped run; text lives ONLY here)
    an-2-64.html  (if stubs picked)  # content-free REDIRECT → an-2-64-76#an-2-64
    …
  sitemap.xml                        # distinct files + chapter files (not redirect stubs)
  assets/site.css                    # one small stylesheet (layouts + tree + type)
  fonts/…                            # Noto Sinhala, font-display: swap (progressive)
  grouping.json  (source, not output)
  .manifest.json (source→[outputs] + hashes, for incremental builds)
```
- **Distinct sutta** → `/tipitaka/<nodeKey>` (own file, full per-sutta SEO); mirrors
  the app's `/tipitaka/<id>`.
- **Chapter (grouped)** → `/tipitaka/<vaggaKey>`; single view `…#<nodeKey>`.
- **Higher container** → `/tipitaka/<containerKey>` TOC (links only) — emitted
  as a **flat `<key>.html`, not `<key>/index.html`** (2026-07-23): the directory
  form gives containers a second URL shape (`…/kn-khp/` plus a 308 hop from
  `…/kn-khp`), breaking the uniform `/tipitaka/<nodeKey>` grammar the codec and
  deep links rely on. Flat files keep one URL per node for every node type.
- **Every sutta's text is in exactly one file.** Hosting split (static on the
  apex, app on `app.<domain>` — decided 2026-07-23) lives in
  `static-web-hosting.md` → "Project topology".

---

## 11. Build & verify

1. `dart run static_site_generator/bin/generate.dart --root kn-khp`
2. `dart run static_site_generator/bin/generate.dart --root kn-iti-1`
3. `dart run static_site_generator/bin/generate.dart --root an-1`  *(P5, grouping)*
4. Serve (`dart run dhttpd --path static_site_generator/build`) and open.
5. **Manual checks:** distinct pages render; range pages show all suttas with
   working anchors; 4 layouts toggle; footnotes link; navigator expands the right
   branch; **JS disabled** → still works; **webfont disabled** → system Sinhala
   readable; **Back/Forward between `#anchors`** → the `:has(:target)` filter
   re-evaluates across browsers (older engines had `:target` history quirks;
   degradation = whole chapter scrolled to the anchor, acceptable).
6. **SEO / no-dup checks:** `curl` → full text in source; distinct files + chapter
   files each have a unique `<title>` + self-canonical and appear in `sitemap.xml`;
   **grep a distinctive phrase → exactly one file** (no text in two files); the
   `#fragment` single-view filters with `:has()` and degrades to the full chapter
   without it.
7. **Re-sync check:** edit one entry in `an-1.json`, rebuild → only the affected
   output file(s) change in `git status`.

> Per project convention: no test suite is added unless asked. The marker parser
> (PREREQ-1) is logic the test-writer agent should later cover — a separate task.

---

## 12. Phasing (small, reviewable steps)

- **P0 — PREREQ-1** Extract `parseContentMarkers` into `wisdom_shared`; refactor
  `text_entry_widget.dart` to consume it (app behaviour unchanged).
- **P1 — PREREQ-2/3** Stand up `static_site_generator/`, share the tree decode,
  print `kn-khp`'s tree to prove Flutter-free reuse compiles.
- **P2** Content slicing (§6) + marker→HTML (`render/`) + the `source→[outputs]`
  manifest. Emit Pali-only **distinct** sutta pages for `kn-khp`.
- **P3** Add the 4-layout CSS shell (§7) + the Sinhala side. All 4 layouts.
- **P4** Static `<details>` navigator (§9) + container **TOC** pages + canonical
  tags + prev/next.
- **P5** Grouping: the distinct-vs-grouped classifier + `grouping.json` + chapter
  files + the CSS `:has()` single-view filter + `sitemap.xml`. Run against `an-1`
  (243 micro-suttas) → chapter files with working `#fragment` single-views (no
  per-sutta files). Threshold already locked (§13.1, 2026-07-22) — P5 just
  regenerates + commits `grouping.json` and reviews the grouped list.
  **Decision gate: ask the maintainer stub-files-vs-Bulk-Redirects *before*
  emitting the 1,593 grouped-leaf stubs** (§6 / §13.2 / hosting doc).
- **P6** Point at `kn-iti-1`; verify nesting + slicing across vaggas.
- *(Later, separate)* client-side / linked search — **server-rendered FTS is
  retired with the content server** (see `static-web-hosting.md`); scroll-spy;
  sitemap/robots/JSON-LD from `static-web-hosting.md`. The `?layout=` enhancement
  (§7-C) is **now the locked shareable-link contract**, not "later".

---

## 13. Open questions & deferred decisions

1. **Grouping model & threshold** *(model **LOCKED 2026-07-21**; threshold
   **LOCKED 2026-07-22** — nothing left to tune; kept for the record)*:

   **LOCKED: per-container *binary*, replacing §6's per-leaf "hoist"
   mechanism.** Decide grouping **per deepest container (vagga)**, not per sutta —
   a vagga is *either* fully **exploded** (every leaf → its own
   `/tipitaka/<nodeKey>` page) *or* fully **grouped** (whole vagga → one chapter
   file `/tipitaka/<vaggaKey>`, single-view via `#<nodeKey>`). **Never split a
   vagga.**
   - *Why not §6's "hoist the substantial siblings out":* on real data the big and
     micro suttas are **interleaved**, not separable — **119/184 AN** and
     **142/243 SN** vaggas are size-mixed, and only ~half have the micro ones
     contiguous (e.g. `an-4-2-3` = `..D..D.DDD`). Hoisting ⇒ mostly *partial*,
     often *non-contiguous* chapter files. Whole-or-nothing avoids that entirely.
   - *Why per-container is safe:* the BJT compilers already package the true
     formulaic runs as their own vaggas (`an-3-7 කම්මපථ පෙය්යාලං` = 20 uniform
     micro) or collapse them into one node (`an-3-8 රාග පෙය්යාලං` = 1 leaf).
     **"Short" ≠ "formulaic"**: a short *named* sutta (`පඨමඅග්ගසුත්තං`, 316c) is
     unique content, not duplicate → it gets its own page (as Mahamevnawa does),
     which the "SEO must never be compromised" rule also wants.
   - *URL consequence — resolves open-Q#3:* the range URL is **always a real tree
     key** (`sn-2-3-1`), never a synthesized `an-1-1-1--10`. (SuttaCentral must
     invent range keys — its data is flat segments; our tree already has the
     container node, so we don't.)
   - *Classifier (seeds `grouping.json`):* group a container iff it is a uniform
     micro run — heuristic: **≥ ~6 leaves AND max leaf < ~1500 combined chars**;
     else explode. **~49 "awkward" vaggas** (mostly-micro + one buried substantial
     sutta — `sn-1-1-2 නන්දනවග්ග` = 9 micro + one 12K sutta; `an-1-14 එතදග්ගපාළි`,
     the foremost-disciples list) are the **only** editorial calls → the committed
     `grouping.json` + a famous-sutta allowlist decide those by hand. (Threshold
     locked 2026-07-22 — see below; P5 regenerates + reviews.)
   - *Why the ≥ ~6-leaf gate (documented 2026-07-22):* "all tiny" alone ≠
     "formulaic run" — **length is the run's fingerprint** (87/145 real groups
     are exactly the classic vagga-of-ten; commentary echo-vaggas legitimately
     run 6–9, hence 6 rather than 10). Dropping the gate would group 138 more
     containers (260 suttas): **85 are single-leaf nodes where BJT already
     collapsed the run itself** (names ending "…සුත්තානි" — grouping adds
     nothing there), and the 2–5-leaf rest are mostly *named* short texts that
     deserve own pages. Win ≈ 260 saved files (~1.8%); cost = burying named
     texts + 260 stubs added back for the locked exact-sutta deep links → net
     ~zero, SEO strictly worse. The gate encodes the design's error-asymmetry:
     a wrong *explode* = a few harmless thin pages; a wrong *group* = a buried
     named text (unacceptable) — so grouping stays the rare, high-confidence
     verdict.
   - *Scale (full canon, exact 2026-07-22/23):* **14,763 real pages** (12,758
     sutta + 145 chapter + 1,859 container TOC + 1 root); **16,356** with the
     1,593 grouped-leaf stubs if stubs are picked at the P5 gate — inside
     Cloudflare Pages' 20,000-file free cap either way (see
     [`static-web-hosting.md`](./static-web-hosting.md)). The **SN 15 seed explodes cleanly**
     (both vaggas above threshold) → every SN 15 sutta keeps its own page + citation
     URL, which the RAG deep-links need.

   **Locked 2026-07-21:** per-container-binary adopted over hoist; §6 body updated
   to match. **Threshold locked 2026-07-22** after a full-corpus classifier run
   (≥ 6 leaves AND max < 1,500 **combined** chars): 145 grouped vaggas / 1,593
   grouped leaves / 12,758 exploded / **14,763 total files**; savings vs
   no-grouping = 1,448; AN 119/186 & SN 142/243 size-mixed confirmed on data;
   the "awkward" set is 85–164 depending on definition but needs **no** mandatory
   curation (default = explode). P5 keeps only: regenerate + commit
   `grouping.json` from the classifier and eyeball the grouped list (Jātaka
   verse-vaggas `kn-jat-*` are allowlist candidates — BJT's Jātaka pali is only
   the gāthās; the searched *stories* live in `atta-kn-jat-*`, which explodes;
   `kn-thag-*`/`kn-thig-*` likewise — each leaf is a *named elder's* verse).
   Exploded thin pages: 1,870 leaves < 800c (only 119 number-only-named) — the
   accepted "harmless thin pages" set; unique scripture, no noindex needed.
   DN/MN group **zero** vaggas — a good sanity signal.
2. **Shareable-link target — app vs web** *(RESOLVED 2026-07-06, C3)*: **both,
   per visitor** — the app side is being built now (see the locked
   `../todo/deep-linking-and-shareable-urls.md`): app installed + link tapped in
   another app → OS opens the app; otherwise the static page serves. The
   **URL is identical either way** (`/tipitaka/<nodeKey>`), as this plan required.
   *(Path segment renamed `/sutta/` → `/tipitaka/` 2026-07-06: commentary links
   made `/sutta/atta-…` self-contradictory; the umbrella noun follows
   tipitaka.lk / Access to Insight — see the app plan's Decisions table.)*
   **Still bundled here — narrowed 2026-07-22, mechanism re-opened 2026-07-23:**
   never Pages `_redirects` (caps at 2,000 static rules vs 1,593 grouped leaves,
   §6); the *form* is **stub HTML files** (meta-refresh-0 + `canonical` →
   chapter; out of sitemap.xml) **or Cloudflare Bulk Redirects** (real edge
   301s; `#fragment` allowed in targets; free quota 10,000 pending a dashboard
   check — hosting doc → "Grouped-leaf clean URLs"). The deadline is unchanged:
   the app's share button emits the **leaf** URL (`/tipitaka/an-2-64`) even for
   a grouped sutta, so once links go public a no-app recipient 404s without one
   of the two.
   **LOCKED 2026-07-22 (user): exact-sutta deep links are required even for
   grouped suttas. Mechanism = P5 decision gate — PROMPT the maintainer before
   generating the 1,593 stubs** (budget either way: 14,763 + 1,593 ≈ 16.4K
   < 20K with stubs, or 14,763 with redirects), paired with the codec fragment
   fix (deep-linking doc Notes) so *both* URL forms land on the exact sutta for
   *both* app and no-app recipients. The static page is always the guaranteed
   fallback. Page furniture for later: OG meta tags
   per sutta (share previews) + an optional dismissible "Open in app" banner
   (iOS Smart App Banner meta tag) — never a blocking interstitial.
3. **Range-page URL form** *(RESOLVED — see §13.1's "URL consequence")*: the
   **vagga key** (`/tipitaka/<vaggaKey>`), never a synthesized range notation.
4. **Slug in URL?** *(RESOLVED 2026-07-06)* — **bare nodeKey**, no slug:
   `/tipitaka/kn-khp-5`. Matches the app's locked choice
   (`../todo/deep-linking-and-shareable-urls.md`).
5. **Default layout per page** — Pali-only, or a heuristic? *Lean: Pali-only.*
6. **Entry alignment** *(RESOLVED 2026-07-22 — full-corpus scan, §7)*: all 1,660
   misaligned pages sit in the 7 `ap-pat*` files; everything else aligns
   perfectly. Pad + warn; ship `ap-pat*` last. No measurement phase needed.
7. **Container TOC depth** — direct children only, or whole subtree? *Lean: direct
   children + `<details>` for the rest.*
8. **Footnote abbreviations** — fold `assets/data/footnote-abbreviations.json`
   into footnote rendering now or later? *Lean: later.*
```
