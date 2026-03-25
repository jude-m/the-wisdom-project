# Client-Server Architecture for Web Deployment

## Goal
Build a Dart server that hosts the databases and content files, and make the Flutter web app call the server API instead of bundling 260MB+ of assets. Native apps (iOS/Android/desktop) stay unchanged.

## Language Recommendation: Dart with `shelf`

**Why Dart over Node.js:**
- Same language as the Flutter app - you deepen one skill, not two
- **Significant code reuse** - FTS query builder (~60 lines), scope filter service, data models can be shared directly
- `shelf` is Google's official Dart server library - stable, simple, production-ready
- The server logic is small (8 endpoints) - no need for a heavy framework

**Server dependencies:** `shelf`, `shelf_router`, `shelf_static`, `sqlite3` (pure Dart SQLite for server-side)

---

## Architecture Overview

```
NATIVE (iOS/Android/Desktop)              WEB
┌──────────────────────────┐    ┌──────────────────────────┐
│  Flutter App             │    │  Flutter App (Web)       │
│  ┌────────────────────┐  │    │  ┌────────────────────┐  │
│  │ Presentation Layer │  │    │  │ Presentation Layer │  │
│  │ (unchanged)        │  │    │  │ (unchanged)        │  │
│  └────────┬───────────┘  │    │  └────────┬───────────┘  │
│  ┌────────▼───────────┐  │    │  ┌────────▼───────────┐  │
│  │ Repository Layer   │  │    │  │ Repository Layer   │  │
│  │ (unchanged)        │  │    │  │ (unchanged)        │  │
│  └────────┬───────────┘  │    │  └────────┬───────────┘  │
│  ┌────────▼───────────┐  │    │  ┌────────▼───────────┐  │
│  │ LOCAL Datasources  │  │    │  │ REMOTE Datasources │  │
│  │ (SQLite + Assets)  │  │    │  │ (HTTP calls)       │  │
│  └────────────────────┘  │    │  └────────┬───────────┘  │
└──────────────────────────┘    └───────────┼──────────────┘
                                            │ HTTP
                                ┌───────────▼──────────────┐
                                │  Dart Server (shelf)     │
                                │  ├─ REST API endpoints   │
                                │  ├─ SQLite databases     │
                                │  ├─ JSON text files      │
                                │  └─ Static web files     │
                                └──────────────────────────┘
```

**Key insight:** Your clean architecture already has abstract datasource interfaces. We just add new "remote" implementations for web. The provider layer picks local vs remote based on `kIsWeb`. No changes to presentation or repository layers.

---

## API Endpoints (7 total)

| Endpoint | Maps to | Purpose |
|----------|---------|---------|
| `GET /api/fts/search` | `FTSDataSource.searchFullText()` | Full-text search with BM25 ranking |
| `GET /api/fts/count` | `FTSDataSource.countFullTextMatches()` | Count matches (for tab badges) |
| `GET /api/fts/suggestions` | `FTSDataSource.getSuggestions()` | Autocomplete suggestions |
| `GET /api/dict/lookup` | `DictionaryDataSource.lookupWord()` | Dictionary word lookup |
| `GET /api/dict/search` | `DictionaryDataSource.searchDefinitions()` | Dictionary definition search |
| `GET /api/dict/count` | `DictionaryDataSource.countDefinitions()` | Count dictionary results |
| `GET /api/text/<fileId>` | `BJTDocumentDataSource.loadDocument()` | Single text content file |

> **Note:** The navigation tree (`tree.json`) does NOT need a server endpoint.
> It uses `rootBundle.loadString()` which works on all platforms including web.
> It's a small static file (~3 MB) bundled in the Flutter web build.

Example: `GET /api/fts/search?query=අනාථ&editionIds=bjt&scope=dn&isPhraseSearch=true&limit=50&offset=0`

No CORS needed - server serves both API and static web files from the same origin.

---

## Implementation Phases

### Phase 1: Split Datasource Files (prep work, no behavior change)

Currently `fts_datasource.dart` contains both the abstract interface AND the implementation that uses `dart:io`. Web builds can't compile `dart:io`. Fix: split them.

**Split `fts_datasource.dart` into:**
- `fts_datasource.dart` - abstract `FTSDataSource` + `FTSMatch` + `FTSSuggestion` (no dart:io)
- `fts_local_datasource.dart` - `FTSDataSourceImpl` (keeps dart:io, sqflite)

**Split `dictionary_datasource.dart` into:**
- `dictionary_datasource.dart` - abstract `DictionaryDataSource` + data classes (no dart:io)
- `dictionary_local_datasource.dart` - `DictionaryDataSourceImpl` (keeps dart:io, sqflite)

**Update imports** in provider files to point to the new local implementation files.

**Add `toJson()` methods** to `FTSMatch` and `FTSSuggestion` (needed for server responses).

