# Top Performance Killers — Audit & Backlog

> **Status:** Backlog (perf TODO worklist — pick items from here to plan/implement)
> **Source:** Full-project performance code review (static, traced through `lib/`),
> plus an interaction-jank investigation addendum (2026-06-05).
> **Related:**
> - `docs/todo/perf-fts-snippet-text-loading.md` — full plan for **#2** (per-hit JSON reload).
> - `docs/todo/perf-search_label_and_tree_lookup_followups.md` — the old item **#4**
>   (`_buildNodeMap` rebuilt per search) now lives there as its item 2.

All findings are based on actual code paths. Each item lists where it lives, how it
hurts, the fix, the expected gain, effort, and blast-radius on existing flows.

---

## Summary

| # | Issue | Effort | Impact to flows |
|---|---|---|---|
| 1 | Tree navigator full re-render on every expand / select / language change | Medium | Low |
| 2 | — *moved to `perf-fts-snippet-text-loading.md` (own plan)* | — | — |
| 3 | All JSON parsing runs on the UI isolate (tree.json 4.18 MB; every sutta) | Medium | None |
| 4 | — *moved to `perf-search_label_and_tree_lookup_followups.md` (item 2)* | — | — |
| 5 | Search widgets watch the entire `searchStateProvider` | Low–Medium | None |
| 6 | `Entry.plainText` getter is not cached | Low | None |
| 7 | `withPaliConjuncts` re-runs on every rebuild for every label | Low | None |
| 8 | Per-word `TapGestureRecognizer` allocation in `TextEntryWidget` | High | Medium |
| 9 | Unbounded document cache in `BJTDocumentRepositoryImpl` | Low | None |
| 10 | `SingleChildScrollView` for "Top Results" + no `RepaintBoundary` in lazy lists | Low | None |
| A1 (interaction) | Font scale routed through the **global** `ThemeData` | Low–Medium | Medium |

Bonus findings (B1–B4) and the interaction-jank addendum (A1) follow the main list.

---

## Top 10 performance killers

### 1. Tree navigator full re-render on every expand / select / language change

**Where:** `TreeNodeWidget.build` (`lib/presentation/widgets/navigation/tree_navigator_widget.dart:147-149`)
calls `ref.watch(expandedNodesProvider)`, `ref.watch(selectedNodeProvider)`,
`ref.watch(navigationLanguageProvider)` and recursively renders all `childNodes`.
Tipitaka has thousands of nodes.

- **How it affects performance:** Each expand/select tap mutates the Set → every
  `TreeNodeWidget` in the tree rebuilds and recomputes `displayName.withPaliConjuncts`.
  On a deep tree this can be 10–50 ms+ jank per chevron tap on mid-range Android, and
  tap latency feels mushy.
- **How to prevent:** Replace whole-set watches with select-based scoped watches:
  `ref.watch(expandedNodesProvider.select((s) => s.contains(node.nodeKey)))` and the
  same for selected/language. Cache `withPaliConjuncts` per node (Expando or memo).
  Also wrap each row in a `KeyedSubtree` + `RepaintBoundary`.
- **Gain:** 5–20× faster expand/collapse; sub-frame chevron taps; visibly smoother
  navigator scroll.
- **Effort:** Medium
- **Impact to existing flows:** Low — pure rebuild-locality fix; no public API change.

### 2. — Moved out of this list

This was `TextSearchRepositoryImpl._loadTextForMatch` re-reading & re-parsing the whole
sutta JSON for every FTS hit. It now has a dedicated implementation plan in
`docs/todo/perf-fts-snippet-text-loading.md`, which covers both the native/client fix
(group-by-file + parse-once + LRU + optional isolate) and the remote/web server path.
Tracked there to keep the detailed plan in one place.

### 3. All JSON parsing happens on the UI isolate

**Where:** `tree.json` is 4.18 MB, parsed via `rootBundle.loadString` + `json.decode` in
`TreeLocalDataSourceImpl.loadNavigationTree`
(`lib/data/datasources/tree_local_datasource.dart:25-26`). Every sutta JSON is parsed the
same way in `BJTDocumentLocalDataSourceImpl.loadDocument`.

- **How it affects performance:** Cold-start parse of `tree.json` blocks the first frame
  for 100–400 ms on mid-range Android / older iPhones. Each sutta open re-blocks the UI
  thread proportional to file size.
