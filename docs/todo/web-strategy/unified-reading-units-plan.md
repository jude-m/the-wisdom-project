# Unify app + static-site reading units around one frozen snapshot

> **Status:** Phase A ready to start · Phase B deliberately deferred.
> **Decided 2026-07-29, filed 2026-08-03. Reworked 2026-08-09: verdicts frozen into a generated snapshot; the hand-override map this plan first proposed is gone (see "Why frozen").**
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

## Phase A — one frozen snapshot (do now, small)

The grouping decision is locked (`static-html-site-plan.md` §6/§13.1: deepest container, ≥6 leaves, max leaf <1,500 combined raw chars → **146 vaggas / 1,603 grouped leaves / 14,753 real pages / 16,356 total**) — but it is re-measured from the text on every run, and the measurement sits on a knife edge. Freeze the verdicts into shared code; demote the classifier to a sync-time advisor.

### Why frozen — the measurement has no safe place to draw a line (measured 2026-08-08)

The classifier run over all 1,165 measured vaggas, by longest-leaf chars:

```
 1000–1249  ██████████████████████████████ 30       vaggas per 250-char bucket
 1250–1499  ██████████████████████████████████████ 38
 1500–1749  ██████████████████████████████████████ 38   ← the line is here
 1750–1999  ███████████████████████████████████████ 39
 2000–2249  ████████████████████████ 24
```

The line sits in the densest region of the whole distribution — a vagga every ~6.5 chars. Every datapoint from 1448 to 1558:

```
1448 1456 │ 1485 1489 1490 ‖1500‖ 1504 1508 1509 │ 1529 1529 │ 1558
                               └ kn-thig-6 — ON the line; one edited char flips it
```

Candidate placements, all bad:

| line at | drift margin | flips vs today |
|---|---|---|
| 1,500 (today) | 10 down / **0 up** | — (`kn-thig-6` exactly on it) |
| 1,502 (i.e. `<=`) | ±2 | `kn-thig-6` groups; the knife edge is mirrored, not removed |
| 1,520 | ±10 | 4 vaggas / 36 suttas |
| 2,266 (first gap ≥40 chars) | ±20 | **101 vaggas / 1,134 suttas lose their own pages** — voids "famous suttas keep own pages" |

So *any* measured rule stays one resync away from a flip, and the `--expect` lock only converts silent breakage into recurring human decisions. Also rejected:

