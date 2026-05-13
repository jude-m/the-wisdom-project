# Search Results Caching Implementation

This document describes the caching mechanism for search results in The Wisdom Project. The cache improves UX by avoiding repeated expensive FTS (Full-Text Search) queries when users search the same terms.

## Overview

- **Pattern**: Repository decorator (wraps existing `TextSearchRepositoryImpl`)
- **Storage**: In-memory LRU cache (capacity-bounded; no TTL)
- **Platforms**: Mobile (iOS/Android), Desktop (macOS/Windows/Linux), Web
- **Data staleness**: Not a concern — Tipitaka corpus is immutable
- **Hottest cacheable call**: `countByResultType` — fired *unawaited* on every keystroke
  (debounced) **and** every tab switch in `SearchStateNotifier._performSearch`
  (`lib/presentation/providers/search_state.dart`). Tab-switch flicker → 0ms.

---

## Architecture

```
Presentation Layer
┌─────────────────────────────────────────┐
│ SearchStateNotifier                     │
│ (lib/presentation/providers/search_state.dart)
└──────────────────┬──────────────────────┘
                   │ uses TextSearchRepository interface
                   ▼
Domain Layer
┌─────────────────────────────────────────┐
│ TextSearchRepository (interface)        │
│ (lib/domain/repositories/text_search_repository.dart)
└──────────────────┬──────────────────────┘
                   │ implemented by
                   ▼
Data Layer
┌─────────────────────────────────────────┐
│ CachingTextSearchRepository (decorator) │ ◄── NEW
│ (lib/data/repositories/)                │
│   - LRU caches per method type          │
│   - Delegates cache misses to wrapped   │
└──────────────────┬──────────────────────┘
                   │ wraps
                   ▼
┌─────────────────────────────────────────┐
│ TextSearchRepositoryImpl                │ (unchanged)
│ (lib/data/repositories/)                │
│   - FTSDataSource                       │
│   - NavigationTreeRepository            │
│   - DictionaryRepository                │
└─────────────────────────────────────────┘
```

### Why Decorator Pattern?

1. **Matches existing pattern**: `BJTDocumentRepositoryImpl` uses simple Map cache
2. **Transparent to presentation layer**: No changes to `SearchStateNotifier`
3. **Easy to test**: Can mock cache behavior
4. **Feature flag support**: Easy to enable/disable for A/B testing

---

## Files to Create

### 1. `lib/data/cache/lru_cache.dart`

Generic LRU (Least Recently Used) cache. **No TTL** — the Tipitaka corpus is
immutable, so cached results never go stale. Capacity bounds memory; LRU
eviction handles cold entries.

```dart
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Generic LRU cache (capacity-bounded, no TTL).
///
/// Uses LinkedHashMap to maintain insertion order.
/// On access, entries are re-inserted to move to "most recently used" position.
/// On capacity overflow, the first entry (least recently used) is evicted.
class LRUCache<K, V> {
  final int capacity;
  final LinkedHashMap<K, V> _map = LinkedHashMap();

  // Aggregated stats. Useful for ad-hoc diagnostics; cheap to maintain.
  int _hits = 0;
  int _misses = 0;

  LRUCache(this.capacity);

  V? get(K key) {
    if (!_map.containsKey(key)) {
      _misses++;
      return null;
    }
    // LRU touch: remove and re-insert at end (most recently used)
    final value = _map.remove(key) as V;
    _map[key] = value;
    _hits++;
    return value;
  }

  void put(K key, V value) {
    if (_map.containsKey(key)) {
      _map.remove(key);
    } else if (_map.length >= capacity) {
      _map.remove(_map.keys.first);
    }
    _map[key] = value;
  }

  void clear() {
    _map.clear();
    _hits = 0;
    _misses = 0;
  }

  void logStats(String cacheName) {
    if (kDebugMode) debugPrint('[$cacheName] $stats');
  }

  int get size => _map.length;

  CacheStats get stats => CacheStats(
        size: _map.length,
        maxSize: capacity,
        hits: _hits,
        misses: _misses,
      );
}

/// Immutable snapshot of cache statistics.
class CacheStats {
  final int size;
  final int maxSize;
  final int hits;
  final int misses;

  const CacheStats({
    required this.size,
    required this.maxSize,
    required this.hits,
    required this.misses,
  });

  double get hitRate => (hits + misses) > 0 ? hits / (hits + misses) : 0.0;

  @override
  String toString() {
    final rate = (hitRate * 100).toStringAsFixed(1);
    return 'size=$size/$maxSize hits=$hits misses=$misses rate=$rate%';
  }
}
```

