# Search Results Caching Implementation

This document describes the caching mechanism for search results in The Wisdom Project. The cache improves UX by avoiding repeated expensive FTS (Full-Text Search) queries when users search the same terms.

## Overview

- **Pattern**: Repository decorator (wraps existing `TextSearchRepositoryImpl`)
- **Storage**: In-memory LRU cache with TTL expiration
- **Platforms**: Mobile (iOS/Android), Desktop (macOS/Windows/Linux), Web
- **Data staleness**: Not a concern - Tipitaka corpus is immutable

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

Generic LRU (Least Recently Used) cache with TTL (Time-To-Live) support.

```dart
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Generic LRU cache with TTL expiration.
///
/// Uses LinkedHashMap to maintain insertion order.
/// On access, entries are re-inserted to move to "most recently used" position.
/// On capacity overflow, the first entry (least recently used) is evicted.
class LRUCache<K, V> {
  final int capacity;
  final Duration ttl;
  final LinkedHashMap<K, _CacheEntry<V>> _map = LinkedHashMap();

  // Global stats (not per-entry)
  int _hits = 0;
  int _misses = 0;

  LRUCache(this.capacity, this.ttl);

  /// Get value for key, or null if not found or expired.
  /// Updates LRU position on hit.
  V? get(K key) {
    if (!_map.containsKey(key)) {
      _misses++;
      return null;
    }

    final entry = _map[key]!;

    // TTL check - remove if expired
    if (DateTime.now().difference(entry.creationTime) > ttl) {
      _map.remove(key);
      _misses++;
      return null;
    }

    // LRU logic: remove and re-insert to move to end (most recently used)
    _map.remove(key);
    _map[key] = entry;
    _hits++;
    return entry.value;
  }

  /// Store value for key. Evicts LRU entry if at capacity.
  void put(K key, V value) {
    // If key exists, remove it first (will be re-added at end)
    if (_map.containsKey(key)) {
      _map.remove(key);
    } else if (_map.length >= capacity) {
      // Eviction: remove first entry (Least Recently Used)
      _map.remove(_map.keys.first);
    }

    _map[key] = _CacheEntry(value, DateTime.now());
  }

  /// Clear all entries and reset stats.
  void clear() {
    _map.clear();
    _hits = 0;
    _misses = 0;
  }

  /// Log cache statistics (debug mode only).
  void logStats(String cacheName) {
    if (kDebugMode) {
      final hitRate = (_hits + _misses) > 0
          ? (_hits / (_hits + _misses) * 100).toStringAsFixed(1)
          : '0.0';
      debugPrint('[$cacheName] Size: ${_map.length}/$capacity | '
          'Hits: $_hits | Misses: $_misses | Rate: $hitRate%');
    }
  }

  /// Current number of entries.
  int get size => _map.length;

  /// Cache statistics snapshot.
  CacheStats get stats => CacheStats(
    size: _map.length,
    maxSize: capacity,
    hits: _hits,
    misses: _misses,
  );
}

/// Private cache entry - holds value and creation timestamp.
class _CacheEntry<V> {
  final V value;
  final DateTime creationTime;
  _CacheEntry(this.value, this.creationTime);
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
  String toString() => 'CacheStats(size: $size/$maxSize, '
      'hits: $hits, misses: $misses, rate: ${(hitRate * 100).toStringAsFixed(1)}%)';
}
```

### 2. `lib/data/cache/cache_config.dart`

Platform-specific configuration with feature flag.