### Phase 2: Create Shared Package

Create `packages/shared/` with code both server and app need:

```
packages/shared/
  lib/
    shared.dart                    # barrel export
    src/
      fts_query_builder.dart       # extracted from FTSDataSourceImpl._buildFtsQuery()
      scope_filter_service.dart    # moved from lib/data/services/
      scope_operations.dart        # moved from lib/domain/entities/search/
      tipitaka_node_keys.dart      # moved from lib/domain/entities/navigation/
      api_constants.dart           # API route paths shared by server + client
  pubspec.yaml
```

Update the Flutter app's `pubspec.yaml` to depend on shared:
```yaml
dependencies:
  shared:
    path: packages/shared
```

### Phase 3: Build the Dart Server

```
server/
  bin/
    server.dart                    # entry point - opens DBs, starts listening
  lib/
    src/
      server_app.dart              # shelf pipeline: gzip + CORS + router
      database/
        database_manager.dart      # opens bjt-fts.db + dict.db with sqlite3 package
      handlers/
        fts_handler.dart           # 3 endpoints: search, count, suggestions
        dictionary_handler.dart    # 3 endpoints: lookup, search, count
        text_handler.dart          # 1 endpoint: serves text/{fileId}.json
  pubspec.yaml                     # depends on shelf, shelf_router, sqlite3, shared
```

