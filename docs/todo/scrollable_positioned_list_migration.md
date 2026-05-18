# Reader Migration to `scrollable_positioned_list`

**Status:** Proposal / not started
**Scope:** Replace `ListView.builder` in the reader's lazy panes with
`ScrollablePositionedList` to remove the retry-based scroll-to-match plumbing.
**Trigger:** In-page-search "stops scrolling" after a layout switch (Brahmajāla
"siila" repro). Documented inline in
`multi_pane_reader_widget.dart::_ensureMatchVisibleWithRetry`.

---

## 1. TL;DR

The reader uses `ListView.builder` for `paliOnly`, `sinhalaOnly`, and `stacked`
layouts. `ListView.builder` is **pixel-addressed and lazy** — it only builds
items currently inside the viewport plus a thin `cacheExtent` (~250 px by
default). Anything outside that band has no `BuildContext`, so
`Scrollable.ensureVisible` can't reach it.

In-page-search drives the viewport by attaching a `GlobalKey` to each entry
and calling `Scrollable.ensureVisible(keyContext)`. After a layout switch the
listener resets pagination and `jumpTo(0)`s the controller, leaving the user
parked at the top of a *wide* pagination range. Matches on pages 1–4 are
*in the item list* but *not built*, so their keys' `currentContext` is `null`
and the scroll doesn't move. We currently work around this by stepping the
viewport one screen at a time until the page lazy-builds (Case (b) in
`_ensureMatchVisibleWithRetry`).

`ScrollablePositionedList` exposes index-addressed APIs (`ItemScrollController.
scrollTo(index)`, `jumpTo(index)`) and an `ItemPositionsListener` that streams
the visible item indices. With it, scroll-to-match becomes a one-line `scrollTo
(index)` regardless of whether the target is currently built, and "top visible
entry" becomes a stream lookup instead of a render-tree walk. The retry
mechanism, the viewport-stepping fallback, and most of the suppress-save
gymnastics can go.

---

## 2. The Problem

### 2.1 Repro (from the bug report)

1. Open Brahmajāla sutta, layout = **side-by-side**.
2. In-page-search **siila** → 10 matches. Next/Previous scroll cleanly.
3. Stop at the 5th match. Switch layout to **Stacked**.
4. The 5th match's entry is at the top of the new layout — correct.
5. Re-open the search bar. ↓ moves to match #1; viewport scrolls up. Fine.
6. ↓, ↓, ↓ … viewport scrolls down through a few matches, then **stops** at
   `චුල්ලසීල නිට්ඨිතං`. The match-index counter still advances and
   highlighting in `TextEntryWidget` still updates, but the scroll position
   does not change. After a full wrap-around it lands back at the stuck
   place.

### 2.2 What's actually happening

`multi_pane_reader_widget.dart::ref.listen<ReaderLayout>` (lines 492–525)
does on layout change:

1. Capture the top-visible entry from the *old* layout.
2. Reset pagination to a narrow range: `(pageStart=top.page, pageEnd=top.page+1,
   entryStart=top.entry)`.
3. Recompute search matches against the new layout.
4. `_scrollController.jumpTo(0)` and `_loadMorePagesIfNeeded(scheduleNextCheck:
   true)`.

So immediately after a switch, pagination is *narrow* (only the page
containing the formerly-top entry is loaded) and scroll is at 0.

The user re-opens search. ↓ moves to match #1. `_scrollToCurrentMatch` sees
`match.pageIndex < pageStart` and expands `pageStart` *backward* (now
`[0, 5)`). Scroll is still ~0. `ListView.builder` only builds the page items
overlapping the viewport plus `cacheExtent` — concretely, page 0 and maybe a
sliver of page 1.