### 2. `lib/data/cache/cache_config.dart`

Platform-specific configuration with feature flag.

```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Configuration for search result caching.
///
/// Memory budget varies by platform. No TTL — corpus is immutable.
class CacheConfig {
  final int maxEntries;
  final bool enabled;

  const CacheConfig({
    required this.maxEntries,
    required this.enabled,
  });

  /// Create platform-appropriate configuration.
  ///
  /// | Platform | Max Entries |
  /// |----------|-------------|
  /// | Mobile   | 20          |
  /// | Web      | 30          |
  /// | Desktop  | 50          |
  factory CacheConfig.forPlatform({bool enabled = true}) {
    if (kIsWeb) {
      return CacheConfig(maxEntries: 30, enabled: enabled);
    }
    if (Platform.isAndroid || Platform.isIOS) {
      // Reduce to 10 if OOM issues surface on older devices.
      return CacheConfig(maxEntries: 20, enabled: enabled);
    }
    // Desktop (macOS, Windows, Linux)
    return CacheConfig(maxEntries: 50, enabled: enabled);
  }

  /// Disabled — all cache calls become pass-through.
  factory CacheConfig.disabled() =>
      const CacheConfig(maxEntries: 0, enabled: false);
}
```

### 3. `lib/data/repositories/caching_text_search_repository.dart`

Repository decorator that wraps `TextSearchRepositoryImpl` with caching.

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/failure.dart';
import '../../domain/entities/search/grouped_search_result.dart';
import '../../domain/entities/search/search_query.dart';
import '../../domain/entities/search/search_result.dart';
import '../../domain/entities/search/search_result_type.dart';
import '../../domain/repositories/text_search_repository.dart';
import '../cache/cache_config.dart';
import '../cache/lru_cache.dart';

/// Caching decorator for TextSearchRepository.
///
/// Wraps an existing repository implementation and adds LRU caching
/// for search results. Cache is transparent to callers.
///
/// Separate caches are maintained for:
/// - Top results (grouped preview)
/// - Full results by type
/// - Result counts
///
/// Suggestions are NOT cached — they're fast (in-memory FTS prefix scan)
/// and the call site fires per-keystroke, so caching adds little.
class CachingTextSearchRepository implements TextSearchRepository {
  final TextSearchRepository _delegate;

  // Nullable so disabled mode requires no special-case in tests / clearAll.
  // (Earlier draft used `late final` + conditional init; that risks a
  // LateInitializationError if a future call site forgets the `enabled` gate.)
  final LRUCache<String, GroupedSearchResult>? _topResultsCache;
  final LRUCache<String, List<SearchResult>>? _fullResultsCache;
  final LRUCache<String, Map<SearchResultType, int>>? _countsCache;

  CachingTextSearchRepository(
    this._delegate, {
    required CacheConfig config,
  })  : _topResultsCache =
            config.enabled ? LRUCache(config.maxEntries) : null,
        // No `* 2` multiplier: pagination not implemented yet (limit=50,
        // offset=0 in current call sites). Bump when "load more" lands.
        _fullResultsCache =
            config.enabled ? LRUCache(config.maxEntries) : null,
        _countsCache =
            config.enabled ? LRUCache(config.maxEntries) : null;

  @override
  Future<Either<Failure, GroupedSearchResult>> searchTopResults(
    SearchQuery query, {
    int maxPerCategory = 3,
  }) async {
    final cache = _topResultsCache;
    if (cache == null) {
      return _delegate.searchTopResults(query, maxPerCategory: maxPerCategory);
    }

    final cacheKey = _generateKey(query, null, maxPerCategory: maxPerCategory);
    final cached = cache.get(cacheKey);
    if (cached != null) {
      if (kDebugMode) debugPrint('🔍 HIT  [topResults] $cacheKey');
      return Right(cached);
    }

    if (kDebugMode) debugPrint('☁️  MISS [topResults] $cacheKey');
    final result = await _delegate.searchTopResults(
      query,
      maxPerCategory: maxPerCategory,
    );

    result.fold(
      (_) {}, // Don't cache failures
      (data) => cache.put(cacheKey, data),
    );
    return result;
  }

  @override
  Future<Either<Failure, List<SearchResult>>> searchByResultType(
    SearchQuery query,
    SearchResultType resultType,
  ) async {
    final cache = _fullResultsCache;
    if (cache == null) return _delegate.searchByResultType(query, resultType);

    final cacheKey = _generateKey(query, resultType);
    final cached = cache.get(cacheKey);
    if (cached != null) {
      if (kDebugMode) debugPrint('🔍 HIT  [fullResults] $cacheKey');
      return Right(cached);
    }

    if (kDebugMode) debugPrint('☁️  MISS [fullResults] $cacheKey');
    final result = await _delegate.searchByResultType(query, resultType);

    result.fold(
      (_) {},
      (data) => cache.put(cacheKey, data),
    );
    return result;
  }

