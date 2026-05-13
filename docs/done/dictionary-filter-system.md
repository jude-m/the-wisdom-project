# Dictionary Filter System

## Overview
Filtering system for dictionary search results (Definitions tab) in the search results pane, with reusable logic for the dictionary bottom sheet.

Uses a **single source of truth** (`selectedDictionaryIds: Set<String>`) shared by both quick filter chips and the refine dialog — the same pattern used by `ScopeFilterChips` for title/FTS search.

---

## Architecture

### Single Source of Truth

```
                    ┌─────────────────────────────────┐
                    │   SearchState (Riverpod)         │
                    │                                   │
                    │   selectedDictionaryIds:          │
                    │     Set<String>                   │
                    │                                   │
                    │   {} ─────────── "All"            │
                    │   {'BUS','MS'} ─ "Sinhala"       │
                    │   {'BUE','DPD',…} ─ "English"   │
                    │   {'BUS','DPD'} ─ "Custom"      │
                    └────────────┬──────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
                    ▼                         ▼
        ┌───────────────────┐    ┌────────────────────────┐
        │ Quick Filter Chips│    │ Refine Dictionary       │
        │ (DictionaryFilter │    │ Dialog                  │
        │  Chips)           │    │ (RefineDictionaryDialog)│
        │                   │    │                         │
        │ [All][Si][En][R]  │    │ ☑ සිංහල                │
        │                   │    │   ☑ BUS                 │
        │ Reads:            │    │   ☑ MS                  │
        │  containsAllKeys  │    │ ☐ English               │
        │  hasCustomSelect  │    │   ☐ DPD                 │
        │                   │    │   ☐ PTS …               │
        │ Writes:           │    │                         │
        │  toggleDictKeys() │    │ Writes:                 │
        │  selectAllDict()  │    │  setDictionaryFilter()  │
        └───────────────────┘    └────────────────────────┘
```

### Data Flow: UI → State → Query → SQL

```
 ┌──────────────┐     ┌──────────────────────┐     ┌──────────────────┐
 │  USER ACTION  │     │  STATE NOTIFIER       │     │  SEARCH QUERY    │
 │               │     │  (SearchStateNotifier) │     │  (SearchQuery)   │
 │ Tap "Sinhala" ├────►│                        ├────►│                  │
 │    chip       │     │ toggleDictionaryKeys() │     │ selectedDict     │
 │               │     │   ┌─────────────────┐  │     │  Ids: {'BUS',   │
 │   — or —      │     │   │ DictionaryFilter│  │     │         'MS'}   │
 │               │     │   │  Operations     │  │     │                  │
 │ Check "BUS"   ├────►│   │  .toggleKeys()  │  │     └────────┬─────────┘
 │  in Refine    │     │   │  .normalize()   │  │              │
 │               │     │   └─────────────────┘  │              │
 └──────────────┘     │                        │              │
                       │ _refreshSearchIfNeeded │              │
                       └──────────────────────┘              │
                                                               ▼
                                                  ┌──────────────────────┐
                                                  │  TEXT SEARCH REPO    │
                                                  │  _searchDefinitions()│
                                                  │  _countDefinitions() │
                                                  │                      │
                                                  │  passes dictionaryIds│
                                                  └──────────┬───────────┘
                                                               │
                                                               ▼
                                                  ┌──────────────────────┐
                                                  │  DICTIONARY REPO     │
                                                  │  searchDefinitions() │
                                                  │  countDefinitions()  │
                                                  └──────────┬───────────┘
                                                               │
                                                               ▼
                                                  ┌──────────────────────┐
                                                  │  DICTIONARY          │
                                                  │  DATASOURCE          │
                                                  │                      │
                                                  │  _appendDictFilter() │
                                                  │                      │
                                                  │  {} → no WHERE       │
                                                  │  {'BUS','MS'} →      │
                                                  │   AND dict_id        │
                                                  │   IN ('BUS','MS')    │
                                                  └──────────────────────┘
```

### Sync Mechanism

```
                selectedDictionaryIds
                   (Set<String>)
                        │
            ┌───────────┴───────────┐
            ▼                       ▼
       Quick Chips             Refine Dialog
       read & write            read & write
       same Set                same Set

       ✓ Single variable, always in sync
       ✓ Chip toggles IDs → dialog sees them
       ✓ Dialog sets IDs → chip detects group match
```

---

## DictionaryFilterOperations

The brain of the system — pure functions (~70 lines), mirrors `ScopeOperations`.

