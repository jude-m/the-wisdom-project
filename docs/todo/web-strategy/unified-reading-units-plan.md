# Unify app + static-site reading units around one shared rule

> **Status:** Phase A ready to start · Phase B deliberately deferred.
> **Decided 2026-07-29, filed 2026-08-03.**
> Supersedes `static-html-site-plan.md` §6's committed `grouping.json` (see A4).

## Context

The app and the static site disagree about **what a "document" is**.

- **App:** the unit is the *content file*. `ReaderTab` = `(contentFileId, pageStart, pageEnd, entryStart)`; opening any node jumps to its coordinate and paginates forward one printed page at a time to the end of the file (`lib/presentation/widgets/reader/multi_pane_reader_widget.dart:170`). Three consequences:
  - Every one of the 16,355 tree nodes has a `contentFileId` — including `sp` (සුත්තපිටක → `dn-1`) — so a folder or root tap dumps raw text. The reader has no TOC concept at all.
  - Only `navigateToPreviousSuttaProvider` exists. **There is no "next".**
  - Tab label and breadcrumb never update while scrolling (`_onScroll` touches only `pageStart/entryStart/scrollOffset`), so scrolling from Mūlapariyāya into Sabbāsava leaves the app claiming you are still in Mūlapariyāya.
- **Static site:** the unit is the *page* — `sutta` (own file) · `chapter` (grouped micro-run vagga) · `toc` (container: preamble + links), prev/next walking readable pages only.

**Decisions (2026-07-29):** the app adopts the site's bounded model at **strict parity**; grouped vaggas open in the app as a **chapter scrolled to the anchor**; the app rework is **deferred** until site review settles the vagga grouping; and **no new static/asset files may be added on the app side** — the shared truth is code, not a bundled data file.

### Where a book's opening headings go

The slice rule (a node owns rows from its coordinate up to the start of the next node **of any kind**) puts each heading on the page of the node it names. `an-1.json` page 0:

```
0 centered  සුත්තන්තපිටකෙ      ┐
1 centered  අඞ්ගුත්තරනිකායො     ├─ an        (container) coord (0,0)   → TOC page body
2 centered  පඨමො භාගො           ┘
3 heading   1. එකක නිපාතො       ─ an-1      (container) coord (0,3)   → TOC page body
4 heading   1. චිත්තපරියාදානවග්ගො ┐─ an-1-1   (container) coord (0,4)  → chapter page head
5 centered  නමො තස්ස …           ┘
6 heading   1. 1. 1.            ┐
7 paragraph එවං මෙ සුතං …        ├─ an-1-1-1 (leaf)      coord (0,6)   → its own page
8 paragraph නාහං භික්ඛවෙ …       ┘
```