```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Configuration for search result caching.
///
/// Different platforms have different memory constraints:
/// - Mobile: Limited memory, smaller cache, shorter TTL
/// - Web: Session-based, moderate cache
/// - Desktop: More memory available, larger cache, longer TTL
class CacheConfig {
  final int maxEntries;
  final Duration ttl;
  final bool enabled;

  const CacheConfig({
    required this.maxEntries,
    required this.ttl,
    required this.enabled,
  });

  /// Create platform-appropriate configuration.
  ///
  /// | Platform | Max Entries | TTL     |
  /// |----------|-------------|---------|
  /// | Mobile   | 20          | 5 min   |
  /// | Web      | 30          | 10 min  |
  /// | Desktop  | 50          | 15 min  |
  factory CacheConfig.forPlatform({bool enabled = true}) {
    if (kIsWeb) {
      return CacheConfig(
        maxEntries: 30,
        ttl: const Duration(minutes: 10),
        enabled: enabled,
      );
    }

    if (Platform.isAndroid || Platform.isIOS) {
      return CacheConfig(
        maxEntries: 20,  // Can reduce to 10 if OOM issues on older devices
        ttl: const Duration(minutes: 5),
        enabled: enabled,
      );
    }

    // Desktop (macOS, Windows, Linux)
    return CacheConfig(
      maxEntries: 50,
      ttl: const Duration(minutes: 15),
      enabled: enabled,
    );
  }

  /// Disabled configuration - all cache operations become pass-through.
  factory CacheConfig.disabled() => const CacheConfig(
    maxEntries: 0,
    ttl: Duration.zero,
    enabled: false,
  );
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
/// Suggestions are NOT cached (fast, change frequently).
class CachingTextSearchRepository implements TextSearchRepository {
  final TextSearchRepository _delegate;
  final CacheConfig _config;

  // Separate caches for different result types
  late final LRUCache<String, GroupedSearchResult> _topResultsCache;
  late final LRUCache<String, List<SearchResult>> _fullResultsCache;
  late final LRUCache<String, Map<SearchResultType, int>> _countsCache;

  CachingTextSearchRepository(
    this._delegate, {
    required CacheConfig config,
  }) : _config = config {
    if (_config.enabled) {
      _topResultsCache = LRUCache(_config.maxEntries, _config.ttl);
      // More capacity for full results (may have multiple pages)
      _fullResultsCache = LRUCache(_config.maxEntries * 2, _config.ttl);
      _countsCache = LRUCache(_config.maxEntries, _config.ttl);
    }
  }

  @override
  Future<Either<Failure, GroupedSearchResult>> searchTopResults(
    SearchQuery query, {
    int maxPerCategory = 3,
  }) async {
    // Bypass cache if disabled
    if (!_config.enabled) {
      return _delegate.searchTopResults(query, maxPerCategory: maxPerCategory);
    }

    final cacheKey = _generateKey(query, null, maxPerCategory: maxPerCategory);

    // Check cache
    final cached = _topResultsCache.get(cacheKey);
    if (cached != null) {
      if (kDebugMode) debugPrint('🔍 Cache HIT [topResults]: $cacheKey');
      return Right(cached);
    }

    if (kDebugMode) debugPrint('☁️ Cache MISS [topResults]: $cacheKey');

    // Delegate to actual implementation
    final result = await _delegate.searchTopResults(
      query,
      maxPerCategory: maxPerCategory,
    );

    // Cache successful results only
    result.fold(
      (failure) {}, // Don't cache failures
      (data) => _topResultsCache.put(cacheKey, data),
    );

    return result;
  }

  @override
  Future<Either<Failure, List<SearchResult>>> searchByResultType(
    SearchQuery query,
    SearchResultType resultType,
  ) async {
    if (!_config.enabled) {
      return _delegate.searchByResultType(query, resultType);
    }

    final cacheKey = _generateKey(query, resultType);

    final cached = _fullResultsCache.get(cacheKey);
    if (cached != null) {
      if (kDebugMode) debugPrint('🔍 Cache HIT [fullResults]: $cacheKey');
      return Right(cached);
    }

    if (kDebugMode) debugPrint('☁️ Cache MISS [fullResults]: $cacheKey');

    final result = await _delegate.searchByResultType(query, resultType);

    result.fold(
      (failure) {},
      (data) => _fullResultsCache.put(cacheKey, data),
    );

    return result;
  }

  @override
  Future<Either<Failure, Map<SearchResultType, int>>> countByResultType(
    SearchQuery query,
  ) async {
    if (!_config.enabled) {
      return _delegate.countByResultType(query);
    }

    final cacheKey = _generateKey(query, null);

    final cached = _countsCache.get(cacheKey);
    if (cached != null) {
      if (kDebugMode) debugPrint('🔍 Cache HIT [counts]: $cacheKey');
      return Right(cached);
    }

    if (kDebugMode) debugPrint('☁️ Cache MISS [counts]: $cacheKey');

    final result = await _delegate.countByResultType(query);

    result.fold(
      (failure) {},
      (data) => _countsCache.put(cacheKey, data),
    );

    return result;
  }

  @override
  Future<Either<Failure, List<String>>> getSuggestions(
    String prefix, {
    String? language,
  }) {
    // Suggestions are NOT cached - they're fast and change frequently
    return _delegate.getSuggestions(prefix, language: language);
  }

  /// Generate deterministic cache key from SearchQuery.
  ///
  /// CRITICAL: Collections (editionIds, scope) MUST be sorted before
  /// stringifying to ensure [BJT, SC] == [SC, BJT].
  String _generateKey(
    SearchQuery query,
    SearchResultType? resultType, {
    int? maxPerCategory,
  }) {
    // MUST sort collections for deterministic keys
    final sortedEditions = (query.editionIds.toList()..sort()).join(',');
    final sortedScope = (query.scope.toList()..sort()).join(',');

    final parts = [
      query.queryText,
      query.isExactMatch,
      sortedEditions.isEmpty ? 'bjt' : sortedEditions,
      query.searchInPali,
      query.searchInSinhala,
      sortedScope,
      query.isPhraseSearch,
      query.isAnywhereInText,
      query.proximityDistance,
      query.limit,
      query.offset,
      resultType?.name ?? 'top',
      maxPerCategory ?? 0,
    ];

    return parts.join('|');
  }

  /// Clear all caches. Call when you need to force fresh results.
  void clearAll() {
    if (_config.enabled) {
      _topResultsCache.clear();
      _fullResultsCache.clear();
      _countsCache.clear();
    }
  }

  /// Log statistics for all caches (debug mode only).
  void logAllStats() {
    if (_config.enabled && kDebugMode) {
      _topResultsCache.logStats('TopResults');
      _fullResultsCache.logStats('FullResults');
      _countsCache.logStats('Counts');
    }
  }
}
```

