# Static HTML Site — Build Plan

**Status:** active · **Created:** 2026-07-27 · **First slice:** `an-1`

> **Page-count figures are owned by
> [`reading-units-and-grouping.md`](./reading-units-and-grouping.md).** Numbers
> quoted below inside a dated phase record (P1–P4 deliverables, measurements,
> revision notes) are **history and stay as written** — they say what a
> particular build measured on a particular day. Anything forward-looking points
> at the grouping doc instead.

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
| D4 | **Sinhala-only titles.** No romanized Pali yet | Tree has **0 Latin chars** in any node — the data does not exist |
| D5 | Grouped chapters live at the **vagga's real nodeKey** | Frame 04's `an-2-64-76` is not in the tree; nodeKey form needs no codec change |
| D6 | **Theme identical to the app. Light only**, structured so dark slots in | Tokens are *generated* from the app theme, not hand-copied — see §3 |
| D7 | **Self-host WOFF2 fonts** | Not optional — see §3 |
| D8 | Every page names its **source JSON + entry slice** | See §4 |
| D9 | **Generator stays Dart.** Node / Python enter only as post-build steps over finished bytes | Rewriting in JS would fork the marker parser and tree decode — see §3 |

### D4 — the romanization seam

Titles render Sinhala-only, because `assets/data/tree.json` carries no Latin
text for any of its nodes (`FIGURES.treeNodes`).

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
Hand-porting across that boundary is a silent-drift generator across every page.

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
every file. If adopted: run after manifest hashing, must pass build-twice.

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
> means every rebuild rewrites every file and re-uploads the whole site.
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
  `^[a-z0-9]+(?:[-.][a-z0-9]+)*$`: every key in the tree accepted, malformed
  input still rejected.
- **Char-counting convention** ✅ — see §5.1 below. Recovered empirically, and
  it surfaced a **146th container** the locked CSV is missing.
- `tools/dump_theme_tokens.dart` ✅ → `static_site_generator/assets/theme_tokens.json`.
  Run with `flutter test tools/dump_theme_tokens.dart` (it lives outside `test/`
  so the normal suite never picks it up). Emits no timestamp, per §11.8.

**Deliverable:** ✅ `dart run static_site_generator/bin/generate.dart --root an-1`
prints the tree (`FIGURES.treeNodes` nodes, 243 leaves under `an-1`) with no
Flutter in the process.

#### 5.1 — Char-counting convention for the 1,500 threshold

**Locked: count `text` exactly as stored in the JSON — markers included — and
sum Pali + Sinhala.** A leaf spans from its own start coordinate to the start
of the next node *anywhere in the file*, not the next sibling.

This was not a free choice. It was **recovered** in 2026-07 from the
then-existing review CSV — the only record of how the locked figures had been
measured — by re-deriving the numbers three ways:

| Convention | Grouped containers | Matched the CSV? |
|---|---|---|
| **Raw — markers included** | **146** | superset by exactly 1, missed nothing |
| `**`/`__` stripped | 149 | no |
| markers + `{footnote}` stripped | 150 | no |

Raw also reproduced the CSV's per-row `min_sutta_chars` / `max_sutta_chars`
exactly (`an-1-1` → min 353, max 862). So raw is the convention that was used.

The CSV itself was **deleted in S1** (2026-08-17) once the convention it was
being read for had a name in code: `NodeSlice.rawCharCount`, measured against
`GroupingPolicy.shortLineChars`. Nothing parsed it, and a frozen
`grouping_snapshot.dart` under `git diff` is the review artifact it was standing
in for. The derivation above is kept because it is *why* the convention is what
it is; the file is not needed to re-run it.

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
> `<` is load-bearing to a single character. The nearest grouped container was
> `atta-an-10-1-1` at 1,490 — a 10-char margin. **Superseded 2026-08-17:** the
> split rule asks the same question of one leaf rather than a whole vagga, so a
> flip can no longer bury a vagga, and the verdicts freeze into a snapshot
> anyway. See [`reading-units-and-grouping.md`](./reading-units-and-grouping.md).

The rule ships as committed source (`lib/domain/grouping_planner.dart` +
`lib/domain/grouping_policy.dart`) — so the number has code behind it, where the
original CSV was an artefact with no source to check it against.

**Since S2 (2026-08-17) that convention is not applied at build time at all.**
The single source of which leaves lose their file is `foldedLeafKeys`, a
generated `const Set<String>` in
`packages/wisdom_shared/lib/src/grouping/grouping_snapshot.dart`; `SitePlan.build`
reconstructs every page from it and no character is counted on the way. A
re-sync of `assets/` can therefore change what a page *says* and never which
pages *exist*.

Generated Dart rather than a committed JSON asset, for a reason outside this
package: **the app must read the same verdicts and may gain no new bundled
file** (`reading-units-and-grouping.md`, "Constraints this plan respects"), and
one `const` compiles into both surfaces from one place.

