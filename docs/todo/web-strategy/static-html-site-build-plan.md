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

### The subset range is whole Unicode blocks, never single characters

`SINHALA_RANGES` = Basic Latin + Latin-1 Supplement + Sinhala + General
Punctuation. Composed from named block constants only — picking individual
codepoints makes the range impossible to reason about and impossible to audit
when the corpus changes. Measured over the 106.5M characters in `text` fields
(the rendered field only — counting every JSON string instead inflates Basic
Latin with metadata values like `"paragraph"`):

| block | share of reading text | why it is in |
|---|---|---|
| Sinhala | 80.81% | the content |
| Basic Latin | 17.85% | space (14.3M), `.` `,` `-` `:` `(` `)`, digits, and the `**` markers — 80 distinct chars |
| General Punctuation | 1.26% | en dash (59,007), **and ZWJ — every conjunct depends on it** |
| Latin-1 Supplement | 0.02% | the MIDDLE DOT, 19,850 uses across 99 files |

That last row is a fix, not an optimisation. Latin-1 was originally excluded, so
the shipped woff2 had no `·` and every one of those 19,850 dots would have
fallen back to a system font — invisible until P6 reached the commentaries,
since `an-1` happens to contain none. See the warning banner in
`subset_fonts.sh` about never overwriting the full faces with subset bytes.

Deliberately **out**: Latin Extended-A / Extended-Additional (`ā ī ū ṃ ṇ ṭ ḍ ḷ`)
— romanized Pali is `NotoSerif`'s job, not the Sinhala families'. Also out:
Mathematical Operators, whose only corpus use is 11 mis-keyed `U+2212` that
should be en dashes (against 59,007 real ones) — a canon-data defect to
normalise upstream, not a font range to widen.

> **P6 check — daggers.** `†` / `‡` appear 45× (e.g. `ap-kvu-8`) inside the
> `{…}` footnote syntax. They are in General Punctuation, but **the source Noto
> Sinhala faces have no such glyph**, so no range change can cover them; the app
> falls back to `NotoSerif`, the site has no self-hosted cover. Almost certainly
> fine — some system font will render them. Just eyeball a dagger page when the
> full corpus builds and confirm it doesn't look out of place.

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
  8 faces, **320 KB** total (328,296 bytes — measure in bytes, not `du` block
  usage, which reads roughly double), in `build/fonts/`.
  > The earlier "`brotli` is not installed" note was stale — it is. Until the
  > script was actually run, every page declared 8 `@font-face` rules pointing
  > at files that did not exist and silently fell back to a system Sinhala face,
  > which is *not* the face the conjuncts were HarfBuzz-verified against. **The
  > 8 `*-Subset.woff2` are committed build inputs.**
  >
  > **Superseded 2026-07-31** — the 8 Sinhala `*-Subset.ttf` are now committed
  > build inputs too, and `pubspec.yaml` bundles *them* rather than the full
  > faces, so app and web render Sinhala from one identical glyph set (verified:
  > same cmap, glyph order and every outline). `.gitignore` now covers only the
  > two Latin-only families, whose subsets nothing consumes. The full faces stay
  > in the repo as the regeneration source — never delete or overwrite them.
  > Widening to Latin-1 (see §3) grew the woff2 from 297 KB to 320 KB and cut
  > 101 KB of deflated ttf from the app bundle.
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

### P2 — Layouts + container TOC · frames 03 + 06 ✅ **done 2026-08-02**

**The site was Pali-only until this phase.** Half the corpus was absent from
every page, including the 14,752 already deployed. That is what P2 closes.

- 4-way radio group (`P` / `S` / side-by-side / stacked), side-by-side grid,
  `lang="pi-Sinh"` + `lang="si"`. ✅
  ⚠️ §7's selectors (`#L-pali:checked ~ .sutta .si`) assume `.sutta` is a
  **sibling** of the radios, but §6 nests `.sutta` inside `.chapter` — so on every
  chapter page the rules never match. ✅ **Defused as predicted** — P1's
  `.content` wrapper makes it `~ .content .si`, no `:has()`, no restructure.
- Container TOC pages — no layout group (per frame 03). ✅ And it costs **zero
  CSS**: with no radio checked, none of the `#L-x:checked ~` rules match, so a
  `.row` keeps its default single column and both languages show stacked, which
  is what a preamble wants. The absence *is* the behaviour.
- ~~Collapsed 48px nav rail~~ → **moved to P3**, built there, and **withdrawn by
  P3.5 the same day** — see P3's revision note. P2's instinct to defer it was
  right for a reason it did not name: 48px of every phone screen is a real cost
  and the thing meant to justify it never did.

**Deliverable:** ✅ `an-1` browsable in all 4 layouts including TOCs; whole
corpus **14,752 pages / 386 MB in 38 s**, build-twice hash identical (§11.8
holds — verified over the full tree, not a subtree).

#### What P2 found

