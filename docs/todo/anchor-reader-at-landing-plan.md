# Anchor the reader at its landing row — plan

Branch `feat/search-pane-redesign`, written against the code at `0992a9c`,
2026-10-10. Decided, not started. Implement on a new branch from this one
when the user says go.

## Problem

A search hit or a `?e=` link opens a tab that should land on its row. Before
`16cf0f6` the tab's list *started* at that row, so nothing above it was built.
Since then the tab renders the whole unit from its top and reaches the row by
scrolling, and that costs everything above it:

- A lazy list can't know where row N starts without laying out the rows
  before it. On a far jump, `RenderSliverList` builds and lays out every page
  in between, in one frame.
- Side-by-side builds every page up to the row on purpose (`_extendToReveal`).

What goes wrong:

1. **Lag.** In stacked and Pali/Sinhala-only since `5f4e5be`; before that the
   reveal gave up after 10 small steps, so far rows were never reached.
   Side-by-side has paid it since `2015bfc`.
2. **Side-by-side never lands.** In the frame the text arrives, the reveal
   jumps to the row, then the slice listener's restore runs `jumpTo(0)`.
3. **Landing lost on a slow load.** The reveal's 10 retries run out while the
   spinner shows. Not seen on macOS: the text is in within one frame.
   Possible on web.
4. **Side-by-side drift.** With 2 and 3 fixed it lands, then slides away:
   `_PairHeightSync` pads the Pali side one frame after the jump. Confirmed:
   with the padding off it lands exactly.

Fix (a) skipped `_restoreScrollPositionImmediate` until the slice loaded. It
fixed 2 and 3, not 4, and was discarded uncommitted: the anchor doesn't need
it, because offset 0 is the landing row and the new restore (step 5) waits for
the rows it needs.

### Measured 2026-10-10

Profile build, macOS, 1440×900 unless marked, `ReaderScreen`'s own tap
sequence. "Frame" is the longest frame's build time. "Now" had fix (a)
applied; without it side-by-side opens at the unit's top. In the anchor
column the stacked rows are a prototype of step 2 and the side-by-side rows a
spike of step 3. Neither was kept.

| Hit | Now: to hit · frame · lands? | Anchor |
|---|---|---|
| `mn-1-1-1` (9 pages), near end, stacked | 113 ms · 30 ms · yes | 46 ms · 16 ms · yes |
| `dn-1-1` (40 pages), middle, stacked | 200 ms · 67 ms · yes | 52–75 ms · 23–30 ms · yes |
| `dn-1-1`, near end, stacked | 314 ms · 115 ms · yes | 52 ms · 23 ms · yes |
| `atta-dn-1-2` (73 pages), middle, stacked, 400 px wide | 367 ms · 148 ms · yes | 53 ms · 9 ms · yes |
| `mn-1-1-1`, near end, side-by-side | 109 ms · 62 ms · 4,298 px off | 49 ms · 23 ms · yes |
| `dn-1-1`, middle, side-by-side | 195 ms · 103 ms · 1,680 px off | 46 ms · 21 ms · yes |
| `dn-1-1`, near end, side-by-side | 319 ms · 162 ms · 8,008 px off | 58 ms · 30 ms · yes |
| `atta-dn-1-2`, middle, side-by-side | 367 ms · 181 ms · 1,771 px off | 56 ms · 21 ms · yes |

- Long frames are about ⅔ text layout and ⅓ widget build. Loading the unit
  (query, inflate, parse) takes about 5 ms.
- Debug is only about 1.5× profile, because text layout is native code.
- The spike also drops side-by-side's ~100 ms first frame, its opening window
  of 60 entry pairs, which every side-by-side open pays: `dn-1-1` from its top
  took 130 ms · 101 ms with the window, 53 ms · 15 ms in the spike.
- Scrolling up three screens from the hit stayed smooth in every layout, the
  spike included.

### Side-by-side selection, measured 2026-10-10