  @override
  Future<Either<Failure, Map<SearchResultType, int>>> countByResultType(
    SearchQuery query,
  ) async {
    final cache = _countsCache;
    if (cache == null) return _delegate.countByResultType(query);

    final cacheKey = _generateKey(query, null);
    final cached = cache.get(cacheKey);
    if (cached != null) {
      if (kDebugMode) debugPrint('🔍 HIT  [counts] $cacheKey');
      return Right(cached);
    }

    if (kDebugMode) debugPrint('☁️  MISS [counts] $cacheKey');
    final result = await _delegate.countByResultType(query);

    result.fold(
      (_) {},
      (data) => cache.put(cacheKey, data),
    );
    return result;
  }

  @override
  Future<Either<Failure, List<String>>> getSuggestions(
    String prefix, {
    String? language,
  }) {
    // Not cached — fast and high-churn (every keystroke in some flows).
    return _delegate.getSuggestions(prefix, language: language);
  }

  /// Generate deterministic cache key from SearchQuery.
  ///
  /// CRITICAL: every Set on SearchQuery (editionIds, scope, selectedDictionaryIds)
  /// MUST be sorted before stringifying. Otherwise {BJT,SC} and {SC,BJT}
  /// produce different keys for logically identical queries → cache thrash.
  String _generateKey(
    SearchQuery query,
    SearchResultType? resultType, {
    int? maxPerCategory,
  }) {
    final sortedEditions = (query.editionIds.toList()..sort()).join(',');
    final sortedScope = (query.scope.toList()..sort()).join(',');
    final sortedDicts =
        (query.selectedDictionaryIds.toList()..sort()).join(',');

    // '__all__' sentinel keeps "no filter" distinct from "explicitly bjt".
    // Today the underlying repo collapses both to {'bjt'} so they'd return
    // the same data, BUT once SC ships, "{}" means "search all editions" and
    // "{'bjt'}" means "BJT only" — and they MUST be different cache entries.
    final editionsPart = sortedEditions.isEmpty ? '__all__' : sortedEditions;

    // Booleans rendered as 0/1 for compact, unambiguous keys.
    final parts = <String>[
      query.queryText,
      query.isExactMatch ? '1' : '0',
      editionsPart,
      query.searchInPali ? '1' : '0',
      query.searchInSinhala ? '1' : '0',
      sortedScope,
      sortedDicts, // BUGFIX vs original draft — was missing entirely
      query.isPhraseSearch ? '1' : '0',
      query.isAnywhereInText ? '1' : '0',
      '${query.proximityDistance}',
      '${query.limit}',
      '${query.offset}',
      resultType?.name ?? 'top',
      '${maxPerCategory ?? 0}',
    ];
    return parts.join('|');
  }

  /// Clear all caches. Use to force fresh results (e.g., after a manual
  /// "reload corpus" action — not currently exposed in the UI).
  void clearAll() {
    _topResultsCache?.clear();
    _fullResultsCache?.clear();
    _countsCache?.clear();
  }

  /// Snapshot of all cache stats — used by the perf measurement panel.
  Map<String, CacheStats> snapshotStats() => {
        if (_topResultsCache != null) 'topResults': _topResultsCache!.stats,
        if (_fullResultsCache != null) 'fullResults': _fullResultsCache!.stats,
        if (_countsCache != null) 'counts': _countsCache!.stats,
      };

  /// Log statistics for all caches (debug mode only).
  void logAllStats() {
    if (!kDebugMode) return;
    _topResultsCache?.logStats('TopResults');
    _fullResultsCache?.logStats('FullResults');
    _countsCache?.logStats('Counts');
  }
}
```

---

## Files to Modify

### `lib/presentation/providers/search_provider.dart`

Update `textSearchRepositoryProvider` to wrap with caching decorator.

> NOTE: import paths are `../../data/...` not `../...` — `search_provider.dart`
> lives in `lib/presentation/providers/`, the new files live in `lib/data/`.
> The earlier draft had this wrong.

```dart
// Add these to the existing imports:
import '../../data/cache/cache_config.dart';
import '../../data/repositories/caching_text_search_repository.dart';

/// Feature flag for search caching.
/// Set to false to disable for A/B testing or debugging.
const bool kEnableSearchCache = true;

