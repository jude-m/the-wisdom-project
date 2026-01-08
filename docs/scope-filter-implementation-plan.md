# Scope-Based Search Filter Implementation Plan

## Overview

Replace the current granular nikaya filters (DN, MN, SN, AN, KN) with a new **Scope Selection** system using Pattern 2 ("All" as Default Anchor).

### Scopes

| Scope | Contains | DB Prefix Pattern |
|-------|----------|-------------------|
| **All** | Everything | No filter applied |
| **Sutta** | Sutta Pitaka (DN, MN, SN, AN, KN) | `dn-`, `mn-`, `sn-`, `an-`, `kn-` |
| **Vinaya** | Vinaya Pitaka | `vp-` |
| **Abhidhamma** | Abhidhamma Pitaka | `ap-` |
| **Commentaries** | All Atthakatha | `atta-` |
| **Treatises** | Visuddhimagga, Saddharmalankaraya, etc. | `anya-` |

### Behavior Rules (Pattern 2)

| # | Action | Result |
|---|--------|--------|
| 1 | Default state | "All" selected, others unselected |
| 2 | Tap unselected scope | Select it, deselect "All" |
| 3 | Tap another unselected scope | Add to selection (multi-select) |
| 4 | Tap selected scope | Deselect it |
| 5 | Tap "All" | Clear all specific selections, return to default |
| 6 | All 5 scopes selected | Auto-collapse to "All" |
| 7 | Last scope deselected | Auto-select "All" (can't have nothing) |

---

## Architecture Design

```
┌─────────────────────────────────────────────────────────────────┐
│ DOMAIN LAYER                                                     │
│                                                                  │
│  SearchScope (enum)         - Defines available scopes          │
│  ScopeFilterConfig          - Maps scopes to DB patterns        │
│  SearchQuery                - Carries scope filters (updated)   │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│ DATA LAYER                                                       │
│                                                                  │
│  ScopeFilterService         - Converts scopes to SQL WHERE      │
│  FTSDataSource              - Applies scope filters (updated)   │
│  TextSearchRepositoryImpl   - Passes scopes to datasource       │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│ PRESENTATION LAYER                                               │
│                                                                  │
│  SearchState                - Holds selectedScopes (updated)    │
│  SearchStateNotifier        - Manages scope selection logic     │
│  ScopeFilterChips           - New widget in _PanelHeader        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Steps

### Phase 1: Domain Layer - Define Scope Model

#### 1.1 Create `SearchScope` enum

**File:** `lib/domain/entities/search/search_scope.dart` (NEW)

```dart
/// Represents a high-level content scope for search filtering.
///
/// Scopes are parallel content domains (not narrowing filters).
/// Selecting multiple scopes expands the search to include all selected areas.
enum SearchScope {
  sutta,        // Sutta Pitaka (Discourses)
  vinaya,       // Vinaya Pitaka (Monastic Law)
  abhidhamma,   // Abhidhamma Pitaka
  commentaries, // All Atthakatha combined
  treatises,    // Visuddhimagga, Saddharmalankaraya, etc.
}

extension SearchScopeX on SearchScope {
  /// Display name in English
  String get displayName {
    switch (this) {
      case SearchScope.sutta:
        return 'Sutta';
      case SearchScope.vinaya:
        return 'Vinaya';
      case SearchScope.abhidhamma:
        return 'Abhidhamma';
      case SearchScope.commentaries:
        return 'Commentaries';
      case SearchScope.treatises:
        return 'Treatises';
    }
  }

  /// Display name in Sinhala
  String get displayNameSi {
    switch (this) {
      case SearchScope.sutta:
        return 'සුත්ත';
      case SearchScope.vinaya:
        return 'විනය';
      case SearchScope.abhidhamma:
        return 'අභිධම්ම';
      case SearchScope.commentaries:
        return 'අට්ඨකථා';
      case SearchScope.treatises:
        return 'ග්‍රන්ථ';
    }
  }
}
```

#### 1.2 Create `ScopeFilterConfig` - Single source of truth

**File:** `lib/domain/entities/search/scope_filter_config.dart` (NEW)

```dart
/// Configuration that maps SearchScopes to database filename patterns.
///
/// SINGLE SOURCE OF TRUTH for how scopes translate to database queries.
class ScopeFilterConfig {
  ScopeFilterConfig._();

  /// Filename prefix patterns for each scope.
  /// Used with SQL LIKE: `filename LIKE 'pattern%'`
  static const Map<SearchScope, List<String>> scopePatterns = {
    SearchScope.sutta: ['dn-', 'mn-', 'sn-', 'an-', 'kn-'],
    SearchScope.vinaya: ['vp-'],
    SearchScope.abhidhamma: ['ap-'],
    SearchScope.commentaries: ['atta-'],
    SearchScope.treatises: ['anya-'],
  };

  /// Get all filename patterns for a set of scopes.
  /// Returns empty list if scopes is empty (means search all).
  static List<String> getPatternsForScopes(Set<SearchScope> scopes) {
    if (scopes.isEmpty) return [];
    return scopes
        .expand((scope) => scopePatterns[scope] ?? [])
        .toList();
  }

  /// Check if a scope has sub-categories (for future drill-down)
  static bool hasSubCategories(SearchScope scope) {
    return scope == SearchScope.sutta; // Only Sutta has DN, MN, etc. for now
  }
}
```

#### 1.3 Update `SearchQuery` entity

**File:** `lib/domain/entities/search/search_query.dart` (MODIFY)

Changes:
- REMOVE: `nikayaFilters` property
- REMOVE: `labelFilters` property
- ADD: `scopes` property

```dart
@freezed
class SearchQuery with _$SearchQuery {
  const factory SearchQuery({
    required String queryText,
    @Default(false) bool isExactMatch,
    @Default({}) Set<String> editionIds,
    @Default(true) bool searchInPali,
    @Default(true) bool searchInSinhala,

    /// Selected scopes. Empty set = search all content (no scope filter).
    @Default({}) Set<SearchScope> scopes,

    @Default(50) int limit,
    @Default(0) int offset,
  }) = _SearchQuery;
}
```

---

### Phase 2: Data Layer - Implement Scope Filtering

#### 2.1 Create `ScopeFilterService`

**File:** `lib/data/services/scope_filter_service.dart` (NEW)

```dart
/// Converts SearchScope selections into SQL WHERE clauses.
class ScopeFilterService {
  /// Builds SQL WHERE clause fragment for scope filtering.
  /// Returns null if no filter should be applied (empty scopes = search all).
  ///
  /// Example output: `(m.filename LIKE ? OR m.filename LIKE ?)`
  static String? buildScopeWhereClause(
    Set<SearchScope> scopes, {
    String tableAlias = 'm',
    String columnName = 'filename',
  }) {
    if (scopes.isEmpty) return null;

    final patterns = ScopeFilterConfig.getPatternsForScopes(scopes);
    if (patterns.isEmpty) return null;

    final conditions = patterns
        .map((_) => '$tableAlias.$columnName LIKE ?')
        .join(' OR ');

    return '($conditions)';
  }

  /// Gets the SQL parameters (pattern values with % wildcard)
  static List<String> getScopeWhereParams(Set<SearchScope> scopes) {
    if (scopes.isEmpty) return [];
    return ScopeFilterConfig.getPatternsForScopes(scopes)
        .map((pattern) => '$pattern%')
        .toList();
  }
}
```

#### 2.2 Update `FTSDataSource` interface and implementation

**File:** `lib/data/datasources/fts_datasource.dart` (MODIFY)

Interface changes:
- REMOVE: `nikayaFilter` parameter
- ADD: `scopes` parameter

```dart
abstract class FTSDataSource {
  Future<List<FTSMatch>> searchFullText(
    String query, {
    required Set<String> editionIds,
    String? language,
    Set<SearchScope> scopes = const {},  // NEW: replaces nikayaFilter
    bool isExactMatch = false,
    int limit = 50,
    int offset = 0,
  });

  Future<int> countFullTextMatches(
    String query, {
    required String editionId,
    Set<SearchScope> scopes = const {},  // NEW
    bool isExactMatch = false,
  });
}
```

Implementation changes in `_searchInEdition`:
- Replace nikaya filter logic with scope filter logic using `ScopeFilterService`

```dart
// Replace this:
if (nikayaFilter != null && nikayaFilter.isNotEmpty) {
  buffer.write(' AND (');
  buffer.write(nikayaFilter.map((_) => 'm.filename LIKE ?').join(' OR '));
  buffer.write(')');
  args.addAll(nikayaFilter.map((n) => '$n-%'));
}

// With this:
final scopeWhereClause = ScopeFilterService.buildScopeWhereClause(scopes);
if (scopeWhereClause != null) {
  buffer.write(' AND $scopeWhereClause');
  args.addAll(ScopeFilterService.getScopeWhereParams(scopes));
}
```

#### 2.3 Update `TextSearchRepositoryImpl`

**File:** `lib/data/repositories/text_search_repository_impl.dart` (MODIFY)

Update all methods to pass `scopes` from `SearchQuery` to datasource:

```dart
Future<List<SearchResult>> _searchFullText({
  // ... existing params ...
}) async {
  final ftsMatches = await _ftsDataSource.searchFullText(
    queryText,
    editionIds: editionIds,
    scopes: query.scopes,  // Pass scopes from query
    isExactMatch: isExactMatch,
    limit: limit ?? 50,
    offset: offset,
  );
  // ...
}
```

---

### Phase 3: Presentation Layer - State & UI

#### 3.1 Update `SearchState`

**File:** `lib/presentation/providers/search_state.dart` (MODIFY)

Changes:
- REMOVE: `nikayaFilters` property
- REMOVE: `filtersVisible` property
- ADD: `selectedScopes` property
- ADD: `isAllSelected` getter

```dart
@freezed
class SearchState with _$SearchState {
  const factory SearchState({
    @Default('') String queryText,
    @Default({}) Set<String> selectedEditions,
    @Default(true) bool searchInPali,
    @Default(true) bool searchInSinhala,

    /// Selected scopes. Empty = "All" is selected (search everything).
    @Default({}) Set<SearchScope> selectedScopes,

    @Default(false) bool isExactMatch,
    @Default({}) Map<SearchResultType, int> countByResultType,
    // ... other existing fields ...
  }) = _SearchState;

  const SearchState._();

  /// True if "All" is effectively selected (no specific scopes chosen)
  bool get isAllSelected => selectedScopes.isEmpty;
}
```

#### 3.2 Update `SearchStateNotifier`

**File:** `lib/presentation/providers/search_state.dart` (MODIFY)

REMOVE methods:
- `addNikayaFilter()`
- `removeNikayaFilter()`
- `toggleFilters()`

ADD methods:

```dart
/// Select a scope. Deselects "All" automatically.
void selectScope(SearchScope scope) {
  final newScopes = {...state.selectedScopes, scope};

  // Auto-collapse to "All" if all scopes selected
  if (newScopes.length == SearchScope.values.length) {
    state = state.copyWith(selectedScopes: {});
  } else {
    state = state.copyWith(selectedScopes: newScopes);
  }
  _refreshSearchIfNeeded();
}

/// Deselect a scope. Returns to "All" if none remain.
void deselectScope(SearchScope scope) {
  final newScopes = {...state.selectedScopes}..remove(scope);
  state = state.copyWith(selectedScopes: newScopes);
  _refreshSearchIfNeeded();
}

/// Toggle a scope on/off.
void toggleScope(SearchScope scope) {
  if (state.selectedScopes.contains(scope)) {
    deselectScope(scope);
  } else {
    selectScope(scope);
  }
}

/// Select "All" - clears all specific scope selections.
void selectAll() {
  state = state.copyWith(selectedScopes: {});
  _refreshSearchIfNeeded();
}
```

UPDATE `_buildSearchQuery()`:

```dart
SearchQuery _buildSearchQuery() {
  // ... existing Singlish conversion ...

  return SearchQuery(
    queryText: effectiveQuery,
    isExactMatch: state.isExactMatch,
    editionIds: state.selectedEditions,
    searchInPali: state.searchInPali,
    searchInSinhala: state.searchInSinhala,
    scopes: state.selectedScopes,  // NEW
  );
}
```

UPDATE `clearFilters()`:

```dart
void clearFilters() {
  state = state.copyWith(
    selectedScopes: {},  // Reset to "All"
    searchInPali: true,
    searchInSinhala: true,
    isExactMatch: false,
  );
  _refreshSearchIfNeeded();
}
```

#### 3.3 Create `ScopeFilterChips` widget

**File:** `lib/presentation/widgets/scope_filter_chips.dart` (NEW)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/search/search_scope.dart';
import '../providers/search_provider.dart';

/// Horizontally scrollable scope filter chips.
/// Implements Pattern 2: "All" as default anchor with multi-select.
class ScopeFilterChips extends ConsumerWidget {
  const ScopeFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedScopes = ref.watch(
      searchStateProvider.select((s) => s.selectedScopes),
    );
    final isAllSelected = selectedScopes.isEmpty;

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        children: [
          // "All" chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: isAllSelected,
              onSelected: (_) {
                ref.read(searchStateProvider.notifier).selectAll();
              },
            ),
          ),

          // Scope chips
          ...SearchScope.values.map((scope) {
            final isSelected = selectedScopes.contains(scope);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(scope.displayName),
                selected: isSelected,
                onSelected: (_) {
                  ref.read(searchStateProvider.notifier).toggleScope(scope);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
```

#### 3.4 Update `_PanelHeader` in search_results_panel.dart

**File:** `lib/presentation/widgets/search_results_panel.dart` (MODIFY)

Add `ScopeFilterChips` as a second row:

```dart
class _PanelHeader extends StatelessWidget {
  final String queryText;
  final VoidCallback onClose;

  const _PanelHeader({
    required this.queryText,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Close button and query text
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
                tooltip: 'Close search results',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Results for "$queryText"',
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Row 2: Scope filter chips
          const ScopeFilterChips(),
        ],
      ),
    );
  }
}
```

---

### Phase 4: Cleanup

#### 4.1 Delete Files

| File | Reason |
|------|--------|
| `lib/presentation/widgets/search_filters_widget.dart` | Replaced by ScopeFilterChips |

#### 4.2 Remove References

- Remove any imports of `search_filters_widget.dart`
- Remove any usage of `SearchFiltersWidget` in the codebase

#### 4.3 Regenerate Freezed Files

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## File Summary

### New Files (4)

| File | Layer | Purpose |
|------|-------|---------|
| `lib/domain/entities/search/search_scope.dart` | Domain | SearchScope enum |
| `lib/domain/entities/search/scope_filter_config.dart` | Domain | Scope-to-pattern mapping |
| `lib/data/services/scope_filter_service.dart` | Data | SQL WHERE clause builder |
| `lib/presentation/widgets/scope_filter_chips.dart` | Presentation | Filter chips UI |

### Modified Files (5)

| File | Changes |
|------|---------|
| `lib/domain/entities/search/search_query.dart` | Replace `nikayaFilters` with `scopes` |
| `lib/presentation/providers/search_state.dart` | Replace nikaya methods with scope methods |
| `lib/data/datasources/fts_datasource.dart` | Use `scopes` parameter |
| `lib/data/repositories/text_search_repository_impl.dart` | Pass scopes to datasource |
| `lib/presentation/widgets/search_results_panel.dart` | Add ScopeFilterChips to _PanelHeader |

### Deleted Files (1)

| File | Reason |
|------|--------|
| `lib/presentation/widgets/search_filters_widget.dart` | Replaced by inline scope chips |

---

## Testing Checklist

- [ ] "All" chip selected by default on fresh search
- [ ] Tapping specific scope deselects "All" and selects that scope
- [ ] Tapping another scope adds to selection (multi-select works)
- [ ] Tapping selected scope deselects it
- [ ] Tapping "All" clears all specific selections
- [ ] Selecting all 5 scopes auto-collapses to "All"
- [ ] Deselecting last scope results in "All" being selected
- [ ] Search results update when scopes change
- [ ] Result counts update correctly per scope
- [ ] SQL queries include correct WHERE clauses

---

## Future Extensions (Not in scope)

1. **Drill-down sub-categories** - Bottom sheet for DN, MN, SN, AN, KN within Sutta
2. **Scope label** - "Searching in: Sutta, Vinaya" above chips
3. **Localization** - Sinhala chip labels via AppLocalizations
4. **Persisted preferences** - Remember last scope selections

-----

  ---
  Refine Search System - Comprehensive Overview

  1. Architecture Diagram

  ┌─────────────────────────────────────────────────────────────────────────────┐
  │                              USER INTERFACE                                  │
  ├─────────────────────────────────────────────────────────────────────────────┤
  │                                                                             │
  │  ┌─────────────────────────────────────────────────────────────────────┐   │
  │  │                    ScopeFilterChips (Widget)                         │   │
  │  │  ┌──────┐ ┌───────┐ ┌────────┐ ┌───────────┐ ┌──────────┐ ┌────────┐│   │
  │  │  │ All  │ │ Sutta │ │ Vinaya │ │Abhidhamma │ │Commentar.│ │ Refine ││   │
  │  │  └──┬───┘ └───┬───┘ └───┬────┘ └─────┬─────┘ └────┬─────┘ └───┬────┘│   │
  │  │     │         │         │            │            │           │      │   │
  │  │     │   toggleChipScope()            │            │     opens dialog │   │
  │  └─────┼─────────┼─────────┼────────────┼────────────┼───────────┼──────┘   │
  │        │         │         │            │            │           │          │
  │        ▼         ▼         ▼            ▼            ▼           ▼          │
  │  ┌─────────────────────────────────────────────────────────────────────┐   │
  │  │                   RefineSearchDialog (Widget)                        │   │
  │  │  ┌─────────────────────────────────────────────────────────────┐    │   │
  │  │  │  Local State: _selectedNodeKeys, _expandedNodes             │    │   │
  │  │  │                                                             │    │   │
  │  │  │  ┌─────────────────────────────────────────────────────┐   │    │   │
  │  │  │  │  Tree View (3 levels: Pitaka → Nikaya → Vagga)      │   │    │   │
  │  │  │  │  □ Vinaya Pitaka (vp)                               │   │    │   │
  │  │  │  │  ▼ Sutta Pitaka (sp)                                │   │    │   │
  │  │  │  │    ☑ Digha Nikaya (dn)                              │   │    │   │
  │  │  │  │    ☑ Majjhima Nikaya (mn)                           │   │    │   │
  │  │  │  │  □ Abhidhamma Pitaka (ap)                           │   │    │   │
  │  │  │  └─────────────────────────────────────────────────────┘   │    │   │
  │  │  └─────────────────────────────────────────────────────────────┘    │   │
  │  │                              │                                       │   │
  │  │                    _toggleNodeSelection()                            │   │
  │  └──────────────────────────────┼───────────────────────────────────────┘   │
  │                                 │                                           │
  └─────────────────────────────────┼───────────────────────────────────────────┘
                                    │
                                    ▼
  ┌─────────────────────────────────────────────────────────────────────────────┐
  │                         STATE MANAGEMENT (Riverpod)                         │
  ├─────────────────────────────────────────────────────────────────────────────┤
  │                                                                             │
  │  ┌─────────────────────────────────────────────────────────────────────┐   │
  │  │                SearchStateNotifier (StateNotifier)                   │   │
  │  │                                                                      │   │
  │  │  SearchState {                                                       │   │
  │  │    scope: Set<String>  ←─── THE SHARED DATA ───────────────────┐    │   │
  │  │    // e.g., {} for All, {'sp'} for Sutta, {'dn','mn'} for both│    │   │
  │  │  }                                                              │    │   │
  │  │                                                                 │    │   │
  │  │  Methods:                                                       │    │   │
  │  │  ├── setScope(nodeKeys)      ← normalizes, then updates state  │    │   │
  │  │  ├── toggleChipScope(chip)   ← delegates to setScope()         │    │   │
  │  │  ├── selectAll()             ← sets scope to {}                │    │   │
  │  │  └── _normalizeScope()       ← auto-collapse if all selected   │    │   │
  │  └─────────────────────────────────────────────────────────────────────┘   │
  │                                 │                                           │
  └─────────────────────────────────┼───────────────────────────────────────────┘
                                    │
                                    ▼
  ┌─────────────────────────────────────────────────────────────────────────────┐
  │                            DOMAIN LAYER                                      │
  ├─────────────────────────────────────────────────────────────────────────────┤
  │                                                                             │
  │  ┌──────────────────────────────┐    ┌──────────────────────────────────┐  │
  │  │     SearchScopeChip          │    │      ScopeFilterConfig           │  │
  │  │                              │    │                                  │  │
  │  │  Predefined chips:           │    │  Maps node keys → SQL patterns:  │  │
  │  │  - sutta:    {'sp'}          │    │  - 'sp' → ['dn-','mn-','sn-',   │  │
  │  │  - vinaya:   {'vp'}          │    │           'an-','kn-']          │  │
  │  │  - abhidhamma: {'ap'}        │    │  - 'dn' → ['dn-']               │  │
  │  │  - commentaries: {'atta-vp', │    │  - 'vp' → ['vp-']               │  │
  │  │      'atta-sp', 'atta-ap'}   │    │                                  │  │
  │  │  - treatises: {'anya'}       │    │  getPatternsForNodeKey(key)      │  │
  │  │                              │    │  getPatternsForScope(scope)      │  │
  │  └──────────────────────────────┘    └──────────────────────────────────┘  │
  │                                                                             │
  └─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
  ┌─────────────────────────────────────────────────────────────────────────────┐
  │                             DATA LAYER                                       │
  ├─────────────────────────────────────────────────────────────────────────────┤
  │                                                                             │
  │  ┌─────────────────────────────────────────────────────────────────────┐   │
  │  │                     ScopeFilterService                               │   │
  │  │                                                                      │   │
  │  │  buildWhereClause({'sp'})                                           │   │
  │  │  → '(m.filename LIKE ? OR m.filename LIKE ? OR ...)'                │   │
  │  │                                                                      │   │
  │  │  getWhereParams({'sp'})                                             │   │
  │  │  → ['dn-%', 'mn-%', 'sn-%', 'an-%', 'kn-%']                         │   │
  │  └─────────────────────────────────────────────────────────────────────┘   │
  │                                 │                                           │
  │                                 ▼                                           │
  │  ┌─────────────────────────────────────────────────────────────────────┐   │
  │  │                        FTS Datasource                                │   │
  │  │  SQL: SELECT ... WHERE (m.filename LIKE 'dn-%' OR ...)              │   │
  │  └─────────────────────────────────────────────────────────────────────┘   │
  │                                                                             │
  └─────────────────────────────────────────────────────────────────────────────┘

  ---
  2. Data Flow: How Scope Chips Link with Refine Search

  The Shared Data: SearchState.scope

  // In SearchState (Freezed class)
  @Default({}) Set<String> scope,

  This single Set<String> is the source of truth for both scope chips and refine dialog.

  | Scope Value  | Meaning                             |
  |--------------|-------------------------------------|
  | {} (empty)   | "All" - search everything           |
  | {'sp'}       | Sutta Pitaka only                   |
  | {'sp', 'vp'} | Sutta + Vinaya                      |
  | {'dn', 'mn'} | Digha + Majjhima Nikayas (granular) |

  Flow 1: Scope Chip → Search State

  User clicks "Sutta" chip
         │
         ▼
  ScopeFilterChips.build() calls:
    ref.read(searchStateProvider.notifier).toggleChipScope(suttaChip)
         │
         ▼
  SearchStateNotifier.toggleChipScope():
    1. currentScope = {} (was All)
    2. Add chip.nodeKeys → {'sp'}
    3. Call setScope({'sp'})
         │
         ▼
  SearchStateNotifier.setScope():
    1. _normalizeScope({'sp'}) → {'sp'} (no change)
    2. state = state.copyWith(scope: {'sp'})
    3. _refreshSearchIfNeeded() → triggers new search

  Flow 2: Refine Dialog → Search State

  User opens Refine, clicks "Digha Nikaya"
         │
         ▼
  RefineSearchDialog._initializeFromSearchState():
    _selectedNodeKeys = searchState.scope  // Syncs from search state
         │
         ▼
  User clicks checkbox
         │
         ▼
  _toggleNodeSelection(dnNode):
    1. Modify local _selectedNodeKeys
    2. ref.read(searchStateProvider.notifier).setScope(_selectedNodeKeys)
    3. Sync back: _selectedNodeKeys = ref.read(searchStateProvider).scope
         │
         ▼
  SearchStateNotifier.setScope():
    1. _normalizeScope(newScope)
    2. Update state
    3. Refresh search

  Flow 3: Search State → UI Updates

  SearchState.scope changes
         │
         ├──────────────────────────────────────┐
         ▼                                      ▼
  ScopeFilterChips                        RefineSearchDialog
  ref.watch(searchStateProvider)          ref.read(searchStateProvider)
         │                                      │
         ▼                                      ▼
  Rebuilds with:                          _selectedNodeKeys synced from
  - isAllSelected = scope.isEmpty         search state after setScope()
  - matchesChip(chip) for each chip
  - hasCustomScope for Refine indicator

  ---
  3. Key Methods and Their Responsibilities

  SearchStateNotifier (search_state.dart)

  | Method                 | Purpose                                                                         |
  |------------------------|---------------------------------------------------------------------------------|
  | setScope(Set<String>)  | Central entry point. Normalizes and sets scope. Both chips and dialog use this. |
  | toggleChipScope(chip)  | Adds/removes chip's nodeKeys, delegates to setScope()                           |
  | selectAll()            | Sets scope to {}                                                                |
  | _normalizeScope(scope) | Auto-collapse: if all chip keys selected → return {}                            |
  | _getAllChipNodeKeys()  | Returns combined nodeKeys from all predefined chips                             |

  RefineSearchDialog (refine_search_dialog.dart)

  | Method                                 | Purpose                                                    |
  |----------------------------------------|------------------------------------------------------------|
  | _initializeFromSearchState()           | Loads scope from search state into local _selectedNodeKeys |
  | _toggleNodeSelection(node)             | Handles checkbox clicks with complex logic                 |
  | _getCoveringAncestors(nodeKey)         | Finds if any selected node already covers this one         |
  | _getNodesNeedingExpansion(keys)        | Determines which tree nodes to expand                      |
  | _isNodeCoveredByRoot(nodeKey, rootKey) | Pattern-based ancestor check                               |

  ScopeFilterConfig (scope_filter_config.dart)

  | Method                     | Purpose                               |
  |----------------------------|---------------------------------------|
  | getPatternsForNodeKey(key) | Converts tree key → filename patterns |
  | getPatternsForScope(scope) | Expands full scope to patterns        |

  ---
  4. Special Behaviors

  Auto-Collapse to "All"

  When all 5 chip scopes are selected, automatically reverts to "All":

  Set<String> _normalizeScope(Set<String> scope) {
    final allChipNodeKeys = _getAllChipNodeKeys();
    // {'sp', 'vp', 'ap', 'atta-vp', 'atta-sp', 'atta-ap', 'anya'}

    if (scope.containsAll(allChipNodeKeys) &&
        allChipNodeKeys.containsAll(scope)) {
      return {}; // Collapse to "All"
    }
    return scope;
  }

  Implicit Selection (Visual)

  When a parent is selected, children appear checked:

  // In _buildTreeNode
  final isImplicitlySelected = _getCoveringAncestors(node.nodeKey).isNotEmpty;
  if (isAllSelected || isDirectlySelected || isImplicitlySelected) {
    checkboxValue = true;
  }

  Narrowing Down

  Clicking a child when parent is selected removes parent:

  // In _toggleNodeSelection
  final coveringAncestors = _getCoveringAncestors(node.nodeKey);
  if (coveringAncestors.isNotEmpty) {
    _selectedNodeKeys.removeAll(coveringAncestors); // Remove parent
  }
  _selectedNodeKeys.add(node.nodeKey); // Add child

  ---
  5. Debugging Checklist

  When debugging scope-related issues:

  1. Check SearchState.scope - What's the current value?
  print(ref.read(searchStateProvider).scope);
  2. Check normalization - Is auto-collapse happening correctly?
    - All chips selected should → {}
  3. Check pattern expansion - Is ScopeFilterConfig returning correct patterns?
  print(ScopeFilterConfig.getPatternsForScope({'sp'}));
  // Should be: ['dn-', 'mn-', 'sn-', 'an-', 'kn-']
  4. Check SQL generation - Is ScopeFilterService building correct WHERE clause?
  print(ScopeFilterService.buildWhereClause({'dn'}));
  print(ScopeFilterService.getWhereParams({'dn'}));
  5. Check dialog sync - After setScope(), is local state updated?
    - _selectedNodeKeys should match searchState.scope

  ---
  6. File Reference

  | File                                                | Purpose                    |
  |-----------------------------------------------------|----------------------------|
  | lib/presentation/providers/search_state.dart        | Shared state + notifier    |
  | lib/presentation/widgets/scope_filter_chips.dart    | Quick filter chips UI      |
  | lib/presentation/widgets/refine_search_dialog.dart  | Advanced tree selection UI |
  | lib/domain/entities/search/search_scope_chip.dart   | Chip definitions           |
  | lib/domain/entities/search/scope_filter_config.dart | Node key → pattern mapping |
  | lib/data/services/scope_filter_service.dart         | Pattern → SQL conversion   |