- **Hand-override map** (this plan's first design): human-curated exceptions bolted onto a live rule — every unlisted vagga stays exposed, and the list only grows.
- **Structural-only rule** (leaf count / tree shape, nothing a typo can move): would group all 1,165 candidates — buries substantial suttas.

**Decision (2026-08-09): stop measuring at build time.** Snapshot today's verdicts; a resync may change page *contents*, never page *structure*.

### A1. Generate the snapshot into `wisdom_shared`

`classify_corpus.dart --write-snapshot` emits `packages/wisdom_shared/lib/src/grouping/grouping_snapshot.dart`, exported from `wisdom_shared.dart`:

```dart
/// GENERATED — the 146 vaggas rendered as one chapter page, frozen from the
/// classifier's 2026-08-09 full-corpus run. Every other container explodes.
/// Regenerating or editing this file is a deliberate act with URL
/// consequences; a resync must never touch it.
const Set<String> groupedVaggaKeys = { 'an-1-1', /* … */ };
```

Generated *code*, not an asset: strict parity means the app must read the same snapshot, the app may gain no new bundled file, and a `const` compiles into both surfaces from one place. Absent key = exploded, which makes new content self-handling: a container the snapshot has never heard of gets a page per sutta — the safe direction (a wrong explode costs thin pages; a wrong group buries named texts). Grouping a *new* micro-run later is a deliberate snapshot edit, never an obligation.

**Regeneration is the supported way to move the cutoff.** The snapshot is always re-derivable from the rule: change `GroupingClassifier.maxLeafChars`, rerun `--write-snapshot`, and the git diff of `grouping_snapshot.dart` *is* the impact review — every key added or removed is one vagga whose URLs change. Freezing removes the *accidental* path to a structure change (resync drift), not the deliberate one; a regenerate ships with the rebuilt site in a single commit, and the with-stubs total (16,356) never moves regardless of where the cutoff lands.

### A2. Demote the classifier to sync-time advisor

The classifier stays in `static_site_generator/` and stops running at build and app runtime. After a re-sync, `classify_corpus.dart` becomes a *report*: which new containers the rule would group (proposals), and which frozen verdicts it now disagrees with (informational — the snapshot wins). The `--expect` policy lock dies with the knife edge: the policy rows in `_locked` (`grouped vaggas`, `grouped leaves`, `real pages`, `with stubs`, both `nearest … chars`) and the whole `_lockedKeys` map guard a decision that no longer exists at build time. Their replacement is an integrity check with no judgment in it — every snapshot key must still exist in the tree as a deepest, single-content-file container; `orphan containers: 0` stays. `corpus_tools_test.dart`'s lock test keeps its shape and becomes the integrity test. The check fires only when upstream renumbers `nodeKey`s: the one event no local design survives, and the sync workflow's stop-the-line moment.

### A3. The CSV stays a human review artifact

`tool/classify_corpus.dart --write-csv` keeps regenerating `docs/todo/web-strategy/grouped-vaggas-threshold-1500.csv` — now from the snapshot plus fresh measurements, so a reviewer can see how far each frozen verdict has drifted from what the rule would say today. Read by humans, parsed by nothing.

### A4. Document the seam

Name the snapshot as the single source in `static-html-site-plan.md` §6 and in `static-html-site-build-plan.md` §5, noting the no-app-assets constraint as the reason. `static-html-site-plan.md` still calls for a committed `grouping.json` in ten places — §6 (×2), §8 (×2), §10, §12 (×2), §13 (×3), which `grep -n 'grouping.json'` lists exactly; every one is superseded by A1. The knife-edge commentary goes in the same sweep — the exactly-1,500 margin note in `grouping_classifier.dart` and the nearest-to-line rows in `_locked` document a fragility A1 removes.

**Verify A:** `--write-snapshot` emits exactly the 146 keys today's classifier reports, and `dart run static_site_generator/bin/generate.dart --root an-1` still emits 110 files (85 sutta + 12 chapter + 13 TOC), byte-identical to the current build — same verdicts, different source. Remove one key from the snapshot, confirm the counts and that vagga's file list move as predicted, restore.

---

## Phase B — the app rework (after site review settles the grouping)

Trigger: vagga grouping stops moving during static-site P2–P6.

### B1. Share the remaining logic

- **`SitePlan` / `PageKind`** (`static_site_generator/lib/domain/site_page.dart`) → `wisdom_shared`. It needs only `TipitakaTree` + the snapshot lookup, so the move is mechanical. This carries the prev/next order and the chapter-swallows-its-leaves rule; the app must not re-derive either.
- **Split `ContentSlicer`** (`static_site_generator/lib/domain/content_slicer.dart`) into a shared coordinate half — entry-counts-per-page + the file's nodes → `(startPage,startEntry) → (endPage,endEntry)` — and a generator-side half that materialises `DocRow`s. The app maps the same range onto its `BJTDocument`. The slicer serves bounded rendering only; grouping verdicts are compiled in via the snapshot.
- Cache slice ranges per content file (the generator already does, via `SlicerCache`); the app computes them once per document load, over entries already parsed in memory.

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

- **No new static/asset files on the app side** — the shared truth is generated Dart in `wisdom_shared`; the CSV under `docs/` stays human-only, parsed by nothing.
- **Verdicts are frozen** — a resync may change what pages *say*, never which pages *exist*. Only a deliberate snapshot edit, or genuinely new content, moves URLs.
- Edition scope, URL grammar, hosting topology and the zero-JS site model stay exactly as locked.
