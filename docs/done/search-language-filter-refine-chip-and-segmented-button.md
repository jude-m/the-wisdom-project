# Search language filter — refine-chip indicator + restyled SegmentedButton

## Context
The Content Language search filter (පාළි / සිංහල) lives in the Refine dialog. Two fixes:
1. The **Refine chip** only lights up for custom scope selections — it ignores a
   single-language narrowing, so that preference is invisible once the dialog closes.
2. The language toggle is a default `SegmentedButton`: visually unrelated to the
   app's filter pills, and the "at least one always on" rule is a silent no-op
   instead of a visible cue.

Decision: keep the **native Material `SegmentedButton`** (works on iOS — Flutter
draws it, not UIKit) but (a) restyle it with the quick-filter color tokens and
(b) disable the lone-selected segment so the lock is visible (dimmed-selected).

## Change 1 — Refine chip reflects the language preference
File: `lib/presentation/widgets/search/scope_filter_chips.dart` (`_ScopeFilterChipsState.build`)
- Default is both languages on (`searchInPali && searchInSinhala`, per `SearchState`).
- Compute `languageNarrowed = available.length >= 2 && !(searchInPali && searchInSinhala)`,
  watching `availableContentLanguagesProvider` (guards single-language editions).
- `hasActiveFilters = hasCustomScope || languageNarrowed;` → pass into `_RefineChip`
  (which already styles its active state). No change to `_RefineChip` itself.

## Change 2 — Restyle the SegmentedButton + lock the last segment
File: `lib/presentation/widgets/search/refine_search_dialog.dart` (`_buildLanguageSection`)
Keep all provider wiring (`availableContentLanguagesProvider`, the
`searchInPali`/`searchInSinhala` watches, `effectiveSelected` clamp, `<2` early return,
`setLanguageFilter`). Only the `SegmentedButton` rendering changes:
- Add `style: ButtonStyle(...)` with `WidgetStateProperty.resolveWith` for
  `backgroundColor` / `foregroundColor` / `side`, mapped to the `_ScopeChip` tokens:
  selected → `secondary` / `onSecondary` / `secondary` border; unselected →
  `surfaceContainerLow` / `onSurfaceVariant` / `outline`. Optional `shape` =
  `RoundedRectangleBorder(circular(100))` to echo pill roundness.
- Selected **and** disabled → dimmed: `secondary.withValues(alpha: 0.45)` fill +
  `onSecondary.withValues(alpha: 0.7)` label.
- `lockLast = effectiveSelected.length == 1;` then per segment
  `enabled: !(lockLast && isSel)` so the lone selected segment is non-tappable and
  rendered dimmed. Keep `showSelectedIcon: false`, `multiSelectionEnabled: true`,
  `emptySelectionAllowed: false`.

## Notes
- No shared-widget extraction; no Freezed/codegen changes.
- No tests written (project rule — test agent handles them). Flag for later:
  refine-chip active-on-narrowing, locked-segment non-tappable.

## Verification (manual)
1. Run app, search a query so the scope chip row shows.
2. Open Refine → LANGUAGE row is a connected bar in the pill colors, both selected.
3. Deselect one → the remaining segment is dimmed + non-tappable (locked); results relabel.
4. Close dialog → Refine chip is lit (primaryContainer + tune icon).
5. Reset / re-enable both → segments normal again, Refine chip back to default.
