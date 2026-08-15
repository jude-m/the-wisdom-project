# Static HTML Site — Build Plan (per-sutta SEO, 4 Layouts, no JS framework)

> Status: **Plan / not started — the real build spec, not a throwaway prototype.**
> Captured 2026-06-12 (revised after field research into tipitaka.lk, buddhadust,
> and SuttaCentral; grouping model refined 2026-07-20).
> Scope: the honest static-HTML surface of the Tipitaka content from
> [`static-web-hosting.md`](./static-web-hosting.md) (Option A′) — **built
> incrementally, smallest subtree first** (§5). Covers static page generation +
> zero-JS navigation + **all 4 reading layouts** + the **per-sutta-page /
> formulaic-range grouping model**. Search is **out of scope here** (deferred —
> it landed as the build plan's P4 after §9's tree navigator was withdrawn).

---

## 1. Goal

Turn the existing content assets into a pile of honest, crawlable, framework-free
HTML pages that:

1. **Generate statically** (SSG) from the same assets the app already ships.
2. Give **every distinct sutta its own indexable page** (SuttaCentral-grade
   name-search SEO), while **grouping only the formulaic micro-sutta runs**.
3. Carry **zero-JavaScript navigation** — breadcrumb, container TOC, prev/next.
   *(Was "a static `<details>` tree navigator"; built, measured and withdrawn
   2026-08-03 — see §9.)*
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
| **C8** | **No JS framework, no flashy stuff.** Breadcrumb/TOC navigation now, a search dialog as the one progressive enhancement. Zero-JS baseline — every page fully usable with JS off. | Slowest connections, all bots/LLMs, low maintenance. |
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
> **Threshold LOCKED 2026-07-22 (full-corpus classifier run); counts restated
> 2026-07-28 under the corrected §6-step-3 slice:** group iff
> **≥ 6 leaves AND max leaf < 1,500 *combined* (pali+sinh) chars** → **146 vaggas /
> 1,603 leaves** group; **12,748** suttas explode; site = **14,753 files**
> (+1,603 stubs = **16,356**, unchanged — the two deltas cancel). The threshold
> itself did not move; the slice it measures was corrected. Reproduce with
> `dart run static_site_generator/tool/classify_corpus.dart`. Nothing
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
   The deepest page the site emits, the continuous-reading surface (C7), and the
   SEO unit for the run.
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
(static-rule cap 2,000, verified 2026-07-22, vs 1,603 grouped leaves — too
tight). Two viable mechanisms — **the pick is a P5 decision gate: ask the
maintainer before generating stubs**:
- **Stub HTML files** (meta-refresh-0 + canonical → chapter): in-repo, portable,
  work on `*.pages.dev` previews; +1,603 files (14,753 + 1,603 = 16,356 < 20K).
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
3. Each node owns entries from **its start** up to **the start of the next node
   of *any* kind** — containers are boundaries exactly like leaves. Pair
   `pali[i]` ↔ `sinh[i]` by index for the dual layouts (alignment risk — see §7).
   > ⚠️ **Corrected 2026-07-28. This said "the next *readable* node's start",
   > which is wrong** and was measured to be wrong: the two rules disagree for
   > **1,418 of the 14,351 leaves**, and the worst (`atta-kn-nett-3-3`) would
   > append **204,809 characters** of the *following* container's preamble to a
   > sutta and print it under that sutta's title. Containers usually sit right
   > on top of their first child, which is why the wrong rule looks equivalent.
   > Build-plan §5.1 always stated the correct one; the two docs disagreed.
4. For a **range page**, concatenate the slices of every sutta in the run, each in
   its own `<section id="<nodeKey>">`.
5. Collect footnotes referenced by `{n}` in the slice. **Numbering restarts on
   every printed page** (verified corpus-wide 2026-07-22), so a multi-page slice
   holds two *different* `{1}`s: anchor ids must carry the printed page
   (`#fn-p4-1`); displayed numbers stay as printed. In **chapter files**, render
   each sutta's footnotes *inside its own `<section>`* — else the
   `:has(:target)` single view shows one sutta with every other sutta's notes.
