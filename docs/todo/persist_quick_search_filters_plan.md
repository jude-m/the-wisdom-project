# Persist Quick Search & Dictionary Filters

## Goal
Remember the user's **static quick-filter** selections across app launches:

- **Search scope chips**: All / Sutta / Vinaya / Abhidhamma / Commentaries / Treatises
- **Dictionary filter chips**: All / Sinhala / English

**Excluded:** *Refine* (custom sub-node or custom dictionary-subset selections). Those
remain session-only.

## Decisions (confirmed with user)
1. **Refine → Reset to All.** The moment the user makes a custom Refine selection, the
   saved static filter is *removed*, so the next launch starts at "All".
   Implemented by: on every filter change, **write** the value when it is a pure
   chip/static selection, otherwise **remove** the stored key.
2. **Persist in both dictionary locations**, applying the same static-only rule:
   - Search-panel "Definitions" tab filter (`SearchState.selectedDictionaryIds`)
   - Reading-mode dictionary bottom sheet (`bottomSheetDictionaryFilterProvider`)

   The bottom sheet only exposes Refine, so it will only ever persist when the chosen
   set *happens to equal* a static group (all-Sinhala / all-English / All) — an arbitrary
   custom subset clears the stored key, consistent with the rule.

## Why this design
- Both search filters already live in one place: `SearchState.scope` and
  `SearchState.selectedDictionaryIds`, managed by `SearchStateNotifier`.
- The "is this a static/chip-only selection?" logic already exists and is reused
  verbatim — no new domain logic:
  - `ScopeOperations.isChipSelectionOnly(scope)`
  - `!DictionaryFilterOperations.hasCustomSelections(ids)`
- The persistence pattern is copied from `LastReaderLayoutNotifier`
  (`lib/presentation/providers/last_reader_layout_provider.dart`): inject
  `KeyValueStore`, hydrate **synchronously** in the constructor, write inline on change.
  `keyValueStoreProvider` is already initialized/overridden in `main.dart`, so **no
  main.dart wiring is needed**.

## Storage keys (`lib/core/storage/storage_keys.dart`)
```dart
/// JSON list of Tipitaka scope node keys for search quick-filter chips
/// (e.g. ["sp"]). Only static chip selections are persisted; a custom Refine
/// selection removes this entry. Absent = "All".
static const searchScope = 'search_scope_v1';

/// JSON list of dictionary IDs for the search-panel quick-filter chips
/// (Sinhala/English). Static-only; custom selections remove it. Absent = "All".
static const searchDictionaryFilter = 'search_dictionary_filter_v1';

/// JSON list of dictionary IDs for the reading-mode dictionary bottom sheet.
/// Only persisted when the selection equals a static group. Absent = "All".
static const bottomSheetDictionaryFilter = 'bottom_sheet_dictionary_filter_v1';
```

## Changes

### 1. `SearchStateNotifier` (`lib/presentation/providers/search_state.dart`)
- Add a `KeyValueStore _store` constructor param.
- Hydrate initial state from storage via a static `_initialState(_store)` that loads
  & **validates** the saved scope (must still be chip-only) and dictionary IDs (must
  still exist in `DictionaryFilterOperations.allIds`); unknown/invalid → treated as unset.
- Add two private persist helpers:
  - `_persistScope(scope)` → write if `ScopeOperations.isChipSelectionOnly`, else `remove`.
  - `_persistDictionaryIds(ids)` → write if `!DictionaryFilterOperations.hasCustomSelections`, else `remove`.
- Call them from the existing mutators:
  - scope: `setScope`, `toggleScopeKeys`, `selectAll`, `clearFilters`
  - dictionary: `setDictionaryFilter`, `toggleDictionaryKeys`, `selectAllDictionaries`, `clearFilters`
- `clearSearch()` re-seeds from the *current* in-memory filters instead of
  `const SearchState()`, so clearing the query text doesn't silently drop the
  user's visible filter selection.

### 2. `searchStateProvider` (`lib/presentation/providers/search_provider.dart`)
- Pass `ref.read(keyValueStoreProvider)` into the notifier (use `read`, not `watch`,
  matching `LastReaderLayoutNotifier` — the store is a singleton).

### 3. Bottom-sheet dictionary filter (`lib/presentation/providers/dictionary_provider.dart`)
- Replace the plain `StateProvider<Set<String>>` with a
  `StateNotifierProvider<BottomSheetDictionaryFilterNotifier, Set<String>>`.
- Notifier hydrates from `StorageKeys.bottomSheetDictionaryFilter` (validated) and
  exposes `set(Set<String> ids)` that updates state and persists with the static-only rule.

### 4. `dictionary_bottom_sheet.dart`
- Change the one writer `…notifier).state = ids` → `…notifier).set(ids)`.
  (`ref.read`/`ref.watch` of the value are unchanged.)

## No-change confirmations
- `main.dart` — `keyValueStoreProvider` already wired.
- Domain `ScopeOperations` / `DictionaryFilterOperations` — reused as-is.
- Refine dialogs — untouched; their custom selections simply won't persist.

## Tests
Per project policy, tests are **not** written here — a separate test-writer agent will
cover the new persist/hydrate paths if requested.

## Manual verification
1. Search, pick "Sutta" chip → hot-restart → "Sutta" still selected.
2. Pick "All" → restart → "All".
3. Open Refine, pick only Dīgha Nikāya → restart → back to "All".
4. Definitions tab: pick "Sinhala" → restart → "Sinhala".
5. Bottom sheet refine = all Sinhala dicts → restart → still applied; pick a custom
   subset → restart → "All".