Scripted mouse, `dn-1-1` opened at a mid-sutta hit.

| Check | Now | Spike |
|---|---|---|
| Drag in one column, across the landing row | stays in its column | same |
| Drag that wanders into the other column | stays in its column | same |
| Double-click a word, then shift-click in the margin | the shift-click clears it | extends it, same column |
| Click in the margin, then Cmd+A | nothing | that column |
| Double-click a Sinhala word, then Cmd+A | the Sinhala column | the Sinhala column's built rows |
| Drag past the bottom edge | no auto-scroll | auto-scrolls, same column |

Not checked yet: shift+arrow keys, touch and handles, web, in-page search and
layout switch on the new pane, the existing integration tests.

## Flutter facts this rests on

Found during the spike; each cost a failed attempt.

- `Scrollable` puts its own selection container (private, in screen order)
  between a `SelectionArea` and the rows. A delegate above it that reorders
  children never sees the cells, so keeping a selection in one column is a
  gate on each cell, not an ordering.
- That container gives drag auto-scroll, and it sends its children
  synthesized edge events. So the gate takes its column from the pointer-down,
  not from selection events, which would flip it.
- After select-all it expects its first and last child to hold a selection:
  an assert in debug, a null error in release.
- A `GestureDetector(onTap:)` inside a `SelectionArea` wins plain clicks, so
  the selection never gets focus: no double-click word, no Cmd+A. A raw
  `Listener` doesn't join the gesture arena.
- Above the anchor, `minScrollExtent` is an estimate until those pages are
  built, so one `jumpTo(minScrollExtent)` stops short of the top.

## The change

Scroll offset 0 sits on the landing row. Pages above it are built only when
the reader scrolls up. `CustomScrollView.center` does this: slivers before the
center grow upward. Anything that changes height above the anchor (padding,
late layout) grows upward too, so the screen doesn't move.

Files: `lib/presentation/models/reader_tab.dart`,
`lib/presentation/providers/tab_provider.dart`,
`lib/presentation/providers/document_provider.dart`
(`activeLandingEntryProvider`), and in `lib/presentation/widgets/reader/`
`multi_pane_reader_widget.dart`, `stacked_pane.dart`,
`single_column_pane.dart` and `dual_column_pane.dart`.

1. **Tab.** `ReaderTab` keeps a persisted anchor `(page, entry)` in place of
   the one-shot landing (`landingPageIndex`/`landingEntryIndex`,
   `clearTabLanding`), and `scrollOffset` is measured from it (negative above
   it). Search hits and `?e=` links set it. Tree taps and next/prev leave it
   null, which means the unit's top. `ReaderTab` is Freezed and saved as
   JSON: keep the fields nullable (see its persistence warning) and rerun
   `build_runner`.
2. **Lazy panes** (`StackedPane`, `SingleColumnPane`). A `CustomScrollView`
   replaces the `ListView`, and the anchor page is split at the anchor row.
   One `SelectionArea` still wraps the whole view, so selection doesn't
   change. From the prototype:

   ```dart
   // (ap, ae): the anchor as (slice-local page, entry). With no anchor, one
   // outside the slice (a stale `?e=` link) or one on the unit's first row,
   // only the center sliver is built, holding the spacer and every page.
   // _pageItem builds one page, or its part from `start` / up to `end`.
   CustomScrollView(
     controller: scrollController,
     center: const ValueKey('below'),
     slivers: [
       // Grows upward from the anchor, nearest page first.
       SliverPadding(
         padding: padding.copyWith(bottom: 0),
         sliver: SliverList.builder(
           itemCount: ap + 2,
           itemBuilder: (context, i) {
             if (i == ap + 1) return spacer; // the action-button spacer
             // The anchor page's rows before the anchor, no page gap.
             if (i == 0) return _pageItem(context, ap, end: ae, gap: false);
             return _pageItem(context, ap - i);
           },
         ),
       ),
       SliverPadding(
         key: const ValueKey('below'),
         padding: padding.copyWith(top: 0),
         sliver: SliverList.builder(
           itemCount: slice.pages.length - ap,
           // The anchor row onward, no page number.
           itemBuilder: (context, i) => i == 0
               ? _pageItem(context, ap, start: ae, label: false)
               : _pageItem(context, ap + i),
         ),
       ),
     ],
   )
   ```