- **How to prevent:** Wrap `json.decode` + the subsequent entity parsing in `compute()`
  (or `Isolate.run` on newer SDK). For `tree.json` specifically, pre-parse to a binary
  format (e.g. msgpack, or just a flatter Dart-friendly JSON shape — the current schema
  needs a second pass through `_buildTreeStructure`).
- **Gain:** First frame appears 100–400 ms sooner; sutta opens become jank-free.
- **Effort:** Medium
- **Impact to existing flows:** None — same data, just moved off the UI isolate.

### 4. — Moved out of this list

This was `TextSearchRepositoryImpl._buildNodeMap` being rebuilt on every search call.
It is the **same issue** as item 2 (🔴) in
`docs/todo/perf-search_label_and_tree_lookup_followups.md`, which now carries the full fix:
reuse the data layer's **existing** cached index via `NavigationTreeRepository.getNodeByKey`
instead of rebuilding `_buildNodeMap`. Tracked there to avoid two sources of truth.

### 5. Search panel & in-page search widgets watch the entire `searchStateProvider`

**Where:** `SearchResultsPanel` (`lib/presentation/widgets/search/search_results_panel.dart:38`),
`GroupedFTSTile` (line 52), `RecentSearchOverlay` (line 45), `ScopeFilterChips` (line 42)
all do `ref.watch(searchStateProvider)`.

- **How it affects performance:** `SearchState` is a huge Freezed object that mutates on
  every keystroke (`rawQueryText`, `effectiveQueryText`, `isLoading`, `fullResults`, …).
  Every keystroke rebuilds the entire results panel, every `GroupedFTSTile`, every chip —
  even when only `rawQueryText` changed.
- **How to prevent:** Replace each call with
  `ref.watch(searchStateProvider.select((s) => <specific field>))`. The panel only needs
  `isLoading`, `selectedResultType`, `groupedResults`, `fullResults`, `effectiveQueryText`,
  `isPhraseSearch`, `isExactMatch`, `countByResultType`. Each watcher should pick exactly
  what it renders.
- **Gain:** 2–5× fewer rebuilds per keystroke; typing in the search bar stops jank-locking
  the results panel.
- **Effort:** Low–Medium
- **Impact to existing flows:** None — same data, finer-grained subscriptions.

### 6. `Entry.plainText` getter is not cached

**Where:** `lib/domain/entities/content/entry.dart:45-50` — runs 3 `replaceAll` operations
on `rawText` every access.

- **How it affects performance:** `plainText` is called inside
  `reader_entry_builder.buildEntry` (lines 46, 62, 81, 107) once per entry per build, and
  inside `in_page_search_provider._findAllMatches` for every entry in the sutta during
  in-page search. With ~50 pages × ~10 entries × 2 languages = 1000+ calls per layout
  switch or scroll-triggered rebuild.
- **How to prevent:** Cache like `markedRanges` does — using the same `Expando<String>`
  pattern so the `const` constructor stays intact.
- **Gain:** Cuts a hot allocation hotspot on every reader rebuild; speeds up in-page search
  compute by ~30–50%.
- **Effort:** Low
- **Impact to existing flows:** None — internal getter caching.

### 7. `withPaliConjuncts` re-runs on every rebuild for every label

**Where:** `applyConjunctConsonants` (`lib/core/utils/pali_conjunct_transformer.dart:59-108`)
executes 5 `replaceAll` + 2 `replaceAllMapped` (touching pattern applied twice) per call.
Used by `TreeNodeWidget` (line 156), `_SearchResultTile` (line 615), `GroupedFTSTile`
(line 95), `_BreadcrumbWidget`, `_TabItem`, etc., none of which cache the result.