Nothing is orphaned, nothing renders twice. The site already does this (`sitegen.dart` passes a container's own slice as `preamble`). **In the app these entries currently have no owner** — visible only if you happen to tap the container, and swallowed by the preceding leaf when you scroll past a boundary (1,418 leaves differ under the wrong rule; worst case 204,809 chars on `atta-kn-nett-3-3`). This change gives them a definite home for the first time.

---

## Phase A — one shared rule (do now, small)

The grouping decision is locked (`static-html-site-plan.md` §6/§13.1: deepest container, ≥6 leaves, max leaf <1,500 combined raw chars → **146 vaggas / 1,603 grouped leaves / 14,753 real pages / 16,356 total**) and the code exists — but it lives only in the generator, which re-derives it on every run. Move the rule, keep it derived.

### A1. Move the classifier into `packages/wisdom_shared/`

`static_site_generator/lib/domain/grouping_classifier.dart` → `packages/wisdom_shared/lib/src/grouping/`. It already depends only on `TipitakaTree` (shared) plus a per-file slice lookup (`ContentSlicer Function(String fileId) slicerFor`), so this is a move. Export from `wisdom_shared.dart`.

> Path note: this file lived at `lib/grouping/grouping_classifier.dart` when the plan was drafted; the whole-corpus work (`bc4d297`) moved it under `domain/`. Destination and reasoning unchanged.

**No data file, on either side.** Both surfaces compute the same verdicts from the same inputs — `tree.json` plus the content file each is already holding. In one repo with one `wisdom_shared`, they cannot drift.

### A2. Hand refinements as a `const` map, not an asset

Refinement while reviewing the site is expected. Record it as code in the same shared library:

```dart
/// Deliberate departures from the classifier's verdict. Code, not data:
/// the app must gain no new bundled asset, and this compiles into both
/// the generator and the app from one place.
const Map<String, GroupingOverride> groupingOverrides = {
  'kn-jat-1-1': GroupingOverride.group(
    why: 'BJT Jātaka pali is gāthās only; the searched stories are in atta-kn-jat-*',
  ),
};
```

`classify()` consults the map before returning. Editing one file changes both surfaces.

### A3. Keep the 146-key list as an *output*

`tool/classify_corpus.dart --write-csv` regenerates `docs/todo/web-strategy/grouped-vaggas-threshold-1500.csv` from the shared classifier (build plan §5.1 already promises this) and prints the near-threshold margins — `kn-thig-6` at exactly 1,500, `atta-an-10-1-1` at 1,490. It is a **review artifact**: read it to check a refinement, never parse it at build or run time. Fix the stale row (`vp-pct-1-3-5`, missing because the old script used the wrong slice rule).

### A4. Document the seam

Name the shared classifier as the single source in `static-html-site-plan.md` §6 and in `static-html-site-build-plan.md` §5, noting the no-app-assets constraint as the reason. `static-html-site-plan.md` still calls for a committed `grouping.json` in ten places — §6 (×2), §8 (×2), §10, §12 (×2), §13 (×3), which `grep -n 'grouping.json'` lists exactly. Every one is superseded by A1/A2. Sections rather than line numbers: the numbers first recorded here had drifted seven lines within two commits.

**Verify A:** `dart run static_site_generator/bin/generate.dart --root an-1` still emits 110 files (85 sutta + 12 chapter + 13 TOC), byte-identical to the current build. `classify_corpus` still reports 146 / 1,603 / 16,356. Add a temporary override, confirm the counts and the `an-1` file list move as predicted, revert.

---

## Phase B — the app rework (after site review settles the grouping)

Trigger: vagga grouping stops moving during static-site P2–P6.

### B1. Share the remaining logic

- **`SitePlan` / `PageKind`** (`static_site_generator/lib/domain/site_page.dart`) → `wisdom_shared`. It needs only `TipitakaTree` + a `classify` callback, so the move is mechanical. This carries the prev/next order and the chapter-swallows-its-leaves rule; the app must not re-derive either.
- **Split `ContentSlicer`** (`static_site_generator/lib/domain/content_slicer.dart`) into a shared coordinate half — entry-counts-per-page + the file's nodes → `(startPage,startEntry) → (endPage,endEntry)` — and a generator-side half that materialises `DocRow`s. The app maps the same range onto its `BJTDocument`. This is also what Phase A's classifier needs at app runtime, so the app pays for the slicer once and gets grouping for free.
- Cache verdicts and slice ranges per content file (the generator already does, via `SlicerCache`); the app computes them once per document load, over entries already parsed in memory.

### B2. Reader renders one page unit

`multi_pane_reader_widget.dart` + `document_provider.dart`:
- Provider resolving `nodeKey → SitePage` (kind + owning page key) from the shared `SitePlan`.
- `sutta` → render the bounded slice; **drop the run-to-end-of-file pagination** (`loadMorePagesProvider`, `_loadMorePagesIfNeeded`) for this kind. Printed page numbers stay.
- `chapter` → all leaves of the grouped vagga with anchors; tapping a grouped leaf opens the chapter scrolled to it (the app equivalent of `#fragment`).
- `toc` → **container preamble + child links** — the heading block shown above, then the list. 258 of 285 files carry preamble entries; rendering links only would delete that text from the app.

### B3. Navigation

- Add "next sutta" beside `navigateToPreviousSuttaProvider` (`lib/presentation/providers/previous_sutta_provider.dart`); both read `SitePlan.previousOf`/`nextOf`, so a chapter is one stop and crossing a vagga lands on a sutta, not a TOC — identical to the site.
- Tree-node tap (`tree_navigator_widget.dart:193`) and `openTabFromNodeKeyProvider` (`tab_provider.dart:450`) route through the page-unit resolver instead of `node.contentFileId` directly.
- When the neighbouring unit lives in another content file, resolve it on tap (its file loads anyway); the card label comes from the tree, which needs no verdict.

### B4. Landing from search and deep links

- `openTabFromSearchResultProvider` (`tab_provider.dart:~400`) — results already carry `nodeKey`; resolve to the owning page unit, scroll to `(pageIndex, entryIndex)`. A hit inside a preamble correctly lands on the container's TOC page.
- `?e=<page>.<entry>` becomes scroll-position-only: the unit comes from the nodeKey.
- In-page search becomes naturally unit-scoped — a simplification, not extra work.

### B5. Persistence and known data hazards

- `ReaderTab`'s `pageStart/pageEnd/entryStart` change meaning. Per the warning at `lib/presentation/models/reader_tab.dart:11-19`, bump `StorageKeys.openTabs` to `_v2` rather than misread saved tabs.
- **77 trailing-colophon leaves** (68 in `vp-pct-1-2`): BJT prints those names *after* their text, so the coordinate sits at the end of what it names and a bounded slice opens with the wrong title. Continuous scroll hides this today; bounded units expose it in the app exactly as on the site. Build the detector once, in shared code — static-site P6 owes it too.
- `ap-pat*` row misalignment (1,660 pages, all 7 files) is unchanged by this work.

**Verify B:** `flutter run -d macos`. Tap සුත්තපිටක → TOC, not DN-1 text. Tap `an` → the three-line title block + nipāta links. Tap Mūlapariyāya → text ends at the sutta boundary with prev/next; title and breadcrumb correct at every scroll position. Tap a leaf inside a grouped `an-1` vagga → chapter opens scrolled to it, vagga heading + *namo tassa* at the top. Open an FTS result matching mid-sutta, and one matching inside a preamble. Open `sammaditthi://tipitaka/<key>?e=<p>.<e>` for a grouped and an exploded leaf. Cross-check ~20 suttas against the generated HTML — same text, same boundaries, same prev/next targets. Per project convention, no tests unless asked.

---

## Constraints this plan respects

- **No new static/asset files on the app side** — the shared truth is Dart in `wisdom_shared`; the only committed artifact is a human-readable CSV under `docs/`, which nothing parses.
- Edition scope, URL grammar, thresholds, hosting topology and the zero-JS site model stay exactly as locked.
