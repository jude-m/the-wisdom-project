# Static HTML Site — Build Plan

**Status:** active · **Created:** 2026-07-27 · **First slice:** `an-1`

This is the *execution* plan. The **model** (grouping, URL grammar, thresholds)
stays locked in `static-html-site-plan.md`; hosting stays in
`static-web-hosting.md`; link contracts stay in `deep-linking-and-shareable-urls.md`.

> **Supersedes §12 (Phasing) of `static-html-site-plan.md`.** Nothing else in that
> doc changes. Mapping table in §6 below — every old phase is accounted for.

---

## 1. Why the phasing changed

§12 started at `kn-khp` (9 distinct suttas) and deferred grouping to P5.

The chosen first slice is **`an-1`**, which is *size-mixed*: 268 nodes, 243 leaves,
23 deepest containers splitting **12 grouped / 11 exploded**, all in **one**
content file (`assets/text/an-1.json`).

That is the point of picking it — it exercises both page types from day one — but
it means **the grouping classifier can no longer be deferred to P5**. It moves
into the first content phase. That single change drives the reordering.

---

## 2. Decisions locked this session

| # | Decision | Note |
|---|---|---|
| D1 | **Bake app conjunct defaults** into the HTML — `standardLigatures` + `touching` ON | Same as tipitaka.lk (`src/text-convert.mjs`), which is indexed with ZWJ baked in |
| D2 | **Un-welded `<title>` / `<h1>` / OG / JSON-LD** — strip the touching ZWJ | Follows tipitaka.lk `src/views/Home.vue:118`; keeps the searched form clean |
| D3 | **Footnotes deferred** to the last phase | Frame 02's `<sup>1</sup>` is omitted until then |
| D4 | **Sinhala-only titles.** No romanized Pali yet | Tree has **0 Latin chars** in all 16,355 nodes — the data does not exist |
| D5 | Grouped chapters live at the **vagga's real nodeKey** | Frame 04's `an-2-64-76` is not in the tree; nodeKey form needs no codec change |
| D6 | **Theme identical to the app. Light only**, structured so dark slots in | Tokens are *generated* from the app theme, not hand-copied — see §3 |
| D7 | **Self-host WOFF2 fonts** | Not optional — see §3 |
| D8 | Every page names its **source JSON + entry slice** | See §4 |
| D9 | **Generator stays Dart.** Node / Python enter only as post-build steps over finished bytes | Rewriting in JS would fork the marker parser and tree decode — see §3 |

### D4 — the romanization seam

Titles render Sinhala-only, because `assets/data/tree.json` carries no Latin
text for any of its 16,355 nodes.

> **Corrected 2026-07-30.** This section used to show a
> `String? romanizedTitle(String nodeKey) => null;` stub and claim "the
> generator still routes every title through" it. **It never did, and the stub
> was never written.** A seam with one implementation, no caller and no data
> behind it is not a head start — it is a function that has to be re-read and
> re-decided by whoever picks this up. The single note at
> `render/page_template.dart` (above `_titleHtml`) carries the same information
> without pretending the plumbing exists.

When it lands, the title helpers in `render/page_template.dart` are the one
place to change: emit `data-roman` on the title element and feed
`<meta name="dc.alternative">`. Pali in Sinhala script is phonemically 1:1 with
IAST, so the mapping is mechanical — the blocker is deciding where the data
comes from, not how to transliterate. **SEO cost of waiting is real** —
"Mangala Sutta" is the string an English speaker types — so this should not sit
forever.

---

## 3. Theme & fonts

### Fonts are a correctness requirement, not polish

Browsers ship **no fonts**; they use the OS. For Sinhala:

| Platform | Ships | Noto? |
|---|---|---|
| Android | Noto Sans Sinhala | ✅ |
| Windows | Nirmala UI / Iskoola Pota | ❌ |
| macOS · iOS | Sinhala Sangam MN | ❌ |
| Linux | varies, often none | ❌ |

Three of four platforms would render in a **different face than the app**. That
breaks more than looks: the conjunct system is glyph-coverage-specific to Noto —
the ඤ්ජ / ඤ්ඡ / ණ්ඩ gaps were HarfBuzz-verified *against the bundled Noto faces*.
Baked ZWJ landing in Nirmala UI is unverified behaviour.

