# How Search Works

This document traces the full search pipeline — from a keystroke in the search
bar all the way to the JSON document that holds the matched text. It follows
clean architecture: presentation → repository (caching) → repository (real) →
datasource (FTS) → SQLite, then back out to the JSON assets.

## The journey at a glance

```
   UI (search bar)
        │  user types "අනාථ"
        ▼
1. SearchStateNotifier.updateQuery()          ← presentation/providers/search_state.dart
        │  • debounce (waits ~300ms after you stop typing)
        │  • computeEffectiveQuery()  (Singlish→Sinhala, strip ZWJ)
        ▼
2. CachingTextSearchRepository                ← data/repositories/caching_text_search_repository.dart
        │  • build cache key, check LRU cache  (HIT → return immediately)
        │  • MISS → call the real repo
        ▼
3. TextSearchRepositoryImpl                    ← data/repositories/text_search_repository_impl.dart
        │  • runs 3 searches: Titles, Full-text, Definitions
        │  • for full-text, calls the FTS datasource
        ▼
4. FTSDataSourceImpl.searchFullText()          ← data/datasources/fts_local_datasource.dart
        │  • buildFtsQuery()  → FTS5 syntax
        │  • SQL: SELECT ... WHERE fts MATCH ?  ORDER BY bm25()
        ▼
   SQLite FTS5 database (bjt-fts.db)
        │  returns rows of *metadata* (filename, eind, nodeKey) — NOT the text
        ▼
5. Back in TextSearchRepositoryImpl
        │  • for each match, _loadTextForMatch()
        │  • reads assets/text/{filename}.json  ← the JSON doc!
        ▼
   SearchResult objects → back up to the UI
        │
        ▼
6. GroupedFTSMatch.fromSearchResults()         ← presentation layer (display time)
        │  • group flat matches by nodeKey (sutta)
        │  • primary match + nested "See X more" secondary matches
        ▼
   Rendered as grouped tiles
```

## Key files

| Layer | File |
|-------|------|
| State / debounce | `lib/presentation/providers/search_state.dart` |
| Providers (DI wiring) | `lib/presentation/providers/search_provider.dart` |
| Query normalization | `lib/core/utils/search_query_utils.dart` |
| Cache decorator | `lib/data/repositories/caching_text_search_repository.dart` |
| Orchestration repo | `lib/data/repositories/text_search_repository_impl.dart` |
| FTS datasource | `lib/data/datasources/fts_local_datasource.dart` |
| FTS data models | `lib/data/datasources/fts_datasource.dart` |
| FTS5 query builder | `packages/wisdom_shared/lib/src/fts/fts_query_builder.dart` |
| Grouping by sutta | `lib/domain/entities/search/grouped_fts_match.dart` |
| Grouped result tile | `lib/presentation/widgets/search/grouped_fts_tile.dart` |

---

## Step 1 — Input → effective query (presentation layer)

When you type, `SearchStateNotifier.updateQuery()` runs. Two important things
happen before any searching.

### Debouncing

It does **not** search on every keystroke. It waits for you to stop typing
(`search_state.dart`):

```dart
_debounceTimer?.cancel();           // cancel the previous pending search
_debounceTimer = Timer(
  duration,                          // ~300ms
  _performSearch,                    // only fires if you stop typing
);
```

### Normalizing the query

`computeEffectiveQuery` (`core/utils/search_query_utils.dart`) turns your raw
text into something the FTS index can match:

```dart
String computeEffectiveQuery(String rawQuery) {
  final sanitized = sanitizeSearchQuery(rawQuery);          // strip junk chars
  // If you typed in Singlish (Roman letters), convert to Sinhala script
  final converted = transliterator.isSinglishQuery(sanitized)
      ? transliterator.convert(sanitized)                   // "anatha" → අනාථ
      : sanitized;
  var result = converted.replaceAll('~', '');
  result = normalizeText(result);                            // strip ZWJ/ZWNJ
  return result;
}
```

The ZWJ/ZWNJ stripping is critical: the FTS database stores text **without**
those invisible joining characters, so the query must match the same way.
(See the shared pipeline note: the Singlish transliterator re-introduces ZWJ for
rakaransha `්‍ර` and yansaya `‍ය`, which `normalizeText` then strips again.)

---

## Step 2 — The cache decorator

`_performSearch` calls `searchTopResults` / `searchByResultType` on the
repository. The registered repository is actually a **`CachingTextSearchRepository`**
wrapping the real one (decorator pattern, wired in `search_provider.dart`). It
builds a deterministic key from the query and checks an LRU cache first
(`caching_text_search_repository.dart`):