3. **Side-by-side** (`DualColumnPane`) becomes a lazy pane like step 2: one
   list of pair rows, `Row(Pali cell, gap, Sinhala cell)`, split at the anchor
   the same way, under one `SelectionArea`, so a drag crosses the landing row.
   - Each row lines up its own pair, so `_PairHeightSync` and `_AlignedEntry`
     (the drift), the 60-pair window and its growth, and `revealTarget` go.
   - The page-number pair is a row too. The divider overlay stays.
   - Each row watches the split ratio in its own `Consumer`, so a divider
     drag re-lays only the built rows.
   - The entry key moves from the Pali entry to the whole row.
   - A column gate keeps a selection in one column. A raw
     `Listener.onPointerDown` inside the area records the column of the press
     (left or right of the divider's center); a shift-click keeps it, so it
     extends. Each cell is a `SelectionContainer` with the gate below as its
     delegate, owned and disposed by the cell's state.
   - Select-all takes that column's built rows only, as stacked does.
   - The select-all branch leans on a Flutter internal, so a test must cover
     Cmd+A in each column.

   The gate, from the spike:

   ```dart
   /// In the active column, events pass through. In the other column the cell
   /// holds no selection and only says where the pointer lies, so the scroll
   /// view's selection walks past it.
   class _ColumnGate extends StaticSelectionContainerDelegate {
     _ColumnGate(this.column, this.active);

     int column;
     _ActiveColumn active; // { int? value; } set by the pane's Listener

     Rect get _rect => MatrixUtils.transformRect(
         getTransformTo(null), Offset.zero & containerSize);

     @override
     SelectionResult dispatchSelectionEvent(SelectionEvent event) {
       final owner = active.value;
       if (event is ClearSelectionEvent || owner == null || owner == column) {
         return super.dispatchSelectionEvent(event);
       }
       if (event is SelectAllSelectionEvent) {
         // Empty selection at the top-left: the scroll view's selection
         // container expects its first and last child to hold one.
         final start = _rect.topLeft;
         super.dispatchSelectionEvent(const ClearSelectionEvent());
         super.dispatchSelectionEvent(
             SelectionEdgeUpdateEvent.forStart(globalPosition: start));
         super.dispatchSelectionEvent(
             SelectionEdgeUpdateEvent.forEnd(globalPosition: start));
         return SelectionResult.none;
       }
       if (value.hasSelection) {
         super.dispatchSelectionEvent(const ClearSelectionEvent());
       }
       return switch (event) {
         SelectionEdgeUpdateEvent(:final globalPosition) => hasSize
             ? SelectionUtils.getResultBasedOnRect(_rect, globalPosition)
             : SelectionResult.next,
         GranularlyExtendSelectionEvent(:final forward) =>
           forward ? SelectionResult.next : SelectionResult.previous,
         DirectionallyExtendSelectionEvent(:final direction) =>
           switch (direction) {
             SelectionExtendDirection.forward ||
             SelectionExtendDirection.nextLine =>
               SelectionResult.next,
             SelectionExtendDirection.backward ||
             SelectionExtendDirection.previousLine =>
               SelectionResult.previous,
           },
         _ => SelectionResult.none,
       };
     }
   }
   ```

4. **Taps, every layout.** Any tap on the page clears the search highlight and
   closes the dictionary, as browsers do with a link-to-text highlight.
   Selection gestures keep working.
   - Now: stacked and Pali/Sinhala-only put `GestureDetector(onTap:
     onTapEmpty)` inside their `SelectionArea`, where it wins every click: in
     a scripted probe, double-click and Cmd+A did nothing there. Check this by
     hand before and after. Side-by-side puts it outside its areas, so only
     margin taps clear.
   - New: one raw `Listener` around the pane in `MultiPaneReaderWidget` calls
     `_clearAllHighlights` on pointer-up when the pointer stayed within the
     tap slop. It takes no click from the selection or a word. Up, not down:
     on a word tap the clear and the new word land in the same frame, so the
     dictionary sheet swaps its word instead of closing and reopening.
   - `onTapEmpty` and the three `GestureDetector`s go. `_clearAllHighlights`
     drops its `unfocus`: the selection now gets the click and clears itself.
     Check that on touch too.
5. **Reader widget.**
   - Restore clamps to `minScrollExtent`, and retries while the saved offset
     is above what's built.
   - Mode 1/Mode 2 and the app-bar tint read `extentBefore`, not `pixels`.
   - "Scroll to beginning" drops the anchor instead of scrolling (see the
     `minScrollExtent` fact above).
   - A reveal whose row isn't built re-anchors at it instead of stepping
     toward it: layout switch (the top visible row) and far in-page matches.
   - `_stepViewportToward`, `_revealTarget`/`_extendToReveal` and most retry
     code then go.
6. **Tests** (separate agent): landing in each layout; restore after a tab
   switch and after a restart with an anchor; layout switch; far in-page
   match; the side-by-side selection checks above, with Cmd+A in each column;
   tap-to-clear, double-click and Cmd+A in each layout.
7. **Measure** before and after, as below.

## How to measure and check

- Use `flutter drive --profile -d macos --driver=test_driver/integration_test.dart --target=<harness>`.
  `flutter test` has no profile mode. Run it outside the sandbox, and never
  run two macOS runs at once (they share a bundle id).
- In the harness:
  - Pass `semanticsEnabled: false` to `testWidgets`; the real app has no
    semantics tree unless an accessibility client asks for one.
  - Set `framePolicy = benchmarkLive` for the timed part.
  - Read frame build times with `addTimingsCallback`.
  - Read the hit's rect after the scroll settles.
- Timeline: use `traceAction(streams: ['Dart', 'Embedder', 'GC'])`. The
  default `all` floods the buffer with API events, and the frames you want
  are dropped.
- The macOS window must stay visible, or frames stop.
- Harness recipe (in `integration_test/`, helpers from `test_overrides.dart`):
  - Pump `ReaderScreen` in a `ProviderScope` with
    `BJTDocumentLocalDataSourceImpl` and an `InMemoryKeyValueStore` whose
    `StorageKeys.lastReaderLayout` is the layout. Await
    `navigationTreeProvider` and `readerUnitResolverProvider`.
  - Build a `SearchResult` with `SearchResultType.fullText`, the absolute
    `pageIndex`/`entryIndex`, the `nodeKey` and the unit's `contentFileId`.
  - Time `_ReaderScreenState._handleSearchResultTap`'s sequence:
    `openTabFromSearchResultProvider`, `ftsHighlightProvider.setForTab`,
    `saveRecentSearchAndDismiss`, `closeSearchProvider`. Landed means the
    text is in and the scroll has been still for 800 ms.
  - Find a row by its registry key: a `GlobalKey` whose `toString()` ends
    with ` entry_<page>_<entry>]`.
- Selection checks, scripted mouse:
  - Click with `tester.tapAt(…, kind: PointerDeviceKind.mouse)`. A
    double-click is two clicks 60 ms apart. After a clearing click, wait
    600 ms, or the next click counts as a double.
  - Shift-click: `sendKeyDownEvent(shiftLeft)`, click, `sendKeyUpEvent`.
    Cmd+A: `metaLeft` down, `keyA`, `metaLeft` up.
  - Read the selection from `lastSelectedTextProvider`. Strip ZWJ (U+200D)
    and collapse whitespace before comparing.
  - Auto-scroll: hold the drag just below the viewport, moving 1 px every
    30 ms.
