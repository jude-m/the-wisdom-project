# Static HTML Prototype Plan — per-sutta SEO, Tree Navigator, 4 Layouts (no JS framework)

> Status: **Plan / not started.** Captured 2026-06-12 (revised same day after
> field research into tipitaka.lk, buddhadust, and SuttaCentral).
> Scope: an honest static-HTML prototype of the Tipitaka content surface from
> [`web-rewrite-strategy.md`](./web-rewrite-strategy.md) (Option A′). Proves, on
> one small subtree: static page generation + a zero-JS tree navigator + **all 4
> reading layouts** + the **per-sutta-page / formulaic-range grouping model**.
> Search is **out of scope** for this prototype (server-rendered FTS comes later).

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

No app shell, no flashy interactivity. If this prototype is clean, it scales to
the whole canon unchanged.

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

## 5. Prototype scope — pick a small subtree

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

> **Current direction** (the SuttaCentral model). The *threshold value* and the
> *famous-sutta allowlist* are to be tuned on real data, and the **shareable-link
> target (app vs web) is deferred** — see §13. Everything else here is settled.

We considered three uniform rules and rejected both extremes:

| Model | Famous suttas (Mettā, mn10…) | Micro-suttas (AN1) | Re-sync | Verdict |
|---|---|---|---|---|
| **Per content-file (1:1)** | ❌ buried (kn-khp hides Maṅgala+Ratana+Mettā on one page) | ✅ fine | ✅ simplest | loses name-search SEO (fails C2) |
| **Per vagga (uniform)** | ❌ buried (mn10 inside a vagga page) | ✅ ideal | ✅ deterministic | still fails C2 for DN/MN |
| **Hybrid (chosen)** | ✅ own page → **ranks** | ✅ ranged | ✅ via manifest | wins both — the SuttaCentral model |

### The rules — a sutta's text lives in exactly one file
Inspection corrects the model: `/an2.64` is **not** a second file — watch it load
and the **whole chapter (`an2.64-76`) flashes first, then the SPA filters to one
sutta**. SuttaCentral has **one data unit (the range)** and renders two routes
from it with JavaScript. We get the single-sutta view **without duplicating text
and without a SPA**:

1. **Distinct / substantial sutta → its own file** `/sutta/<nodeKey>`: full text,
   `<title>` = sutta name, canonical self → full per-sutta SEO (C2), shareable
   (C3), single view (C4); mirrors the app's `/sutta/<id>`. Its container is a
   **TOC** (links only); continuous reading via prev/next.
2. **Micro / grouped sutta → lives *only* in its chapter file** `/sutta/<vaggaKey>`:
   one page holding the whole run, each sutta `<section class="sutta" id="<nodeKey>">`.
   The navigator's deepest link, the continuous-reading surface (C7), and the SEO
   unit for the run.
3. **Single view of a micro-sutta = a URL filter on that chapter file** (next
   subsection) — no second file.
4. **Higher containers** → TOC pages (links only, no full text).

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
- `/sutta/an-2-64-76`          → whole chapter (continuous reading).
- `/sutta/an-2-64-76#an-2-64`  → just AN 2.64 (single view) — shareable (C3/C4).
- In single view, render a "↩ whole chapter" link (drops `#`) + prev/next (swap
  `#`) — plain anchors, no script.
- **Graceful degradation:** browsers without `:has()` (pre-2023) show the whole
  chapter scrolled to the anchor — still correct, just unfiltered.
- This filter is **only for grouped suttas**; distinct suttas are already their own
  file.

**App-parity URL (optional, deferred).** The app uses `/sutta/<id>` for *every*
sutta. A grouped sutta's clean `/sutta/<nodeKey>` can resolve via a **content-free
redirect** (an empty stub file, or a host rewrite) → `…/<vaggaKey>#<nodeKey>`. No
text, so no duplication. Exact form rides with the app-vs-web decision (§13).