```
 ┌─────────────────────────────────────────────────────────────┐
 │  DictionaryFilterOperations                                 │
 │                                                             │
 │  Constants (derived from DictionaryInfo.all):               │
 │  ┌──────────────────────────────────────────────┐          │
 │  │ sinhalaIds = {'BUS', 'MS'}                   │          │
 │  │ englishIds = {'BUE','DPD','VRI','PTS',       │          │
 │  │              'CR','DPDC','ND','PN'}           │          │
 │  │ allIds     = sinhalaIds ∪ englishIds (10)     │          │
 │  └──────────────────────────────────────────────┘          │
 │                                                             │
 │  Methods:                                                   │
 │  ┌──────────────────────────────────────────────────────┐  │
 │  │ isAllSelected(ids)      → ids.isEmpty                │  │
 │  │ containsAllKeys(ids, k) → ids ⊇ k                   │  │
 │  │ hasCustomSelections(ids) → not empty & not any group │  │
 │  │ normalize(ids)          → if ids == allIds → {}      │  │
 │  │ toggleKeys(cur, keys)   → add/remove + normalize     │  │
 │  └──────────────────────────────────────────────────────┘  │
 └─────────────────────────────────────────────────────────────┘

  Used by:
  ├── DictionaryFilterChips  → derive chip isSelected states
  ├── SearchStateNotifier    → toggleDictionaryKeys(), setDictionaryFilter()
  └── (future) DictionaryBottomSheet → same callbacks
```

---

## Chip State Detection

```
 selectedDictionaryIds          Chip States
 ─────────────────────          ──────────────────────────────────

 {}                        →   [All✓] [Si ] [En ] [R ]

 {'BUS','MS'}              →   [All ] [Si✓] [En ] [R ]

 {'BUE','DPD','VRI',       →   [All ] [Si ] [En✓] [R ]
  'PTS','CR','DPDC',
  'ND','PN'}

 {'BUS','DPD'}             →   [All ] [Si ] [En ] [R✓]
                                              (Refine highlighted)

 {'BUS','MS','BUE','DPD',  →   normalize() collapses to {} →
  'VRI','PTS','CR','DPDC',     [All✓] [Si ] [En ] [R ]
  'ND','PN'}
```

---

## File Map

```
 lib/
 ├── domain/entities/dictionary/
 │   ├── dictionary_filter_operations.dart  ← core logic (pure functions)
 │   ├── dictionary_info.dart               ← dictionary metadata
 │   └── dictionary_params.dart             ← lookup/search params
 │
 ├── domain/entities/search/
 │   └── search_query.dart                  ← carries selectedDictionaryIds
 │
 ├── domain/repositories/
 │   └── dictionary_repository.dart         ← interface (dictionaryIds param)
 │
 ├── data/
 │   ├── datasources/
 │   │   └── dictionary_datasource.dart     ← SQL filtering
 │   └── repositories/
 │       ├── dictionary_repository_impl.dart
 │       └── text_search_repository_impl.dart
 │
 └── presentation/
     ├── providers/
     │   ├── search_state.dart              ← single source of truth
     │   └── dictionary_provider.dart       ← lookup/search providers
     └── widgets/
         ├── dictionary/
         │   ├── dictionary_filter_chips.dart← quick filter UI
         │   └── refine_dictionary_dialog.dart← tree selection dialog
         └── search/
             └── search_results_panel.dart  ← hosts filter chips
```

---

## Design Decisions

1. **Single state variable** (`selectedDictionaryIds: Set<String>`) instead of dual enum + set — eliminates sync bugs, matches scope_chips pattern.
2. **DB-level filtering** via `dict_id IN (...)` — efficient, keeps count badges accurate.
3. **Callback-based widget** (`DictionaryFilterChips`) — reusable across search panel and dictionary bottom sheet without provider coupling.
4. **Toggle/multi-select chips** — Sinhala + English toggle = All (auto-normalize), consistent with scope chips behavior.
5. **Pure operations class** (`DictionaryFilterOperations`) — testable, no framework dependencies, single responsibility.

## Verification Checklist
1. Click "Sinhala" chip → open Refine → only BUS, MS should be checked
2. In Refine, check all English dicts → close → "English" chip should be highlighted
3. Click "All" → Refine shows everything checked
4. In Refine, select BUS + DPD (cross-group) → Refine chip highlights, no language chip selected
5. In Refine, select all 10 dicts → auto-normalizes to "All"
6. Search results update correctly for each filter combination
