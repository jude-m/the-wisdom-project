# Scroll Positioning: Layout Switch vs Tab Switch

The `MultiPaneReaderWidget` manages scroll position in two distinct scenarios. They solve different problems using different strategies, but can conflict with each other.

## Architecture

There is a **single `ListView`** and a **single `ScrollController`** shared across all tabs. Switching tabs swaps the content shown in the same list — it does not create a separate scrollable per tab. This keeps memory low (only the active tab's content is in the widget tree), but requires manual save/restore of scroll positions.

## 1. Tab Switching — Save/Restore by Pixel Offset

**Problem:** User reads sutta A at scroll position 3500px, switches to tab B, then returns to tab A. They expect to be where they left off.

**Strategy:** Save and restore the raw pixel offset.

**Flow:**
1. Tab A -> Tab B triggers the `activeTabIndexProvider` listener.
2. `_saveScrollPosition(previous)` stores Tab A's `scrollController.offset` (e.g. 3500px) into the tab's state.
3. After Flutter rebuilds with Tab B's content (via `addPostFrameCallback`), `_restoreScrollPositionImmediate()` reads Tab B's saved offset and jumps there.

**Why pixels work here:** The layout hasn't changed — Tab A is still in the same layout mode as when the user left it. So pixel offsets map to the same content.

## 2. Layout Switching — Sync by Logical Entry Position

**Problem:** User is reading in side-by-side mode with entry #42 at the top of the viewport (at pixel 3500px). They switch to stacked mode. Entry #42 might now be at pixel 7000px because stacked mode is taller (Pali paragraph *then* Sinhala paragraph vertically, instead of side-by-side).

**Strategy:** Identify which logical entry is visible, then re-paginate from that entry.

**Flow:**
1. Layout change triggers the `activeReaderLayoutProvider` listener.
2. `_entryKeyRegistry.findTopVisibleEntry()` determines which `(pageIndex, entryIndex)` is at the viewport top.
3. `updateActiveTabPaginationProvider` resets pagination to **start from** that entry — changing *what* content is displayed.
4. `jumpTo(0)` — because the content now begins at the target entry, position 0 is the correct scroll position.

**Why pixels don't work here:** Different layouts render the same entry at different pixel offsets. 3500px in side-by-side and 3500px in stacked show completely different content.

### How EntryKeyRegistry Works

Each text entry rendered on screen registers a `GlobalKey` keyed by `(absolutePageIndex, entryIndex)`. When `findTopVisibleEntry` is called, it iterates all registered keys, uses `RenderAbstractViewport.getOffsetToReveal` to compute each entry's scroll offset, and returns the entry closest to the current viewport top. This gives a layout-independent "logical position" that can survive a layout switch.

### Why jumpTo(0) is Necessary After Layout Switch

After re-paginating from the target entry, the list content starts with that entry at index 0. Without `jumpTo(0)`, the scroll offset would remain at its old value (e.g. 3500px). If the new list is shorter than that, Flutter clamps to `maxScrollExtent` (the bottom). If longer, the user sees some random entry far below the intended one. `jumpTo(0)` aligns the viewport with the first item — which is now the entry the user was reading.

## The Conflict: Tab Switch That Also Changes Layout

Each tab remembers its own layout. Switching from a tab in stacked mode to a tab in side-by-side mode triggers **both** listeners:

1. **Tab listener** fires — wants to restore Tab B's saved pixel offset.
2. **Layout listener** fires — sees layout changed, wants to reset pagination and `jumpTo(0)`.

Without intervention, the layout listener would overwrite the tab listener's scroll restoration.

### Solution: `_suppressLayoutListener`

A boolean flag set to `true` at the start of a tab switch and cleared after the scroll restore completes:

```
Tab A (stacked) -> Tab B (side-by-side):
  1. _suppressLayoutListener = true
  2. Save Tab A's scroll position
  3. Schedule post-frame callback:
     a. _suppressLayoutListener = false
     b. Restore Tab B's saved pixel offset
```

The layout listener checks `!_suppressLayoutListener` and skips its logic during tab switches. This works reliably because Riverpod's `ref.listen` callbacks fire synchronously — the flag is guaranteed to be `true` when the layout listener runs in the same notification cycle.

## Summary

| | Tab Switch | Layout Switch |
|---|---|---|
| **Trigger** | User clicks a different tab | User changes layout mode |
| **Strategy** | Save/restore pixel offset | Find visible entry, re-paginate from it |
| **Why** | Same layout, pixels are valid | Different layout, pixels are meaningless |
| **Scroll action** | Jump to saved offset | Jump to 0 (content re-paginated to start at target entry) |
| **Conflict** | When a tab switch also changes layout, `_suppressLayoutListener` prevents the layout listener from interfering |

## Key File References

- `lib/presentation/widgets/multi_pane_reader_widget.dart` — main widget with both listeners
- `lib/presentation/widgets/reader/entry_key_registry.dart` — logical entry position lookup
- `lib/presentation/models/reader_layout.dart` — layout enum (paliOnly, sinhalaOnly, sideBySide, stacked)
- `lib/presentation/providers/tab_provider.dart` — tab state including per-tab scroll position and layout