/// Concrete decorator instance (when enabled). Exposed separately so the
/// performance-measurement debug panel can read `snapshotStats()` /
/// call `clearAll()` without going through the abstract repo interface.
final cachingSearchRepositoryProvider =
    Provider<CachingTextSearchRepository?>((ref) {
  if (!kEnableSearchCache) return null;
  final base = TextSearchRepositoryImpl(
    ref.watch(ftsDataSourceProvider),
    ref.watch(navigationTreeRepositoryProvider),
    ref.watch(dictionaryRepositoryProvider),
  );
  return CachingTextSearchRepository(
    base,
    config: CacheConfig.forPlatform(),
  );
});

/// Provider for the text search repository (with optional caching).
final textSearchRepositoryProvider = Provider<TextSearchRepository>((ref) {
  final cached = ref.watch(cachingSearchRepositoryProvider);
  if (cached != null) return cached;

  // Cache disabled — return the bare implementation.
  return TextSearchRepositoryImpl(
    ref.watch(ftsDataSourceProvider),
    ref.watch(navigationTreeRepositoryProvider),
    ref.watch(dictionaryRepositoryProvider),
  );
});
```

**To test without caching:** flip `kEnableSearchCache` to `false` and hot-restart.

---

## Cache Key Strategy

Cache keys must be **deterministic** — the same logical query must always produce the same key.

### Key Format

```
"{queryText}|{isExactMatch}|{sortedEditions|__all__}|{pali}|{sinh}|{sortedScope}|{sortedDicts}|{phrase}|{anywhere}|{proximity}|{limit}|{offset}|{resultType}|{maxPerCategory}"
```

### Example Keys

```
"dhamma|0|__all__|1|1|sp||1|0|10|50|0|fullText|0"
"සති|1|bjt,sc|1|1|dn,mn|BUS,MS|0|1|100|20|0|top|3"
```

### CRITICAL: sort every Set, include every filter

Three Sets exist on `SearchQuery`. All three MUST be sorted before joining:

```dart
final sortedEditions = (query.editionIds.toList()..sort()).join(',');
final sortedScope    = (query.scope.toList()..sort()).join(',');
final sortedDicts    = (query.selectedDictionaryIds.toList()..sort()).join(',');
```

**Why this matters:** Sets in Dart have undefined iteration order, so
`{BJT, SC}.join(',')` could yield either `"bjt,sc"` or `"sc,bjt"`. Without
sorting, two logically identical queries can produce different keys → cache
thrash and incorrect cache hits.

The original draft of this plan **omitted `selectedDictionaryIds`** entirely.
That bug would have caused the cache to return stale results from a different
dictionary filter when the user toggled `BUS` ↔ `MS` ↔ `All`. Fixed.

### Empty editionIds: `__all__` not `'bjt'`

```dart
sortedEditions.isEmpty ? '__all__' : sortedEditions
```

Today, `text_search_repository_impl.dart:70` collapses an empty set to
`{'bjt'}`, so functionally `{}` and `{'bjt'}` return the same data. But the
moment SC edition is added, `{}` will mean "all editions" while `{'bjt'}` will
mean "only BJT" — they MUST be different cache entries. Using `__all__` keeps
the key correct across that change.

---

## Eviction Policy

1. **On `get()`**: returns the value and re-inserts at end (most recently used).
2. **On `put()`**: if at capacity, removes the first entry (least recently used).
3. **No TTL** — corpus is immutable, no staleness to expire.

### No selective invalidation (v1)

Only `clear()` / `clearAll()` is implemented. Selective invalidation
(e.g., `invalidateWhere(predicate)`) can be added later if "load more"
pagination needs it.

---

## Platform Considerations

| Platform | Max Entries | Notes |
|----------|-------------|-------|
| Mobile (iOS/Android) | 20 | Limited memory. Reduce to 10 if OOM appears on older devices. |
| Web | 30 | Session-based. Reduce to 20 if Safari memory issues surface. |
| Desktop | 50 | More memory available. |

### Mobile Lifecycle

Cache is **kept** when app goes to background. The OS handles memory pressure automatically by killing the app if needed. No proactive cache clearing required.

### Memory Safety

20 entries for mobile is a safe starting point. However, if OOM (Out of Memory) crashes occur on older Android devices (search results can contain large text chunks), reduce `maxEntries` to 10 in `CacheConfig.forPlatform()`.

---

## Pagination Compatibility

### Current: Page-Based Caching

Each `(query, limit, offset)` combination is a separate cache entry. This is simple and works for the current "load all" behavior.

```dart
// These are cached separately:
SearchQuery(queryText: "dhamma", limit: 50, offset: 0)   // Page 1
SearchQuery(queryText: "dhamma", limit: 50, offset: 50)  // Page 2
```

### Future: Accumulated Caching

When "load more" pagination is implemented, consider accumulated caching:

```dart
class AccumulatedCacheEntry {
  final List<SearchResult> results;
  final int totalCount;
  final int loadedOffset;  // How far we've loaded
  final bool hasMore;

