# Refactor: MultiPaneReaderWidget (1129 LOC → ~350 LOC orchestrator)

## Context

`multi_pane_reader_widget.dart` is a 1129-line god-widget that handles:
scroll management, pagination, 3 column layout modes, text selection/context menus,
entry building, split-pane resizing, action button visibility, dictionary lookup,
and in-page search coordination — all in a single `ConsumerStatefulWidget`.

The goal is to split it into focused, testable pieces while keeping the orchestration
logic (provider listeners, scroll controller, action button visibility) in the parent.

---

## Current Structure (by line range)

| Lines       | Concern                          | LOC  |
|-------------|----------------------------------|------|
| 56–142      | State, lifecycle, scroll fields  | ~87  |
| 144–265     | Scroll/navigation methods        | ~122 |
| 267–529     | `build()` — listeners + Stack    | ~263 |
| 535–608     | Selection & context menu         | ~74  |
| 610–761     | `_buildContentLayout` (3 modes)  | ~152 |
| 764–788     | `_clearAllHighlights`, `_handleWordTap` | ~25 |
| 793–890     | `_buildBothModePages`            | ~98  |
| 894–981     | `_buildSplitRow`, `_buildDividerOverlay` | ~88 |
| 983–1127    | `_buildPageNumber`, `_buildEntries`, `_buildEntry` | ~145 |

---

## Extraction Plan (4 new files)

### 1. `reader/single_column_pane.dart` (~100 lines)

**What:** The `paliOnly` and `sinhalaOnly` cases in `_buildContentLayout` are near-duplicates
(only differ by `paliSection` vs `sinhalaSection` and `enableDictionaryLookup`).

**Extract into:** A single parameterized `StatelessWidget`:

```dart
class SingleColumnPane extends StatelessWidget {
  final ScrollController scrollController;
  final List<ContentPage> pages;
  final int entryStart;
  final int absolutePageStart;
  final InPageSearchState searchState;
  final String languageCode;        // 'pi' or 'si'
  final bool enableDictionaryLookup;
  final GlobalKey currentMatchKey;
  final VoidCallback onTapEmpty;
  final void Function(String word) onWordTap;
  final Widget Function(BuildContext, SelectableRegionState) contextMenuBuilder;
  final void Function(SelectedContent?) onSelectionChanged;
}
```

**Saves:** ~100 lines (eliminates duplicated ListView.builder code)

---

### 2. `reader/dual_column_pane.dart` (~200 lines)

**What:** The `both` case from `_buildContentLayout` plus `_buildBothModePages`,
`_buildSplitRow`, and `_buildDividerOverlay`.

**Extract into:** A `ConsumerWidget` that watches `activeSplitRatioProvider` internally:

```dart
class DualColumnPane extends ConsumerWidget {
  final ScrollController scrollController;
  final List<ContentPage> pages;
  final int entryStart;
  final int absolutePageStart;
  final InPageSearchState searchState;
  final double splitRatio;
  final GlobalKey currentMatchKey;
  final VoidCallback onTapEmpty;
  final void Function(String word) onWordTap;
  final Widget Function(BuildContext, SelectableRegionState) contextMenuBuilder;
  final void Function(SelectedContent?) onSelectionChanged;
}
```

Contains: `_buildBothModePages`, `_buildSplitRow`, `_buildDividerOverlay`

**Saves:** ~190 lines

---

### 3. `reader/reader_entry_builder.dart` (~150 lines)

**What:** `_buildEntry`, `_buildEntries`, `_buildPageNumber` — these are pure data→widget
mappers with no state dependency. They only need `BuildContext` (for theme) and parameters.

**Extract into:** A utility class with static methods:

```dart
class ReaderEntryBuilder {
  static Widget buildEntry(BuildContext context, Entry entry, { ... });
  static List<Widget> buildEntries(BuildContext context, List<Entry> entries, { ... });
  static Widget buildPageNumber(BuildContext context, int pageNumber);
}
```

