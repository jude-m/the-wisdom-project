# Both Mode: Migrate from Eager Column to Lazy ListView.builder

## Current State

In `lib/presentation/widgets/multi_pane_reader_widget.dart`, the "both" column mode (`ColumnDisplayMode.both`) uses:

```
SingleChildScrollView -> Column -> [all entry widgets]
```

This is an **eager** layout — every entry widget across all loaded pages is built and laid out on every rebuild, even if most are off-screen.

In contrast, `paliOnly` and `sinhalaOnly` modes use `ListView.builder`, which is **lazy** — it only builds widgets currently visible on screen.

## Impact

### Performance Cost
- **Rebuild scope**: Every time `searchState` changes (typing a character, navigating matches), or `splitRatio` changes (dragging the divider), the entire `Column` of all loaded entries is rebuilt.
- **Growth**: Infinite scroll keeps loading pages into `pageStart..pageEnd`. The `Column` grows without bound as the user scrolls. A document with 50 pages and ~20 entries per page = ~1000 entry widgets all built eagerly.
- **Memory**: All widget trees, `TextSpan` trees, and `TapGestureRecognizer` maps for off-screen entries remain in memory.

### Comparison
| Metric | paliOnly/sinhalaOnly | both mode |
|--------|---------------------|-----------|
| Builder | `ListView.builder` (lazy) | `Column` (eager) |
| Widgets built per frame | ~10-15 visible | ALL loaded entries |
| Memory growth | Bounded by viewport | Unbounded (grows with scroll) |
| Rebuild cost (search typing) | O(visible) | O(all loaded) |
| Rebuild cost (divider drag) | N/A | O(all loaded) |

## Why It's Currently Eager

The side-by-side layout requires **row-level alignment** — each Pali entry must sit next to its corresponding Sinhala entry. The current implementation achieves this with `_buildSplitRow` which creates a `Row` containing both entries in sized boxes.

With `ListView.builder`, items are independent — there's no built-in mechanism to ensure the left item (Pali) and right item (Sinhala) align in a single row. A naive two-column `ListView.builder` approach would cause misalignment because entries have variable heights.

## Proposed Implementation

### Approach: Single ListView.builder with paired-row items

Each item in the builder is a complete row (Pali + Sinhala side-by-side), reusing the existing `_buildSplitRow` pattern:

```dart
case ColumnDisplayMode.both:
  // Precompute flat list of items: page headers + paired entry rows
  final items = _computeBothModeItems(pages, entryStart);

  return ListView.builder(
    controller: _scrollController,
    padding: const EdgeInsets.all(24.0),
    itemCount: items.length + 1, // +1 for ParallelTextButton
    itemBuilder: (context, index) {
      if (index == 0) return const ParallelTextButton();
      final item = items[index - 1];
      return item.build(context, ...);
    },
  );
```

### Item Model

```dart
// Sealed class for the flat item list
sealed class _BothModeItem {}

class _PageHeaderItem extends _BothModeItem {
  final int pageNumber;
  _PageHeaderItem(this.pageNumber);
}

class _PairedEntryItem extends _BothModeItem {
  final Entry paliEntry;
  final Entry? sinhalaEntry;
  final int absolutePageIndex;
  final int entryIndex;
  _PairedEntryItem({
    required this.paliEntry,
    this.sinhalaEntry,
    required this.absolutePageIndex,
    required this.entryIndex,
  });
}
```

### Precomputation

The flat item list is computed once per build (O(n) where n = total entries) and passed to the builder. This replaces the current nested loops in `_buildBothModePages`:

```dart
List<_BothModeItem> _computeBothModeItems(
  List<dynamic> pages,
  int entryStart,
  int absolutePageStart,
) {
  final items = <_BothModeItem>[];
  for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
    final page = pages[pageIndex];
    final absolutePageIndex = absolutePageStart + pageIndex;
    final startEntry = pageIndex == 0 ? entryStart : 0;

    items.add(_PageHeaderItem(page.pageNumber));

    for (var i = startEntry; i < page.paliSection.entries.length; i++) {
      items.add(_PairedEntryItem(
        paliEntry: page.paliSection.entries[i],
        sinhalaEntry: i < page.sinhalaSection.entries.length
            ? page.sinhalaSection.entries[i]
            : null,
        absolutePageIndex: absolutePageIndex,
        entryIndex: i,
      ));
    }
  }
  return items;
}
```

### Divider Overlay Compatibility

The `ResizableDivider` overlay (`_buildDividerOverlay`) uses `Positioned.fill` inside a `Stack` and is independent of the scroll content. This works the same way with `ListView.builder` as with `SingleChildScrollView` — no changes needed.

### Search Highlight Integration

The `itemBuilder` callback would contain the same per-entry `hasMatchInEntry` check and `_currentMatchKey` assignment that `_buildBothModePages` currently has. The logic is identical, just moved inside the builder closure.

### Scroll-to-Match

`Scrollable.ensureVisible` works with `ListView.builder` the same way — the `GlobalKey` on the current match entry allows scrolling to it. If the match is outside the currently built range, the pagination expansion in `_scrollToCurrentMatch` ensures the page is loaded, then the post-frame callback scrolls to the keyed widget.

## Effort Estimate

- **Complexity**: Medium — the core layout logic already exists, it just needs restructuring
- **Files changed**: 1 (`multi_pane_reader_widget.dart`)
- **Risk**: The `_buildSplitRow` + `LayoutBuilder` pattern inside `itemBuilder` should work, but needs testing for:
  - Row height alignment (IntrinsicHeight may be needed if entries have different heights)
  - Divider overlay positioning during fast scroll
  - Scroll position preservation on tab switch
  - `_currentMatchKey` behavior with lazy building (widget may be disposed and rebuilt)

## Verification

1. Open a sutta in "both" mode
2. Scroll through many pages — verify smooth scrolling without jank
3. Drag the column divider — verify only visible rows rebuild
4. Use in-page search — verify highlights and navigation work
5. Switch tabs — verify scroll position is preserved
6. Open the same sutta in paliOnly mode — compare scroll smoothness