6. **Preamble rule (verified 2026-07-22: 258/285 files):** entries before a
   container's first child (pitaka/nikāya headings, *namo tassa*, vagga
   heading) belong to **the container** — rendered on its TOC page (exploded
   vagga) or at the top of the chapter file (grouped vagga), never in a leaf
   file (preserves the no-duplication rule).
   > This is not a separate rule — it **falls out of step 3**. A container's
   > slice *is* its preamble, because the next boundary after a container is
   > its first child. Every row lands in exactly one slice, so nothing is
   > dropped and nothing is rendered twice. Verified on `an-1`: 581 source
   > entries → 581 rendered elements across its 110 pages.
   > Preambles are **not** only at the head of a file: they appear at every
   > container boundary, which is precisely what the old "next readable node"
   > rule got wrong — it handed them to the *preceding* leaf.

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

### Parallel text — canon ↔ commentary cross-link (added 2026-07-25)

Mirrors the app's `parallelTextNodeProvider` (canon ↔ `atta-<nodeKey>`). Build-time
rule: emit the link **iff the twin key exists in `tree.json`** — prepend `atta-` on a
canon page, strip it on a commentary page. Pure key test, no new files, no JS.

```html
<a href="/tipitaka/atta-mn-2-3-6" target="_blank" rel="noopener">අට්ඨකථා</a>
```

- **`target="_blank"` (maintainer, 2026-07-25)** — new browser tab, matching the
  app's new-tab behaviour. Reciprocal link on the commentary side (මූල පාඨය).
- **Coverage (measured 2026-07-25):** 4,627 / 8,355 canon leaves have an exact twin
  (DN 34/34, MN 152/152, SN 984/2,190, AN 949/1,849, KN 1,768/2,573, VP 355/641,
  AP 385/916) + 920 / 1,059 canon containers. No twin → no link, never a 404.
- Bonus: a strong internal-link signal between the two halves of the corpus.

---

## 8. Clean-architecture prerequisites (do these to avoid hacks)

The biggest "don't fork logic later" item: the marker→display logic lives in a
Flutter widget. Fix the seam first.

### PREREQ-1 — Pure-Dart marker parser into `wisdom_shared`
- **Today:** `**…**`/`__…__`/`{n}` handling lives in
  `lib/domain/entities/content/entry.dart` — `plainText`, `markedRanges` and
  `_computeMarkedRanges()`, cached through an `Expando`.
  `text_entry_widget.dart` only *consumes* `markedRanges` (with a
  `TapGestureRecognizer`); it computes nothing.
  > **Corrected 2026-07-27.** This section previously named
  > `text_entry_widget.dart` as the site of the logic. It isn't, and the shape
  > differs too: the existing model is **bold ranges over plainText**, not the
  > typed segment list below. `__underline__` is currently **stripped and
  > discarded** ("underline — stripped, not rendered"), and `{footnote}` bodies
  > are skipped entirely — so the extraction is a *widening*, not a move.
  > **Underline is not a rounding error:** `__` appears **536 times across 74 of
  > the 285 files** (≈268 spans). It is absent from the first slice (`an-1`,
  > `kn-khp`, `mn-1` all have 0; `atta-an-1` has 2), so P1 is unaffected — but
  > every one of those spans is silently dropped today, in the app as well as
  > the future site. Decide render-vs-drop before P6 goes corpus-wide.
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
- New top-level `static_site_generator/` (repo root, beside `server/`), plain Dart
  console app. **No `flutter` dependency** — only `wisdom_shared` + `dart:io`.
  Compiling without Flutter is the proof that no UI logic leaked in.
- Reads `../assets/...` at build time; writes HTML to `static_site_generator/build/`.
- **Toolchain boundary (D9, build plan §3 — 2026-07-27):** Dart owns all corpus
  logic — `wisdom_shared` runs the *same* marker parser and tree decode in the
  generator and the app. A Node generator would fork both in TS and drift. Node
  and Python are allowed only as **post-processing over finished bytes**
  (`pyftsubset`, `wrangler`, link/HTML checkers, optional minify).