- **Labels come from the app, not from §7.** The sketch's
  "පාළි / සිංහල / පාළි + සිංහල / තට්ටු" was invented for the doc. The app ships
  `layoutPaliOnly` … `layoutStacked` in `app_si.arb` —
  **පාළි පමණයි / සිංහල පමණයි / දෙකම / ගොඩගැසූ** — and those are what the radios
  carry as `aria-label`. Two names for one control is how surfaces drift. The
  visible glyphs stay the sketch's compact `P` / `S` / two icons.
- **The baked default is `sideBySide`, and it folds.** The app has no single
  default — `resolveSeedLayout` seeds **stacked in portrait, sideBySide in
  landscape** — and CSS cannot switch a `checked` attribute on orientation. So
  side-by-side is baked and its *own* rule is what carries the second column:
  below the breakpoint it falls back to the base single column, which is
  stacked. One default in the HTML, both of the app's behaviours on screen.
  (§7's sketch baked `paliOnly`, which is neither.)
- ⚠️ **`48rem` in a media query is 768px, not 691px.** Media-query lengths
  resolve against the *initial* root font size (16px) and ignore
  `html { font-size: 90% }`, which every other rule in the sheet is measured
  in. Verified in Chrome: two columns at 800, one at 720. Left in `rem` so it
  still tracks a reader's own font-size setting; noted at the constant.
- **A missing side is a row class, not a missing row.** `no-pali` / `no-si` are
  decided at build time, so a single-language layout can skip a row that has
  nothing in that language instead of printing an empty gap. Placeholder cells
  would have worked for the grid and put that blank into the other two layouts;
  side-by-side keeps its columns straight with explicit `grid-column` instead.
  Corpus-wide: **7,377 `no-pali` and 12,690 `no-si`** rows.
- ✅ **The `untranslated` comment count reached zero** — the conservation check
  P1 planted, now met across all 14,752 pages.
- **P1 was losing 15 Sinhala container titles per `an-1`.** `_withoutRepeatedTitle`
  dropped the whole preamble row when its heading repeated the `<h1>`; but the
  `<h1>` is the Pali name only, so the Sinhala name went with it and a
  sinhalaOnly reader met a page titled in a language they had switched off. It
  now clears the **Pali cell alone** and the row survives as `no-pali`.
- **Heading depths must rank both sides.** `_headingDepths` scanned Pali only.
  A Sinhala-only heading would have fallen through to the `<h2>` default and
  reopened the skipped-level gap the post-P1 fix closed.
- **Pali runs heavier wherever the two share a column** — `stacked_pane.dart`
  does this with `AppFonts.paliWeight` ("two weight steps heavier … so Pali
  stays visually distinct from its translation"), and on this corpus it is not
  a nicety: the Pali is set in *Sinhala script*, so weight is the only thing
  telling a stacked pair apart. Applied to body types only, exactly as
  `ReaderEntryBuilder.buildEntry` scopes it. Delivered through a new
  `paneWeights` block in the token file and read by the entry rules as
  `var(--body-weight, N)` — one declaration per layout instead of one per type.
  > ⚠️ **The exported weight is the *native* one (600), deliberately.** Both
  > `paliWeight` and `bodyWeight` branch on `kIsWeb`, and it is tempting to
  > reason "the site is the web, take the web value". The web branch exists to
  > compensate for **CanvasKit**, whose text rendering lacks native Skia's stem
  > darkening. The static site is real HTML text in the browser's own engine,
  > so that deficit does not exist and its correction would just be heavy type.
  > Contrast `fonts.webDefaultScale`, which *does* take the web value — that
  > one is a reading-size choice, not a renderer patch.
- **Two more literals promoted to tokens.** The stacked pane's `8.0` / `20.0`
  pair spacing were typed into the widget tree, the same shape the post-P1
  review fixed for `entryGapPx` / `pageGapPx`. Now `AppFonts.stackedPairGapPx`
  and `stackedPairBottomGapPx`, read by the pane and the dump script alike. The
  base `.row` had `gap: 1rem` against a `12px` between-row margin — a pair
  *less* connected than two unrelated ones, which nothing showed while only one
  language rendered.
- **Side-by-side widens the column.** `44rem` is a measure for one column of
  text; split in two it gives each language ~21rem, too narrow for the corpus's
  compounds. `#L-sbs:checked` takes it to `64rem`, and the toolbar's inner
  wrapper with it, or the control stops sitting over the text it governs.
- **Column captions (පාළි / සිංහල) in side-by-side only.** Also corpus-specific:
  both columns are the same alphabet, so a reader landing mid-page cannot
  otherwise tell canon from translation. Hidden in the three layouts that show
  one language or alternate them.

#### Post-P2 review pass (2026-08-03)

Six findings, all fixed. Page counts, the caption gate aside, are unchanged.

- **The sticky toolbar had no scroll offset.** `.sutta:target` still carried
  P1's `scroll-margin-top: 1rem` — written when the page had no fixed chrome —
  which is 14.4px against a 56px bar, so every `#fragment` landed ~42px behind
  it. Masked today only because nothing emits a fragment yet; `#<nodeKey>` is
  the locked deep-link form and P7's footnotes will hit it constantly. Now
  `html { scroll-padding-top: calc(var(--toolbar-height) + 1rem) }` — on the
  scroll container, so it covers anchors that do not exist yet — and the
  per-target margin is gone rather than stacking a second offset. The 56px is
  a single constant feeding both the bar's height and the offset.
- **On a phone the lit button was not the layout on screen.** `#L-sbs` is baked
  `checked` and its *highlight* sat outside the media query while its
  two-column rule sat inside. Below 768px the page rendered stacked with the
  side-by-side button lit, two of four buttons looked identical, and tapping
  "stacked" changed nothing but which button glowed. Side-by-side is now not
  offered below the breakpoint at all — it has no distinct rendering there —
  and the stacked button lights for both; above it, the media query hands the
  highlight back.
  > **The radio goes with the button** (follow-up, same review). Hiding only
  > the *label* left the radio behind it focusable — `.layout-input` hides the
  > inputs off-screen precisely so the group stays arrow-navigable — so
  > arrowing onto side-by-side on a narrow window selected it, moved the
  > highlight to stacked, and painted the focus ring onto a `display: none`
  > label: focus vanished for one keypress. The input is now `display: none`
  > there too, which takes it out of the tab order and the arrow cycle.
  > **`:checked` and `~` still match a `display: none` input** — verified in
  > Chrome at 500px, where the stacked button is still lit by
  > `#L-sbs:checked ~ …` — so the layout engine is untouched and the baked
  > default still drives the single-column rendering.
  > Written as base-state-plus-override, *not* a `max-width` query: the
  > obvious spelling needs `47.99rem`, which would put two expressions of one
  > breakpoint in a sheet where `48rem` already means two different pixel
  > widths. One number, stated once.
- **210 pages captioned an empty column.** Every one in the 7 `ap-pat*` files,
  which carry no Sinhala: under the baked side-by-side default they widened to
  two columns, put all the text in column 1, and printed "සිංහල" over blank
  space. `_columnHeads()` now takes the page's slices and emits nothing unless
  **both** languages are actually present. Verified: 210 → 0, and 12,684 of
  12,894 readable pages still caption. The test is symmetric even though no
  readable page lacks Pali — nothing guarantees that after a re-sync.
- **The layout ids lived in two files with nothing tying them together**, and
  the stylesheet spelled each one out again across a dozen rules. Renaming one
  would have killed the entire layout engine silently — a CSS rule matching
  nothing is not an error, the analyzer says nothing, and there is no test
  suite here. All four now live in `render/reading_layouts.dart`, written once
  each, with the markup and every selector generated from them.
- `dart format` failed on `page_template.dart`. Fixed — and the run also
  rewrapped `tool/serve.dart`, whose 80-column `if` then tripped
  `curly_braces_in_flow_control_structures`; braced. **`dart format
  --set-exit-if-changed` and `dart analyze` are both clean over the package
  now**, which they were not before this pass.
- **`<nav class="layouts">` was not navigation** — it added a fourth unnamed
  landmark beside the breadcrumb and pager. Now a plain `<div>`.
  `role="radiogroup"` would be no better: the radios sit outside this element,
  and the grouping is already carried by their shared `name="layout"`. The
  `title` on each label stays — it is a hover tooltip for sighted users facing
  a "P", and it never reaches the a11y tree, since the input is named by its
  own `aria-label` and a `<label>` is not focusable.
- **`.col-heads { display: none }` was beating `.row { display: grid }` on
  source order alone** — equal specificity, and reordering the writers in
  `buildStylesheet` would have revealed the captions in every layout. Now
  `.row.col-heads`.
- **Not fixed, carried to P5:** rendering both languages emits two `<hN>` per
  heading row, doubling every heading in the outline. Inherent to a bilingual
  page — the alternative is demoting one language's headings to `<p>`, which
  would leave sinhalaOnly with no outline at all — but P5's structured data
  should decide what it claims about the document.

Re-verified after the fixes: 14,752 pages, `dart analyze` and `dart format`
clean, and a build-twice hash over the full tree that is still identical.

### P3 — Navigator · frames 01 + 02 sidebar ✅ **done 2026-08-03**

- ~~**Collapsed 48px nav rail**~~ · ~~**static pruned `<details>` tree per
  page**~~ — **built, then withdrawn 2026-08-03 (P3.5). See the revision note
  below.** Both shipped and worked; measured on the full corpus they did not earn
  the space, and the tree had an accessibility defect that only showed up at
  scale.
- **Landing page at `/` — see 5.2 below.** ✅ `/` returns 200. Rebuilt as a
  container TOC by P3.5; the front-door requirement it answers is unchanged.
- ~~Specify the **preamble rule**~~ ✅ **already closed by P1**, which is the
  finding. Making containers slice boundaries produced it for free
  (`content_slicer.dart`), and the shape the bullet asked to be specified is
  what the build already emits — verified against the `an-1` output:
  `an-1` → `pages[0].[3..3]`, `an-1-1` → `pages[0].[4..5]`, first leaf
  `an-1-1-1` → `pages[0].[6..8]`. Nothing to write but this line.
- ~~Pin **sibling sort determinism**~~ ✅ **closed for the generator by P0** —
  `TipitakaTree.fromJson` has taken document order as an explicit tiebreak since
  the extraction; §11.8 was never actually at risk. What *was* still open is
  that **the app kept its own copy of the old comparator**, so the two surfaces
  could order `kn`'s 18 index-less children differently. Now fixed in
  `tree_local_datasource.dart`. Order on today's data is unchanged — the
  full-corpus invariant check compares 2,005 parents and reports **0 ordering
  mismatches** — so this removes a fragility rather than moving anything.

**Deliverable:** ✅ `an-1` navigable without typing URLs, and `/` a real page.
110 pages + `index.html`, build-twice hash identical, `dart analyze` and
`dart format --set-exit-if-changed` clean across the generator package.

#### P3.5 — the rail withdrawn *(2026-08-03, same day)*

> **It never reached a commit.** P3 was still uncommitted when this landed, so
> the two were squashed and the rail appears nowhere in git history — don't go
> looking for the diff. It was really built and really measured against the full
> 14,752-page corpus; the numbers below are from that build, not an estimate.

The navigator was generated onto all 14,752 pages and then measured on the full
build. Four findings, and together they say the component was chrome, not
navigation:

- **42 of ~69 rail rows are identical on every page** — the 7 roots plus their 35
  children, shipped whole regardless of where the reader is. Reading Maṅgala
  Sutta, the rail offers the eight books of the Abhidhamma commentary.
- **The other ~27 rows are the breadcrumb, drawn vertically.** `kn-khp-5`'s open
  branch is `sp › kn › kn-khp` — the trail the breadcrumb already prints, one
  line above the text.
- **122 MB of the 487 MB build**, 26% of all bytes, ~0.99 KB of a 5.43 KB gzipped
  page — to save at most one click over "breadcrumb up, then pick".
- **Its disclosure toggle was a 12×28 px target.** `.tree summary .node
  { flex: 1 }` gave the anchor the whole row, leaving only `summary::before` at
  `width: 1em` — 12.2 px, with `html { font-size: 90% }` × `.tree
  { font-size: 0.85em }`. Clicking a root's *label* navigated away instead of
  expanding it. **WCAG 2.2 SC 2.5.8 (AA) requires 24×24.** It failed on the
  phone, where the drawer was the primary navigator.

A fifth, softer one explains why it *looked* wrong before any of this was
measured: **siblings at one level render in two different shapes.** Under `sp`,
`dn`/`mn`/`sn`/`an` are plain links while `kn` is a `<details>` — same level,
same kind of node, different affordance, purely because of where the reader
happens to be standing. Correct per-node (a pruned container has nothing to
disclose), but the eye reads it as a malfunction.

What replaced it was already there: breadcrumb (up), TOC (down), pager (along),
aṭṭhakathā (across) — 6 contextual links on a leaf page, and every node reachable
from `/` through container TOCs. The toolbar keeps a home link, which the rail
had been the sole carrier of. Build 487 → 388 MB, stylesheet 15.2 → 12.1 KB, page
count unchanged.

**The general lesson, worth more than the component:** a navigator that ships the
same rows on every page is a table of contents stapled to the chrome. The parts
that earn their bytes are the ones that differ per page.

#### What P3 found

- **Container TOCs needed the toolbar they were denied.** P2 emitted the bar
  only on readable pages, because the layout group was all it held. That was
  wrong for the hamburger and stays wrong without it: a TOC page with no bar is a
  page with no way home, and no way to reach search when P4 adds it. Every page
  gets the bar; only the *layout group* stays gated, which is what frame 03
  actually specifies.
- **The emblem is a committed derivative, not the source.** §5.2 flagged the
  634 KB master; the site ships a 200×200, 47 KB copy from
  `assets/make_emblem.sh`. Same contract as the fonts: run by hand, output
  committed, build copies bytes. It now renders at 28px in the toolbar rather
  than 100px in a hero, so the file is larger than any single use needs —
  deliberately, since it is one request cached for the whole site and a
  retina-density bar mark still wants the pixels.
- **`<head>` is now written once** (`render/document_shell.dart`). The landing
  page needs the identical five-line contract — charset, viewport, canonical,
  stylesheet, generator — and P5 adds OG and JSON-LD to all of them at once. A
  second copy for `/` would have been a second place to forget.

#### 5.2 — The landing page (`/`)

**Why it is in the plan at all.** The first dev deploy (2026-08-03) shipped
14,752 pages and the site still had no front door: `/` → 404, and so did the
first thing anyone tries next, `/<nodeKey>`. Every page lives under
`/tipitaka/<nodeKey>` (`site_page.dart:15`, sharing `TipitakaLink.pathSegment`
with the app's deep-link codec), which is right — but it means the origin
wrangler prints is a dead link, and a deploy nobody can click through is a
deploy nobody has checked. `deploy.sh` now prints a working `entry` URL as a
stopgap and drops that line by itself once `$OUT/index.html` exists.

**Where.** `index.html` at the **site root** — the one page outside the
`/tipitaka/` grammar, and one extra file against the 20,000 cap.

**What.** A container TOC like every other container in the corpus — heading,
hint, list of children — with `tree.roots` as the children.

*(Revised 2026-08-03 with P3.5. This was first built as the app's empty reader
state: an emblem hero on one side, the P3 navigator tree on the other. The tree
went with the rest of the rail, and rebuilding a second, tree-shaped front page
for its own sake would have been the wrong lesson to draw from that. `/` is now
one page shape with the rest of the site, sharing `tocList()` with every
container TOC.)*

- **The list** — `tree.json`'s **7 top-level nodes**: `vp` විනයපිටක ·
  `sp` සුත්තපිටක · `ap` අභිධම්මපිටක · `atta-vp` විනය අට්ඨකථා ·
  `atta-sp` සුත්ත අට්ඨකථා · `atta-ap` අභිධම්ම අට්ඨකථා · `anya` අන්‍ය. In
  `tree.json`'s declared order, which document order pins (§11.8) — nothing here
  is sorted or derived at build time.
  > ⚠️ **Corrected 2026-08-03 — these were the Sinhala names.** This list used
  > to read `vp` විනය පිටකය · `sp` සූත්‍ර පිටකය · `atta-vp` විනය අටුවාව, which
  > is `tree.json`'s **Sinhala** field. Every page already built renders the
  > **Pali** field — `an-1`'s breadcrumb says සුත්තපිටක, not සූත්‍ර පිටකය — and
  > the site names every node exactly one way on every surface. The frame was
  > drawn from the app, whose Content Language defaults to Sinhala
  > (`content_language_provider.dart:54`); the static site has no such setting.
  > Left as written, this list and the breadcrumbs one click below it would have
  > named the same seven nodes two different ways. The rule is now stated once,
  > in `render/node_labels.dart`.
- **The heading and hint** — the site title above, the app's "pick something to
  read" line below it, both plain text. No emblem hero: the emblem is toolbar
  chrome on every page now, `/` included, and drawing it twice the size in the
  body as well would be the same mark twice on one screen.

**Strings and assets come from the app.** Same lesson P2 learned the hard way
about the layout labels: two names for one thing is how surfaces drift.

- Hint = `statusSelectSuttaToRead`, `app_si.arb:186` —
  *කියවීම ආරම්භ කිරීමට ව්‍යූහයෙන් සූත්‍රයක් තෝරන්න*
  (EN `app_en.arb:479`). Not a new welcome line.
- Title = `appTitle`, `app_si.arb:4`.
- Emblem = `assets/icons/app_logo.png`, in the toolbar at 28 px.
  ⚠️ **The source file is 634 KB.** The build ships one CSS and eight woff2 and
  no rasters at all otherwise. Ship a resized/optimised copy, never the source —
  `assets/make_emblem.sh` produces the committed 200×200, 47 KB derivative.
- Titles are `tree.json`'s **Pali** field, per the correction above.

**Costs zero layout CSS.** Like container TOCs (frame 03) it carries no radio
group, and by P2's mechanism the absence *is* the behaviour: with nothing
checked, no `#L-x:checked ~` rule matches.

**Hand to P5.** `/` becomes the site's canonical root and the highest-value page
in the whole SEO effort — its title, description and OG matter more than any
single sutta's, and it is what `sitemap.xml` names as the entry.

### P4 — JS layer: the search dialog · frame 05

**The only JS in the build.** Everything above degrades gracefully without it.

*(Rescoped 2026-08-03 with P3.5. This phase used to be "full tree on demand"
— §9's Layer 2, a shared `/nav.html` fetched and swapped into the rail. There is
no rail to swap into, and the measurements below say search is both cheaper and a
better answer to the same question: a reader who wants a named sutta should type
its name, not climb to it. "Nav collapse persistence" is gone with the rail.)*

- **Search dialog.** `<dialog>` + `showModal()`, opened from a toolbar button:
  do your search, click a result, or close. Chosen over the popover attribute
  because search needs JS regardless, and only the modal path gives the focus
  trap, `::backdrop` and Esc-to-close for free.
- **Trigger emitted with the `hidden` attribute**, unhidden by the script. With
  JS off there is no dead control (C8), and the markup stays deterministic
  instead of being injected from a string.
- **The index — `assets/search-index.json`.** Row-wise, one array per node in
  tree order: `[key, weldedPali, sinhala, parentIdx, chapterIdx]`. Measured on
  the full corpus: **2,315 KB raw / 252 KB gzip / ~214 KB brotli** — *cheaper
  than the 200–400 KB Layer 2 fetch it replaces*. Fetched on first dialog open,
  not on page load, then cached for the whole site.
  - `parentIdx` is an index into the same array, for the parent-path subtitle on
    a result row. An integer, not a repeated key string — it compresses far
    better.
  - `chapterIdx` is `-1` when the node has its own page. **1,603 of 16,355 nodes
    do not** (grouped into 146 chapter files), so their result must link
    `…/<chapterKey>#<key>`, never `…/<key>` — which 404s today. All 1,603 resolve
    from `SitePlan`, which is *why* the index has to be built after
    `SitePlan.build()` rather than from `tree.json` alone.
  - Must be byte-deterministic (§11.8): iterate the plan, never a `Map` with
    incidental ordering.
- **⚠️ Store the welded name, normalize at match time.** This is the detail that
  would otherwise ship a search that silently misses. Names go through
  `weldTitle()` before display (D1), which inserts touching ZWJ and folds
  `ේ→ෙ`, `ෝ→ො`; raw `tree.json` names are the *unwelded* form (0 of 16,355 Pali
  names carry touching ZWJ, 0 carry `ේ`/`ෝ`). An index in either form alone fails
  against a query typed in the other. Ship **welded** — it costs only +17 KB
  gzipped (243 vs 226 KB on the name columns), it is what the reader sees on the
  page they land on, and it avoids porting `beautifyPaliText`'s conjunct tables
  to JS. Then normalize *both* the index string and the query:
  `s.replace(/[‌‍]/g,'').replace(/ේ/g,'ෙ').replace(/ෝ/g,'ො')` — a
  transcription of `removeConjunctFormatting` + `shortenVowels`
  (`packages/wisdom_shared/lib/src/text/pali_conjuncts.dart:168,263`). The vowel
  fold is a no-op on today's data; it is insurance against an upstream re-sync.
  Sinhala names ship raw — 8,536 carry ligature ZWJ (rakaransaya/yansaya), which
  is ordinary spelling that the zero-width strip removes on both sides anyway.
- **Matching**: substring over both name columns, exact-prefix ranked first,
  capped at ~50 rows. A result row is the welded name plus its parent path. No
  fuzzy matching, no scoring library.
- `search.js` is a committed source file the build **copies**, same contract as
  the fonts and the emblem — no bundler in the loop (D9).
- `?layout=` + `localStorage`.

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
| P4 | Navigator + TOC + canonical + prev/next | TOC → **P2**; navigator → **P3**, then withdrawn (P3.5); canonical → **P5** |
| P5 | Grouping + `:has()` + sitemap + gate | classifier + `:has()` → **P1**; sitemap → **P5**; gate → **P6** |
| P6 | Verify against `kn-iti-1` | **P6** (full corpus supersedes) |
| — | *(later)* search | **P4** (now the whole of it) |

---

## 7. Open

1. **Where romanized titles come from** (D4). Transliterate, or source externally?
   Deferred, not dropped.
2. **`colors_and_type.css` / `support.js`** referenced by
   `Dev/designs/Static Site Sketches.dc.html` were never shared. Resolved by D6
   (generate from the app theme) — but if those files surface, reconcile.
3. **Stub files vs Bulk Redirects** — P6 gate, unchanged.

---

## 8. Testing

*Absorbs the `Test coverage` subsection that sat under §7 from 2026-07-27 — it
was a status record, not an open question. Nothing in it changed; §8.2 and §8.3
are new (2026-08-03).*

### 8.1 What exists today

The P0 equivalence proofs no longer exist only as prose:

| Where | What | Needs the corpus |
|---|---|---|
| `packages/wisdom_shared/test/text/content_markers_test.dart` | 89 cases; the pre-extraction `Entry.plainText` / `_computeMarkedRanges` is duplicated in-test as a **frozen oracle** | no |
| `packages/wisdom_shared/test/tree/tipitaka_tree_test.dart` | 18 cases on synthetic fixtures — each ordering hazard in isolation, plus the malformed-row guards | no |
| `packages/wisdom_shared/test/links/tipitaka_link_test.dart` | 68 cases on the `/tipitaka/<nodeKey>` codec both surfaces share | no |
| `static_site_generator/test/wiring_contract_test.dart` | §8.3, shipped 2026-08-06: 15 cases over the markup ⇄ stylesheet seam and the template's own decisions | no |
| `static_site_generator/test/corpus_tools_test.dart` | shipped 2026-08-06: runs both whole-corpus tools below and fails on a non-zero exit | **yes** |
| `static_site_generator/tool/verify_corpus_invariants.dart` | the exhaustive run: 466,127 entries + all 2,005 parents against both frozen oracles | **yes** — all 340 MB |

⚠️ **Corrected 2026-08-03: this column used to read "Runs in CI", with ✅ on the
first two rows. Nothing runs in CI. `.github/workflows/` is empty and no workflow
is tracked anywhere in the repo** — every row above is run by hand today. What
the column actually distinguishes is which ones *could* run on a bare checkout,
which is the useful question until CI exists.

All four no-corpus rows are ready to run unattended the moment there is a
workflow, and so are the two corpus ones: the deploy workflow decided 2026-07-31
(hosting doc, "Build & deploy pipeline") checks the corpus out on a GitHub
Actions runner in order to generate the site, so both can ride along in that job.

**Both corpus tools became tests on 2026-08-06.** They were kept out of
`dart test` because each was thought to take about a minute. Measured, the page
budget is **~3s** and the exhaustive run **~23s**, so `test/corpus_tools_test.dart`
now runs both and the whole suite finishes in ~25s. Each test just runs the tool
and expects exit 0, so `_locked` stays the one place the page budget lives.

They carry the `corpus` tag, declared in `static_site_generator/dart_test.yaml`:

| Command | Runs |
|---|---|
| `dart test` | everything, ~25s |
| `dart test -x corpus` | the 15 wiring cases only, under a second |

Still run the tools by hand when reviewing a change. A test says pass or fail;
only the printout gives you the margins either side of the 1,500-char line.

The tree test's load-bearing case is **40 index-less siblings** — past the
32-element cliff where `List.sort` stops being accidentally stable. The real
corpus tops out at 23, so nothing in `assets/` would catch a regression here.

**Still uncovered by example-based tests:** the grouping classifier and the
slicer. Both are instead verified by whole-corpus tools — the stronger check
here and, now that they are tagged tests, the cheaper one too. The properties
that matter are corpus-wide invariants, not examples:

| Tool | Reports |
|---|---|
| `tool/classify_corpus.dart` | reproduces 146 vaggas / 1,603 leaves / 16,356 files, and prints the two containers nearest the 1,500 line every run |
| `tool/classify_corpus.dart --expect` | the same run, **asserted** against the locked budget — 10 rows including the two threshold neighbours, exit 1 on any drift. Run by `test/corpus_tools_test.dart` |
| the `an-1` build | 581 source entries → 581 rendered elements (nothing dropped or duplicated), and a build-twice diff that is empty |

`--expect` landed 2026-08-06, closing the "it prints, it does not assert" gap
this table used to carry. The locked figures live in `_locked` at the foot of the
tool; moving one is a decision that changes the plan docs in the same commit.
`kn-thig-6` measuring **exactly** 1,500 is now an asserted row, so the strict `<`
in the classifier can no longer be loosened silently.

The comparison runs **both ways**: a locked figure the run never produced fails
just as a mismatched one does. Checking only the rows a run emits means deleting
a line from the tool's own count list stops checking that figure and still exits
0 — a green wall with one fewer row in it, which is not a thing anyone reads
closely enough to catch.

### 8.2 The gap P2's review exposed — the wiring contract

The layout-id finding (§P2, post-P2 review pass) is a *class* of bug none of the
above can reach, and it is worth naming rather than filing as one fixed defect,
because everything built from here adds more of it: P4's search dialog and
`?layout=`, P7's footnote anchors.

`page_template.dart` emits classes and ids. `stylesheet.dart` writes selectors
against them. **Nothing connects the two.** When they disagree, the build is
green in every way currently checked:

| Signal | Verdict on a dead layout engine |
|---|---|
| `dart analyze` | clean — neither file is wrong on its own |
| `dart format` | clean |
| build-twice hash (§11.8) | identical — determinism survives a broken site |
| entry conservation (581 in → 581 out) | passes — every element is present |
| HTML validator (P6) | passes — the markup is valid |
| link checker (P6) | passes — no URL changed |

A CSS rule that matches nothing is not an error anywhere in the toolchain. The
whole reading-layout system can stop working and every signal above stays green.
It was caught by *reading*, which does not scale past one review.

Centralising the four ids in `render/reading_layouts.dart` narrowed the window
but did not close it: nothing stopped the next selector being typed by hand, and
the *class* names were never centralised at all — `'no-pali'` is still a bare
literal in `page_template.dart` and again inside a selector string in
`stylesheet.dart`. §8.3 is what closes it, by asserting across the two outputs
instead of trying to make one file own both.

### 8.3 The guard ✅ **shipped 2026-08-06**

`static_site_generator/test/wiring_contract_test.dart` — **15 cases, no corpus,
no new dependencies, well under a second.** `test: ^1.24.0` was already a
`dev_dependency`; the package simply had no `test/` directory. Both sides are
pure functions — `buildStylesheet(tokens)` returns a String,
`PageTemplate.render(…)` returns a String — which is what made this cheap rather
than a project.

**Part 1 — the contract itself.** Render one page of each kind, build the sheet,
assert across the two outputs:

| Assert | Catches |
|---|---|
| every `#L-…` in the emitted CSS resolves to a `readingLayouts` id | a hand-typed selector — the P2 finding's exact shape |
| every `readingLayouts` id appears in the HTML as both an `<input id>` and a `<label for>` | a layout added to the list but not to the markup |
| exactly one `<input>` carries `checked`, and it is `defaultLayoutId` | two defaults, or none |
| `defaultLayoutId` and `narrowFallbackLayoutId` are themselves real ids | a typo in either, which the stylesheet interpolates unchecked |
| layout ids **and tokens** are each unique | duplicate ids (invalid HTML); duplicate tokens would make a layout unreachable from P4's `?layout=` |
| every class named in a rule that mentions a `#L-…` radio is emitted by the template | a class renamed on one side only |
| every layout has at least one rule reaching `.content` | a layout with a radio and a button that changes nothing when chosen |
| every class named in a rule that mentions `:target` is emitted — `.chapter`, `.chapter-bar`, `.sutta` | the grouped-chapter filter dying, so every deep link shows the whole run |
| chapter `<section>`s are anchored by the bare nodeKey | P4's `…/<chapter>#<leafKey>` links for the 1,603 grouped leaves silently landing on the chapter head |

Both class checks **derive** their list from the sheet rather than holding one by
hand, and that is the point rather than a convenience. A hand-kept array covers
only what someone remembered to add — P4 brings more — and matching a name
against the *whole* stylesheet proves less than it appears to: `.content`
renamed inside a single layout rule still finds `.content { … }` in the page
chrome and passes, while paliOnly quietly stops hiding anything. Scoping to the
rules that mention the mechanism is what makes the assertion mean its name.

**Part 2 — the template's own decisions**, over synthetic `NodeSlice`s. These are
the branches that have already been wrong once:

| Assert | Catches |
|---|---|
| a repeated title clears the **Pali cell only**, keeps the Sinhala, marks the row `no-pali` | the P1 regression that lost 15 Sinhala container titles per `an-1` |
| a preamble heading that *differs* survives intact | the control — without it the row above passes against a renderer that drops every preamble heading |
| `no-pali` / `no-si` track the cells actually emitted, and only `DocRow.isEmpty` drops a row | an empty grid item printing a gap where nothing is |
| `_columnHeads` emits nothing when a language is wholly absent from the page | the 210 `ap-pat*` pages captioning an empty column |
| heading depths are contiguous from `<h2>` and rank **both** language sides | the skipped-level outline, twice fixed already |
| the `.si` cell carries no touching ZWJ, **while the `.pali` cell does** | the conjunct transform leaking into the translation — asserted both ways, or it passes against a build where welding is off everywhere |
| every page kind emits exactly one toolbar; only readable pages emit radios | a page with no way home; radios on a page with nothing to switch |

> The toolbar row above used to read *"a TOC page emits no toolbar"*. That was
> written against P2's behaviour and was already stale when §8.3 was drafted:
> **P3 gives every page the bar**, on the grounds that a page without one has no
> way home and no route to search when P4 lands. Only the *layout group* stays
> gated, which is what frame 03 specifies and what `site_chrome.dart` documents.

**Verified by mutation, not by going green.** Each guarded behaviour was broken
in turn and the suite re-run: a class renamed in the markup only, a hand-typed
`#L-paali` selector, heading depths ranking Pali alone, ungated column captions,
the repeated-title fix reverted to clearing both cells, the conjunct transform
applied to Sinhala, every radio checked, the toolbar dropped from TOC pages, a
prefixed chapter-section id, `.content` renamed inside one layout rule, the
`.chapter` wrapper renamed in markup, `.chapter-bar` renamed in the sheet,
`.sutta` typo'd inside the `:target` filter, the stacked layout left reachable
and inert, and a locked row deleted from `--expect`'s count list. **15 of 15
caught.** A guard that survives its own mutation is decoration.

> The last six were added on 2026-08-06 after a review of this commit, and four
> of them are why the class checks now derive their lists. The first version of
> this file **survived** `.content` renamed inside a single layout rule, and
> never looked at `.chapter` or `.chapter-bar` at all — the wrapper that does
> the filtering, one element out from the `.sutta` anchor the file already
> guarded. The mutation script lives in the session scratchpad, not the repo:
> it edits `lib/` in place, and a tool that rewrites source to prove a point
> should not be one keystroke from a stray run.

**Deliberately out:**

- **The slicer and the classifier.** Corpus-wide invariants, already checked the
  right way by `tool/verify_corpus_invariants.dart` and `tool/classify_corpus.dart`
  — see §8.1, where `--expect` now makes the latter assert rather than print.
- **Whether the CSS renders correctly** — that a 600 weight reads as distinct,
  that the sticky bar clears an anchor, that a phone shows three buttons. A
  string test cannot see a browser. That stays eyeball, `tool/serve.dart`, and
  the ui-auditor; the post-P2 method (build, grep the output, reason about the
  cascade) is what actually caught both of those.
- **Golden HTML files.** They would fail on every legitimate change and teach the
  reflex of regenerating them without reading the diff — the opposite of a guard.

**Where it runs.** `dart test` from the package root, by hand like everything
else — there is no CI (§8.1). It needs no corpus, so it is the cheapest thing in
this section to automate, and it goes into the deploy workflow (hosting doc,
"Build & deploy pipeline") the moment that lands — **ahead** of the exhaustive
run rather than beside it: a wiring failure should stop a deploy before 386 MB is
generated, not after.

⚠️ That job must set its **working directory to `static_site_generator/`**. Two
paths in the suite are relative to the CWD — `assets/theme_tokens.json` here, and
`tool/` in `corpus_tools_test.dart`. Both tests fail naming the package root when
they cannot find their file, though from the repo root you hit an earlier and
blunter error first: the root pubspec has no `test` dev_dependency, so resolution
fails before any test runs. Either way the fix is in the workflow, not the tests.

**What it does not cover, and P4 will add more of.** The seam this guards is two
files disagreeing about a string. P4's search dialog adds a third language to the
same disagreement — the trigger's id and `hidden` attribute, the `<dialog>` id,
the index's **field order** against the JS reading it, and the `?layout=` tokens.
Get the field order wrong and search returns plausible results pointing at the
wrong suttas, with no error anywhere. Extend this file as that lands; the
`readingLayouts.token` field already exists so P4 needs no second lookup table,
but nothing yet proves the JS uses it.
