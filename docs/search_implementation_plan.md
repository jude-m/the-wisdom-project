# Search Feature Implementation Plan

## Table of Contents
1. [User Story Analysis](#1-user-story-analysis)
2. [Industry Standards Comparison](#2-industry-standards-comparison)
3. [Tipitaka.lk Feature Comparison](#3-tipitakalk-feature-comparison)
4. [Architecture Analysis](#4-architecture-analysis)
5. [Search Technology Comparison](#5-search-technology-comparison)
6. [Implementation Plan](#6-implementation-plan)

---

## 1. User Story Analysis

### Coverage Assessment

| User Story | Priority | Scenario Coverage | Gap Analysis |
|------------|----------|-------------------|--------------|
| **Search by name** | P1 | Good | Covers basic sutta discovery |
| **Search by content/keyword** | P1 | Good | Covers deep content discovery |
| **Filter by Nikaya** | P1 | Good | Essential for large corpus |
| **Filter by labels** | P3 | Partial | Need to define label taxonomy |
| **Search within sutta** | P1 | Good | Web-page style Ctrl+F |
| **Auto-suggestions** | P2 | Partial | Missing: suggestion sources |
| **Recent searches** | P2 | Good | Standard UX pattern |
| **Category browsing** | P4 | Partial | Need to define categories |
| **Related content** | P4-c | Partial | Algorithm undefined |

### Missing User Scenarios

The following scenarios should be considered for completeness:

#### Must Have (Recommended P1/P2)
1. **Empty state handling** - What shows when no results found?
2. **Search result count** - "Found X results in Y suttas"
3. **Result context preview** - Show surrounding text of match
4. **Search language preference** - Search Pali, Sinhala, or both?
5. **Pagination/infinite scroll** - For large result sets
6. **Error handling** - Network/database errors during search

#### Nice to Have (P3+)
7. **Search history management** - Clear history, delete individual items
8. **Boolean operators** - AND, OR, NOT for power users
9. **Phrase search** - Exact phrase matching with quotes
10. **Wildcard search** - Partial word matching
11. **Fuzzy/typo tolerance** - Handle misspellings
12. **Search analytics** - Track popular searches for improvement
13. **Offline search** - Full functionality without network
14. **Voice search** - Accessibility feature
15. **Share search results** - Deep linking to search

---

## 2. Industry Standards Comparison

### Reference Applications Analyzed

Based on research of leading religious text applications:
- [IslamiCity Quran Search](https://www.islamicity.org/quransearch/)
- [Quran App](https://quranapp.org/)
- [SuttaCentral](https://suttacentral.net/)
- [Tipitaka.org](https://tipitaka.org/)

### Industry Standard Features

| Feature | Your User Story | Industry Standard | Gap |
|---------|-----------------|-------------------|-----|
| Basic keyword search | P1 | Standard | Covered |
| Advanced search (boolean) | Not mentioned | Common | Add as P3 |
| Filter by book/chapter | P1 (Nikaya) | Standard | Covered |
| Search within document | P1 | Standard | Covered |
| Auto-suggestions | P2 | Standard | Covered |
| Recent searches | P2 | Standard | Covered |
| Result highlighting | P1 (mentioned) | Standard | Covered |
| Context preview | Not explicit | Standard | Add as P1 |
| Multi-language search | Not explicit | Common | Add as P2 |
| Root word/stem search | Not mentioned | Advanced (Quran apps) | Consider P4 |
| Topic/theme index | P4 | Advanced | Covered |
| Cross-reference search | Not mentioned | Advanced | Consider P4 |
| Bookmark search results | Not mentioned | Common | Add as P3 |
| Export/share results | Not mentioned | Common | Add as P3 |

### Recommendations to Meet Industry Standards

**Add to P1:**
- Result context preview (2-3 lines around match)
- Result count display
- Search language selection (Pali/Sinhala/Both)

**Add to P2:**
- Phrase search (exact match in quotes)
- Result sorting options (relevance, location order)

**Add to P3:**
- Boolean operators (AND, OR, NOT)
- Bookmark/save search results
- Export search results

---

## 3. Tipitaka.lk Feature Comparison

### Existing Tipitaka.lk Features

Based on the [tipitaka.lk GitHub repository](https://github.com/pathnirvana/tipitaka.lk):

| Feature | Tipitaka.lk | Your User Story | Status |
|---------|-------------|-----------------|--------|
| Full-text search (FTS) | Yes (fts.db) | P1 | Match |
| Search by sutta name | Yes | P1 | Match |
| Search highlighting | Yes | P1 | Match |
| Navigate to position | Yes | P1 | Match |
| Pali search | Yes | Implicit | Need to specify |
| Sinhala search | Yes | Implicit | Need to specify |
| Filter by Pitaka/Nikaya | Yes | P1 | Match |
| Dictionary integration | Yes (dict.db) | Not mentioned | Gap |
| Search within page | Browser native | P1 | Match |
| Auto-suggestions | Unknown | P2 | Cannot compare |
| Recent searches | Unknown | P2 | Cannot compare |
| Category browsing | Partial (tree) | P4 | Similar |

### Features to Match Tipitaka.lk

1. **SQLite FTS database** - You already plan to use fts.db
2. **Dual language search** - Add explicit Pali/Sinhala toggle
3. **Dictionary lookup** - Consider for P3 (word definitions)
4. **Result navigation** - Jump to exact position in text

### Features to Improve Upon Tipitaka.lk

1. **Modern UI/UX** - Tipitaka.lk has dated interface
2. **Auto-suggestions** - Not implemented in original
3. **Recent searches** - Not implemented in original
4. **Related content** - Not implemented in original
5. **Offline-first** - Better mobile experience
6. **Accessibility** - Modern accessibility standards

---

## 4. Architecture Analysis

### Current Architecture Review

```
lib/
├── domain/
│   ├── entities/
│   │   ├── tipitaka_tree_node.dart     # Has name search support
│   │   ├── bjt_document.dart           # Content structure
│   │   ├── entry.dart                  # Text with plainText getter
│   │   └── failure.dart                # Error handling
│   ├── repositories/
│   │   ├── navigation_tree_repository.dart  # Has searchNodes() method
│   │   └── bjt_document_repository.dart     # No search method
│   └── usecases/                       # Empty - needs search use cases
├── data/
│   ├── datasources/
│   │   ├── tree_local_datasource.dart  # Loads tree.json
│   │   └── bjt_document_local_datasource.dart  # Loads text files
│   └── repositories/
│       ├── navigation_tree_repository_impl.dart  # searchNodes implemented
│       └── bjt_document_repository_impl.dart     # No search
└── presentation/
    ├── providers/                      # Needs search providers
    └── widgets/                        # Needs search widgets
```

### Required Architectural Changes

#### 1. New Domain Entities (Required)

```dart
// lib/domain/entities/search/
├── search_result.dart          # Search result model
├── search_query.dart           # Query with filters
├── search_filter.dart          # Nikaya/label filters
├── search_suggestion.dart      # Auto-suggestion model
└── search_history_entry.dart   # Recent search entry
```

#### 2. New Repository Interfaces (Required)

```dart
// lib/domain/repositories/
├── text_search_repository.dart      # NEW: Full-text search
├── search_history_repository.dart   # NEW: Recent searches
└── navigation_tree_repository.dart  # EXISTING: Enhance for suggestions
```

#### 3. New Data Sources (Required)

```dart
// lib/data/datasources/
├── fts_datasource.dart              # NEW: SQLite FTS queries
├── search_history_local_datasource.dart  # NEW: SharedPreferences/SQLite
└── tree_local_datasource.dart       # EXISTING: Add suggestion index
```

#### 4. New Use Cases (Required)

```dart
// lib/domain/usecases/
├── search_content_usecase.dart      # Full-text search
├── search_by_name_usecase.dart      # Name/title search
├── search_within_document_usecase.dart  # In-document search
├── get_suggestions_usecase.dart     # Auto-complete
├── get_recent_searches_usecase.dart # History retrieval
└── save_search_usecase.dart         # History storage
```

#### 5. New Presentation Layer (Required)

```dart
// lib/presentation/
├── providers/
│   ├── search_provider.dart         # Search state management
│   ├── search_history_provider.dart # Recent searches
│   └── suggestion_provider.dart     # Auto-suggestions
├── widgets/
│   ├── search_bar_widget.dart       # Search input with suggestions
│   ├── search_results_widget.dart   # Results list
│   ├── search_filter_dialog.dart    # Nikaya filter UI
│   ├── search_result_item.dart      # Individual result
│   └── in_document_search_widget.dart  # Ctrl+F style search
└── screens/
    └── search_screen.dart           # Full search experience
```

### Database Architecture

#### Option A: Bundled FTS Database (Recommended)
```
assets/
├── data/
│   ├── tree.json
│   ├── fts.db          # Pre-built SQLite FTS5 database
│   └── ...
```

**Pros:**
- Instant search, no indexing required
- You already have fts.db from Tipitaka.lk
- Consistent results across devices

**Cons:**
- Larger app bundle
- Updates require app update

#### Option B: Runtime Index Building
Build search index on first launch from JSON files.

**Pros:**
- Smaller initial download
- Can update content independently

**Cons:**
- Slow first launch
- Complex synchronization

### Recommended Architecture Decision

**Use Option A** (Bundled FTS Database) because:
1. You already have fts.db available
2. Content updates are infrequent (canonical texts)
3. Better user experience (instant search)
4. Matches Tipitaka.lk approach

---

## 5. Search Technology Comparison

### Your Current fts.db Analysis

**Database Statistics:**
- **File Size:** 455 MB
- **Total Entries:** 466,127 records
- **Languages:** Pali and Sinhala
- **Technology:** SQLite FTS4 with unicode61 tokenizer
- **Custom Tokenchars:** Full Sinhala Unicode range (0x0D80-0x0DFF)

**Schema:**
```sql
CREATE VIRTUAL TABLE tipitaka USING fts4(
    filename,   -- e.g., 'dn-1', 'an-10-2'
    eind,       -- entry index as 'pageIndex-entryIndex' (e.g., '0-5')
    language,   -- 'pali' or 'sinh'
    type,       -- 'paragraph', 'heading', 'centered', etc.
    level,      -- hierarchy level (0-4)
    text,       -- actual content (formatting markers stripped)
    tokenize = unicode61 "tokenchars='<sinhala-unicode-range>'"
);
```

**Performance Test:**
```
Query: "බුද්ධ" across 466,127 entries
Time: 0.015 seconds (15ms)
Results: 20 matches with snippets
```

This is **excellent performance** - the current FTS4 approach is already blazing fast!

---

### Alternative Technologies Comparison

| Technology | Offline Support | Flutter Support | Performance | Index Size | Ease of Use |
|------------|-----------------|-----------------|-------------|------------|-------------|
| **SQLite FTS4** | Excellent | Native (sqflite) | Excellent (15ms) | ~455MB | Easy |
| **SQLite FTS5** | Excellent | Limited* | Slightly better | Similar | Moderate |
| **Tantivy (Rust)** | Excellent | FFI required | Excellent | +30% data size | Complex |
| **Meilisearch** | Server only | HTTP client | Excellent | N/A | Easy |
| **Lunr.js/FlexSearch** | Good | Dart port needed | Good | In-memory | Easy |
| **Isar (Dart)** | Excellent | Native | Good | Varies | Easy |

*FTS5 not available by default on Android < API 24 and requires custom SQLite build.

---

### Option Analysis

#### Option 1: Keep SQLite FTS4 (RECOMMENDED)

**Why this is the best choice for your use case:**

1. **Already blazing fast** - 15ms search across 466K entries is excellent
2. **You already have the database** - No new development needed
3. **Proven solution** - Tipitaka.lk has been using this successfully
4. **Universal compatibility** - Works on all Android versions (API 11+)
5. **Offline-first** - No network required
6. **Full Unicode support** - Already configured for Sinhala script
7. **Snippet support** - FTS4's `snippet()` function is actually better than FTS5's

**What FTS4 provides:**
- Full-text search with boolean operators (AND, OR, NOT)
- Phrase search with quotes
- Prefix search with `*`
- NEAR operator for proximity search
- `snippet()` for context preview with highlighting
- `matchinfo()` for relevance ranking

#### Option 2: Upgrade to FTS5

**When you might consider this:**
- If you need BM25 ranking (built-in)
- If you need custom tokenizers beyond unicode61
- If all your target devices are Android 7.0+ (API 24+)

**Challenges:**
- [Not available by default on older Android](https://dzolnai.medium.com/speed-up-searching-in-your-app-by-using-sqlite-and-fts-8896ab74b598)
- Would require bundling custom SQLite library
- FTS5's snippet() function is less featured than FTS4's
- Minimal performance gain for your use case

**Verdict:** Not worth the compatibility headaches for marginal gains.

#### Option 3: Tantivy (Rust-based)

**What it offers:**
- Lucene-style full-text search
- BM25 ranking, faceted search
- Blazing fast indexing and search

**Challenges:**
- Requires Rust FFI integration with Flutter
- Adds 30% to data size
- Complex build setup
- Overkill for your corpus size

**Verdict:** Great for large-scale applications, but excessive complexity for your needs.

#### Option 4: Isar Database

**What it offers:**
- Native Dart database with full-text search
- Built specifically for Flutter
- Good performance

**Challenges:**
- Would require rebuilding entire search index
- Different query syntax
- Less mature FTS than SQLite

**Verdict:** Worth considering for greenfield projects, but no benefit to switch.

---

### Recommendation: Stick with FTS4

**The existing fts.db with SQLite FTS4 is the optimal choice because:**

1. **15ms search time is excellent** - Users won't perceive any delay
2. **Zero migration cost** - Database already exists and works
3. **Maximum compatibility** - Works on all devices
4. **Battle-tested** - Proven in production on Tipitaka.lk
5. **Full feature set** - Has everything you need:
   - ✅ Fast full-text search
   - ✅ Snippet extraction with highlighting
   - ✅ Boolean operators
   - ✅ Phrase search
   - ✅ Proximity search (NEAR)
   - ✅ Prefix/wildcard search
   - ✅ Sinhala Unicode support
   - ✅ Offline capability

**The only change I recommend:** Consider adding a **word frequency table** for auto-suggestions (the populate script already has code for this but it's disabled).

---

### Database Size Optimization

#### Current Size Problem

| Component | Size |
|-----------|------|
| fts.db (current) | 455 MB |
| JSON text files | 340 MB |
| **Total** | **795 MB** |

The current FTS4 database stores text **twice** - once in the FTS index and once in the content table (`tipitaka_content` = 339 MB).

#### Size Breakdown of Current fts.db

| Table | Size | Purpose |
|-------|------|---------|
| tipitaka_content | 339 MB | Full text storage (REDUNDANT!) |
| tipitaka_segments | 103 MB | FTS index |
| tipitaka_docsize | 7 MB | Document sizes |
| Other | < 1 MB | Metadata |

#### Comparison: Old vs New Database Structure

##### Old Database (Original fts.db - 455 MB)

The original Tipitaka.lk database used a **standard FTS4 table** that stores both the search index AND the full text content:

```sql
-- Original schema (stores text TWICE - in FTS index AND content table)
CREATE VIRTUAL TABLE tipitaka USING fts4(
    filename,   -- e.g., 'dn-1'
    eind,       -- e.g., '0-5'
    language,   -- 'pali' or 'sinh'
    type,       -- 'paragraph', 'heading', etc.
    level,      -- 0-4
    text,       -- FULL TEXT STORED HERE (redundant!)
    tokenize = unicode61 "tokenchars='<sinhala-range>'"
);
```

**How FTS4 stores data internally:**
```
tipitaka (virtual table)
    ├── tipitaka_content  (339 MB) ← Stores ALL column values including full text
    ├── tipitaka_segments (103 MB) ← The actual FTS search index
    ├── tipitaka_docsize  (7 MB)   ← Document size metadata
    └── tipitaka_segdir   (<1 MB)  ← Index directory
```

**The Problem:** The `tipitaka_content` table stores the full text of every entry, but this text is ALREADY stored in the JSON files! This is 339 MB of redundant data.

**Search Query (Old):**
```sql
-- Could SELECT any column and use snippet()
SELECT filename, eind, language,
       snippet(tipitaka, '<b>', '</b>', '...', 5, 20) as preview
FROM tipitaka
WHERE text MATCH 'බුද්ධ'
LIMIT 50;
```

##### New Database (Optimized fts-contentless.db - 114 MB)

The new database uses a **contentless FTS4 table** (`content=''`) paired with a **separate metadata table**:

```sql
-- NEW: Metadata table (small - stores only location info, NOT the text)
CREATE TABLE tipitaka_meta (
    id INTEGER PRIMARY KEY,
    filename TEXT NOT NULL,    -- e.g., 'dn-1'
    eind TEXT NOT NULL,        -- e.g., '0-5'
    language TEXT NOT NULL,    -- 'pali' or 'sinh'
    type TEXT NOT NULL,        -- 'paragraph', 'heading', etc.
    level INTEGER NOT NULL     -- 0-4
    -- NOTE: NO text column! Text is in JSON files
);

-- NEW: Contentless FTS4 table (stores ONLY the search index)
CREATE VIRTUAL TABLE tipitaka USING fts4(
    content='',  -- ← KEY DIFFERENCE: No content storage!
    text,        -- Only indexes text, doesn't store it
    tokenize=unicode61 "tokenchars='<sinhala-range>'"
);

-- NEW: Suggestions table for auto-complete
CREATE TABLE suggestions (
    word TEXT PRIMARY KEY,
    language TEXT NOT NULL,
    frequency INTEGER NOT NULL
);
```

**How the new structure stores data:**
```
fts-contentless.db (114 MB total)
    ├── tipitaka_meta     (~25 MB)  ← Location info only (no text!)
    ├── tipitaka_segments (~85 MB)  ← FTS search index
    ├── suggestions       (~3 MB)   ← Word frequency for auto-complete
    └── indexes           (~1 MB)   ← For fast metadata lookups
```

**Search Query (New) - Requires JOIN:**
```sql
-- Must JOIN to get metadata (contentless can only return rowid)
SELECT m.filename, m.eind, m.language, m.type
FROM tipitaka t
JOIN tipitaka_meta m ON t.rowid = m.id
WHERE t.text MATCH 'බුද්ධ'
LIMIT 50;
```

##### Key Differences Summary

| Aspect | Old (fts.db) | New (fts-contentless.db) |
|--------|--------------|--------------------------|
| **Size** | 455 MB | 114 MB |
| **Text storage** | Stored in FTS table | NOT stored (use JSON files) |
| **snippet() function** | ✅ Works | ❌ Not available |
| **Query complexity** | Simple SELECT | Requires JOIN |
| **Metadata storage** | Inside FTS virtual table | Separate `tipitaka_meta` table |
| **Suggestions** | Not included | ✅ 95,326 words included |
| **Redundancy** | Text stored twice | No redundancy |

##### Why the New Structure Works

1. **Contentless FTS4** (`content=''`) only builds the search index, it doesn't store the actual text
2. **The text already exists** in your JSON files - no need to duplicate it
3. **Metadata table** stores just the location info (filename, eind, language) - very small
4. **rowid links** the FTS results to the metadata table
5. **After search**, fetch the actual text and context from JSON files

---

#### Optimization Options

##### Option 1: Contentless FTS4 with Metadata Table (IMPLEMENTED ✅)

This is what we built. See comparison above.

**Actual Results (Verified):**
| Metric | Original FTS4 | Optimized Contentless |
|--------|---------------|----------------------|
| Database size | 455 MB | **114 MB** |
| Size reduction | - | **75%** |
| Total entries | 466,127 | 456,977 |
| Suggestions | 0 | 95,326 |

##### Option 2: Compress JSON Files

JSON files compress extremely well:
- Original: 873 KB per file
- Gzipped: 104 KB (**88% reduction**)

Flutter can read gzipped assets using `GZipCodec`.

##### Option 3: Combined Approach (BEST)

| Component | Before | After | Savings |
|-----------|--------|-------|---------|
| fts.db | 455 MB | 114 MB | 341 MB |
| JSON files | 340 MB | ~40 MB (gzipped) | 300 MB |
| **Total** | **795 MB** | **~154 MB** | **81%** |

---

### Optimized Database Implementation (COMPLETED ✅)

#### Files Created

| File | Location | Size | Purpose |
|------|----------|------|---------|
| `fts-populate-contentless.js` | `tools/` | 16 KB | Build script |
| `fts-contentless.db` | `tools/` | **114 MB** | Optimized search database |
| `word-frequency-pali.csv` | `tools/` | 1.5 MB | Pali word suggestions |
| `word-frequency-sinh.csv` | `tools/` | 1.3 MB | Sinhala word suggestions |

#### How to Regenerate the Database

```bash
cd tools
npm install better-sqlite3  # First time only
node fts-populate-contentless.js
```

#### Search Query Patterns

```sql
-- Basic search with JOIN to get metadata
SELECT m.filename, m.eind, m.language, m.type
FROM tipitaka t
JOIN tipitaka_meta m ON t.rowid = m.id
WHERE t.text MATCH 'බුද්ධ'
LIMIT 50;

-- Search with language filter
SELECT m.filename, m.eind
FROM tipitaka t
JOIN tipitaka_meta m ON t.rowid = m.id
WHERE t.text MATCH 'ධම්ම' AND m.language = 'pali'
LIMIT 50;

-- Search with Nikaya filter
SELECT m.filename, m.eind, m.language
FROM tipitaka t
JOIN tipitaka_meta m ON t.rowid = m.id
WHERE t.text MATCH 'query' AND m.filename LIKE 'dn-%'
LIMIT 50;

-- Get auto-suggestions
SELECT word, frequency FROM suggestions
WHERE language = 'sinh' AND word LIKE 'බුද්%'
ORDER BY frequency DESC
LIMIT 10;
```

#### Performance Results

| Query Type | Time |
|------------|------|
| Simple search (`බුද්ධ`) | ~4ms |
| Search with JOIN + filter | ~193ms |
| Suggestions lookup | <1ms |

#### Fetch Context from JSON (After Search)

Since we don't store text in the database, fetch it from JSON files:

```dart
// After getting search results, load context from JSON
final document = await loadBJTDocument(result.filename);
final pageIndex = int.parse(result.eind.split('-')[0]);
final entryIndex = int.parse(result.eind.split('-')[1]);
final page = document.pages[pageIndex];
final entry = page.getSection(result.language).entries[entryIndex];
final contextPreview = entry.plainText;
```

#### Recommendation

**Use the optimized `fts-contentless.db`:**

1. ✅ **Already built** - `tools/fts-contentless.db` (114 MB)
2. ✅ **Includes suggestions** - 95,326 words for auto-complete
3. ✅ **75% smaller** than original (341 MB saved)
4. 🔄 **Optionally gzip JSON files** for additional 300 MB savings

---

### Performance Optimization Tips

Even though FTS4 is already fast, here are tips for optimal performance:

```sql
-- 1. Use prefix search for auto-complete (very fast)
SELECT DISTINCT text FROM tipitaka WHERE text MATCH 'බුද්*' LIMIT 10;

-- 2. Limit results for pagination
SELECT filename, eind, snippet(...) FROM tipitaka
WHERE text MATCH 'query' LIMIT 50 OFFSET 0;

-- 3. Filter by filename prefix for Nikaya filtering
SELECT ... FROM tipitaka
WHERE text MATCH 'query' AND filename LIKE 'dn-%';

-- 4. Use snippet() for context preview
SELECT filename, eind,
       snippet(tipitaka, '<mark>', '</mark>', '...', 5, 30) as preview
FROM tipitaka WHERE text MATCH 'query';
```

---

## 6. Implementation Plan

### Phase Overview

| Phase | Features | Priority | Estimated Effort |
|-------|----------|----------|------------------|
| Phase 1 | Core Search Infrastructure | P1 | Foundation |
| Phase 2 | Search by Name | P1 | Core |
| Phase 3 | Full-Text Content Search | P1 | Core |
| Phase 4 | Filter by Nikaya | P1 | Core |
| Phase 5 | Search Within Document | P1 | Core |
| Phase 6 | Auto-Suggestions | P2 | Enhancement |
| Phase 7 | Recent Searches | P2 | Enhancement |
| Phase 8 | Label Filtering | P3 | Enhancement |
| Phase 9 | Categories & Related | P4 | Future |

---

### Phase 1: Core Search Infrastructure

#### 1.1 Add SQLite Dependencies

```yaml
# pubspec.yaml
dependencies:
  sqflite: ^2.3.0
  path_provider: ^2.1.1
  path: ^1.8.3
```

#### 1.2 Create Search Domain Entities

**SearchResult Entity:**
```dart
// lib/domain/entities/search/search_result.dart
@freezed
class SearchResult with _$SearchResult {
  const factory SearchResult({
    required String id,
    required SearchResultType type,  // name, content
    required String title,           // Sutta name
    required String subtitle,        // Nikaya path
    required String matchedText,     // The matching text
    required String contextBefore,   // Text before match
    required String contextAfter,    // Text after match
    required String contentFileId,   // For navigation
    required int pageIndex,          // Location in document
    required int entryIndex,         // Location in page
    required String nodeKey,         // Tree node reference
    double? relevanceScore,          // For ranking
  }) = _SearchResult;
}
```

**SearchQuery Entity:**
```dart
// lib/domain/entities/search/search_query.dart
@freezed
class SearchQuery with _$SearchQuery {
  const factory SearchQuery({
    required String queryText,
    @Default(true) bool searchInPali,
    @Default(true) bool searchInSinhala,
    @Default([]) List<String> nikayaFilters,  // e.g., ['dn', 'mn']
    @Default([]) List<String> labelFilters,
    @Default(SearchType.all) SearchType searchType,
    @Default(50) int limit,
    @Default(0) int offset,
  }) = _SearchQuery;
}

enum SearchType { all, nameOnly, contentOnly }
```

#### 1.3 Create FTS Data Source

```dart
// lib/data/datasources/fts_datasource.dart
abstract class FTSDataSource {
  Future<void> initialize();
  Future<List<FTSMatch>> searchContent(
    String query, {
    List<String>? nikayaFilter,
    int limit = 50,
    int offset = 0,
  });
  Future<List<String>> getSuggestions(String prefix, {int limit = 10});
}

class FTSDataSourceImpl implements FTSDataSource {
  Database? _database;

  @override
  Future<void> initialize() async {
    // Copy fts.db from assets to documents directory
    // Open database connection
  }

  @override
  Future<List<FTSMatch>> searchContent(
    String query, {
    List<String>? nikayaFilter,
    int limit = 50,
    int offset = 0,
  }) async {
    // Execute FTS5 MATCH query
    // Apply nikaya filters
    // Return results with snippets
  }
}
```

#### 1.4 Create Search Repository

```dart
// lib/domain/repositories/text_search_repository.dart
abstract class TextSearchRepository {
  Future<Either<Failure, List<SearchResult>>> search(SearchQuery query);
  Future<Either<Failure, List<String>>> getSuggestions(String prefix);
}

// lib/data/repositories/text_search_repository_impl.dart
class TextSearchRepositoryImpl implements TextSearchRepository {
  final FTSDataSource _ftsDataSource;
  final NavigationTreeRepository _treeRepository;

  // Combine FTS results with tree metadata
}
```

---

### Phase 2: Search by Name (P1)

#### 2.1 Enhance Existing Tree Search

The `NavigationTreeRepositoryImpl.searchNodes()` already exists. Enhance it:

```dart
// Add to navigation_tree_repository.dart interface
Future<Either<Failure, List<SearchResult>>> searchByName({
  required String query,
  bool searchInPali = true,
  bool searchInSinhala = true,
  List<String>? nikayaFilter,
});
```

#### 2.2 Create Search Use Case

```dart
// lib/domain/usecases/search_by_name_usecase.dart
class SearchByNameUseCase {
  final NavigationTreeRepository repository;

  Future<Either<Failure, List<SearchResult>>> execute(SearchQuery query);
}
```

#### 2.3 Build Search UI

```dart
// lib/presentation/widgets/search_bar_widget.dart
class SearchBarWidget extends ConsumerWidget {
  // TextField with decoration
  // Debounced search trigger
  // Clear button
  // Filter button
}

// lib/presentation/widgets/search_results_widget.dart
class SearchResultsWidget extends ConsumerWidget {
  // ListView of SearchResultItem widgets
  // Empty state
  // Loading state
  // Error state
}

// lib/presentation/widgets/search_result_item.dart
class SearchResultItem extends StatelessWidget {
  // Title (sutta name)
  // Subtitle (nikaya path)
  // Highlighted match text
  // Tap to navigate
}
```

---

### Phase 3: Full-Text Content Search (P1)

#### 3.1 Integrate FTS Database

```dart
// Asset to app directory copy utility
class DatabaseCopyHelper {
  static Future<String> copyFTSDatabase() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(documentsDir.path, 'fts.db');

    if (!await File(dbPath).exists()) {
      final data = await rootBundle.load('assets/data/fts.db');
      await File(dbPath).writeAsBytes(data.buffer.asUint8List());
    }

    return dbPath;
  }
}
```

#### 3.2 Create Content Search Use Case

```dart
// lib/domain/usecases/search_content_usecase.dart
class SearchContentUseCase {
  final TextSearchRepository searchRepository;
  final NavigationTreeRepository treeRepository;

  Future<Either<Failure, SearchResults>> execute(SearchQuery query) async {
    // 1. Execute FTS search
    // 2. Enrich results with tree metadata
    // 3. Generate context snippets
    // 4. Return ranked results
  }
}
```

#### 3.3 Display Content Search Results

- Show matched text with highlighting
- Show context (text before/after match)
- Show sutta name and location
- Navigate to exact position on tap

---

### Phase 4: Filter by Nikaya (P1)

#### 4.1 Create Filter Dialog

```dart
// lib/presentation/widgets/search_filter_dialog.dart
class SearchFilterDialog extends ConsumerWidget {
  // Checkbox tree of Nikayas:
  // □ Dīgha Nikāya
  //   □ Sīlakkhandha-vagga
  //   □ Mahā-vagga
  //   □ Pāthika-vagga
  // □ Majjhima Nikāya
  // □ Saṃyutta Nikāya
  // □ Aṅguttara Nikāya
  // □ Khuddaka Nikāya
}
```

#### 4.2 Apply Filters to Search

```dart
// Modify FTS query to filter by nikaya
String buildFilteredQuery(String query, List<String> nikayas) {
  if (nikayas.isEmpty) return query;

  final nikayaClause = nikayas.map((n) => "file_id LIKE '$n%'").join(' OR ');
  return "$query AND ($nikayaClause)";
}
```

---

### Phase 5: Search Within Document (P1)

This is the "Ctrl+F" style search within the currently open sutta.

#### 5.1 Create In-Document Search Widget

```dart
// lib/presentation/widgets/in_document_search_widget.dart
class InDocumentSearchWidget extends ConsumerWidget {
  // Floating search bar (appears with keyboard shortcut or icon)
  // Shows: "3 of 17 matches"
  // Up/Down navigation buttons
  // Highlights all matches in document
  // Scrolls to current match
}
```

#### 5.2 Create In-Document Search Provider

```dart
// lib/presentation/providers/in_document_search_provider.dart
class InDocumentSearchState {
  final String query;
  final List<MatchLocation> matches;
  final int currentMatchIndex;
  final bool isSearching;
}

class InDocumentSearchNotifier extends StateNotifier<InDocumentSearchState> {
  void search(String query, BJTDocument document);
  void nextMatch();
  void previousMatch();
  void clearSearch();
}
```

#### 5.3 Highlight Matches in Reader

Modify `MultiPaneReaderWidget` to:
1. Accept list of match positions
2. Highlight matches in text
3. Scroll to current match
4. Update highlight on match navigation

---

### Phase 6: Auto-Suggestions (P2)

#### 6.1 Build Suggestion Index

Options:
1. Use FTS database prefix search
2. Build separate trie/prefix index
3. Use tree node names as suggestions

```dart
// lib/data/datasources/suggestion_datasource.dart
class SuggestionDataSourceImpl {
  // Option 1: FTS prefix search
  Future<List<String>> getSuggestions(String prefix) async {
    return _database.rawQuery(
      "SELECT term FROM fts_terms WHERE term LIKE ? LIMIT 10",
      ['$prefix%'],
    );
  }

  // Option 2: Sutta name suggestions from tree
  Future<List<SuttaSuggestion>> getSuttaSuggestions(String prefix) {
    // Search node names in tree
  }
}
```

#### 6.2 Create Suggestion UI

```dart
// Dropdown below search bar
class SuggestionDropdown extends StatelessWidget {
  // Shows as user types
  // Recent searches at top
  // Matching suttas
  // Matching terms
  // Tap to search or navigate
}
```

---

### Phase 7: Recent Searches (P2)

#### 7.1 Create History Storage

```dart
// lib/data/datasources/search_history_datasource.dart
class SearchHistoryDataSource {
  static const _key = 'recent_searches';
  final SharedPreferences _prefs;

  Future<List<SearchHistoryEntry>> getRecentSearches({int limit = 10});
  Future<void> addSearch(SearchHistoryEntry entry);
  Future<void> removeSearch(String id);
  Future<void> clearHistory();
}
```

#### 7.2 Create History Entity

```dart
@freezed
class SearchHistoryEntry with _$SearchHistoryEntry {
  const factory SearchHistoryEntry({
    required String id,
    required String query,
    required DateTime timestamp,
    SearchQuery? fullQuery,  // Preserve filters
  }) = _SearchHistoryEntry;
}
```

#### 7.3 Display Recent Searches

Show recent searches when:
- Search bar is focused with empty query
- Below suggestions in dropdown

---

### Phase 8: Label Filtering (P3)

This requires defining a label taxonomy. Recommend:

1. **System Labels** (predefined):
   - Content type: Sutta, Vinaya, Abhidhamma
   - Topics: Meditation, Ethics, Psychology, Philosophy
   - Difficulty: Beginner, Intermediate, Advanced

2. **User Labels** (custom):
   - Allow users to tag suttas
   - Store in local database

#### 8.1 Label Entity

```dart
@freezed
class Label with _$Label {
  const factory Label({
    required String id,
    required String name,
    required LabelType type,  // system, user
    String? color,
    String? icon,
  }) = _Label;
}
```

---

### Phase 9: Categories & Related Content (P4)

This is an advanced feature requiring:

1. **Category Taxonomy**:
   - Define categories (Buddha's Life, Four Noble Truths, etc.)
   - Map suttas to categories (manual curation or ML)

2. **Related Content Algorithm**:
   - Option A: Manual curation (editorial)
   - Option B: Text similarity (ML/embeddings)
   - Option C: Same category = related
   - Option D: Cross-references in commentaries

---

## FTS Database Schema (Reference)

Expected schema for fts.db (based on Tipitaka.lk pattern):

```sql
-- Main FTS5 virtual table
CREATE VIRTUAL TABLE content_fts USING fts5(
  file_id,      -- e.g., 'dn-1'
  page_number,  -- page in document
  entry_index,  -- entry in page
  language,     -- 'pi' or 'si'
  content,      -- actual text (plain, no formatting)
  tokenize='unicode61'
);

-- Metadata table for quick lookups
CREATE TABLE content_metadata (
  id INTEGER PRIMARY KEY,
  file_id TEXT,
  page_number INTEGER,
  entry_index INTEGER,
  language TEXT,
  nikaya TEXT,      -- 'dn', 'mn', 'sn', 'an', 'kn'
  sutta_name TEXT
);

-- Suggestion terms (optional)
CREATE TABLE search_terms (
  term TEXT PRIMARY KEY,
  frequency INTEGER,
  language TEXT
);
```

---

## Testing Strategy

### Unit Tests
- Search result entity creation
- Query building with filters
- FTS query execution
- Result ranking algorithm

### Widget Tests
- SearchBarWidget rendering
- SearchResultsWidget states (empty, loading, results, error)
- InDocumentSearchWidget navigation
- FilterDialog selection

### Integration Tests
- Full search flow: type query → see results → tap result → navigate to position
- Filter application
- In-document search with highlighting
- Recent searches persistence

---

## Implementation Guidelines

### 1. Search UX Best Practices

```dart
// Debounce search input (300-500ms)
final searchQueryProvider = StateProvider<String>((ref) => '');

// Don't search on every keystroke
ref.listen(searchQueryProvider, (previous, next) {
  _debouncer.run(() => ref.read(executeSearchProvider)(next));
});
```

### 2. Result Highlighting

```dart
// Use RichText with TextSpan for highlighting
Widget buildHighlightedText(String text, String query) {
  final spans = <TextSpan>[];
  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();

  int start = 0;
  int index;

  while ((index = lowerText.indexOf(lowerQuery, start)) != -1) {
    // Add text before match
    if (index > start) {
      spans.add(TextSpan(text: text.substring(start, index)));
    }
    // Add highlighted match
    spans.add(TextSpan(
      text: text.substring(index, index + query.length),
      style: TextStyle(backgroundColor: Colors.yellow),
    ));
    start = index + query.length;
  }

  // Add remaining text
  if (start < text.length) {
    spans.add(TextSpan(text: text.substring(start)));
  }

  return RichText(text: TextSpan(children: spans));
}
```

### 3. Search Provider Pattern

```dart
// lib/presentation/providers/search_provider.dart
@freezed
class SearchState with _$SearchState {
  const factory SearchState.initial() = _Initial;
  const factory SearchState.loading() = _Loading;
  const factory SearchState.results(List<SearchResult> results) = _Results;
  const factory SearchState.empty(String query) = _Empty;
  const factory SearchState.error(Failure failure) = _Error;
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._searchUseCase) : super(const SearchState.initial());

  final SearchContentUseCase _searchUseCase;

  Future<void> search(SearchQuery query) async {
    if (query.queryText.isEmpty) {
      state = const SearchState.initial();
      return;
    }

    state = const SearchState.loading();

    final result = await _searchUseCase.execute(query);

    state = result.fold(
      (failure) => SearchState.error(failure),
      (results) => results.isEmpty
        ? SearchState.empty(query.queryText)
        : SearchState.results(results),
    );
  }
}
```

### 4. Navigate to Search Result

```dart
void navigateToSearchResult(SearchResult result, WidgetRef ref) {
  // 1. Create or find tab for this content
  final existingTabIndex = ref.read(tabsProvider).indexWhere(
    (tab) => tab.contentFileId == result.contentFileId,
  );

  if (existingTabIndex >= 0) {
    // Switch to existing tab and navigate to position
    ref.read(switchTabProvider)(existingTabIndex);
  } else {
    // Create new tab
    final tab = ReaderTab(
      label: result.title,
      fullName: result.title,
      contentFileId: result.contentFileId,
      nodeKey: result.nodeKey,
      pageIndex: result.pageIndex,
      // ... other fields
    );
    ref.read(tabsProvider.notifier).addTab(tab);
    ref.read(activeTabIndexProvider.notifier).state =
      ref.read(tabsProvider).length - 1;
  }

  // 2. Navigate to exact position
  ref.read(currentPageIndexProvider.notifier).state = result.pageIndex;

  // 3. Optionally highlight the match
  ref.read(highlightedEntryProvider.notifier).state = result.entryIndex;
}
```

---

## Summary

### What the User Story Covers Well
- Core search functionality (name and content)
- Filtering by Nikaya
- Search within document
- Modern UX features (suggestions, history)

### Recommended Additions
1. **P1**: Result context preview, search language selection
2. **P2**: Phrase search, result sorting
3. **P3**: Boolean operators, bookmark results

### Architectural Changes Required
1. Add SQLite/FTS dependencies
2. Create new domain entities for search
3. Create FTS data source and repository
4. Add search providers and widgets
5. Integrate with existing tab navigation

### Key Implementation Decisions
1. **Use bundled fts.db** - matches existing Tipitaka.lk approach
2. **Combine name + content search** - unified search experience
3. **In-document search as overlay** - non-intrusive UX
4. **Recent searches in SharedPreferences** - simple persistence

---

## Next Steps

### Completed ✅
1. ~~**Obtain fts.db**~~ - Analyzed original database structure
2. ~~**Analyze fts.db schema**~~ - Documented in this plan
3. ~~**Optimize database**~~ - Created `fts-contentless.db` (75% size reduction)
4. ~~**Generate suggestions**~~ - 95,326 words for auto-complete

### Ready to Start
5. **Copy database to assets** - Move `tools/fts-contentless.db` to `assets/data/`
6. **Add SQLite dependencies** - Add sqflite, path_provider to pubspec.yaml
7. **Phase 1 implementation** - Create FTS datasource in Flutter
8. **Iterative development** - Phase by phase with testing