### PREREQ-4 — Clean layering inside the generator
```
static_site_generator/
  bin/generate.dart      # entrypoint: args (root key), orchestrate
  lib/
    domain/              # pure models: SiteNode, SuttaDoc, ContentSegment*
    data/                # asset readers: tree.json, file-map.json, text/<id>.json
    grouping/            # distinct-vs-formulaic classifier + grouping.json I/O
    render/              # pure string→HTML: page template, chrome, entry
    manifest/            # source→[outputs] + content hashes (incremental builds)
    sitegen.dart         # use-case: classify → slice → render → write
  grouping.json          # committed, curated grouping data (analogue of child_range.json)
  build/                 # OUTPUT (gitignored)
```
- `render/` is pure (domain → `String`), unit-testable. `data/` is the only layer
  touching the filesystem. `ContentSegment` is **imported from `wisdom_shared`**.

---

## 9. ~~The tree navigator (pruned static core + one shared full tree)~~

> ## ⛔ SUPERSEDED 2026-08-03 (P3.5) — there is no tree navigator.
>
> Layer 1 was built and shipped to all 14,752 pages, then measured and withdrawn:
> 42 of its ~69 rows were identical on every page, the rest duplicated the
> breadcrumb, it cost 26% of the build's bytes, and its disclosure toggle was a
> 12×28 px target that fails WCAG 2.2 SC 2.5.8 (AA). Full findings in the build
> plan's **P3 revision note**.
>
> Navigation is now breadcrumb (up) + container TOC (down) + prev/next (along) +
> aṭṭhakathā (across), with a **search dialog** as the jump-to-anything answer
> (build plan **P4**).
>
> **Layer 2 died on its own sizing.** The one number worth keeping from the
> original section: a shared `/nav.html` holding the full tree would have been
> ~2 MB raw / 200–400 KB gzipped to fetch. The search index built in its place
> measures **247 KB gzipped / 175 KB brotli** on the real corpus, and answers
> "take me to X" directly instead of making the reader climb to it. Layer 2 was
> strictly the worse buy, so the phase that would have built it became the
> search phase instead.

---

## 10. Output & URLs

