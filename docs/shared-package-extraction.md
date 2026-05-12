# Shared Package Extraction + Quick Wins

## Context
The Flutter client and Dart server duplicate ~160 lines of business logic (FTS query builder, scope filters, dictionary helpers). A bug fix in one copy will be missed in the other. We'll extract a shared pure-Dart package `wisdom_shared` that both import.

## Package Structure
```
packages/wisdom_shared/
├── pubspec.yaml                    # pure Dart, no Flutter dep
├── analysis_options.yaml
├── lib/
│   ├── wisdom_shared.dart          # barrel export
│   └── src/
│       ├── constants/
│       │   └── tipitaka_node_keys.dart
│       ├── fts/
│       │   └── fts_query_builder.dart
│       ├── scope/
│       │   ├── scope_patterns.dart
│       │   └── scope_filter_sql.dart
│       ├── dictionary/
│       │   ├── dictionary_sql_helpers.dart
│       │   └── dictionary_language.dart
│       └── utils/
│           └── csv_parser.dart
```

## Steps

### 1. Create package scaffold
- `packages/wisdom_shared/pubspec.yaml` — pure Dart, `publish_to: none`, SDK `>=3.0.0 <4.0.0`
- `packages/wisdom_shared/lib/wisdom_shared.dart` — barrel exports
- `packages/wisdom_shared/analysis_options.yaml`

### 2. Move TipitakaNodeKeys
- Copy `TipitakaNodeKeys` class → `packages/wisdom_shared/lib/src/constants/tipitaka_node_keys.dart`
- In `lib/core/constants/constants.dart`: replace class body with `export 'package:wisdom_shared/wisdom_shared.dart' show TipitakaNodeKeys;`
- Zero downstream import changes (re-export is transparent)

### 3. Extract FTS query builder
- `_buildFtsQuery()` → public `buildFtsQuery()` in `packages/wisdom_shared/lib/src/fts/fts_query_builder.dart`
- Remove from `lib/data/datasources/fts_local_datasource.dart` (lines 24-112), call shared version
- Remove from `server/lib/src/handlers/fts_handler.dart` (lines 230-270), call shared version

### 4. Extract scope pattern logic
- `ScopePatterns` class in `packages/wisdom_shared/lib/src/scope/scope_patterns.dart`
  - `expandedPatterns`, `getPatternsForNodeKey()`, `getPatternsForScope()`
  - `isNodeCoveredBy()`, `findCoveringAncestors()`
- `ScopeFilterSql` class in `packages/wisdom_shared/lib/src/scope/scope_filter_sql.dart`
  - `buildWhereClause()`, `getWhereParams()`
- Update client `scope_operations.dart`: delegate pattern methods to `ScopePatterns.*` (keeps existing API intact)
- Update client `scope_filter_service.dart`: re-export as `typedef ScopeFilterService = ScopeFilterSql;`
- Remove duplicated scope logic from server `fts_handler.dart` (lines 272-303)

### 5. Extract dictionary helpers
- `buildDictionaryLikePattern()` + `appendDictionaryFilter()` → `dictionary_sql_helpers.dart`
- `inferTargetLanguage()` → `dictionary_language.dart`
- Remove from `dictionary_local_datasource.dart`, use shared versions
- Remove from server `dictionary_handler.dart`, use shared versions

### 6. Extract `parseCsvToSet` utility
- Both server handlers duplicate `_parseSet()` — extract to `csv_parser.dart`

### 7. Wire up dependencies
- Root `pubspec.yaml`: add `wisdom_shared: { path: packages/wisdom_shared }`
- `server/pubspec.yaml`: add `wisdom_shared: { path: ../packages/wisdom_shared }`
- Run `flutter pub get` + `cd server && dart pub get`

### 8. Quick wins
- **#8**: `platform_utils.dart` — change `dart.library.html` → `dart.library.js_interop`
- **#10**: Server handlers — change `Router get router` → `late final router` (3 files)
- **#12**: `scripts/web/run_mac.sh` — add `[ -d ... ] &&` guards before `rm -rf`

## Files Modified

| File | Change |
|------|--------|
| `packages/wisdom_shared/**` | NEW — 8 source files + pubspec + barrel |
| `pubspec.yaml` | Add path dependency |
| `server/pubspec.yaml` | Add path dependency |
| `lib/core/constants/constants.dart` | Re-export TipitakaNodeKeys |
| `lib/data/datasources/fts_local_datasource.dart` | Remove _buildFtsQuery, import shared |
| `lib/data/datasources/dictionary_local_datasource.dart` | Remove helpers, import shared |
| `lib/domain/entities/search/scope_operations.dart` | Delegate pattern methods to shared |
| `lib/data/services/scope_filter_service.dart` | Re-export as typedef |
| `server/lib/src/handlers/fts_handler.dart` | Remove duplicated logic, import shared, late final router |
| `server/lib/src/handlers/dictionary_handler.dart` | Remove duplicated logic, import shared, late final router |
| `server/lib/src/handlers/text_handler.dart` | late final router |
| `lib/core/utils/platform_utils.dart` | dart.library.js_interop |
| `scripts/web/run_mac.sh` | Guard rm -rf |

## Verification
1. `cd packages/wisdom_shared && dart analyze` — shared package clean
2. `flutter analyze` — client clean
3. `cd server && dart analyze` — server clean
4. `flutter test` — existing tests pass (with user confirmation per CLAUDE.md)
5. `cd packages/wisdom_shared && dart test` — (tests not written unless requested)