**Self-host WOFF2 subsets** of the four families already in `assets/fonts/`
(`noto-sans`, `noto-sans-sinhala`, `noto-serif`, `noto-serif-sinhala`), reusing
the existing `assets/fonts/subset_fonts.sh`.

### Tokens are generated, never hand-copied

`app_colors.dart` and `text_entry_theme.dart` both `import
package:flutter/material.dart`, so the Flutter-free generator cannot read them.
Hand-porting across that boundary is a silent-drift generator across 16,356 pages.

Instead — `tools/dump_theme_tokens.dart` (Flutter side) emits a committed
`static_site_generator/assets/theme_tokens.json`; the generator reads that. Drift
becomes impossible by construction rather than by discipline.

Dark theme: tokens are authored as custom properties on `:root`, so
`@media (prefers-color-scheme: dark)` + `:root[data-theme="dark"]` blocks drop in
later with no restructuring. Only light values are populated now.

### The Node / Python seam — shell out, never rewrite (D9)

Node has better *peripheral* tooling. It still can't own the generator: the
corpus logic (`_scan`, `tipitaka_tree.dart`) is shared **in-process** with the
app via `wisdom_shared`. A TS generator forks both, and forks drift — meaning the
site would render bold/footnotes/sibling-order differently from the app. Tools
are fine as **post-processing over finished bytes**:

| Want | Tool | Verdict |
|---|---|---|
| WOFF2 subsets | `pyftsubset` (Python) | **Required** (D7) — already `assets/fonts/subset_fonts.sh` |
| Deploy | `wrangler` (Node) | Already in the deploy path |
| Link check · HTML validate | Node CLIs over `build/` | P6 |
| HTML/CSS minify | `html-minifier-terser` | **Skip by default** ↓ |

**Minify buys little.** CF brotlis at the edge, so pre-minifying saves single
digits — and a build id or unstable attribute order breaks §11.8 and re-uploads
all 16,356 files. If adopted: run after manifest hashing, must pass build-twice.