```
build/
  index.html                         # `/` — TOC of the roots this build wrote
  tipitaka/
    kn-khp.html                      # container TOC — FLAT file like every node
    kn-khp-5.html  kn-khp-9.html …   # DISTINCT sutta files (text lives ONLY here)
    an-2-64-76.html                  # CHAPTER file (grouped run; text lives ONLY here)
    an-2-64.html  (if stubs picked)  # content-free REDIRECT → an-2-64-76#an-2-64
    …
  sitemap.xml                        # distinct files + chapter files (not redirect stubs)
  assets/site.css                    # one small stylesheet (layouts + chrome + type)
  fonts/…                            # Noto Sinhala WOFF2, font-display: swap — COPIED, not built
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
- **`fonts/` is a build *input*, not output** (2026-07-27). `subset_fonts.sh`
  runs by hand (subsets to TTF, then `fonttools ttLib.woff2 compress`), output
  is committed, generator copies bytes — same pattern as `theme_tokens.json`.
  Only the faces the stylesheet declares are copied, off one shared list.

### Commentary titles & canonical (decided 2026-07-25)

The 6,731 `atta-*` pages carry the **same sutta names** as their canon twins —
untreated they compete for the same name searches.

- **Distinct `<title>` / OG title:** canon = `<sutta> — <vagga> — <collection>`;
  commentary = `<sutta> අට්ඨකථා — <vagga> — <collection>`.
  > **`<h1>` split off from `<title>`, 2026-07-30.** The heading carries the
  > node's own name **plus the commentary marker** — `චිත්තපරියාදානවග්ගො
  > අට්ඨකථා` — and *not* the vagga/collection parts. The marker is the half
  > that matters here: without it a commentary page and its canon twin print
  > the identical heading. The other two parts exist to disambiguate a title
  > seen alone in a results list; on the page itself the breadcrumb sits
  > directly above the heading and already says them, so repeating them reads
  > as a stutter. 57 nodes (`atta-vp` "විනය අට්ඨකථා", `atta-dn` …) are named
  > with the marker already and are left alone — the test is `endsWith`, since
  > `atta-ap-dhs-5` "අට්ඨකථාකණ්ඩො" merely contains the word.
  > **Vagga part added 2026-07-28, measured.** `<sutta> — <collection>` alone
  > leaves **2,216 leaves sharing a `<title>` with another leaf** (worst: 16 ×
  > "අට්ඨමසික්ඛාපදං — පාචිත්තියපාළි"), which is the duplicate-content signal C2
  > exists to avoid; the vagga cuts it to 377. It also carries the pages whose
  > own name is only a number — **1,165 leaves corpus-wide, and 243 of 243 in
  > `an-1`** ("1. 16. 8. 9-24"), in *both* languages. Repeated parts are
  > dropped, so a node directly under its collection never says it twice.
  > `<collection>` = the highest ancestor below the root-level pitaka node —
  > `an`, `kn`, `vp-pct` — which is the level BJT titles its volumes at.
- **Canonical is always self.** The two are different texts, not duplicates —
  never point an `atta-*` page at its canon twin.
- **No `noindex`.** Commentary is unique scripture (57 M of the corpus's ~103 M
  chars) and is searched in its own right; the title split + the reciprocal
  cross-link (§7) are enough to keep the canon page the stronger hit for a bare
  sutta-name query.

---

## 11. Build & verify

1. `dart run static_site_generator/bin/generate.dart --root kn-khp`
2. `dart run static_site_generator/bin/generate.dart --root kn-iti-1`
3. `dart run static_site_generator/bin/generate.dart --root an-1`  *(P5, grouping)*
4. Serve (`dart run dhttpd --path static_site_generator/build`) and open.
5. **Manual checks:** distinct pages render; range pages show all suttas with
   working anchors; 4 layouts toggle; footnotes link; breadcrumb climbs and the
   container TOC lists the right children; toolbar home reaches `/` from any page
   shape; **JS disabled** → still works; **webfont disabled** → system Sinhala
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
8. **Determinism check (REQUIRED — added 2026-07-25):** rebuild with **no** input
   change → **zero** files differ (`git status` clean). Cloudflare's upload dedup
   is purely **content-hash** based: it skips any file whose hash it already has
   ([direct-upload docs](https://developers.cloudflare.com/workers/static-assets/direct-upload/)),
   so a build timestamp, a random build id, or unstable map/set ordering in the
   HTML makes all 16,356 hashes change and **re-uploads the whole site every
   deploy**. Byte-identical output when the input is unchanged is a hard
   requirement, not a nicety. *(Distinct from the `.manifest.json` in §10 — that
   decides what to **regenerate**; this is what gets **uploaded**.)*
9. **Link + markup check (full-corpus phase):** link checker + HTML validator over
   `build/`. Node CLIs are fine here — finished output is the seam PREREQ-3 allows.
10. **Minify only if measured.** CF brotlis at the edge, so pre-minifying saves
    single digits. If added: run **after** manifest hashing, and step 8 must still
    come back empty. **Default: don't.**

> Per project convention: no test suite is added unless asked. The marker parser
> (PREREQ-1) is logic the test-writer agent should later cover — a separate task.

---

## 12. Phasing (small, reviewable steps)

> ⚠️ **SUPERSEDED 2026-07-27 by [`static-html-site-build-plan.md`](static-html-site-build-plan.md).**
> The first slice moved from `kn-khp` to **`an-1`**, which is size-mixed
> (12 grouped / 11 exploded containers) — so the grouping classifier can no
> longer wait until P5 and moves into the first content phase. That reordering
> cascades through everything below. The build plan carries an old→new mapping
> table so no phase is lost.
>
> **The rest of this document is current** — the grouping model, thresholds, URL
> grammar and constraints C1–C10 all still govern. Only this section is stale.

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
  emitting the 1,603 grouped-leaf stubs** (§6 / §13.2 / hosting doc).
- **P6** Point at `kn-iti-1`; verify nesting + slicing across vaggas.
- **Client-side search — built 2026-08-14** (build plan P4), a names-only index
  fetched on first dialog open. Server-rendered FTS stays retired with the
  content server (see `static-web-hosting.md`). The `?layout=` enhancement
  (§7-C) shipped with it and is **the locked shareable-link contract**, not
  "later".
- *(Later, separate)* scroll-spy; sitemap/robots/JSON-LD from
  `static-web-hosting.md`.

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
   - *Scale (full canon, exact 2026-07-22/23):* **14,753 real pages** (12,748
     sutta + 146 chapter + 1,858 container TOC + 1 root); **16,356** with the
     1,603 grouped-leaf stubs if stubs are picked at the P5 gate — inside
     Cloudflare Pages' 20,000-file free cap either way (see
     [`static-web-hosting.md`](./static-web-hosting.md)). The **SN 15 seed explodes cleanly**
     (both vaggas above threshold) → every SN 15 sutta keeps its own page + citation
     URL, which the RAG deep-links need.

   **Locked 2026-07-21:** per-container-binary adopted over hoist; §6 body updated
   to match. **Threshold locked 2026-07-22** after a full-corpus classifier run
   (≥ 6 leaves AND max < 1,500 **combined** chars): 146 grouped vaggas / 1,603
   grouped leaves / 12,748 exploded / **14,753 total files**; savings vs
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

   **Re-examined & rejected again 2026-07-25 — "group *everything*, use `#`
   fragments throughout"** (measured, not estimated):

   | | Current | Group everything |
   |---|---|---|
   | Files | 14,753 (+1,603 stubs) | **2,005** |
   | Median page | 2,501 chars | 24,070 |
   | p90 / p99 | 16,647 / — | 150,287 / 550,111 |
   | Max page | 455,233 (`vp-mv-1`) | **1,766,812** (`vp-mv`) |
   | Pages > 400 K chars | ~1 | 25 |

   Rejected on three counts: (a) **Google does not index `#fragments` as pages** —
   12,748 rankable sutta URLs collapse to 2,005, and "සාමඤ්ඤඵල සුත්ත" would have to
   rank a 1.2 M-char `dn-1` titled with the *vagga* name → kills C2, the site's
   whole purpose; (b) **page weight** — `dn-1` ≈ 2–3 MB HTML against the "instant
   ~20 KB page" goal, and `:has(:target)` hides siblings only *after* transfer, so
   a single micro-sutta still costs the full download; (c) **redirects get ~9×
   worse** — all 14,351 leaf URLs would need `<container>#<leaf>` redirects, over
   the Bulk Redirects free quota (10 K) and far over `_redirects` (2 K), vs 1,603
   today. Underlying point: **the file cap was never the constraint** — 16,356 /
   20,000 with a corpus that never grows, and deploys are hash-incremental (§11.8),
   so shrinking the file count buys nothing worth C2.