The server:
1. Opens SQLite databases on startup (kept open, like tipitaka.lk's Go connection pooling)
2. Text JSON files served from disk on-demand
3. Gzip compression on all responses
4. Serves static Flutter web build at root `/`
5. API at `/api/*`
6. Listens on port 8080 (configurable via `--port`)
7. Request logging with timestamps and response times (optional `--verbose` and `--log-file`)

**The server reuses the same SQL queries** as the local datasources - the FTS query builder and scope filter service from the shared package construct identical queries.

### Phase 4: Build Remote Datasources (Flutter client)

Four new files implementing existing abstract interfaces:

**`fts_remote_datasource.dart`** implements `FTSDataSource`:
```dart
class FTSRemoteDataSourceImpl implements FTSDataSource {
  final http.Client _client;
  final String _baseUrl;

  // searchFullText() -> GET /api/fts/search -> deserialize List<FTSMatch>
  // countFullTextMatches() -> GET /api/fts/count -> deserialize int
  // getSuggestions() -> GET /api/fts/suggestions -> deserialize List<FTSSuggestion>
  // initializeEditions() -> no-op (server manages DBs)
  // close() -> no-op
}
```

**`dictionary_remote_datasource.dart`** implements `DictionaryDataSource`:
- `lookupWord()` -> `GET /api/dict/lookup`
- `searchDefinitions()` -> `GET /api/dict/search`
- `countDefinitions()` -> `GET /api/dict/count`

**`bjt_document_remote_datasource.dart`** implements `BJTDocumentDataSource`:
- `loadDocument(fileId)` -> `GET /api/text/{fileId}` -> parse JSON (same parsing logic)

Add `http` package to Flutter `pubspec.yaml`.

### Phase 5: Conditional Provider Wiring

New file `lib/presentation/providers/platform_providers.dart`:

```dart
List<Override> getWebOverrides() {
  return [
    ftsDataSourceProvider.overrideWithValue(
      FTSRemoteDataSourceImpl(baseUrl: ''),  // same origin
    ),
    dictionaryDataSourceProvider.overrideWithValue(
      DictionaryRemoteDataSourceImpl(baseUrl: ''),
    ),
    // NOTE: tree.json uses rootBundle on all platforms (no remote needed)
    bjtDocumentDataSourceProvider.overrideWithValue(
      BJTDocumentRemoteDataSourceImpl(baseUrl: ''),
    ),
  ];
}
```

Update `main.dart`:
```dart
void main() async {
  // ... existing setup ...

  // Skip local DB validation on web
  if (!kIsWeb) {
    // existing rootBundle.load check...
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        if (kIsWeb) ...getWebOverrides(),  // <-- THE KEY LINE
      ],
      child: const MyApp(),
    ),
  );
}
```

Handle `dart:io` conditional import (Platform.isWindows check in main.dart):
```dart
// platform_utils.dart - conditional export
export 'platform_utils_io.dart' if (dart.library.html) 'platform_utils_web.dart';
```

### Phase 6: Handle matchedText for Search Results

`TextSearchRepositoryImpl._loadTextForMatch()` (line 593) uses `rootBundle.loadString()` which won't work on web.

**Solution:** The server's FTS search endpoint enriches results with the actual matched text. Add an optional `matchedText` field to `FTSMatch`. When it's non-null, the repository skips the `rootBundle` call.

```dart
// In FTSMatch:
final String? matchedText;  // Server pre-loads this

// In TextSearchRepositoryImpl._searchFullText():
final text = match.matchedText ??  // Use server-provided text if available
    await _loadTextForMatch(match.filename, match.eind, match.language);
```

### Phase 7: Testing & Tester Distribution

Build and serve:
```bash
./scripts/serve-web.sh            # build + start server on port 8080
./scripts/serve-web.sh --skip-build  # skip build if already built
./scripts/serve-web.sh --port 3000   # custom port
```

The script:
1. Runs `flutter build web --release`
2. **Strips server-only assets** from `build/web/` (databases + text JSON files) — reduces web bundle from ~638 MB to ~37 MB
3. Installs server deps if needed (`dart pub get`)
4. Starts the Dart server serving both API + static web files

---

## New Files to Create

| File | Purpose |
|------|---------|
| `packages/shared/pubspec.yaml` | Shared package definition |
| `packages/shared/lib/shared.dart` | Barrel export |
| `packages/shared/lib/src/fts_query_builder.dart` | Extracted FTS5 query builder |
| `packages/shared/lib/src/scope_filter_service.dart` | Scope-to-SQL conversion |
| `packages/shared/lib/src/scope_operations.dart` | Scope pattern resolution |
| `packages/shared/lib/src/tipitaka_node_keys.dart` | Node key constants |
| `packages/shared/lib/src/api_constants.dart` | API route path constants |
| `server/pubspec.yaml` | Server dependencies |
| `server/bin/server.dart` | Server entry point |
| `server/lib/src/server_app.dart` | Shelf pipeline assembly |
| `server/lib/src/database/database_manager.dart` | SQLite connection manager |
| `server/lib/src/handlers/fts_handler.dart` | FTS search endpoints |
| `server/lib/src/handlers/dictionary_handler.dart` | Dictionary endpoints |
| `server/lib/src/handlers/text_handler.dart` | Text content endpoint |
| `lib/data/datasources/fts_local_datasource.dart` | Extracted local FTS impl |
| `lib/data/datasources/fts_remote_datasource.dart` | New remote FTS impl |
| `lib/data/datasources/dictionary_local_datasource.dart` | Extracted local dict impl |
| `lib/data/datasources/dictionary_remote_datasource.dart` | New remote dict impl |
| `lib/data/datasources/bjt_document_remote_datasource.dart` | New remote document impl |
| `lib/presentation/providers/platform_providers.dart` | kIsWeb conditional wiring |
| `lib/core/utils/platform_utils.dart` | Conditional dart:io export |
| `lib/core/utils/platform_utils_io.dart` | Native platform helpers |
| `lib/core/utils/platform_utils_web.dart` | Web platform stubs |
| `scripts/serve-web.sh` | Build + serve script for testers |

## Files to Modify

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `http` package, `shared` path dep |
| `lib/main.dart` | `kIsWeb` conditional overrides, conditional `dart:io` import |
| `lib/data/datasources/fts_datasource.dart` | Keep only abstract + data classes, move impl out |
| `lib/data/datasources/dictionary_datasource.dart` | Keep only abstract, move impl out |
| `lib/data/datasources/fts_datasource.dart` FTSMatch | Add optional `matchedText` field + `toJson()` |
| `lib/presentation/providers/search_provider.dart` | Update import path for local impl |
| `lib/presentation/providers/dictionary_provider.dart` | Update import path for local impl |
| `lib/data/repositories/text_search_repository_impl.dart` | Use `matchedText` when available |

## Files That Stay Unchanged

All domain entities, domain repository interfaces, all presentation widgets/screens, all existing tests. The clean architecture boundary means changes are confined to the datasource layer and provider wiring.

---

## Asset Strategy

Assets are declared in `pubspec.yaml` for native platforms but not all are needed on web:

| Asset | Native | Web | Reason |
|-------|--------|-----|--------|
| `assets/data/tree.json` | rootBundle | rootBundle | Small static JSON, works everywhere |
| `assets/data/file-map.json` | rootBundle | rootBundle | Small static JSON, works everywhere |
| `assets/text/*.json` (285 files) | rootBundle | Server API | Too large to bundle (~340 MB) |
| `assets/databases/bjt-fts.db` | sqflite | Server API | sqflite doesn't work on web |
| `assets/databases/dict.db` | sqflite | Server API | sqflite doesn't work on web |

The `serve-web.sh` script removes `databases/` and `text/` from the web build output after `flutter build web`, reducing the bundle from **~638 MB to ~37 MB**. Flutter doesn't support per-platform asset exclusion in pubspec.yaml, so this post-build cleanup is the cleanest approach.

## What Testers Get

A single server process that serves everything:
1. The web app (static HTML/JS/CSS — ~37 MB)
2. The API (search, dictionary, text content)
3. All databases and text files stay on the server

They run one command and open `localhost:8080` in a browser. No Flutter SDK needed.