```dart
final cacheKey = _generateKey(query, null, maxPerCategory: maxPerCategory);
final cached = cache.get(cacheKey);
if (cached != null) return Right(cached);     // cache HIT — done, no DB hit

final result = await _delegate.searchTopResults(query, ...);  // MISS → real repo
result.fold((_) {}, (data) => cache.put(cacheKey, data));     // store result
```

Notes:
- Three independent LRU caches: top results, full per-tab results, and counts.
- The cache key sorts every `Set` (editions, scope, dictionaries) so that
  `{BJT, SC}` and `{SC, BJT}` map to the same entry.
- Only **successful** results are cached — failures never poison the cache.
- Suggestions are **not** cached (cheap, per-keystroke).
- Repeating a recent search never touches the database.

---

## Step 3 — The repository orchestrates 3 searches

`TextSearchRepositoryImpl.searchTopResults` runs **three independent searches**
and bundles them into a `GroupedSearchResult`:

1. **Title matches** — `_searchTitles()` scans the in-memory navigation tree.
   Fast, no DB; plain Dart string matching (not FTS). Respects the
   පාළි / සිංහල language scope and the scope chips.
2. **Full-text matches** — `_searchFullText()` → goes to the FTS database
   (the part most people mean by "search").
3. **Definition matches** — `_searchDefinitions()` → the dictionary repository.

For full-text it **overfetches** (7× the needed amount,
`_groupedSearchOverfetchMultiplier = 7`) because results are later grouped by
sutta (`nodeKey`), and it needs enough rows to fill the requested number of
groups.

The language toggle maps to a DB code in exactly one place:

```dart
String? _ftsLanguageFilter(SearchLanguageScope scope) => switch (scope) {
      SearchLanguageScope.both    => null,   // search both languages
      SearchLanguageScope.pali    => 'pali',
      SearchLanguageScope.sinhala => 'sinh', // DB stores Sinhala as 'sinh'
    };
```

---

## Step 4 — FTS matching (the actual SQLite query)

`FTSDataSourceImpl.searchFullText` does the matching. It can search several
editions in parallel (each edition has its own `{editionId}-fts.db`, copied from
assets to the documents directory on first use).

### 4a. Build FTS5 syntax

`buildFtsQuery` (`packages/wisdom_shared/lib/src/fts/fts_query_builder.dart`)
converts the normalized query into FTS5 query syntax:

| You typed | Options | FTS5 query produced |
|-----------|---------|---------------------|
| `අනාථ` | normal | `අනාථ*` (prefix match) |
| `අනාථ` | exact | `අනාථ` (exact token) |
| `word1 word2` | phrase, exact | `"word1 word2"` |
| `word1 word2` | phrase, prefix | `NEAR(word1* word2*, 1)` |
| `word1 word2` | separate, anywhere, prefix | `word1* word2*` (implicit AND) |
| `word1 word2` | separate, proximity, prefix | `NEAR(word1* word2*, 10)` |

(FTS5 doesn't support wildcards inside phrase quotes, so phrase-with-prefix is
approximated by `NEAR(..., 1)`.)

### 4b. The SQL

The key clause is `WHERE {table} MATCH ?` — that is FTS5 performing the actual
full-text matching (`fts_local_datasource.dart`):

```sql
WITH ranked AS (
  SELECT m.id, m.filename, m.eind, m.language, m.type, m.level, m.nodeKey,
         bm25(bjt_fts) AS score             -- relevance ranking
  FROM bjt_fts
  JOIN bjt_meta m ON bjt_fts.rowid = m.id   -- join FTS index → metadata table
  WHERE bjt_fts MATCH ?                       -- ← the FTS match happens HERE
    AND <scope filter>                        -- optional: limit to dn-, sp-, etc.
    AND <language filter>                     -- optional: පාළි / සිංහල toggle
)
SELECT * FROM ranked ORDER BY score LIMIT ? OFFSET ?
```

Two tables work together:
- **`bjt_fts`** — the FTS5 virtual table (the searchable word index).
- **`bjt_meta`** — a normal table holding metadata per entry: `filename`,
  `eind` (`"pageIndex-entryIndex"`), `language`, `type`, `level`, and `nodeKey`.

The CTE (`WITH ranked AS ...`) exists so `bm25()` is computed in the correct FTS
context (the FTS table referenced directly, not aliased); ordering and
pagination then happen in the outer query.

`ORDER BY score` uses **BM25**, SQLite's built-in relevance ranking. Lower (more
negative) scores are better matches.

Crucially, **the FTS database does not return the text itself** — only metadata
pointing to *where* the match lives. Each row becomes an `FTSMatch`
(`fts_datasource.dart`), carrying `filename`, `eind`, and `nodeKey`.

`countByResultType` uses the same `MATCH` clause but `SELECT COUNT(*)` (and only
joins `bjt_meta` when a scope or language filter is active) to populate the tab
badge numbers cheaply.

---

## Step 5 — Finding the JSON doc