**SEO consequence (honest, your trade).** A micro-sutta's text is in the chapter
file only, so the **chapter is its SEO unit** — searching "AN 2.64" lands on the
chapter (the text + heading are there; Google may offer a jump-to anchor). Grouped
suttas get **no separately-ranked clean URL** — that needs the text in a second
file, which you've ruled out. The cost is ~nil: grouped suttas are exactly the ones
nobody searches by individual name. **Distinct / famous suttas keep full per-sutta
SEO** via their own files (the `/an2.64`-style #1 result lands on those).

### Classifying distinct (own file) vs grouped (chapter file)
- Substantial suttas (≥ size threshold) → **distinct** (own file). Runs of
  consecutive small siblings → **grouped** into one chapter file. (kn-khp: ~600–800
  chars separates substantial from trivial; tune on AN1/AN2 in P5.)
- A small **allowlist** can force a famous-but-short sutta to be distinct.
- **Persist to committed `grouping.json`** (curated, stable → no URL drift); a text
  correction never re-buckets. Re-grouping is an explicit edit.

### Re-sync — the `source → [outputs]` manifest (satisfies C1)
- The generator records, per source `assets/text/<fileId>.json`, the **list** of
  HTML files it produces (distinct sutta pages + range pages + the TOC fragments
  it feeds) plus a content hash.
- A correction to `an-1.json` → hash changes → regenerate **exactly that file's
  output list**. Deterministic + idempotent ⇒ the git diff shows only the suttas
  whose rendered HTML actually changed.
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
5. Collect footnotes referenced by `{n}` in the slice → render at the page bottom.

> **Why not per printed page?** `pageNum`/`pageOffset` are print provenance,
> useful as in-page anchors (`<span id="pg-4">` for citations) but wrong as the
> web unit. The *document* is the sutta (or the formulaic run), never the book page.

---

## 7. The 4 layouts in HTML — CSS-only (hard requirement C5)

Both `pali` and `sinh` are in the JSON, so each page renders **both** and toggles
with **zero JavaScript** via the radio-button `:checked` sibling trick.

### Markup (per sutta `<section>`, or per content page)
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
| **A. Default + radios only** | no URL state | ✅ prototype default; zero JS |
| **B. `:target` via hash** | CSS `:target` | ⚠️ steals the fragment from sutta anchors; skip |
| **C. ~8-line enhancement script** | read `?layout=`, check the radio once | ✅ later; page works 100% without it |

> **Risk — entry alignment.** Side-by-side/stacked pair `pali[i]` with `sinh[i]`.
> Unequal counts (localized headings; some nodes lack Sinhala — cf. the `ap-pat`
> TODO in `TipitakaTreeNode`) make naive pairing drift, and this bites hardest on
> the heaviest commentary pages. Prototype mitigation: pad the short side with
> empty cells and **log a warning** so we measure how often it happens.

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

## 9. The static tree navigator (zero JS)

- Native `<details>`/`<summary>`, one `<details>` per container, `<a>` per leaf —
  same `tree.json` the app's `navigation_tree_provider` consumes.
- Rendered into **each** page (shared partial) so it's present without JS and is
  itself crawlable. Current branch + ancestors `open`; siblings closed.
- Names via `getDisplayName(ContentLanguage)` (Pali in Sinhala script by default),
  reusing the entity's fallback rule.

```html
<nav class="tree">
  <details open><summary>ඉතිවුත්තකපාළි</summary>
    <details open><summary>එකකනිපාතො</summary>
      <details><summary>පඨමො වග්ගො</summary>
        <a href="/sutta/kn-iti-1-1-1">ලොභසුත්තං</a> …
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
  sutta/
    kn-khp/index.html                # TOC (children distinct → links only)
    kn-khp-5.html  kn-khp-9.html …   # DISTINCT sutta files (text lives ONLY here)
    an-2-64-76.html                  # CHAPTER file (grouped run; text lives ONLY here)
    an-2-64.html        (optional)   # content-free REDIRECT → an-2-64-76#an-2-64
    …
  sitemap.xml                        # distinct files + chapter files (not redirect stubs)
  assets/site.css                    # one small stylesheet (layouts + tree + type)
  fonts/…                            # Noto Sinhala, font-display: swap (progressive)
  grouping.json  (source, not output)
  .manifest.json (source→[outputs] + hashes, for incremental builds)
```
- **Distinct sutta** → `/sutta/<nodeKey>` (own file, full per-sutta SEO); mirrors
  the app's `/sutta/<id>`.
- **Chapter (grouped)** → `/sutta/<vaggaKey>`; single view `…#<nodeKey>`.
- **Higher container** → `/sutta/<containerKey>/` TOC (links only).
- **Every sutta's text is in exactly one file.** Hosting split (static `/`, app
  `/app/`) lives in `web-rewrite-strategy.md`.

---

## 11. Build & verify

1. `dart run static_site_generator/bin/generate.dart --root kn-khp`
2. `dart run static_site_generator/bin/generate.dart --root kn-iti-1`
3. `dart run static_site_generator/bin/generate.dart --root an-1`  *(P5, grouping)*
4. Serve (`dart run dhttpd --path static_site_generator/build`) and open.
5. **Manual checks:** distinct pages render; range pages show all suttas with
   working anchors; 4 layouts toggle; footnotes link; navigator expands the right
   branch; **JS disabled** → still works; **webfont disabled** → system Sinhala
   readable.
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
  per-sutta files). Tune the size / run threshold.
- **P6** Point at `kn-iti-1`; verify nesting + slicing across vaggas.
- *(Later, separate)* server-rendered FTS search; `?layout=` enhancement (§7-C);
  scroll-spy; sitemap/robots/JSON-LD from `web-rewrite-strategy.md`.

---

## 13. Open questions & deferred decisions

1. **Final grouping lock** *(kept open on purpose)*: the **size / run-length
   threshold** separating *distinct* (own file) from *grouped* (chapter file).
   Tune on real AN1/AN2/SN data in P5 before committing `grouping.json`.
2. **Shareable-link target — app vs web** *(deferred, C3)*: does a `/sutta/<id>`
   link open the app (Universal/App Links intercept) or serve the web page? The
   **URL is identical either way**, so deciding later changes nothing structural.
   **Bundled here:** the *form* of a grouped sutta's clean `/sutta/<nodeKey>` —
   content-free redirect stub vs host rewrite → `<vaggaKey>#<nodeKey>`. The static
   page is always the guaranteed fallback.
3. **Range-page URL form**: `/sutta/<vaggaKey>` vs a SuttaCentral-style range
   notation `/sutta/an-1-1-1--10`. *Lean: the vagga key — already in our tree.*
4. **Slug in URL?** `/sutta/kn-khp-5` vs `/sutta/kn-khp-5-mangala`. Must match the
   app's choice (`../todo/deep-linking-and-shareable-urls.md` Q1). *Lean: bare key
   for the prototype.*
5. **Default layout per page** — Pali-only, or a heuristic? *Lean: Pali-only.*
6. **Entry alignment** — how common are unequal pali/sinh counts? Measure via the
   P3 warning log before designing real alignment.
7. **Container TOC depth** — direct children only, or whole subtree? *Lean: direct
   children + `<details>` for the rest.*
8. **Footnote abbreviations** — fold `assets/data/footnote-abbreviations.json`
   into footnote rendering now or later? *Lean: later.*
```