`tool/plan_corpus.dart` keeps the rule alive at sync time in three modes —
`--write-snapshot` regenerates the set, `--check` asks the four integrity
questions that a re-sync can break (tree-only, ~1 s, run by
`test/corpus_tools_test.dart`), and the bare run prints the budget plus what the
rule would now say about newly synced content. Its old `--expect` page-budget
lock is gone with the knife edge it guarded: counts that nothing re-measures
cannot drift, and new upstream content should add pages without failing CI.

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
entry conservation check and the full-corpus grouping budget are all
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
  compounds. `#L-sbs:checked` takes it to `64rem`.

  > ⚠️ **Corrected 2026-08-08 — the toolbar has no reading width at all.** The
  > rule moved `.toolbar-inner` to `64rem` alongside the text, so the control
  > would go on sitting over what it governs. But that wrapper is a *centred*
  > box with the emblem on one edge and the layout group on the other, so its
  > width is the only thing positioning either: picking a single-language layout
  > slid the group 144px left and the emblem 144px right, every time. Measured
  > in Chrome at 1400px — group right edge 1161px under side-by-side, 1017px
  > under Pali-only; `(64rem − 44rem) ÷ 2` at this sheet's 14.4px rem, halved
  > because the box is centred.
  >
  > Pinning the bar to `64rem` in every layout stopped the slide, and was
  > measured to buy it at a price: a bar wider than its own text on every window
  > between 670px and 957px (17.7px drift at 720px, 37.7px at 760px, where
  > side-by-side is not even offered) and on all 1,859 TOC-and-`/` pages, which
  > have no layout to switch and so could never have jumped (144px at 1400px).
  >
  > **Settled: the bar is chrome.** `.toolbar` spans the window with
  > `.content`'s own `1.25rem` padding and takes no number from the reading
  > column in any layout, on any page, at any size. One element, too: the
  > `.toolbar-inner` wrapper existed only to hold a width the bar no longer has,
  > so it is folded away — and with it the question that produced both wrong
  > answers, of which box owns the width. This is the app's `AppBar`
  > (`reader_screen.dart:120`), which pins `leading`/`actions` to the window
  > while `TextEntryTheme.readingPadding` centres the text at 54.5em behind
  > it — the two do not align there either, on any wide window. It is also the
  > shape the breadcrumb wants when it moves into this bar, as it already has
  > in the app: the whole window to run in, not a slice, and one more flex item
  > rather than that question asked a third time.