**Fonts are committed build inputs**, like `theme_tokens.json` — run
`subset_fonts.sh` by hand, commit, generator copies bytes. Keeps Python out of
the build loop. It subsets **once** to TTF and then runs
`fonttools ttLib.woff2 compress` over that result — woff2 is the same tables in
a brotli container, so a second `pyftsubset --flavor=woff2` over the *original*
would redo the whole glyph pass to reach identical outlines, and leave two
subsets free to drift apart (review D5, 2026-07-30).
(`--no-recalc-timestamp` is already pyftsubset's default — verified 2026-07-27.)

---

## 4. Conventions — existing standards, not invented ones

### HTML → source data

Dublin Core `dc.source` (ISO 15836 / RFC 5013) means precisely *"the resource from
which this was derived"*. `<meta name="generator">` is the long-standing convention
Hugo / Jekyll / WordPress all emit.

```html
<meta name="generator" content="wisdom-ssg 0.1.0">
<meta name="dc.source" content="assets/text/an-1.json">
<!--
  node: an-1-1 (chapter)
  preamble: pages[0].[4..5]
  an-1-1-1: pages[0].[6..8]
  an-1-1-2: pages[0].[9..10]
-->
```

The **entry slice** matters more than the filename. When a page renders wrong the
question is always *"which entries did the slicer grab?"*. One line per sutta on
the page, plus the container's own preamble. The coordinate is not split per
language — Pali and Sinhala share an entry index by construction, so naming one
range says both.

> ⚠️ **No build timestamp anywhere in the output.** §11.8 requires byte-identical
> output on unchanged input because Cloudflare dedups by content hash. A timestamp
> means every rebuild rewrites all 16,356 files and re-uploads the whole site.
> Content hashes only.

This is the **reverse** of the §10 `.manifest.json` (`source → [outputs]`, one file,
build-level). Both directions are wanted: the manifest decides *what to rebuild*;
this tells you *where a broken page came from*. Debugging runs in this direction.

*(Source Maps are the real standard for generated→source, but they are built for
JS/CSS and do not apply meaningfully to HTML.)*

### Dart → Dart

No standard exists for "this file mirrors that file". Convention is a fixed header:

```dart
/// Mirrors: lib/core/theme/text_entry_theme.dart
/// Any change there must be reflected here.
```

Applies to every generator file tracking an app file.

### JSON is the source of truth

Already locked as **C1** — the generator never edits `assets/text/*.json`.
Restated here because it is the constraint every phase below inherits.

---

## 5. Phases

Each phase ends with something openable in a browser. `an-1` scoped through P5.

### P0 — Shared foundations *(no HTML)* ✅ **done 2026-07-27**

- **PREREQ-1** ✅ — marker parsing extracted to
  `packages/wisdom_shared/lib/src/text/content_markers.dart`.
  §8 named the wrong file: the logic was in
  `lib/domain/entities/content/entry.dart` (`plainText`, `markedRanges`,
  `_computeMarkedRanges`), **not** `text_entry_widget.dart` — the widget only
  *consumes* `markedRanges`. `Entry` now delegates; the shared implementation
  was diffed against the old inline one over **all 466,127 corpus entries with
  zero differences** in `plainText` or ranges, so the app's rendering is
  provably unchanged.
  - ⚠️ That zero is **empirical, not an identity.** The old chained `replaceAll`
    could *fabricate* a marker: `_**_` → strip `**` → `__` → stripped to empty;
    the single-pass scanner correctly yields `__`. Nothing in the corpus hits it
    today; new data could. Latent-bug fix, not a regression.
  - `parseContentMarkers()` adds the typed `ContentSegment` list §8 asked for.
    **§8's `int? footnoteRef` is wrong** — of 30,514 footnote refs, 1,097 are
    non-numeric: `*` (621), `a`–`o` (441), `†` (21), `‡` (2), `එම` (11).
    Typed as `int?` those are silently dropped, so the field is `String? footnoteLabel`.
  - Markers are **toggles, not matched delimiters** — 12 entries have an odd
    number of `**`, and a delimiter parser would throw or eat their tails.
    Bold and underline nest (23 + 6 cases) but **never interleave** across the
    whole corpus, so two independent toggles suffice.
  - `__` appears **536× across 74 of 285 files** = **268 spans** (every entry has
    an even count) — 0 in the `an-1` slice. ✅ **Decided 2026-07-30: dropped, to
    match the app.** `text_entry_widget.dart` styles `markedRanges` with nothing
    but `FontWeight.bold` and feeds it from `boldRanges`, so the app strips `__`
    and prints the text unstyled; the generator briefly emitted `<u>`, which
    would have underlined 268 spans the app leaves plain. No text is lost either
    way — only the styling. Revisit **on both surfaces at once**, never one.
  - ✅ **Fixed — footnote segments now carry their ambient style.** Found by the
    corpus script, not by review. `parseContentMarkers` was emitting `{label}`
    as `ContentSegment(text: '', footnoteLabel: …)` with `bold`/`underline`
    cleared whatever the enclosing state, so **326 footnote references** — every
    one sitting inside a `**…**` or `__…__` span — reached a renderer with no
    style information. The visible extreme was `__{4}__`, one entry corpus-wide
    (the Vibhaṅgavagga uddāna in `mn-3-4.json`), whose span wraps *nothing but*
    a reference and so lost its underline entirely: 268 source spans arrived as
    267 styled runs. Now 268/268.
    Invisible to the app — it never reads segments, and `boldRanges` is computed
    independently — so this was purely a latent P1 rendering bug.
    `stripMarkers` / `boldRanges` / the rebuild invariant are unaffected because
    footnote text is empty.
- **PREREQ-2** ✅ — tree decode extracted to
  `packages/wisdom_shared/lib/src/tree/tipitaka_tree.dart`.
  Ordering verified against the app's algorithm across **all 2,005 parents:
  zero mismatches**, and re-decoding the same bytes is byte-stable.
  - ⚠️ **The app's sibling sort is only correct by accident.** 113 keys have no
    trailing integer (`vp`, `sp`, `ap`, `kn-khp`, and every dotted commentary
    key — `1.1` doesn't parse), clustered under 18 parents that include `root`,
    `sp`, `kn`, `ap` and `anya`. The comparator returns `0` for those and
    `List.sort` is explicitly **not stable**; today's order survives only because
    Dart falls back to insertion sort below 32 elements and the largest of the 18
    (`atta-ap-vbh-6`) has 23 children. The tree's widest parent, `ap-pat-2` at 90,
    is past that threshold but safe — all 90 keys carry a trailing integer, so the
    comparator is total there. The shared decode makes **document order the
    explicit tiebreak** — same output, now guaranteed, which §11.8 requires.
- **PREREQ-3/4** ✅ — `static_site_generator/` stood up (pubspec, `bin/generate.dart`,
  `lib/data/corpus_reader.dart`, own `analysis_options.yaml`, `build/` gitignored).
  `dart pub deps` resolves **zero Flutter packages** — the mechanical proof
  PREREQ-3 asks for.
- ~~Fix `_nodeKeyPattern`~~ ✅ — it rejected the **53 dotted
  nodeKeys** (`atta-ap-dhs-2-1-1.1`, `atta-vp-cv-3-2.5`), 50 of them leaves, so
  those deep links resolved to null in the shipping app. Now
  `^[a-z0-9]+(?:[-.][a-z0-9]+)*$`: all 16,355 keys accepted, malformed input
  still rejected.
- **Char-counting convention** ✅ — see §5.1 below. Recovered empirically, and
  it surfaced a **146th container** the locked CSV is missing.
- `tools/dump_theme_tokens.dart` ✅ → `static_site_generator/assets/theme_tokens.json`.
  Run with `flutter test tools/dump_theme_tokens.dart` (it lives outside `test/`
  so the normal suite never picks it up). Emits no timestamp, per §11.8.

**Deliverable:** ✅ `dart run static_site_generator/bin/generate.dart --root an-1`
prints the tree (16,355 nodes, 243 leaves under `an-1`) with no Flutter in the
process.

#### 5.1 — Char-counting convention for the 1,500 threshold

**Locked: count `text` exactly as stored in the JSON — markers included — and
sum Pali + Sinhala.** A leaf spans from its own start coordinate to the start
of the next node *anywhere in the file*, not the next sibling.

This was not a free choice. It was **recovered** from
`grouped-vaggas-threshold-1500.csv` by re-deriving the numbers three ways:

| Convention | Grouped containers | Matches CSV? |
|---|---|---|
| **Raw — markers included** | **146** | superset by exactly 1, misses nothing |
| `**`/`__` stripped | 149 | no |
| markers + `{footnote}` stripped | 150 | no |

Raw also reproduces the CSV's per-row `min_sutta_chars` / `max_sutta_chars`
exactly (`an-1-1` → min 353, max 862). So raw is the convention that was used.

> ✅ **RATIFIED 2026-07-27, root cause found 2026-07-28: the count is 146, not
> 145 — and the missing row was a *slicing* bug, not a classifier slip.** The
> CSV omitted `vp-pct-1-3-5`. P0 read its max leaf as **781** chars; under the
> rule stated above it is **2,157**, which is over the threshold and would
> *correctly* exclude it. Both numbers are right about different slices:
> `vp-pct-1-3-5-10` is the last leaf of its vagga, and the old CSV script ran
> to the next **readable** node, swallowing the following vagga's heading and
> its first rule's body. §6 of the model doc stated that wrong rule; §5.1 here
> stated the right one. **The right one is "next node of any kind"** — it is
> what makes the preamble rule work, and it independently reproduces 146.
> **Impact:** +1 grouped container ⇒ its 10 leaves stop getting files while its
> TOC page becomes the chapter page, so **14,763 → 14,753** real pages and
> **1,593 → 1,603** stubs. **16,356 total is unchanged** — the deltas cancel,
> which is the stub invariant doing its job. The P5 gate is untouched.
>
> Note the earlier claim that `kn-thig-6` is the 145↔146 swing node was
> measured under the *stripped* convention. Under the real one it is the
> **nearest miss**: its longest leaf measures exactly **1,500**, so the strict
> `<` is load-bearing to a single character. The nearest grouped container is
> `atta-an-10-1-1` at 1,490 — a 10-char margin, which
> `tool/classify_corpus.dart` now prints on every run.

The classifier ships as committed source in P1
(`lib/domain/grouping_classifier.dart`), and `tool/classify_corpus.dart
--write-csv` regenerates the CSV from it — so the number is reproducible, and
the artefact that was previously unreviewable now has the code behind it.

### P1 — The reading page · frames 02 + 04 ✅ **done 2026-07-28**

- **PREREQ-5 (unplanned, found in P1)** ✅ — `pali_conjunct_transformer.dart` +
  `pali_letter_options.dart` moved into `wisdom_shared`. D1 needs
  `beautifyPaliText` inside the Flutter-free generator, and both files turned
  out to have **no Flutter imports at all**, so this was a move, not a port.
  The old paths stay as re-exports, so the 22 importers and their tests are
  untouched.
- Generator skeleton (PREREQ-3/4), content slicing, **grouping classifier**
  (early — `an-1` is mixed).
  - Slicing is verified by **conservation, not by eye**: `an-1`'s 581 source
    entries render as exactly 581 elements across its 110 pages. Nothing
    dropped, nothing duplicated — the check to re-run whenever the slicer moves.
- All 5 entry types → HTML + CSS from `theme_tokens.json`:
  `paragraph` 335,518 · `gatha` 58,031 · `heading` 32,462 (L1–5) ·
  `centered` 31,773 · `unindented` 8,343.
  These are exactly what `text_entry_theme.dart` already styles — the stylesheet
  is a **port of an approved file, not a new design**. The sketch's verse
  `padding-left: 2.4em` is already `AppFonts.gathaIndentEm = 2.4`.
- Conjunct baking (D1) + un-welded titles (D2). The un-weld is
  character-for-character tipitaka.lk's (`views/Home.vue:118`): it strips only
  the **touching** ZWJ (`ZWJ + hal`), never the **ligature** ZWJ (`hal + ZWJ`),
  which is ordinary Sinhala spelling and appears in **8,536 of the tree's
  32,710 names** (`සූත්‍ර`). Only 2 names carry a touching ZWJ to begin with, so
  the regex is nearly a no-op.
  > ⚠️ **Scope corrected 2026-07-30: D2 covers machine-read strings only.**
  > P1 first applied the un-weld to the `<h1>`, breadcrumb, TOC and pager as
  > well, which printed a sutta's name one way in the breadcrumb and another
  > way in the body two lines below it — and diverged from *both* references.
  > The app welds those very labels (`breadcrumb_provider.dart`,
  > `tree_navigator_widget.dart`, both watching `paliLetterOptionsProvider`),
  > and tipitaka.lk un-welds `document.title` alone. Now: `<title>` (plus OG /
  > JSON-LD at P5) un-welds; **everything a reader looks at goes through
  > `weldTitle` and matches the app.** The two helpers sit side by side in
  > `render/entry_renderer.dart` so the split is hard to re-blur.
- **Title composition (decided 2026-07-28): `<leaf> — <vagga> — <collection>`.**
  §10's `<sutta> — <collection>` leaves **2,216 leaves with a duplicate
  `<title>`** (worst bucket: 16 × "අට්ඨමසික්ඛාපදං — පාචිත්තියපාළි"); adding the
  parent vagga cuts that to 377. Not cosmetic — `an-1`'s **entire** 243 leaves
  are titled with nothing but a number ("1. 16. 8. 9-24"), in both languages,
  and 1,165 leaves corpus-wide are. Repeated parts are dropped, so a node
  directly under its collection does not say it twice.
- WOFF2 subsetting (D7) ✅ **run and committed 2026-07-30** — `subset_fonts.sh`
  emits both `-Subset.ttf` (the intermediate) and `-Subset.woff2` (the site),
  and the generator copies the woff2 — **only the 8 faces the stylesheet
  declares**, driven off the same `webFontFaces()` list, not a glob (review D6).
  8 faces, 632 KB total, in `build/fonts/`.
  > The earlier "`brotli` is not installed" note was stale — it is. Until the
  > script was actually run, every page declared 8 `@font-face` rules pointing
  > at files that did not exist and silently fell back to a system Sinhala face,
  > which is *not* the face the conjuncts were HarfBuzz-verified against. **The
  > 8 `*-Subset.woff2` are committed build inputs.** The `*-Subset.ttf` are
  > gitignored: `pubspec.yaml` still bundles the full TTFs, so they are
  > regenerable scratch until that switch is made deliberately.
- Provenance block (D8). Romanization (D4) is deferred outright — no stub, see
  the corrected D4 above.
- Breadcrumb, centered title, in-flow prev/next cards. Prev/next walks
  **readable pages only**, so crossing a vagga boundary lands on the next sutta
  rather than a table of contents (C7); a chapter file is one stop.
- Grouped chapter: `:has(:target)` single view + the "සම්පූර්ණ පරිච්ඡේදය" context bar.
  ⚠️ Write the filter as `.sutta:not(:target):not(:has(:target))` from the start.
  The naive `.chapter:has(.sutta:target)` form **breaks in P7**: targeting a
  footnote makes it stop matching and every hidden sutta reappears. Costs nothing
  now; a rewrite later. ✅ written in the guarded form.

**Not in this phase:** sidebar, layout switcher (Pali-only), search, footnotes.
**Deliverable:** ✅ `dart run static_site_generator/bin/generate.dart --root an-1`
→ **110 files** in 85 ms: 85 sutta pages + 12 chapter pages + 13 container TOCs.
*(§12's "24 files" was wrong — it counted deepest containers, not pages.)*
Build-twice diff is empty, so §11.8 holds from the first phase.

#### Post-P1 review pass (2026-07-30)

An audit of the finished phase against C1–C10 and the app. Page count, the 581-
entry conservation check and the full-corpus 146 / 1,603 / 16,356 are all
unchanged by it — these are structure and parity fixes, not behaviour.

- **Layers now point one way.** `ContentEntry` / `ContentPage` / `ContentFile`
  were entities living inside `data/corpus_reader.dart`, so `domain/` and
  `render/` both imported *up* into `data/`. They moved to
  `domain/content_file.dart`; the reader keeps only I/O and hashing. Same for
  `ThemeTokens` — now a pure typed view over a decoded map, with the file read
  in `bin/generate.dart` (the composition root), so `render/` no longer reaches
  sideways for it. `grouping/` folded into `domain/` because it is pure policy,
  not a layer of its own.

  The result is checkable in one line rather than asserted:
  **no file under `domain/` or `render/` imports `dart:io`, and neither imports
  `data/`.** `dart:io` now appears in exactly four places — `data/ancestor_dir`,
  `data/corpus_reader`, `manifest/build_manifest` and `sitegen.dart`.

  ```
  domain/   pure — entities, slicer, classifier, tokens, hash
  data/     reads  (-> domain/)
  render/   pure   (-> domain/)
  manifest/ writes one file
  sitegen   the only place they meet
  ```
- **`build/` is wiped before each run.** The build only ever *added* files, so a
  page that stopped existing — a vagga crossing the threshold, a nodeKey shifted
  by a re-sync — left its old HTML behind for Cloudflare to serve. §11.8's
  determinism covers building the *same* input twice and says nothing about a
  changed one, which is exactly when orphans appear. The wipe **refuses any
  directory that is neither empty nor a previous build** (`.manifest.json` is
  the marker) — `--out` is one typo from somewhere that matters.
- **Heading outline is contiguous.** `h${7 - level}` mapped source *sizes*
  straight onto HTML depths, giving every `an-1` page an `<h1> → <h4> → <h6>`
  outline with h2, h3 and h5 missing — a skipped-level failure claiming three
  levels of nesting that are not there. Now the sizes present on a page are
  ranked largest-first and handed `<h2>`, `<h3>`, … in order; the `l<n>` class
  still carries the source level, so the stylesheet is untouched. Verified:
  110 × `<h1>`, 110 × `<h2>`, 158 × `<h3>`, nothing else.
- **Commentary link is same-tab.** It had `target="_blank"`; the app opens the
  twin in place, and one link should not behave differently on the two surfaces.
- **The reader's vertical rhythm is a shared constant.** `entryGapPx` /
  `pageGapPx` were literals typed into `tools/dump_theme_tokens.dart` *and*
  into four reader panes — the hand-copy the generated-token pipeline exists to
  prevent, reintroduced one layer up. Both now live in `AppFonts`; the panes and
  the dump script read the same constant. `pageNumberGapPx` is deliberately
  **not** exported: it spaces a chip this surface does not render.
- **Dropped:** `ContentEntry.plainText` and `.noAudio` (no consumer), the
  `BuildReport.warnings` list (one producer — `stderr` at the point of
  detection says the same thing), and ~60 lines of flag parsing and upward
  directory-walking in `bin/generate.dart` (`Platform.script` answers exactly
  what the walk was inferring). Every `StateError` refusal now prints as a
  clean one-line CLI error instead of a Dart stack trace.

#### Carried into P2 by what P1 measured

1. **The layout radios must be siblings of one `.content` wrapper**, not of
   `.sutta`. §7's selectors (`#L-pali:checked ~ .sutta .si`) never match on a
   chapter page, where `.sutta` is nested inside `.chapter`. P1 already emits
   that wrapper, so P2 is `~ .content .si` and the flagged landmine is defused
   without `:has()`.
2. **18.9% of paired entries are Pali `gatha` against Sinhala `paragraph`** —
   43,081 of 228,496, across 245 of the 285 files. §7 only ever quantified
   *count* misalignment (the 7 `ap-pat*` files). So side-by-side rows routinely
   pair an italic, 2.4em-indented verse with upright justified prose: style
   each **cell** by its own entry type, never the row, and expect uneven row
   heights. `an-1` has zero gatha, which is why P1 never saw it.
3. **`gatha` asks for italic and no Sinhala italic face exists.** The token says
   `fontStyle: italic`; `assets/fonts/noto-serif-sinhala/` ships only
   Regular/Medium/SemiBold/Bold. Browsers synthesise an oblique by default. P1
   emits the token faithfully; if the app turns out to render upright, the knob
   is `font-synthesis: style none`.
4. **`paragraphIndent` is a dead token** — `text_entry_theme.dart:54` computes
   it and *nothing in the app consumes it*. The CSS deliberately does not apply
   it; honouring the token would make the site the odd one out.

### P2 — Layouts + container TOC · frames 03 + 06

- 4-way radio group (`P` / `S` / side-by-side / stacked), side-by-side grid,
  `lang="pi-Sinh"` + `lang="si"`.
  ⚠️ §7's selectors (`#L-pali:checked ~ .sutta .si`) assume `.sutta` is a
  **sibling** of the radios, but §6 nests `.sutta` inside `.chapter` — so on every
  chapter page the rules never match. Needs `:has()` or a restructure.
  ✅ **Already defused** — see "Carried into P2" item 1 above: P1 emits a
  `.content` wrapper, so the rule is `~ .content .si`, with no `:has()` and no
  restructure. The warning stands only against §7's original selectors.
- Container TOC pages — plain app bar, no layout group (per frame 03).
- Collapsed 48px nav rail styling.

**Deliverable:** `an-1` subtree browsable including TOCs, all 4 layouts.

### P3 — Navigator · frames 01 + 02 sidebar

- Static pruned `<details>` tree per page, zero JS.
- Landing page with lotus + welcome.
- Specify the **preamble rule** — verified nested on `an-1`: entries 0–2 → `an`,
  entry 3 → `an-1`, entries 4–5 → `an-1-1`, entry 6 → first leaf. Currently
  under-specified; 258 of 285 files have preamble entries.
- Pin **sibling sort determinism**. `_extractChildIndex` returns `null` for
  non-numeric suffixes and the comparator then returns 0 — unstable. `kn` has 18
  such children. Directly violates §11.8.

**Deliverable:** `an-1` fully navigable without typing URLs.

### P4 — JS layer · frame 05

**The only JS in the build.** Everything above degrades gracefully without it.

- Trimmed title index (`tree.json` is 4.2 MB — cannot ship raw).
- Tree search: flat match list, substring highlight, parent-path subtitle.
- `?layout=` + `localStorage`; nav collapse persistence.

### P5 — SEO & metadata

- ~~`dc.source` / `generator` / canonical~~ ✅ landed in P1 (they cost nothing
  once the template exists). Still open: **OG + JSON-LD**, un-welded per D2.
- `sitemap.xml` with `<lastmod>` from manifest hashes (`.manifest.json` ships
  from P1, hashes included).
- ~~**Determinism check**~~ ✅ green from P1 — build-twice diff is empty. Re-run
  it at each phase; it is a property that gets *broken*, not one that gets won.
- Decide `?e=` behaviour: silently ignored on static pages today.

### P6 — Full corpus

- Scale `an-1` → 16,356 files (canon 9,414 / `atta-*` 6,731 / anya 210).
- ~~Commit the classifier script~~ ✅ done in P1 —
  `lib/domain/grouping_classifier.dart` + `tool/classify_corpus.dart`.
- ⚠️ **77 leaves point at a *trailing colophon*, not a leading label** (found
  2026-07-28). BJT prints some sections' names *after* their text, so the tree
  coordinate sits at the end of the sutta it names. The slice then opens with
  sutta N's name and continues into sutta N+1's body — a page that is wrong
  without looking wrong. **68 of the 77 are in `vp-pct-1-2`** (its majority),
  the rest scattered: `an-2-17-1/2/3`, `an-8-2-5`, `kn-pv-2-9`, `kn-pv-3-4`,
  `kn-pv-4-3`, `kn-vv-4-7`, `vp-prj-1`. Five of the 146 grouped vaggas live in
  `vp-pct-1-2`; on a chapter page the text is all present and in order, but each
  `#fragment` lands one sutta early. **Needs a build-time detector before this
  phase ships** — the shape is "the slice's first entry is a heading matching
  the node's own name, and a *numbering* entry follows it".
- ⚠️ **Decision gate:** stub files vs Cloudflare Bulk Redirects for grouped-leaf
  clean URLs. **Ask before emitting the 1,603 stubs.**
- **Link checker + HTML validator** over `build/` (Node CLIs, D9) — at 16k files
  broken links stop being findable by eye.
- **Measure before minifying** (D9). Adopt only if the brotli'd win is real *and*
  the build-twice diff stays empty. Default: don't.
- **The output of this phase is never committed** — ~340 MB of HTML, produced by CI
  and uploaded straight to Cloudflare. `build/` stays gitignored; the pipeline
  (GitHub Actions → `wrangler` direct upload, and why Cloudflare's own build system
  doesn't run the generator) is decided in the hosting doc, "Build & deploy
  pipeline".

### P7 — Footnotes

Greenfield — the app renders **zero** footnotes today (parser and entity only, no
presentation consumer). Needs per-printed-page numbering. The P1 `:target` guard
is what makes this phase cheap.

---

## 6. Old §12 → new phase

| §12 | Was | Now |
|---|---|---|
| P0 | PREREQ-1 marker extraction | **P0** (+ corrected file, + codec fix) |
| P1 | Stand up generator, tree decode | **P0** |
| P2 | Slicing + marker→HTML + manifest, `kn-khp` | **P1** (`an-1` instead) |
| P3 | 4-layout CSS + Sinhala side | **P2** |
| P4 | Navigator + TOC + canonical + prev/next | TOC → **P2**; navigator → **P3**; canonical → **P5** |
| P5 | Grouping + `:has()` + sitemap + gate | classifier + `:has()` → **P1**; sitemap → **P5**; gate → **P6** |
| P6 | Verify against `kn-iti-1` | **P6** (full corpus supersedes) |
| — | *(later)* search | **P4** |

---

## 7. Open

1. **Where romanized titles come from** (D4). Transliterate, or source externally?
   Deferred, not dropped.
2. **`colors_and_type.css` / `support.js`** referenced by
   `Dev/designs/Static Site Sketches.dc.html` were never shared. Resolved by D6
   (generate from the app theme) — but if those files surface, reconcile.
3. **Stub files vs Bulk Redirects** — P6 gate, unchanged.

### Test coverage (added 2026-07-27, on request)

The P0 equivalence proofs no longer exist only as prose:

| Where | What | Runs in CI |
|---|---|---|
| `packages/wisdom_shared/test/text/content_markers_test.dart` | 89 cases; the pre-extraction `Entry.plainText` / `_computeMarkedRanges` is duplicated in-test as a **frozen oracle** | ✅ |
| `packages/wisdom_shared/test/tree/tipitaka_tree_test.dart` | 18 cases on synthetic fixtures — each ordering hazard in isolation, plus the malformed-row guards | ✅ |
| `static_site_generator/tool/verify_corpus_invariants.dart` | the exhaustive run: 466,127 entries + all 2,005 parents against both frozen oracles | ❌ needs the 340 MB corpus — but see below |

The ❌ is now addressable: the deploy workflow decided 2026-07-31 (hosting doc,
"Build & deploy pipeline") checks the corpus out on a GitHub Actions runner in
order to generate the site, so the exhaustive run can ride along in the same job.

The tree test's load-bearing case is **40 index-less siblings** — past the
32-element cliff where `List.sort` stops being accidentally stable. The real
corpus tops out at 23, so nothing in `assets/` would catch a regression here.

Re-run the corpus script whenever `content_markers.dart` or `tipitaka_tree.dart`
changes, and whenever `assets/` is re-synced from upstream tipitaka.lk.

**Still uncovered by tests:** the grouping classifier and the slicer. Both are
instead verified by whole-corpus tools, which is the stronger check here and the
cheaper one — the properties that matter are corpus-wide invariants, not
example-based:

| Tool | Reports |
|---|---|
| `tool/classify_corpus.dart` | reproduces 146 vaggas / 1,603 leaves / 16,356 files, and prints the two containers nearest the 1,500 line every run. ⚠️ It **prints**; it does not assert — nothing exits non-zero if a number moves, so read the output, or give it a `--expect` mode before wiring it into CI |
| the `an-1` build | 581 source entries → 581 rendered elements (nothing dropped or duplicated), and a build-twice diff that is empty |