---

## Files to Modify

### `lib/presentation/providers/search_provider.dart`

Update `textSearchRepositoryProvider` to wrap with caching decorator.

```dart
import '../cache/cache_config.dart';
import '../repositories/caching_text_search_repository.dart';

/// Feature flag for search caching.
/// Set to false to disable caching for A/B testing or debugging.
const bool kEnableSearchCache = true;

/// Provider for the text search repository (with optional caching).
final textSearchRepositoryProvider = Provider<TextSearchRepository>((ref) {
  final baseRepository = TextSearchRepositoryImpl(
    ref.watch(ftsDataSourceProvider),
    ref.watch(navigationTreeRepositoryProvider),
    ref.watch(dictionaryRepositoryProvider),
  );

  // Wrap with caching decorator (can be disabled via feature flag)
  return CachingTextSearchRepository(
    baseRepository,
    config: CacheConfig.forPlatform(enabled: kEnableSearchCache),
  );
});
```

**To test without caching:** Change `kEnableSearchCache` to `false` and hot-restart.

---

## Cache Key Strategy

Cache keys must be **deterministic** - the same query parameters must always produce the same key.

### Key Format

```
"{queryText}|{isExactMatch}|{sortedEditions}|{pali}|{sinh}|{sortedScope}|{phrase}|{anywhere}|{proximity}|{limit}|{offset}|{resultType}|{maxPerCategory}"
```

### Example Keys

```
"dhamma|false|bjt|true|true|sp|true|false|10|50|0|fullText|0"
"සති|true|bjt,sc|true|true|dn,mn|false|true|100|20|0|top|3"
```

### CRITICAL: Sort Collections

Collections (Sets/Lists) must be sorted before joining to string:

```dart
// WRONG - order depends on Set iteration order
final key = query.editionIds.join(',');  // Could be "sc,bjt" or "bjt,sc"

// CORRECT - sorted for deterministic order
final sortedEditions = (query.editionIds.toList()..sort()).join(',');  // Always "bjt,sc"
```

If you don't sort, `[BJT, SC]` and `[SC, BJT]` will produce different cache keys, causing cache misses for logically identical queries.

---

## Eviction Policy

### LRU + TTL (Combined)

1. **On `get()`**: If entry exists but TTL expired, remove it and return null (cache miss)
2. **On `put()`**: If at capacity, remove the least recently used entry (first in LinkedHashMap)
3. **On access**: Re-insert entry to move it to "most recently used" position

### No Selective Invalidation (v1)

For v1, only `clear()` is implemented. Selective invalidation (e.g., `invalidateWhere(predicate)`) can be added later when "load more" pagination is implemented.

---

## Platform Considerations

| Platform | Max Entries | TTL | Notes |
|----------|-------------|-----|-------|
| Mobile (iOS/Android) | 20 | 5 min | Limited memory. Can reduce to 10 if OOM on older devices. |
| Web | 30 | 10 min | Session-based. Can reduce to 20 if Safari memory issues. |
| Desktop | 50 | 15 min | More memory available. |

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

## Verification Plan

### 1. Test with Caching Enabled (`kEnableSearchCache = true`)

1. Search "dhamma" → observe cache miss (first request)
2. Search "dhamma" again → should be instant (cache hit)
3. Toggle exact match → new search (cache miss, different key)
4. Change scope filter → new search (cache miss, different key)
5. Check `CacheStats` via debug logging

### 2. Test with Caching Disabled (`kEnableSearchCache = false`)

1. Search "dhamma" → note response time
2. Search "dhamma" again → same response time (no caching)
3. Compare times with caching enabled to measure benefit

### 3. Debug Logging

All cache operations are logged in debug mode:

```
🔍 Cache HIT [topResults]: dhamma|false|bjt|true|true|...|top|3
☁️ Cache MISS [fullResults]: dhamma|false|bjt|true|true|...|fullText|0
[TopResults] Size: 5/20 | Hits: 12 | Misses: 3 | Rate: 80.0%
```

---

## Future Enhancements

Since Tipitaka data is **immutable** (the underlying FTS database never changes), persistent caching can be added for significant UX improvement:

- **Web**: IndexedDB with long TTL (30 days)
- **Mobile**: Hive or similar with long TTL (30 days)

This would allow returning users to get instant search results for previously searched terms, even across app restarts.

---

## Implementation Checklist

- [ ] Create `lib/data/cache/lru_cache.dart`
- [ ] Create `lib/data/cache/cache_config.dart`
- [ ] Create `lib/data/repositories/caching_text_search_repository.dart`
- [ ] Update `lib/presentation/providers/search_provider.dart`
- [ ] Test on mobile (iOS and Android)
- [ ] Test on web (Chrome and Safari)
- [ ] Test on desktop (macOS)
- [ ] Monitor for OOM issues on older Android devices