Back in `TextSearchRepositoryImpl._searchFullText`, each `FTSMatch` becomes a
`SearchResult`. To get the preview snippet, it reads the actual JSON document
(`text_search_repository_impl.dart`):

```dart
Future<String?> _loadTextForMatch(String filename, String eind, String language) async {
  final eindParts = eind.split('-');               // "12-3" → page 12, entry 3
  final pageIndex = int.parse(eindParts[0]);
  final entryIndex = int.parse(eindParts[1]);

  // ← THE JSON DOC: bundled asset, named by the filename from the FTS row
  final jsonString = await rootBundle.loadString('assets/text/$filename.json');
  final jsonData = json.decode(jsonString) as Map<String, dynamic>;

  final page = (jsonData['pages'] as List)[pageIndex];   // jump to the page
  final langData = page[lang];                            // 'pali' or 'sinh'
  final entry = langData['entries'][entryIndex];          // jump to the entry
  return entry['text'] as String;                         // the matched text
}
```

So:
- **`filename`** tells you *which* JSON file to open.
- **`eind`** (e.g. `"12-3"`) is the **coordinate** pinning the match to an exact
  page + entry inside that file. No scanning — direct indexed access.
- **`nodeKey`** is used for an O(1) lookup into the navigation tree
  (`nodeMap[match.nodeKey]`) to get the sutta title and breadcrumb path — no
  tree walking needed.

> **`nodeKey` vs `filename` (contentFileId)** — these are *not* the same thing.
> `nodeKey` identifies the **sutta/section**; `filename` identifies the **JSON
> file**. Multiple suttas can live in one content file, so several `nodeKey`s can
> map to the same `filename`. This matters for grouping (next step) and for
> performance (see the "Related reading" TODO on redundant parsing).

---

## Step 6 — Grouping matches by sutta (nested results)

The flat list of `SearchResult`s often contains **several matches from the same
sutta**. Rather than showing each as a separate row, the presentation layer
groups them. `GroupedFTSMatch.fromSearchResults`
(`lib/domain/entities/search/grouped_fts_match.dart`) buckets results by
`nodeKey`:

```dart
final grouped = <String, List<SearchResult>>{};
for (final result in results) {
  grouped.putIfAbsent(result.nodeKey, () => []).add(result);   // bucket by sutta
}
```

Within each group, matches are sorted by appearance order (`pageIndex`, then
`entryIndex`) and split into:

- **`primaryMatch`** — the first match, shown in the collapsed tile.
- **`secondaryMatches`** — the rest, hidden behind a **"See X more"** link.

`grouped_fts_tile.dart` renders the primary like a normal result tile, plus the
expandable link that reveals the secondary matches as `SecondaryMatchTile`s. Each
sub-match taps through to its own exact `pageIndex`/`entryIndex` in the sutta.

This is why a single search can produce many matches pointing at the **same JSON
file** — both within one group (same sutta) and across groups (suttas sharing a
file). See the "Related reading" TODO on redundant parsing for the performance
implication.

> **Two grouping steps, don't confuse them:**
> - `_limitToGroups` (repository, Step 3) — caps the **Top Results** preview to N
>   distinct suttas using the 7× overfetch.
> - `GroupedFTSMatch.fromSearchResults` (presentation, this step) — turns the flat
>   results into primary + nested-secondary tiles for display.

---

## Web vs native: where the text comes from

The JSON read differs by platform (`text_search_repository_impl.dart`):

```dart
final matchedText = match.matchedText                    // web: already loaded
    ?? await _loadTextForMatch(match.filename, match.eind, match.language)  // native
    ?? '';
```

- **Native** (macOS / iOS / Android): the JSON files are bundled assets, so the
  repository reads them via `rootBundle`.
- **Web**: the JSON files are *not* bundled. The server pre-loads the text and
  attaches it as `match.matchedText` in the response, so the repository skips
  the file read entirely.

---

## The whole thing in one sentence

> You type → it's debounced and normalized (Singlish→Sinhala, ZWJ stripped) →
> checked against an LRU cache → the FTS5 `MATCH` query finds *which entries*
> contain the word (ranked by BM25, returning only metadata: `filename` +
> `eind` + `nodeKey`) → those coordinates are used to open
> `assets/text/{filename}.json` and pull the exact entry's text for the result
> snippet.

---

## Related reading

- `docs/multi_edition_architecture.md` — how multiple content sources (BJT,
  SuttaCentral) share this pipeline.
- `docs/todo/search_redundant_json_parsing.md` — the same JSON file is currently
  re-parsed once per match (Step 5); nested sub-matches (Step 6) make this common.
- `lib/domain/entities/search/` — the search entities (`SearchQuery`,
  `SearchResult`, `GroupedSearchResult`, `GroupedFTSMatch`,
  `SearchLanguageScope`).