  bool containsRange(int offset, int limit) => offset < loadedOffset;
}
```

This would allow stitching pages together and avoiding re-fetches for already-loaded ranges.

---

## What This Does NOT Change

- `SearchStateNotifier` - no changes needed (cache is transparent)
- `TextSearchRepositoryImpl` - unchanged (decorator wraps it)
- Domain layer interfaces - unchanged
- FTS datasource - unchanged

---

## Diagnostics

The decorator emits debug-only HIT/MISS logs and exposes lightweight stats
for ad-hoc inspection. All of this is gated on `kDebugMode` and costs nothing
in release.

### Debug log lines

```
🔍 HIT  [topResults] dhamma|0|__all__|1|1|sp||1|0|10|50|0|top|3
☁️  MISS [fullResults] dhamma|0|__all__|1|1|||1|0|10|50|0|fullText|0
```

Filter the browser/IDE console for `MISS` or `HIT` to narrow down to cache
events. Suggestions are not cached and don't appear here.

### Stats snapshot

```dart
ref.read(cachingSearchRepositoryProvider)?.logAllStats();
// [TopResults]  size=2/50 hits=4 misses=2 rate=66.7%
// [FullResults] size=3/50 hits=0 misses=3 rate=0.0%
// [Counts]      size=2/50 hits=8 misses=2 rate=80.0%
```

Use this when you want to confirm the cache is being exercised. A persistently
low hit rate (<10%) on `Counts` suggests a cache-key bug: some flag is
changing between calls when it shouldn't, or some flag is missing from the
key when it should be there.

The original draft of this doc included `Stopwatch` timing, `avgMissMs` and
`estimatedTimeSavedMs` for verifying speedup before/after. Once verified,
that scaffolding was removed; only the cheap `hits` / `misses` / `size`
counters remain.

---

## Future Enhancements

Since Tipitaka data is **immutable** (the underlying FTS database never changes), persistent caching can be added for significant UX improvement:

- **Web**: IndexedDB with long TTL (30 days)
- **Mobile**: Hive or similar with long TTL (30 days)

This would allow returning users to get instant search results for previously searched terms, even across app restarts.

---

## Implementation Checklist

- [x] Create `lib/data/cache/lru_cache.dart`
- [x] Create `lib/data/cache/cache_config.dart` (no `ttl` field)
- [x] Create `lib/data/repositories/caching_text_search_repository.dart`
  - [x] Cache key includes `selectedDictionaryIds`
  - [x] Empty `editionIds` keyed as `__all__`, not `'bjt'`
  - [x] Caches are nullable, not `late final`
- [x] Update `lib/presentation/providers/search_provider.dart`
  - [x] Add `kEnableSearchCache` feature flag
  - [x] Expose `cachingSearchRepositoryProvider` for diagnostics
- [x] Verify HIT/MISS logs in browser DevTools console (debug build)
- [ ] Test on mobile (iOS and Android)
- [ ] Test on desktop (macOS)
- [ ] Monitor for OOM issues on older Android devices

## Changelog vs. original draft

| Change | Reason |
|---|---|
| Removed TTL everywhere | Corpus is immutable; TTL only adds cost & surprise misses |
| Added `selectedDictionaryIds` to cache key | Without it, dictionary filter changes returned stale results |
| Empty editionIds → `__all__` sentinel (was `'bjt'`) | Future-proof for SuttaCentral edition |
| Caches nullable, not `late final` | Avoid `LateInitializationError` if a future call site forgets the gate |
| Dropped `* 2` capacity multiplier on `_fullResultsCache` | Pagination not implemented yet — add the multiplier when "load more" lands |
| Fixed import paths in provider snippet | `../cache/...` → `../../data/cache/...` |
| Booleans rendered as `0/1` in cache key | Compact, unambiguous — easier to debug |
| Used `defaultTargetPlatform` instead of `dart:io`'s `Platform` | Web-safe; no conditional imports needed |
| Added then **removed** Stopwatch-based miss timing | Used to verify the speedup; once obvious, the scaffolding was stripped per moderate-cleanup pass |