- **The breadcrumb moved into the bar, and grew a leaf and an up button**
  (2026-08-09). The move the note above expected. `.toolbar` is now trail ·
  up · layouts, and `<main>` opens on its `<h1>`.
  > **It fits because the bar is window-sized, and only because of that.**
  > Shaped with HarfBuzz in the shipped WOFF2 subset at the real 12.24px, over
  > all 14,752 built pages, and measured as the boxes actually render — emblem
  > and per-segment padding included, since that is what decides fit: a trail is
  > 684px at the median, 869px at p90 and 1,154px at the worst, across 6
  > segments at the median and 7 at most. Room in the bar is the window minus
  > 259px of pinned controls (36 padding + 21.6 of gaps + the 36px up button +
  > 165px of layout buttons), so every trail in the corpus fits above 1,412px
  > and 73% of them do at 1024px. Under the old `44rem` cap even a wide desktop
  > was mostly clipped; the cap, not the trail, was the problem.
  > **The leaf is in, per the app.** `BreadcrumbWidget` ends on the current node
  > and so does this — a `<span>`, not a self-link, with `aria-current="page"`.
  > The old trail stopped at the parent because the `<h1>` sat directly beneath
  > it; a sticky bar has no "beneath", so a reader who has scrolled would
  > otherwise have no name for the page they are on. The `<h1>` says the name
  > twice now, in two landmarks, deliberately — `wiring_contract_test.dart`
  > counts inside `<main>` for that reason.
  > **The emblem is segment zero,** not a control beside the trail: `/` is the
  > real parent of the seven roots. It also puts the route home at the one end
  > of the line nothing is ever taken from.
  > **Every segment clips itself, and narrow widths drop rather than clip.** One
  > shared line with one `text-overflow` ate the *end* — the near ancestors and
  > the page's own name, which is the half a reader needs. Per-segment boxes
  > make the ancestors give first (`flex-shrink: 200` against the leaf's 1), and
  > three `max-width` steps then zero them outright: the 3 nearest ancestors
  > survive below 48rem, 1 below 36rem, none below 30rem. `width: 0`, never
  > `display: none` — the trail is this site's internal link graph and Google
  > crawls it at phone width. At 768px the surviving trail fits on 39% of pages
  > where the full one would fit on 13%; below 30rem the emblem and the leaf are
  > all that is left, and the leaf fits whole on 53% of pages at 390px, with the
  > `<h1>` one line below printing the same name for the rest.
  > **The up button exists because of what those steps drop.** `.up` is pinned
  > outside the clipping box and points at `parentNodeKey` — omitted on the
  > seven roots, where it would be a second route to `/`. The app needs no
  > equivalent; it has the navigator tree this site withdrew at P3.5.
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
  space. Captions are now withheld unless **both** languages are actually
  present on the page. Verified: 210 → 0, and 12,684 of 12,894 readable pages
  still caption. The test is symmetric even though no readable page lacks
  Pali — nothing guarantees that after a re-sync.

  > **Finished 2026-08-20 — the same pages also offered a layout that emptied
  > them.** Withholding the caption was half the fix. The layout group stayed,
  > so *සිංහල පමණයි* was still on the toolbar of a page with no Sinhala at all,
  > and `#L-si:checked ~ .content .row.no-si { display: none; }` hid every row on
  > it. `site.js` remembers the choice, so picking it once anywhere blanked every
  > Paṭṭhāna page a reader opened afterwards — reported from
  > `/tipitaka/ap-pat-4-10`, a page holding 21 KB of Pali.
  >
  > The fact was there and used in one of the two places that needed it. It is
  > now `_hasBothLanguages()`, asked **once per page** over the preamble and
  > every slice, and it decides three things that must not disagree: the
  > captions, the layout group (`withLayouts: page.isReadable && bothLanguages`
  > — no radios, no labels, so the state is unreachable with JS on *or* off, and
  > no focusable orphan is left behind), and a `solo` class on `.content`.
  >
  > `solo` exists only because two declarations lived on the single-language
  > layouts and a page with no radios has no `:checked` selector to reach it:
  > the `--entry-gap` between rows, and the Pali weight bump that exists to
  > distinguish Pali from a translation the page does not have. Both join the
  > existing selector lists rather than being restated.
  >
  > `FIGURES.readablePagesWithoutSinhala` is unchanged and now names three sets
  > at once — the pages without captions, without a switcher, and marked `solo`.
  > Verified over the whole corpus: the three counts are equal, no page is both
  > `solo` and switchable, the page total does not move, and a both-languages
  > page is byte-identical to the previous build apart from the `?v=` hash.
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
- **Not fixed, and P5 did not fix it either:** rendering both languages emits
  two `<hN>` per heading row, doubling every heading in the outline. Inherent to
  a bilingual page — the alternative is demoting one language's headings to
  `<p>`, which would leave sinhalaOnly with no outline at all. The hope was that
  P5's structured data would decide what the document claims about itself; it
  did not, because `BreadcrumbList` describes a page's *place*, not its outline,
  and nothing else P5 emits reads the headings at all. Now backlog **A8**, on
  its own, where it is correctly ranked low.

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
count unchanged. (The breadcrumb and the home link later merged into one trail
in the bar, and gained an explicit up button — see P2's toolbar-width note.)

**The general lesson, worth more than the component:** a navigator that ships the
same rows on every page is a table of contents stapled to the chrome. The parts
that earn their bytes are the ones that differ per page.

#### What P3 found

- **Container TOCs needed the toolbar they were denied.** P2 emitted the bar
  only on readable pages, because the layout group was all it held. That was
  wrong for the hamburger and stays wrong without it: a TOC page with no bar is a
  page with no way home, and — once P4 landed — no way to reach search either.
  Every page gets the bar; only the *layout group* stays gated, which is what
  frame 03 actually specifies.
- **The emblem is a committed derivative, not the source.** §5.2 flagged the
  634 KB master; the site ships a 200×200, 47 KB copy from
  `assets/make_emblem.sh`. Same contract as the fonts: run by hand, output
  committed, build copies bytes. It now renders at 28px in the toolbar rather
  than 100px in a hero, so the file is larger than any single use needs —
  deliberately, since it is one request cached for the whole site and a
  retina-density bar mark still wants the pixels.
- **`<head>` is now written once** (`render/document_shell.dart`). The landing
  page needs the identical five-line contract — charset, viewport, canonical,
  stylesheet, generator — and P5 hung the description, OG and JSON-LD off the
  same parameters, which is why it grew from five lines to that without either
  template gaining a meta tag of its own. A second copy for `/` would have been
  a second place to forget.

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

**Taken up by P5** (2026-08-22). `/` is the site's canonical root and the
highest-value page in the whole SEO effort, so it is the one page whose
description is written rather than generated, the only `og:type: website`, the
first `<loc>` in `sitemap.xml` — and the one page with no `BreadcrumbList`, a
single item saying only what the URL already says.

### P4 — JS layer: the search dialog · frame 05 ✅ **done 2026-08-14**

**The only JS in the build**, and everything above still degrades gracefully
without it: with JS off the layout falls back to the one baked `checked` in the
HTML and the search button never appears.

*(Rescoped 2026-08-03 with P3.5. This phase used to be "full tree on demand"
— §9's Layer 2, a shared `/nav.html` fetched and swapped into the rail. There is
no rail to swap into, and the measurements said search is both cheaper and a
better answer to the same question: a reader who wants a named sutta should type
its name, not climb to it. "Nav collapse persistence" went with the rail.)*

- **Search dialog.** `<dialog>` + `showModal()`, opened from a toolbar button.
  ✅ Chosen over the popover attribute because search needs JS regardless, and
  only the modal path gives the focus trap, `::backdrop` and Esc-to-close for
  free.
- **Trigger emitted with the `hidden` attribute**, unhidden by the script. ✅ No
  dead control with JS off (C8), and the markup stays deterministic instead of
  being injected from a string.
- **The index — `assets/search-index.json`.** ✅ Row-wise, one array per node in
  plan order: `[key, weldedPali, sinhala, parentIdx, chapterIdx, marked]`.
  Measured on the built corpus: **2,248 KB raw / 254 KB gzip / 180 KB brotli** —
  *cheaper than the 200–400 KB Layer 2 fetch it replaced*, and brotli came in
  well under the ~214 KB the estimate carried. Fetched on first dialog open,
  never on page load, then cached for the whole site.
  - `parentIdx` is an index into the same array, for the parent-path subtitle on
    a result row. An integer, not a repeated key string — it compresses far
    better.
  - `chapterIdx` is `-1` when the node has its own page. **The grouped leaves
    do not** (they live inside chapter files — count in the grouping doc), so
    their result links
    `…/<chapterKey>#<key>`, never `…/<key>` — which 404s. All of them resolve from
    `SitePlan`, which is *why* the index is built after `SitePlan.build()` and
    not from `tree.json` alone. ✅ Verified on the build: every row resolves to a
    file that exists.
  - `marked` is 1 on the commentary nodes whose own page appends අට්ඨකථා
    (`FIGURES.nodesCarryingCommentaryMarker`), and the script applies it to a
    row's own name only — never to the
    ancestors in its trail, which follow the site's breadcrumb and stay bare.
    See "What P4 found" below.
  - Byte-deterministic (§11.8) by iterating the plan, never a `Map`. ✅
    Build-twice over all 14,766 output files is hash-identical.
  - The index URL and `site.js` both carry `?v=<one hash of both files>`,
    computed by the build (`render/site_assets.dart`). Nothing checks the field
    order at runtime, and a cached script from before a change beside a fresh
    index returns plausible results pointing at the wrong sutta — so the two are
    busted as one. This replaced a hand-bumped `searchContractVersion`, whose
    trigger ("bump when a field moves") missed every other way either file
    changes, an upstream re-sync first among them.
- **⚠️ Store the welded name, normalize at match time.** ✅ The detail that would
  otherwise have shipped a search that silently misses. Names go through
  `weldTitle()` before display (D1), which inserts touching ZWJ; raw `tree.json`
  names are the *unwelded* form. An index in either form alone fails against a
  query typed in the other. Shipped **welded** — it is what the reader sees on
  the page they land on, and it avoids porting `beautifyPaliText`'s conjunct
  tables to JS. `site.js` then folds *both* the row and the query, a
  transcription of `removeConjunctFormatting` + `shortenVowels`
  (`pali_conjuncts.dart:263,168`). The vowel fold is a no-op on today's data;
  it is insurance against an upstream re-sync. Sinhala names ship raw — 8,536
  carry ligature ZWJ (rakaransaya/yansaya), ordinary spelling that the
  zero-width strip removes from both sides anyway.
- **Matching**: substring over both name columns, prefix ranked first, capped at
  50 rows. A result row is the welded name plus its parent path. No fuzzy
  matching, no scoring library. ✅ — with one correction the plan did not
  anticipate, below.
- `site.js` is a committed source the build **copies**, same contract as the
  fonts and the emblem — no bundler in the loop (D9). ✅
- `?layout=` + `localStorage`. ✅ In the same file, resolving against the radios'
  `value` (`ReadingLayout.token`), so the script carries no second table of
  layout names. The URL wins over the remembered choice — a shared link is
  someone saying "read it like this".

**Deliverable:** ✅ whole corpus **14,752 pages + `/` in ~50 s**, 14,766 files,
build-twice hash identical.

#### What P4 found

- **⚠️ Prefix ranking was measuring the wrong end of the string.** BJT prints an
  ordinal in front of most names, and **7,986 of the 16,355 Pali names start
  with a digit** (8,012 of the Sinhala). The Maṅgala Sutta is titled
  `5. මඞ්ගලසුත්තං`, so a search for මඞ්ගල matched it only mid-string and sorted
  it *below* every prefix hit — the first working build put a commentary
  sub-section (මඞ්ගලපඤ්හසමුට්ඨානකථා) above the most famous sutta in the
  Khuddakapāṭha. On the corpus's most-searched names the prefix bucket was doing
  the exact opposite of its job. Fixed by ranking against an **offset** — where
  the name begins past its ordinal — rather than a second stripped string, so
  the number stays matchable and the row still displays what the printed page
  carries. The shapes are `5. `, `1-2. `, `4 `, `5-8 `: measured across the
  corpus, `^[0-9]+(-[0-9]+)?[.\s]+` matches 15,803 of the 32,710 names and
  empties none. The 195 that still begin with a digit are names that are *only*
  a number; they have no name proper to rank and keep offset 0.
- **⚠️ Styling a `<dialog>`'s `display` un-hides it on every page.** The closed
  state is the UA's `dialog:not([open]) { display: none }`, and **any** author
  declaration outranks it — cascade origin is settled before specificity is
  consulted. A bare `.search { display: flex }` therefore does not merely style
  the panel; it leaves the dialog rendered, open, in the normal flow of **every
  page in the build**. `display` lives on `.search[open]` and must stay there.
- **The toolbar's breakpoints are a function of the pinned chrome, and this
  phase moved it.** The search button added a 36px control and the `gap` before
  it: **+46.8px** at every width, taking the bar's pinned width from 259/218 to
  305/264. Nothing on the trail's side changed, so the three collapse steps are
  P3's plus that delta, rounded up to the next whole rem — **48/36/30rem →
  51/39/33rem**. Re-deriving from the corpus would have re-litigated judgment
  already settled (480px was itself rounded up from a computed 445 to a
  conventional breakpoint); adding the delta pays only for what changed.
  - **The phone cost, stated rather than hidden:** at 390px the trail now gets
    125px against 172px before, which leaves **83px for the page's own name
    against a 126px median** — so the median leaf name ellipsizes on a phone
    where it used to just fit. Accepted: the `<h1>` one line below carries it in
    full, and the only way to buy the room back was to drop the up button or a
    layout button. Search reaches the whole corpus; those two reach one node and
    one rendering.
  - `_trailKeepThree` no longer coincides with `_twoColumnMinWidth`, as both sat
    at 48rem through P3. That was always arithmetic rather than sharing, and
    this is the first of the two to move.
- **The script spells no string, no URL and no layout token of its own.** Labels
  arrive on `data-loading` / `data-empty` / `data-error` / `data-count` /
  `data-count-capped` / `data-marker`, the index path and the link prefix on
  `data-index` / `data-base`, and layouts resolve off the radios' `value`. The stylesheet is *generated* from `reading_layouts.dart` for exactly
  this reason (a CSS rule that matches nothing is not an error); a hand-synced
  copy of a Sinhala label or of `/tipitaka/` in a JS file fails the same silent
  way, and there is no analyzer on that side at all.
- **The dialog and its script close every body, from `document_shell.dart`.**
  Both are byte-identical on every page in the build, so they belong to the shell for
  the same reason the five head lines do. Position is not cosmetic: they must
  not come between the layout radios and `.toolbar`/`.content` (every layout
  rule is a sibling combinator off those radios), and they must not precede
  `<main>` in the tab order.
- **`tool/serve.dart` was serving `.js` as `application/octet-stream`** — it had
  no `.js` in its MIME map, having never needed one. A classic `<script src>`
  still runs under that, which is worse than failing: the preview then behaves
  unlike any host sending `X-Content-Type-Options: nosniff`. Fixed there.
- **⚠️ The index shipped a name no page displays** (found in review, fixed
  2026-08-14). It stored `weldTitle(paliName)` — the *link* form — while the page
  a result lands on heads itself with the commentary marker. **127 commentary
  rows were byte-identical to a canon row**, same name over the same trail, one
  of the two landing on an `<h1>` that said something else; typing අට්ඨකථා
  matched only the 57 nodes named that way upstream, not the 6,731 that show it.
  The rule now lives in one place, `nodeTitle()` beside `nodeLabelHtml()` in
  `node_labels.dart` — "the page you are on" and "a step on the way to one" are
  the only two ways the site names anything, and the index had quietly become a
  third. It ships the *verdict* as column 6 rather than a second name string:
  525 KB raw to duplicate it, 33 KB (748 B gzipped) to flag it, and deriving it
  in JS would put the rule back in three places.
- **The status line was a bare integer.** `role="status"` announced "50" — no
  noun, and the cap reading as a total. Now `ගැළපෙන නම් {n}ක්` (tipitaka.lk's
  own wording, `TSearch.vue:66`), with the capped variant naming both numbers.
  The count is exact: the scan stopped early at the cap and now runs to the end,
  an `indexOf` pair per remaining row.
- **Three smaller review fixes.** A result click closes the dialog (a
  `<chapter>#<leaf>` link clicked from that same chapter navigates nothing, so
  the panel sat over the single-view it had just triggered); a failed fetch no
  longer latches for the visit; the results list draws a focus ring, its tint
  being **1.44:1** against the panel and SC 2.4.13 asking 3:1 of the only
  indicator the arrow keys have. The panel is bounded in `dvh`, not `vh` —
  `100vh` on mobile Safari is the URL-bar-hidden height.
- **Both ends of the loading state were wrong** (found in manual testing, fixed
  2026-08-15). The message was set the moment the dialog opened, but the index
  is cached `immutable`, so from the second page on it resolves in a few
  milliseconds and the status flashed. It is now on a **1 s** timer a settled
  fetch cancels — below a second a wait is not experienced as one, and nothing
  is blocked by the silence. At the other end, a request that never settled left
  `loading` true for the life of the page, so the dialog could never try again;
  a **15 s** `AbortController` turns the hang into the error path reopening
  already retries. Its deadline is on the *response*, not the download — 254 KB
  gzipped is a legitimate minute on the slow lines this surface is for.
- **Name-only search cannot find a sutta by a name BJT does not print.** The
  Kālāma Sutta is titled `කේසමුත්තිසුත්තං` in this corpus, so "කාලාම" finds only
  its commentary. That is a data fact, not a matcher bug, and the fix is an
  alias table — deliberately **not** built here, since it is editorial content
  the corpus does not carry. Worth knowing before anyone reports it as broken.

### P5 — SEO & metadata ✅ **done 2026-08-22**

Everything a crawler and a messaging app read, shipped in one pass because every
item edits the same `<head>`: each on its own would invalidate every page's
content hash and pay the full push again. Same argument the backlog makes for
pairing B1 with B2.

- ~~`dc.source` / `generator` / canonical~~ ✅ landed in P1 (they cost nothing
  once the template exists).
- ✅ **`<meta name="description">`**, generated by `render/page_description.dart`
  — the click-through lever, and the largest one that was available.
- ✅ **Open Graph**, un-welded per D2, gated on the canonical so `404.html`
  cannot emit any. With a real `og:image`: `assets/og-card.png`, 1200×630, cut
  by `make_emblem.sh` beside the emblem.
- ✅ **JSON-LD `BreadcrumbList`** in `render/structured_data.dart`, from the same
  trail list the toolbar draws. Nothing beyond it — `Book`/`Chapter` have no
  rich-result treatment.
- ✅ **`sitemap.xml`** — `FIGURES.realPages` URLs from `SitePlan.pages` — and
  **`robots.txt`**, whose `Sitemap:` line is the only reason it needs to exist.
- ~~**Determinism check**~~ ✅ still green — build-twice over the full corpus is
  hash-identical. Re-run it at each phase; it is a property that gets *broken*,
  not one that gets won.
- ✅ **`?e=` decided: silently ignored, and that is now harmless.** See below.

#### What P5 found

- **⚠️ `<lastmod>` cannot come from the manifest hashes, and this plan said it
  could.** `.manifest.json` holds FNV-1a *content hashes* and, by §11.8, carries
  no date anywhere — deliberately, since a timestamp would rewrite every file on
  every build. A hash answers "did this change", never "when", and `<lastmod>`
  is a W3C datetime. The only date on hand is `bjt-provenance.json`'s single
  `synced_on`, which would stamp all `FIGURES.realPages` URLs with one day: the
  uninformative signal Google discounts, and being discounted for lying is worse
  than being believed for saying nothing. **Shipped without it**, to revisit
  when a second corpus sync produces per-file dates worth publishing.
- **The apex domain was never the blocker it looked like.** The canonical had
  been root-relative since P1 on the reasoning that a wrong absolute one points
  the whole corpus at a host that does not serve it — correct, and it left the
  tag doing none of its job, since a relative URL resolves to whatever host you
  happened to load and so can never say which host is real. The domain is
  *still* not settled (`static-web-hosting.md` owns that, and still lists it as
  open). What changed is that the generator stopped needing to know:
  `deploy.sh` already computed an origin per target, from the same constants
  that decide everything else about a deploy, and now passes it as `--origin`.
  Validated in `bin/generate.dart` — this is the one input the corpus cannot
  check, and a wrong one builds a complete, correct-looking site that a search
  engine quietly declines to index.
  > The backlog's A4 asserted "the domain is settled now" in two places. It was
  > unsourced, named no domain, and contradicted its own closing sentence.
  > Deleted there rather than reconciled, so the hosting doc stays sole owner.
- **`?e=` needed no code — the canonical was the whole fix.** Nothing in the
  generator reads that query and no page emits per-entry ids, so
  `…/an-1-1?e=12.4` was the same bytes answering at a second address, which
  Google counts as a second URL. An absolute self-canonical folds it onto the
  clean one.
- **Every string in a description is borrowed.** `පාළි පෙළ` / `සිංහල පරිවර්තනය`
  is tipitaka.lk's own pairing for this exact material
  (`src/views/Welcome.vue`), `කොටස්` is the app's `researchMatchedPassage`, and
  `{n}ක්` is the counting form the search dialog already uses. Upstream sets no
  per-page description at all — its `metaInfo` carries a title and an `og:title`
  and nothing else — so there was vocabulary to copy and no sentence, which is
  the closest this site has come to writing prose of its own. It opens on the
  `<title>` string rather than re-deriving a location, so the tab and the
  snippet cannot disagree about where a page sits.
- **`bothLanguages` now decides five things.** Captions, the layout group, the
  `solo` class, the column heads — and whether the description may promise a
  translation. On the `FIGURES.readablePagesWithoutSinhala` pages it stops at
  `පාළි පෙළ`. Verified on the full build: the `solo` pages and the Pali-only
  descriptions come to the same count exactly, which is the same shape the
  2026-08-20 fix left.
- **A nav-only container is not reading text, and its description must not
  pretend.** Those pages count their subdivisions instead. The distinction is
  `SitePage.isReadable`, already the gate for the pager and the radios.
- **The card takes a different form of the same sentence.** The snippet opens on
  the title because Google prints it under a title the searcher has already
  read; a link-preview card draws `og:title` in bold and the description
  directly beneath it, where the identical string renders as a subtitle
  repeating its own heading verbatim before adding six words — on exactly the
  surface Open Graph was added for. `pageDescription` returns both: the snippet,
  and the same clauses with the leading title clause dropped. Verified on the
  full build: no page's `og:description` begins with its `og:title`, and none is
  left empty.
- **The JSON-LD had to be told, three times, not to reuse the breadcrumb's
  strings.** `nodeLabelHtml` is welded (D1) and HTML-escaped so one string can
  be both text and attribute; a `<script>` element does neither entity parsing
  nor welding, so those names would arrive at Google carrying `&quot;` and a
  ZWJ. `<` is escaped to `\u003c` on the way out — nothing in `tree.json`
  contains one, and the alternative is an invisible dependency on that staying
  true.
- **The OG card retires the emblem's last excuse.** `make_emblem.sh` kept the
  toolbar mark at 200px partly because "P5's OG card wants a raster larger than
  the bar does". The card is 1200×630 and its own file — a square is the wrong
  shape at any size — so **backlog B1 is now unopposed**. Not done here: it is a
  shared-chrome edit belonging with B2.
- **The preview server was serving two more types as `application/octet-stream`**
  — `.txt` and `.png`, neither of which it had ever needed. The same trap P4
  found with `.js`: a browser sniffs a PNG and renders it anyway, so nobody
  noticed, while a host sending `X-Content-Type-Options: nosniff` would not, and
  a link scraper rejects a card on the type alone.
- **What it cost, raw and on the wire — and they differ by 7.5×.** The head
  additions are **1,966 B/page raw** (measured over 150 random pages: the
  description, seven OG tags, the absolute canonical and the JSON-LD block),
  taking the build from 388 MB to 412 MB. Brotli'd, the same additions are
  **261 B/page** — 6,932 against 6,671 over 40 pages. This is backlog **B6**
  exactly: repeated chrome is the most compressible thing on a page, so a raw
  figure overstates what a reader waits for by an order of magnitude. The build
  number is a deploy cost, which is real; the wire number is what the audience
  on slow connections actually pays, and it is a quarter of a kilobyte.

- **The four per-build values became one.** The origin, the generator stamp,
  the hashed asset URLs and the link resolver were four separate fields on
  `PageTemplate`, four more on `LandingPage` and three parameters on
  `htmlDocument`. Adding `--origin` — one string — cost ten edits to carry it
  from the place that knows it to the place that prints it, which is what turned
  a list into a pattern. They are one `SiteBuild` now
  (`render/site_build.dart`), and the fifth such value is one line in it. The
  templates keep per-page parameters for what actually varies per page; this is
  only what does not.
- **The default origin named the wrong local server.** `_defaultOrigin` was
  `http://localhost:8080` on the stated grounds that it is "`tool/serve.dart`'s
  own default host". `serve.dart` defaults to **8083** and reserves 8080 for
  Flutter web — a different surface serving different bytes at the same paths —
  so a hand-run build wrote canonicals naming a host that serves the app. Now
  8083, with the coupling written down at both ends.
- **Nothing new is tested**, by decision. The sitemap ⇄ `SitePlan.pages`
  agreement, `robots.txt` naming the file the build writes, and canonical ⇄
  `og:url` sharing one origin are all checked by hand here and by nothing
  standing. `og-card.png` also made the asset store a sixth file and a fifth
  token, which widens backlog C1 — still ranked first for the next asset change.

### P6 — Full corpus

- Scale `an-1` → 16,356 files (canon 9,414 / `atta-*` 6,731 / anya 210).
- ~~Commit the classifier script~~ ✅ done in P1 — since 2026-08-17
  `lib/domain/grouping_planner.dart` + `lib/domain/grouping_policy.dart` +
  `tool/plan_corpus.dart`.
- ✅ **The trailing-colophon defect is fixed** — detector plus correction,
  2026-08-19. BJT prints some sections' names *after* the text they name, and
  upstream took that closing line for the opening one, so every leaf in the run
  carried the previous unit's title over the next unit's body — a page that is
  wrong without looking wrong. Three pieces:
  - `lib/domain/slice_alignment.dart` finds them. A slice opening on a label is
    misaligned when it holds no running text at all — asked first, whatever the
    label says — or, where that label is not itself a number, when the first
    label below it *is* one, that second row being the leading label the
    coordinate should have pointed at.
  - `lib/domain/coordinate_planner.dart` derives where each should point, and
    `correctedTreeCoordinates` (`wisdom_shared`) freezes the answer:
    `FIGURES.correctedCoordinates` leaves, regenerated by
    `plan_corpus.dart --write-alignment` against the **raw** tree. A map rather
    than an edit to `tree.json`, which is vendored and overwritten by the next
    re-sync; and in `wisdom_shared` so the app inherits it.
  - `TipitakaTree.fromJson` applies it before anything slices, so the build,
    the reading order and both frozen snapshots all see one coordinate.
  `FIGURES.trailingColophonLeaves` is now **0**, and that is the value to watch:
  a colophon reappearing means a re-sync moved the defect and
  `--write-alignment` needs re-running. The whole `vp-pct-1-3-*` sekhiya block
  was affected — all seven vaggas, every rule in them.
- **The 2026-07-28 count of 77 was wrong in both directions**, settled
  2026-08-19 by reading the flagged pages. Five too high: `an-2-17-1/2/3`,
  `an-8-2-5` and `vp-prj-1` are correct, because those books print a leading
  title *above* its number rather than below it, which reads as the same shape.
  `_closesItself` separates them — a slice ending on its own
  `නිට්ඨිතං`/`සමත්තො` colophon contains a whole unit, where a trailing-colophon
  slice always ends mid-body — and the separation is total across the corpus,
  with nothing in between. But it was also **seven too low**: the *last* leaf of
  each affected vagga has no number below it, because the run has ended, so it
  answered "aligned" while holding its own closing label and nothing else.
  `vp-pct-1-3-1-10` rendered as a title over an empty page.
- ✅ **The stray dividers are fixed too**, 2026-08-19, by the same map under a
  second rule. `FIGURES.strayDividerLeaves` opened on a `භාණවාරං` recitation
  marker closing the division *above* — `kn-vv-4-7` is named
  `චතුරිත්ථිවිමානං` but began on `භාණවාරං දුතියං.`, with its own `4. 7.` on the
  next row. One row out rather than one unit, so `_correctDivider` moves the
  leaf onto its own number and the marker falls to the foot of the leaf before
  it, which is the bhāṇavāra it actually closes. Verified: `kn-vv-4-6` now ends
  on that line and `kn-vv-4-7` opens on `4. 7.`. Kept as its own rule because
  the leaves around a divider are already correct, where a colophon run moves
  as a body. `FIGURES.misalignedSlices` is now **0** and the build prints no
  warning at all.
- ✅ **`ap-vbh-18` was one section out on all ten leaves**, fixed 2026-08-20 by
  the same map under a third rule. The mirror of the colophon shape: there the
  coordinate lands too *late*, on the label closing a unit; here too *early*, on
  the body above. BJT leads each section of the ධම්මහදය විභඞ්ග with a bare
  number, and upstream anchored every leaf one row past the *previous* section's
  number, so each page carried its own title over the section before it and
  `ap-vbh-18-1` published as a number over an empty page.

  It was invisible to `--misaligned`, in two different ways, which is the part
  worth keeping. Leaves 2–10 open on a `paragraph`, and `verdictFor` ended the
  walk at the "is the opening row a label" guard. Leaf 1 opens on the bare
  number `1.`, and the numeric exemption returned "the ordinary shape" *before*
  the question that asks whether the slice holds a body. **A leading number
  leads something**; the exemption was answering a question nobody had asked
  yet. Question 1 now runs ahead of it — corpus-wide that changes exactly one
  verdict. (The blank-opening-row exemption still stands ahead of question 1,
  and stays: a blank row is not a heading printed over nothing, it is no
  heading.)

  `SliceMisalignment.strandedLeadingNumber` reads from the other end: the leaf's
  own leading number sitting at the *foot* of its slice, confirmed by the same
  own-name test the colophon branch uses. `_correctShiftedRun` then corrects the
  whole container, because the name test structurally misses the last leaf — the
  same hole the colophon shape has, here because `ap-vbh-18-10`'s slice closes on
  `විභඞ්ගප්පකරණං සමත්තං.` rather than a stranded number. It is **one** walk for
  both shapes, differing only in which slice holds the number a leaf should open
  on: the previous node's for a colophon run, the leaf's own for a stranded one.
  Nine coordinates moved;
  leaf 1's was already correct and emits no row, and it got its text back the
  moment leaf 2 moved.

  Verified over the whole corpus: this is the only container with the shape,
  both frozen snapshots regenerate byte-identical (**text moved, no URL did**),
  and `FIGURES.strandedLeadingNumberLeaves` is now **0**.
  `FIGURES.headingOnlyLeaves` went 7 → 8 → 7 across the two commits, and
  `FIGURES.thinSuttaPages` dropped by one, which was `ap-vbh-18-1`'s empty page.
- ℹ️ **Two leaves keep the *next* leaf's number as their last row** and are
  deliberately left alone (noted 2026-08-20): `an-4-3-1-5` closes on
  `4. 3. 1. 6{*}`, `sn-2-5-4-7` on `5. 4. 8–13.`. A one-row overshoot at the
  tail, the mirror of a stray divider — both slices are correctly cut and read
  correctly, and nothing on either page is wrong. They are the two candidates
  the stranded rule's own-name test rejects, which is what that test is for.
- ℹ️ **`FIGURES.headingOnlyLeaves` are not a defect and must not be "fixed".**
  Checked leaf by leaf 2026-08-19: in every one the leaf's name matches the
  heading its slice opens on *and* the next node's name matches the heading
  below it, so the coordinate is exactly right and the rows underneath belong
  to a sibling correctly named for them. The one leaf that later joined them and
  did *not* pass that check was `ap-vbh-18-1`, above — the slice alone cannot
  tell a bare heading from a starved one, and what convicted it was its
  siblings. Moving one would take text from that
  sibling — the very defect the correction removed. They are what BJT prints: a
  group title whose content is split across its siblings
  (`දුක්ඛසච්චනිද්දෙසවණ්ණනා` over `ජාතිනිද්දෙසො`), one of the book's own
  abbreviations standing in for two sections at once
  (`ආසව ගොච්ඡක කුසල දුකතික සදිසං`), or a recitation marker modelled as a node
  (`සන්ථතභාණවාරො`). They are counted apart from the defect total, listed by
  `--misaligned`, and never warned about.
- **Decision gate — deferred 2026-08-19.** Stub files vs Cloudflare Bulk
  Redirects for grouped-leaf clean URLs is still open and blocks nothing:
  neither works until there is a deploy on a custom domain, and a folded leaf's
  URL now answers an honest `404` in the meantime (backlog A1). The half they
  share is built — `plan_corpus.dart --redirects` writes `source,target` for
  every folded leaf, verified row for row against the built pages and their
  anchors. Still: **ask before emitting the stubs.**
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
3. **Stub files vs Bulk Redirects** — P6 gate, unchanged. Note P4 makes the
   *search* half of it moot: result rows for the grouped leaves link
   `…/<chapter>#<key>` directly and never need a redirect. The gate is now only
   about what a **pasted or inbound** `…/<key>` URL does.
4. **A sutta's other names.** Name-only search finds what BJT prints, so the
   Kālāma Sutta is reachable as කේසමුත්තිසුත්තං and not as කාලාම (P4 finding).
   An alias table would fix it and is editorial content the corpus does not
   carry — no owner, no source, not scheduled.

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
budget is **~9s** and the exhaustive run **~36s**, so `test/corpus_tools_test.dart`
now runs both and the whole suite finishes in ~45s. Each test just runs the tool
and expects exit 0; the assertions live in the tool itself.

They carry the `corpus` tag, declared in `static_site_generator/dart_test.yaml`:

| Command | Runs |
|---|---|
| `dart test` | everything, ~45s |
| `dart test -x corpus` | the 15 wiring cases only, under a second |

Still run the tools by hand when reviewing a change. A test says pass or fail;
only the printout gives you the page budget and what the rule would now say
about newly synced content.

The tree test's load-bearing case is **40 index-less siblings** — past the
32-element cliff where `List.sort` stops being accidentally stable. The real
corpus tops out at 23, so nothing in `assets/` would catch a regression here.

**Still uncovered by example-based tests:** the grouping classifier and the
slicer. Both are instead verified by whole-corpus tools — the stronger check
here and, now that they are tagged tests, the cheaper one too. The properties
that matter are corpus-wide invariants, not examples:

| Tool | Reports |
|---|---|
| `tool/plan_corpus.dart --check` | the four integrity questions the frozen snapshot can fail, plus the derivation identity — which, once those pass, can only catch a subtree no root can reach. Exit 1 on any. Tree-only, ~1 s. Run by `test/corpus_tools_test.dart` |
| `tool/plan_corpus.dart` | the same, plus the page budget owned by [`reading-units-and-grouping.md`](./reading-units-and-grouping.md), the Impact derivation as a self-consistency check, the ten worked subtrees that doc argues about, and what the rule would now say about newly synced content |
| the `an-1` build | 581 source entries → 581 rendered elements (nothing dropped or duplicated), and a build-twice diff that is empty |

**`--expect`'s locked page budget is gone (S2, 2026-08-17), and that is not a
weakening.** It landed 2026-08-06 to close a real "it prints, it does not
assert" gap, and it was the right guard while the rule ran at build time and one
edited character could move a URL. Freezing the verdicts removed the thing it
was guarding: nothing re-measures the counts, so they cannot drift on their own,
and new upstream content *should* add pages without failing CI.

What replaced it asks only questions with no judgment in them — every folded key
still names a leaf; its container still holds nothing but leaves, all in one
content file; the index-0 invariant holds; orphan containers stay at 0. It fires
on exactly one event: an upstream re-sync that renumbers `nodeKey`s, which is
the sync workflow's stop-the-line moment. Verified by hand-editing the snapshot
three ways — a key that names nothing, a first-child fold beside an unfolded
sibling, and one legitimate unfold — and confirming the first two exit 1 naming
the offending key, and the third moves the file set exactly as predicted.

For deliberate moves the review artifact is the git diff of
`grouping_snapshot.dart`: one line per sutta whose URL moved, which is a
stronger review than ten aggregate rows ever gave. `kn-thig-6` measuring
**exactly** 1,500 no longer needs an asserted row — `kn-thig` is a promoted book
and none of its leaves is measured at all.

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
| layout ids **and tokens** are each unique | duplicate ids (invalid HTML); duplicate tokens would make a layout unreachable from `?layout=` |
| every class named in a rule that mentions a `#L-…` radio is emitted by the template | a class renamed on one side only |
| every layout has at least one rule reaching `.content` | a layout with a radio and a button that changes nothing when chosen |
| every class named in a rule that mentions `:target` is emitted — `.chapter`, `.chapter-bar`, `.sutta` | the grouped-chapter filter dying, so every deep link shows the whole run |
| chapter `<section>`s are anchored by the bare nodeKey | search's `…/<chapter>#<leafKey>` links for the grouped leaves silently landing on the chapter head |

Both class checks **derive** their list from the sheet rather than holding one by
hand, and that is the point rather than a convenience. A hand-kept array covers
only what someone remembered to add — P4's dialog brought more — and matching a name
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
> way home and no route to search. Only the *layout group* stays gated, which is
> what frame 03 specifies and what `site_chrome.dart` documents.

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

> The fifteenth no longer applies: S2 retired `--expect` and its count list
> (§8.1). Its replacement was mutated the same way — a snapshot key that names
> nothing, and a first-child fold beside an unfolded sibling — and both exit 1
> naming the offending key.

> The last six were added on 2026-08-06 after a review of this commit, and four
> of them are why the class checks now derive their lists. The first version of
> this file **survived** `.content` renamed inside a single layout rule, and
> never looked at `.chapter` or `.chapter-bar` at all — the wrapper that does
> the filtering, one element out from the `.sutta` anchor the file already
> guarded. The mutation script lives in the session scratchpad, not the repo:
> it edits `lib/` in place, and a tool that rewrites source to prove a point
> should not be one keystroke from a stray run.

**Deliberately out:**

- **The slicer and the grouping rule.** Corpus-wide invariants, already checked
  the right way by `tool/verify_corpus_invariants.dart` and
  `tool/plan_corpus.dart --check` — see §8.1.
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

**What it does not cover — the JavaScript seam, open since P4.** The seam this
file guards is two *Dart* files disagreeing about a string. P4 added a third
language to the same disagreement, and **no test crosses that boundary yet.**

P4 shrank the surface as far as design allows: `site.js` spells no Sinhala, no
`/tipitaka/`, and no layout token, because every one of those arrives on a
`data-` attribute or is read off the radios' `value`. What is left cannot be
designed away, only asserted:

| Untested contract | How it fails |
|---|---|
| the index's **field order** vs. the JS reading it | search returns plausible results pointing at the **wrong sutta** — no error, anywhere. Mitigated for *caches* by the shared `?v=` token, not for a mismatched edit |
| the six DOM ids in `search_dialog.dart` vs. `getElementById` in the script | the dialog silently never opens, or its close button is drawn, focusable and dead |
| the eight `data-` attributes vs. the names the script reads | dead links, or `null` printed as a status line |
| `{n}` / `{shown}` in the count strings vs. the script's `replace` | the placeholder is announced literally |
| `.search[open]`'s `display` guard | the dialog renders open, in flow, on every page in the build |

The last two are exactly the bugs P4 shipped and caught by hand (see *What P4
found*), which is the argument for the table rather than against it: both were
invisible to `dart analyze`, to the existing suite, and to a page that looked
fine until it did not. A Dart test can read `assets/site.js` as a string and
assert these; that needs no JS runtime and no bundler.
