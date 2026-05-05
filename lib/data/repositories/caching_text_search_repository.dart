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

/// Caching decorator for [TextSearchRepository].
///
/// Wraps an existing repository and adds three independent LRU caches:
/// - [_topResultsCache]   — for `searchTopResults` (grouped preview)
/// - [_fullResultsCache]  — for `searchByResultType` (full per-tab results)
/// - [_countsCache]       — for `countByResultType` (tab badge numbers)
///
/// Suggestions are NOT cached: they're cheap and per-keystroke.
///
/// The cache is transparent to callers — `SearchStateNotifier` is unchanged.
class CachingTextSearchRepository implements TextSearchRepository {
  final TextSearchRepository _delegate;

  /// Caches are nullable instead of `late final` + conditional init.
  /// This way, disabled mode is just `null` everywhere — no risk of a
  /// `LateInitializationError` if a future call site forgets the gate.
  final LRUCache<String, GroupedSearchResult>? _topResultsCache;
  final LRUCache<String, List<SearchResult>>? _fullResultsCache;
  final LRUCache<String, Map<SearchResultType, int>>? _countsCache;

  CachingTextSearchRepository(
    this._delegate, {
    required CacheConfig config,
  })  : _topResultsCache =
            config.enabled ? LRUCache(config.maxEntries) : null,
        // No `* 2` multiplier on full-results capacity yet: pagination is
        // not implemented (limit=50, offset=0 in current call sites).
        // Bump when "load more" lands.
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

    // Cache successful results only — never poison the cache with failures.
    result.fold(
      (_) {},
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
    // Not cached — cheap (in-memory FTS prefix scan) and called per keystroke.
    return _delegate.getSuggestions(prefix, language: language);
  }

  /// Builds a deterministic cache key from a [SearchQuery].
  ///
  /// IMPORTANT: every `Set` on SearchQuery (editionIds, scope,
  /// selectedDictionaryIds) MUST be sorted before stringifying. Sets in Dart
  /// have no guaranteed iteration order, so without sorting `{BJT, SC}` and
  /// `{SC, BJT}` would produce different keys for the same logical query.
  String _generateKey(
    SearchQuery query,
    SearchResultType? resultType, {
    int? maxPerCategory,
  }) {
    final sortedEditions = (query.editionIds.toList()..sort()).join(',');
    final sortedScope = (query.scope.toList()..sort()).join(',');
    final sortedDicts =
        (query.selectedDictionaryIds.toList()..sort()).join(',');

    // '__all__' sentinel keeps "no edition filter" distinct from "explicitly
    // bjt only". Today the underlying repo collapses both to {'bjt'}, but
    // once SuttaCentral ships, "{}" will mean "search all editions" and
    // "{'bjt'}" will mean "BJT only" — they must be different cache entries.
    final editionsPart = sortedEditions.isEmpty ? '__all__' : sortedEditions;

    // Booleans rendered as 0/1 keep keys compact and unambiguous.
    final parts = <String>[
      query.queryText,
      query.isExactMatch ? '1' : '0',
      editionsPart,
      query.searchInPali ? '1' : '0',
      query.searchInSinhala ? '1' : '0',
      sortedScope,
      sortedDicts,
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

  /// Clears all caches. Use to force fresh results (not currently exposed
  /// in the UI; intended for diagnostics or tests).
  void clearAll() {
    _topResultsCache?.clear();
    _fullResultsCache?.clear();
    _countsCache?.clear();
  }

  /// Snapshot of all cache stats — useful for ad-hoc diagnostics.
  Map<String, CacheStats> snapshotStats() => {
        if (_topResultsCache != null) 'topResults': _topResultsCache.stats,
        if (_fullResultsCache != null) 'fullResults': _fullResultsCache.stats,
        if (_countsCache != null) 'counts': _countsCache.stats,
      };

  /// Logs statistics for all caches in debug mode only.
  void logAllStats() {
    if (!kDebugMode) return;
    _topResultsCache?.logStats('TopResults');
    _fullResultsCache?.logStats('FullResults');
    _countsCache?.logStats('Counts');
  }
}