- **How it affects performance:** Tree node display names get re-transformed on every node
  rebuild (compounding with #1). Search result titles re-transform on every keystroke
  (compounding with #5). The cost grows linearly with the number of items the user sees.
- **How to prevent:** Cache via memoization keyed by `String` (a top-level
  `LRUCache<String, String>`), or push the transform up into a Freezed-derived field that's
  computed once at parse time.
- **Gain:** Removes the dominant per-frame string work in 3 different screens.
- **Effort:** Low
- **Impact to existing flows:** None — pure caching.

### 8. Per-word `TapGestureRecognizer` allocation in `TextEntryWidget`

**Where:** `lib/presentation/widgets/reader/text_entry_widget.dart:194-219` — one recognizer
per word, disposed + recreated whenever text changes.

- **How it affects performance:** The reader can render dozens of entries × dozens of words.
  Cold-loading a Dīgha Nikāya sutta builds 1000s of recognizers. Each is an Object + listener
  list + Flutter gesture-arena registration — both allocation pressure and gesture-routing
  overhead per tap.
- **How to prevent:** (a) Use a single `TapGestureRecognizer` at the entry level and resolve
  the tapped word from the tap position (`RenderParagraph`'s `getPositionForOffset`).
  (b) Only attach recognizers when `enableTap && onWordTap != null` — already true, but
  additionally short-circuit for Sinhala entries upstream.
- **Gain:** Big memory drop on suttas; faster `ListView` item-build; smoother scroll.
- **Effort:** High
- **Impact to existing flows:** Medium — touches the dictionary-tap UX; needs a careful
  regression pass.

### 9. Unbounded document cache in `BJTDocumentRepositoryImpl`

**Where:** `lib/data/repositories/bjt_document_repository_impl.dart:11, 27` —
`Map<String, BJTDocument>` never evicts. Documents are large (deeply nested
`BJTDocument → BJTPage → BJTSection → Entry`).

- **How it affects performance:** Over a long session the user can browse hundreds of suttas;
  every parsed document stays resident even after the tab/provider is disposed. This pairs
  poorly with the provider-layer `autoDispose` + `keepAlive` because the repo cache outlives
  the provider. Memory monotonically grows → background OOM kills on mobile.
- **How to prevent:** Replace `_cache` with the existing `LRUCache` (config e.g. 20 documents).
  Or drop the repo cache entirely and rely on the Riverpod `keepAlive`.
- **Gain:** Stable long-session memory; prevents Android background kills; faster GC pauses.
- **Effort:** Low
- **Impact to existing flows:** None — caller-transparent.

### 10. `SingleChildScrollView` for the "Top Results" tab + no `RepaintBoundary` in lazy lists

**Where:** `SearchResultsPanel._buildTopResultsTabContent`
(`lib/presentation/widgets/search/search_results_panel.dart:123`) wraps a `Column` of every
group inside a `SingleChildScrollView`. Reader `SingleColumnPane` and `StackedPane` use
`ListView.builder` (good) but don't wrap items in `RepaintBoundary`.

- **How it affects performance:** Top Results panel builds + lays out every group up front
  (defeats lazy rendering for big result sets). In the reader, any state change (FTS
  highlight, in-page match index) repaints every visible page rather than just the affected
  one — observable as paint-time spikes on sutta-heavy suttas.
- **How to prevent:** (a) Use `ListView.builder` (or slivers) for Top Results content.
  (b) Wrap each `ListView.builder` item in `RepaintBoundary` in `single_column_pane.dart`,
  `stacked_pane.dart`, and search list builders. (c) Also wrap individual `TextEntryWidget`s
  when they sit inside large rebuilding trees.
- **Gain:** Smoother scroll under highlight/animation; predictable frame times on long results.
- **Effort:** Low
- **Impact to existing flows:** None — Flutter idioms.

---

## Bonus findings

### B1. First-launch DB copy reads the entire DB into memory

`dict.db` (174 MB) and `bjt-fts.db` (99 MB) are loaded with
`rootBundle.load(...).buffer.asUint8List()` then `writeAsBytes`
(`lib/data/datasources/dictionary_local_datasource.dart:40-44`,
`lib/data/datasources/fts_local_datasource.dart:62-67`).

- **Why it matters:** Transient ~275 MB allocation peak on cold install of a mobile device.
  Risk of OOM on low-RAM phones.
- **Fix:** Stream from the asset via `rootBundle.load` + chunked write, or copy directly from
  the asset bundle's file (`AssetManager` / native plugins like `flutter_asset_loader`).

### B2. `HighlightedFtsSearchText` re-creates `SearchMatchFinder` + normalizes text on every build

`lib/presentation/widgets/search/highlighted_fts_search_text.dart:66-71`.

- **Why it matters:** One result tile typically rebuilds 3–5× per panel update. The finder +
  position-map build is O(text length).
- **Fix:** Cache by `(matchedText, effectiveQuery, isPhraseSearch, isExactMatch)` inside the
  widget; or hoist computation into a Provider keyed on the result ID.

### B3. Active scroll listener fires `setState` + provider write on every pixel

`lib/presentation/widgets/reader/multi_pane_reader_widget.dart:106-143`.

- **Why it matters:** `_onScroll` reads/writes Riverpod state (`readerScrolledUnderProvider`),
  schedules debounce timers, and calls `setState` on every callback. Although guarded, it
  still walks state on every scroll tick (hundreds of times per second on trackpad).
- **Fix:** Throttle via `Scheduler.addPostFrameCallback` / Timer-based throttle for
  `_syncScrolledUnder`; promote the threshold transitions to a `ValueNotifier` consumed via
  `ValueListenableBuilder` so it doesn't dirty the whole reader.

### B4. AppBar repaints on every scroll due to `readerScrolledUnderProvider`

`lib/presentation/screens/reader_screen.dart:116`,
`lib/presentation/widgets/search/search_bar.dart:156`.

- **Why it matters:** The full `Scaffold` rebuilds (and the search bar) when the tint flips.
  Visible as small frame stalls on fast scrolls.
- **Fix:** Use a `ValueListenableBuilder<bool>` inside a thin AppBar-tint widget so only the
  colored container rebuilds.

---

## Why these are the priorities

In rough order of perceived user impact:

1. **#2 + #3** ship as a bundled "search & sutta-open are fast" upgrade — they remove the
   worst UI-thread stalls users see today. (#2 now has its own plan in
   `perf-fts-snippet-text-loading.md`; old #4 moved to
   `perf-search_label_and_tree_lookup_followups.md`, item 2.)
2. **#1 + #5** make the two most-touched UIs (tree navigator and search panel) feel
   responsive instead of mushy.
3. **#6 + #7** are tiny, low-risk caching wins that compound across every screen.
4. **#8 + #9** are foundations for a long session without memory growth or scroll jitter.
5. **#10** restores the lazy-render and paint-locality contracts that Flutter expects.

**Quick wins to land first:** #6, #7, #9 — mechanical, measurable, and don't touch the UI tree.

---

## Addendum (2026-06-05) — Interaction-jank investigation

The audit above is a static review optimised for cold-start / UI-thread stalls. A follow-up
investigation into reported **interaction** jank (font-size changes and divider dragging
janking "like crazy", worst on low-/mid-end web) surfaced one finding that outranks
everything above for that class of symptom but was **not** in the original list. Ranked #1
for perceived interaction smoothness on the reader.

### A1 (interaction). Font scale is routed through the global `ThemeData`

**Where:** `fontScaleProvider → currentThemeDataProvider`
(`lib/core/theme/theme_notifier.dart:124-132`) rebuilds a brand-new `ThemeData` on any scale
change, and `MaterialApp.theme` watches it (`lib/main.dart:170,198`). The font-size slider
(`lib/presentation/widgets/app/settings_menu_button.dart:205`) calls `setScale` on every drag
tick (no `onChangeEnd` / no debounce — only the step-rounding dedupes equal values).

- **How it affects performance:** Each effective font-scale step swaps `MaterialApp.theme`,
  so **every** widget in the tree re-inherits `Theme.of(context)` and re-lays-out its text.
  Font size travels through the single most global object in the app. In the reader's "both"
  mode this compounds with the eager `Column` (see `both_mode_lazy_builder.md`) — all ~1000
  entry widgets re-layout at once, and on CanvasKit web every Sinhala glyph re-rasterises into
  the glyph atlas. Net: dragging the font slider triggers an app-wide relayout per step →
  visible jank, worst on low-/mid web. This is fixable rebuild waste, **not** a CanvasKit floor.
- **How to prevent:** Stop sending font scale through global `ThemeData`. Keep `ThemeData`
  font-scale-independent and have reader text widgets read `fontScaleProvider` at the leaf
  (scoped select-watch) so a scale change repaints only the text, not the whole app. Add
  `onChangeEnd` / debounce to the slider (or apply on release) so mid-drag ticks don't each
  trigger an app-wide relayout. Pairs naturally with the both-mode lazy `ListView` migration
  (`both_mode_lazy_builder.md`), which caps the relayout at the ~15 visible rows.
- **Gain:** Eliminates the dominant interaction-jank source — the font slider goes from
  whole-app relayout per step to text-only repaint. Largest single perceived-smoothness win
  for the reading screen; directly resolves the reported "font size janks like crazy" symptom.
- **Effort:** Low–Medium
- **Impact to existing flows:** Medium — changes how text sizing is applied app-wide. Needs a
  pass to confirm every surface that currently relies on the theme's scaled text styles still
  scales correctly (reader + non-reader surfaces like settings/menus). Best landed together
  with the both-mode lazy builder.