Now ↓ steps to match #3 on, say, page 2. `match.pageIndex == 2` is inside
`[pageStart=0, pageEnd=5)` — so the OLD `_ensureMatchVisibleWithRetry` falls
into the "needs more pages" branch, calls `_loadMorePagesIfNeeded`, and that
is a **no-op** (pageEnd doesn't need to grow). The entry's `GlobalKey` has
no `currentContext` because `ListView.builder` never built that item, so
`Scrollable.ensureVisible` can't run. After 10 retries the function gives up.
Match index advances, highlight state changes in the entry widget — but the
viewport never moves.

### 2.3 Why pixel-addressed lazy lists make this hard

`ListView.builder` (`SliverList`) is **pixel-addressed**: its position is an
offset in scroll pixels. To compute "what offset corresponds to item N?" it
needs item N (and everything above it) to be laid out and measured. With
variable item heights — which the reader has, because page items contain
variable numbers of entries — there is no way to derive the pixel offset of
an unbuilt item.

Flutter's own answer to "scroll to an item I haven't built yet" is the
`scrollable_positioned_list` package (maintained by the `google/flutter.widgets`
repo): it is an **index-addressed** scrollable that internally measures items
on demand and animates by index rather than pixels.

---

## 3. Current Workaround (what ships today)

`_ensureMatchVisibleWithRetry` splits the unmounted-key failure into:

* **Case (a)** `match.pageIndex >= pageEnd` → call `_loadMorePagesIfNeeded()`
  to grow the item list, retry next frame.
* **Case (b)** `match.pageIndex in [pageStart, pageEnd)` but key not mounted
  → step `_scrollController` by one `viewportDimension` toward the match.
  The step is bounded by `pos.maxScrollExtent`, suppresses scroll-save during
  the intermediate jumps, and retries next frame. Direction is inferred from
  `EntryKeyRegistry.findTopVisibleEntry`.

This is correct, bounded (`_matchScrollMaxRetries = 10`), and well-commented.
It's the right *tactical* fix. But it accumulates accidental complexity:

- Two retry budgets to reason about (this one and `_restoreScrollWithRetry`).
- `_suppressScrollSave` flag toggled inside a recursion — easy to break on
  later edits.
- `EntryKeyRegistry.findTopVisibleEntry` walks every registered key calling
  `RenderAbstractViewport.getOffsetToReveal` — render-object math we wouldn't
  have to do if the list told us its positions.
- The whole `EntryKeyRegistry` (per-entry `GlobalKey` map) exists to support
  *two* features: (1) layout-switch top-entry capture, (2) scroll-to-match.
  Both go away with index-addressed scrolling.

---

## 4. Proposed Solution

Replace `ListView.builder` in `single_column_pane.dart` and `stacked_pane.dart`
with `ScrollablePositionedList.builder`. Keep `SingleChildScrollView+Column`
in `dual_column_pane.dart` *unchanged* — see §4.3.

### 4.1 What `scrollable_positioned_list` gives us

```dart
final itemScrollController = ItemScrollController();
final itemPositionsListener = ItemPositionsListener.create();

ScrollablePositionedList.builder(
  itemCount: pages.length + 1, // existing top spacer
  itemBuilder: (context, index) { /* same as today */ },
  itemScrollController: itemScrollController,
  itemPositionsListener: itemPositionsListener,
);

// Scroll-to-match — no retries, no key, works for unbuilt items:
itemScrollController.scrollTo(
  index: matchPageItemIndex,
  alignment: 0.3,                          // 30% from top, same as today
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeInOut,
);

// Top-visible entry — streamed, no render walk:
final positions = itemPositionsListener.itemPositions.value;
final top = positions
    .where((p) => p.itemLeadingEdge < 1)
    .reduce((a, b) => a.itemLeadingEdge > b.itemLeadingEdge ? a : b);
// top.index → page-item index
```

### 4.2 Why this fixes the bug (the *why*)

`scrollTo(index)` doesn't need the target item to be built. The package's
internal `SliverPositionedList` lazily resolves index→offset by laying out
just enough items to reach the target, then animates or jumps. So:

- **Case (b) disappears.** Asking to reveal page-index 3 when only page 0
  is built triggers an internal layout pass that builds 1, 2, 3 and reveals
  page 3. No external retry needed.
- **Case (a) disappears too.** `scrollTo` doesn't care about `pageEnd` — the
  layout listener can still narrow the slice for memory, but search jumps
  cease to depend on `_loadMorePagesIfNeeded`. (We still call it for the
  infinite-scroll-at-bottom case, just not as a scroll-to-match crutch.)
- **`EntryKeyRegistry.findTopVisibleEntry` can be replaced by an
  `ItemPositionsListener` snapshot.** That's one synchronous list operation
  instead of N render-object queries per call.

### 4.3 Benefits

| Today | After migration |
|---|---|
| Custom `EntryKeyRegistry` of GlobalKeys per (page, entry) | Built-in `ItemPositionsListener` per page-item |
| `_ensureMatchVisibleWithRetry` (~55 lines, two cases, bounded retry) | Single `itemScrollController.scrollTo(...)` call |
| `_loadMorePagesIfNeeded` invoked as a scroll-to-match crutch | Only invoked for genuine bottom-of-viewport infinite scroll |
| Layout-switch top-entry capture via reveal-offset math | `itemPositionsListener.itemPositions.value` snapshot |
| `_suppressScrollSave` flag toggled inside a recursion | No more programmatic intermediate jumps |
| Search-to-match depends on cacheExtent / lazy build timing | Independent of cacheExtent |

Secondary wins:

- `_restoreScrollPositionImmediate` could move to **index + leading-edge
  fraction** instead of raw pixels. Cross-layout restore would become
  layout-independent (a side-by-side offset of 1240px and a stacked offset
  of 2480px both become "page 5, 0.0" — same logical location). This is the
  same insight the layout listener already encodes ("change WHAT is rendered,
  not WHERE to scroll").
- Predictable memory: the list's own caching is index-based; the visible
  window is reliably scoped.

### 4.4 Caveats

- Package is by `google/flutter.widgets` but lives outside Flutter SDK; one
  more dep to keep on a Flutter version we test against.
- Does not support **reverse layout combined with sliver appbars** (we use
  neither — fine).
- `SelectionArea` and `GestureDetector` wrap the scrollable as today; no
  selection-handling change expected, but verify (see §5).
- Does **not** apply to `dual_column_pane`: that pane uses
  `SingleChildScrollView+Column` because it needs row-aligned Pali/Sinhala
  heights. Migrating it is a separate (and bigger) effort tracked in
  `docs/todo/both_mode_lazy_builder.md`. So side-by-side keeps its current
  scroll-to-match behavior, which already works (the whole Column is built,
  every key is mounted, no Case (b)).

---

## 5. How To Do It

### Phase 0 — Dependency

`pubspec.yaml`:

```yaml
dependencies:
  scrollable_positioned_list: ^0.3.8   # check pub.dev for latest
```

`flutter pub get`. No codegen needed.

### Phase 1 — Wrapper

Create `lib/presentation/widgets/reader/positioned_list_controller.dart`:

```dart
class PositionedListController {
  final ItemScrollController items = ItemScrollController();
  final ItemPositionsListener positions = ItemPositionsListener.create();

  /// Returns the page-item index whose leading edge is at or above
  /// the viewport top — i.e., the "currently reading" item.
  int? topVisibleIndex() {
    final snapshot = positions.itemPositions.value;
    if (snapshot.isEmpty) return null;
    final visible = snapshot.where((p) => p.itemTrailingEdge > 0);
    if (visible.isEmpty) return null;
    return visible
        .reduce((a, b) => a.itemLeadingEdge <= b.itemLeadingEdge ? a : b)
        .index;
  }
}
```

This intentionally mirrors `EntryKeyRegistry.findTopVisibleEntry`'s
contract so the layout listener can be migrated with a one-line change.

### Phase 2 — Migrate `single_column_pane.dart`

Replace `ListView.builder(...)` with `ScrollablePositionedList.builder(...)`.
The `itemBuilder` body is unchanged. Pass `positionedListController.items`
and `positionedListController.positions` instead of `scrollController`.

Note: `ScrollablePositionedList` does *not* use a `ScrollController`. The
existing `_scrollController` in `MultiPaneReaderWidget` becomes a
`PositionedListController`. Keep the field name short — many call sites.

### Phase 3 — Migrate `stacked_pane.dart`

Same change as Phase 2. The +1 top spacer item stays.

### Phase 4 — Rework `MultiPaneReaderWidget`

In `multi_pane_reader_widget.dart`:

1. **Scroll-to-match.** Replace `_scrollToCurrentMatch` + the entire
   `_ensureMatchVisibleWithRetry` machinery with:

   ```dart
   void _scrollToCurrentMatch(InPageSearchState s) {
     final m = s.currentMatch;
     if (m == null) return;
     final pageStart = ref.read(activePageStartProvider);
     final pageEnd   = ref.read(activePageEndProvider);
     // Still expand the slice if match falls outside loaded range
     // (we keep pagination as a memory bound).
     if (m.pageIndex < pageStart || m.pageIndex >= pageEnd) {
       ref.read(updateActiveTabPaginationProvider)(
         pageStart: math.min(m.pageIndex, pageStart),
         pageEnd:   math.max(m.pageIndex + 1, pageEnd),
         entryStart: m.pageIndex == suttaStartPage
             ? suttaStartEntry  // same clamp as current fix
             : 0,
       );
     }
     // The +1 accounts for the top spacer item.
     _list.items.scrollTo(
       index: (m.pageIndex - pageStart) + 1,
       alignment: 0.3,
       duration: const Duration(milliseconds: 300),
       curve: Curves.easeInOut,
     );
   }
   ```

   Delete `_ensureMatchVisibleWithRetry`, `_matchScrollMaxRetries`, and the
   Case (b) viewport-step logic.

2. **Layout-switch top entry.** Replace
   `_entryKeyRegistry.findTopVisibleEntry(_scrollController)` with
   `_list.topVisibleIndex()`. The result is the page-item index → translate
   to absolute `pageIndex` by adding `pageStart - 1` (subtracting the spacer).

3. **Entry-level capture (page+entry vs page-only).** Today the registry
   tracks per-*entry* keys so layout-switch can preserve the entry, not
   just the page. Since `ScrollablePositionedList` is page-item granularity,
   we need to keep the entry-within-page index. Two options:

   - **Cheap:** keep `EntryKeyRegistry` *only* for "which entry is at the
     top within the top-visible page", a single lookup at switch time. No
     retries, no scroll-to-match coupling. Most of the registry's footprint
     goes away because we no longer call into it for every search match.
   - **Cleaner:** replace per-entry GlobalKeys with a single
     `RenderObject`-based measurement at switch time inside the top page
     item. One callback at the switch instant rather than N keys living the
     whole time.

   Recommend starting with the cheap option to keep the migration small.

4. **Scroll restoration.** `_restoreScrollWithRetry` currently does pixel
   `jumpTo(saved)` with retries because `maxScrollExtent` is small on cold
   load. Replace `ReaderTab.scrollOffset` semantics with `(pageItemIndex,
   leadingEdge)` and use `items.jumpTo(index, alignment)`. This is a real
   data-model change — see §7.4.

   *Alternative:* leave restoration on pixel semantics for now and only
   migrate scroll-to-match. The retry survives in `_restoreScrollWithRetry`
   but disappears from `_ensureMatchVisibleWithRetry`. Phased migration is
   fine; we can ship Phase 4.1–4.3 alone.

5. **`_loadMorePagesIfNeeded` trigger.** Today it's called from `_onScroll`
   when within 200 px of `maxScrollExtent`. With
   `ScrollablePositionedList`, watch `itemPositionsListener.itemPositions`
   for the last item's trailing edge approaching 1.0 (one viewport from
   end). Same intent, different signal.

### Phase 5 — Delete dead code

- Most of `EntryKeyRegistry` (or all of it, if Phase 4.3 picks the cleaner
  option).
- `_ensureMatchVisibleWithRetry`, `_matchScrollMaxRetries`, the suppress-save
  toggles inside it.
- The per-entry `GlobalKey` plumbing in `SingleColumnPane`, `StackedPane`,
  `dual_column_pane.dart` (the registry param goes away).

### Phase 6 — Verify in browser

Per `CLAUDE.md`, drive the bug repro by hand:

1. Brahmajāla, side-by-side, search "siila", advance to match #5.
2. Switch to Stacked. Re-open search. Step through all matches with ↓ from
   match #1 to last and back to match #1. Viewport must follow every match.
3. Same with ↑.
4. Same starting from `paliOnly` → `sinhalaOnly` (different match-count
   ratios — see §6.1).
5. Restart the test with a longer sutta (e.g. DN-1's commentary if loaded)
   to exercise more pages between matches.

---

## 6. Test Scenarios

### 6.1 Already covered by the suite

**Unit — `test/presentation/providers/in_page_search_provider_test.dart`**
- ✅ `openSearch` toggles `isVisible` and retains query on close
- ✅ `clearQuery` resets raw/effective/matches/index
- ✅ Debounce — empty clears immediately, non-empty defers, rapid typing
  keeps only the last
- ✅ `nextMatch` / `previousMatch` wrap (both directions, no-op when empty)
- ✅ `onTabClosed` re-indexes; `clearAll` empties; per-tab independence

**Integration — `integration_test/layout_switch_test.dart`**
- ✅ "Top-visible entry survives a full layout cycle and updates on
  re-scroll" — exercises the layout listener's entry-capture path. Covers
  `EntryKeyRegistry.findTopVisibleEntry` → `topVisibleIndex` equivalence.
- ✅ "Layout switch recomputes in-page search matches against new layout"
  — paliOnly/sinhalaOnly/sideBySide round-trip on match *counts*. Locks in
  the recompute side (orthogonal to scrolling).

**Integration — `integration_test/in_page_search_test.dart`**
- ✅ Match the query, advance/wrap, counter reads correctly (lines 125+).
- ✅ Singlish conversion → matches (lines 180+).
- ✅ Per-tab search state survives tab switches (lines 217+).
- ✅ **Stepping forward through matches scrolls the viewport** (line 277).
  This is the closest existing test to the bug. It runs in the default
  (paliOnly) layout where the bug doesn't reproduce because pagination
  isn't reset, so it would pass even with the bug. Migration must keep
  this test green.
- ✅ Close/clear retains-vs-resets behavior (lines 393, 431).
- ✅ Tab close cleans search state (lines 468, 513).

**Integration — `integration_test/scroll_restoration_test.dart`**
- ✅ Tab switch round-trip restores scroll, fresh tabs start at 0, closed
  tabs clear state. Migration to index-based restoration (Phase 4.4) must
  keep these green.

### 6.2 NOT covered today — add as part of this work

**The exact bug — load-bearing:**
- ❌ *"Stepping through matches after layout switch scrolls every match
  into view"*: in a sutta with ≥5 matches across ≥4 pages, set layout to
  side-by-side, advance to match #5, switch to Stacked, re-open search,
  step through all matches forward and back. After each `next`/`previous`,
  the controller's reported top item index must equal the match's page
  item index (within 1 for the 0.3-alignment offset).
- ❌ *Same as above with `paliOnly → stacked` and `stacked → paliOnly`*.
- ❌ *Match outside `[pageStart, pageEnd)` after a layout switch*: assert
  that pagination still expands AND viewport follows. (Today's Case (a)
  vs Case (b) merger — both must work post-migration.)

**Layout-switch top-entry, broader coverage:**
- ❌ Switch with a *mid-page* entry (not entry 0) at the top — current
  test starts from the document top. Make sure `topVisibleIndex` +
  intra-page entry index resolve correctly.
- ❌ Switch when scroll is between two page items (split viewport).

**Scroll restoration with index semantics (if Phase 4.4 ships):**
- ❌ Save offset in side-by-side, reload app cold, layout is now stacked
  → expected: lands on the same logical entry, not the same pixel offset.
  This is a semantic improvement worth a new test.

**Regression bounds:**
- ❌ Search with no matches doesn't drive `scrollTo` (assert
  `itemScrollController` was never invoked when matches are empty).
- ❌ Rapid `next` taps don't enqueue conflicting `scrollTo` animations
  (the package coalesces — assert by snapshotting the listener stream).

### 6.3 Manual / exploratory checks (not auto-tested)

- Text selection across a page boundary still works (`SelectionArea`
  semantics with the new scrollable).
- Dictionary bottom-sheet opening doesn't fight the new scroll machinery.
- Web (Chrome/Safari) and mobile (iOS/Android) all behave — the package
  has had Cupertino-bounce edge cases in older versions; pin to a known-
  good range.
- Cold-load on web: the document arrives after first frame; ensure
  `items.isAttached` is checked before `scrollTo` (the package throws
  otherwise — easy to miss in a postFrameCallback flow).

---

## 7. Other Considerations

### 7.1 Effort estimate

- Phase 0–3 (dep + two pane migrations): ~half day.
- Phase 4 (rework `MultiPaneReaderWidget`): ~1 day. Most of the time is
  re-reading the layout listener and infinite-scroll wiring carefully.
- Phase 5 (deletes): trivial once Phase 4 lands.
- Tests: ~half day to add §6.2's missing scenarios.

A phased landing is realistic: Phase 4.1–4.3 (scroll-to-match only) in
one PR; Phase 4.4 (index-based restoration) in a follow-up that ships the
data model change for `ReaderTab.scrollOffset`.

### 7.2 What stays the same

- The search provider (`in_page_search_provider.dart`) doesn't move at
  all. The recompute, the visibility gating from the recent staged fix,
  and the per-tab state map are independent of how the widget scrolls.
- `dual_column_pane` keeps its eager `SingleChildScrollView+Column`. The
  bug never reproduced there because every entry is built — `ensureVisible`
  finds a mounted context immediately.

### 7.3 Risks

- **`ScrollablePositionedList`'s internal sliver is different from
  `SliverList`.** Anything that introspects the scrollable (a
  `NotificationListener`, custom `ScrollPhysics`, a `Scrollbar` widget
  expecting a `ScrollController`) needs adapting. Audit before the PR.
- **Animation interplay.** `scrollTo` runs its own animation. Concurrent
  `_loadMorePagesIfNeeded` triggered by reaching the bottom won't fight
  it (different driver) but the user-visible animation duration may
  change subtly — verify against current 300 ms.
- **`itemPositions` stream timing.** It updates *after* layout — reading
  it inside a layout-switch listener will see *old* values until the next
  frame. Today's `findTopVisibleEntry` has the same constraint, so this
  is parity, not regression. Worth a comment at the call site.
- **Cross-platform**: confirm package supports current Flutter version on
  web + mobile. Pin the version in `pubspec.yaml`.

### 7.4 Data-model knock-on for restoration

`ReaderTab.scrollOffset: double` was always a leaky abstraction — pixel
offsets are layout-dependent. The clean replacement is
`{ pageItemIndex: int, leadingEdge: double }`. That's a Freezed change
plus a migration in whatever persistence layer holds tabs. Recommend
deferring this until Phase 4.4 and pairing it with a written migration
note. The Phase 4 stub above keeps pixel restoration intact so this
isn't a blocker.

### 7.5 What NOT to do

- Don't migrate `dual_column_pane`. It's out of scope and has its own
  open initiative in `docs/todo/both_mode_lazy_builder.md`. Doing both
  at once doubles the surface area of this PR.
- Don't delete `EntryKeyRegistry` until Phase 4.3 picks an option for
  the within-page entry capture. Removing it prematurely silently
  regresses cross-layout top-entry alignment.
- Don't change `Either<Failure, T>` flows or anything in `domain/` /
  `data/`. This is a presentation-layer refactor end-to-end.

---

## 8. Rollback

If the migration is shipped and a critical regression is found post-
release:

1. Phase 4.1–4.3 are a single commit pair (pane migration + reader
   rewiring). Revert restores the retry-based path and the bug.
2. Phase 4.4 (data model) — keep the new fields backward-compatible:
   write both `scrollOffset: double` (pixel) and `pageItemIndex` /
   `leadingEdge` for one release. Rollback then drops the new fields
   without losing persisted state.

A feature flag is overkill — this is widget machinery, not user-facing
behavior toggle. A clean revert commit is sufficient.

---

## 9. References

- Package: <https://pub.dev/packages/scrollable_positioned_list>
- Upstream repo: <https://github.com/google/flutter.widgets>
- Companion doc: `docs/todo/both_mode_lazy_builder.md` (side-by-side
  pane's separate laziness problem)
- Current workaround: `multi_pane_reader_widget.dart::_ensureMatchVisibleWithRetry`
  Case (b) — read its docstring for the full Flutter-side rationale.
- Bug repro: Brahmajāla "siila" steps in §2.1 above.