2. **Shareable-link target — app vs web** *(RESOLVED 2026-07-06, C3)*: **both,
   per visitor** — the app side is being built now (see the locked
   `../todo/deep-linking-and-shareable-urls.md`): app installed + link tapped in
   another app → OS opens the app; otherwise the static page serves. The
   **URL is identical either way** (`/tipitaka/<nodeKey>`), as this plan required.
   *(Path segment renamed `/sutta/` → `/tipitaka/` 2026-07-06: commentary links
   made `/sutta/atta-…` self-contradictory; the umbrella noun follows
   tipitaka.lk / Access to Insight — see the app plan's Decisions table.)*
   **Still bundled here — narrowed 2026-07-22, mechanism re-opened 2026-07-23:**
   never Pages `_redirects` (caps at 2,000 static rules vs 1,603 grouped leaves,
   §6); the *form* is **stub HTML files** (meta-refresh-0 + `canonical` →
   chapter; out of sitemap.xml) **or Cloudflare Bulk Redirects** (real edge
   301s; `#fragment` allowed in targets; free quota 10,000 pending a dashboard
   check — hosting doc → "Grouped-leaf clean URLs"). The deadline is unchanged:
   the app's share button emits the **leaf** URL (`/tipitaka/an-2-64`) even for
   a grouped sutta, so once links go public a no-app recipient 404s without one
   of the two.
   **LOCKED 2026-07-22 (user): exact-sutta deep links are required even for
   grouped suttas. Mechanism = P5 decision gate — PROMPT the maintainer before
   generating the 1,603 stubs** (budget either way: 14,753 + 1,603 = 16,356
   < 20K with stubs, or 14,753 with redirects), paired with the codec fragment
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