**Saves:** ~145 lines
**Bonus:** Used by both `SingleColumnPane` and `DualColumnPane`, avoiding duplication.

---

### 4. `reader/reader_selection_handler.dart` (~80 lines)

**What:** `_onSelectionChanged`, `_buildSelectionContextMenu`, `_currentSelectedText`.
These form a cohesive "text selection" concern.

**Extract into:** A mixin on `ConsumerState`:

```dart
mixin ReaderSelectionHandler on ConsumerState<MultiPaneReaderWidget> {
  String? currentSelectedText;
  void onSelectionChanged(SelectedContent? selection);
  Widget buildSelectionContextMenu(BuildContext context, SelectableRegionState state);
}
```

**Saves:** ~75 lines

---

## After Refactoring: What stays in `multi_pane_reader_widget.dart` (~350 lines)

The parent widget keeps its orchestration role:

1. **State fields** — `_scrollController`, `_currentMatchKey`, `_isScrolledDown`
2. **Scroll management** — `_onScroll`, `_loadMorePagesIfNeeded`, `_saveScrollPosition`,
   `_restoreScrollPosition`, `_scrollToBeginning`, `_navigateToPreviousSutta`, `_scrollToCurrentMatch`
3. **`build()`** — provider listeners, visibility flags, and the Stack layout
   (delegates to `SingleColumnPane` / `DualColumnPane` instead of inline building)
4. **`_clearAllHighlights`**, **`_handleWordTap`** (small, tightly coupled to providers)

The `_buildContentLayout` switch becomes:

```dart
Widget _buildContentLayout(...) {
  switch (columnMode) {
    case ColumnDisplayMode.paliOnly:
      return SingleColumnPane(languageCode: 'pi', enableDictionaryLookup: true, ...);
    case ColumnDisplayMode.sinhalaOnly:
      return SingleColumnPane(languageCode: 'si', enableDictionaryLookup: false, ...);
    case ColumnDisplayMode.both:
      return DualColumnPane(...);
  }
}
```

---

## File Tree After Refactoring

```
lib/presentation/widgets/
  multi_pane_reader_widget.dart          (~350 lines, down from 1129)
  reader/
    single_column_pane.dart              (~100 lines) NEW
    dual_column_pane.dart                (~200 lines) NEW
    reader_entry_builder.dart            (~150 lines) NEW
    reader_selection_handler.dart         (~80 lines) NEW
    text_entry_widget.dart               (existing, unchanged)
    in_page_search_bar.dart              (existing, unchanged)
    reader_action_buttons.dart           (existing, unchanged)
```

---

## Implementation Order

1. **`reader_entry_builder.dart`** — No dependencies, extract static methods first
2. **`reader_selection_handler.dart`** — Extract mixin, apply to state class
3. **`single_column_pane.dart`** — Uses `ReaderEntryBuilder`, replaces 2 switch cases
4. **`dual_column_pane.dart`** — Uses `ReaderEntryBuilder`, replaces `both` case + helpers
5. **Update `multi_pane_reader_widget.dart`** — Remove extracted code, wire up new widgets
6. **Update tests** — `multi_pane_reader_widget_test.dart` should still pass since the public API
   (`MultiPaneReaderWidget`) doesn't change

---

## Verification

- Run `flutter analyze` to check for lint issues
- Run existing tests: `flutter test test/presentation/widgets/multi_pane_reader_widget_test.dart`
- Manual testing: verify all 3 column modes render correctly, text selection works,
  dictionary lookup works, in-page search scrolls to matches, split pane resizing works
- No new tests will be created (per project rules — test agent handles that separately)

---

## Risk Assessment

- **Low risk**: All extractions are mechanical moves — no logic changes
- **Scroll controller sharing**: Passed as constructor parameter to child widgets (standard Flutter pattern)
- **Provider access**: `SingleColumnPane` doesn't need `ref` (receives callbacks); `DualColumnPane` needs `ref` for split ratio (uses `ConsumerWidget`)
- **Existing tests**: Widget test imports `MultiPaneReaderWidget` — public API unchanged
