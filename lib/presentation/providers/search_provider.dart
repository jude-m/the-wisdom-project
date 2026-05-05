import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/cache/cache_config.dart';
import '../../data/datasources/fts_datasource.dart';
import '../../data/datasources/fts_local_datasource.dart';
import '../../data/repositories/caching_text_search_repository.dart';
import '../../data/repositories/recent_searches_repository_impl.dart';
import '../../data/repositories/text_search_repository_impl.dart';
import '../../domain/repositories/recent_searches_repository.dart';
import '../../domain/repositories/text_search_repository.dart';
import 'dictionary_provider.dart';
import 'navigation_tree_provider.dart';
import 'search_state.dart';

/// Provider for SharedPreferences
/// Must be overridden in ProviderScope with AsyncValue from SharedPreferences.getInstance()
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
      'SharedPreferences must be overridden at app startup');
});

/// Provider for the FTS data source
/// Supports multiple edition databases
final ftsDataSourceProvider = Provider<FTSDataSource>((ref) {
  // Editions are initialized on-demand when search is performed
  return FTSDataSourceImpl();
});

/// Feature flag for the search-results cache.
/// Flip to `false` to disable for A/B testing or debugging, then hot-restart.
const bool kEnableSearchCache = true;

/// Concrete decorator instance, exposed separately so the perf-verification
/// panel can call `snapshotStats()` / `logAllStats()` / `clearAll()` without
/// going through the abstract [TextSearchRepository] interface.
///
/// Returns `null` when [kEnableSearchCache] is false.
///
/// PERF SCAFFOLDING — once cache effectiveness is verified, this provider can
/// be folded back into [textSearchRepositoryProvider].
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

/// Provider for the text search repository.
/// Wraps [TextSearchRepositoryImpl] with [CachingTextSearchRepository] when
/// [kEnableSearchCache] is true; otherwise returns the bare implementation.
final textSearchRepositoryProvider = Provider<TextSearchRepository>((ref) {
  final cached = ref.watch(cachingSearchRepositoryProvider);
  if (cached != null) return cached;

  return TextSearchRepositoryImpl(
    ref.watch(ftsDataSourceProvider),
    ref.watch(navigationTreeRepositoryProvider),
    ref.watch(dictionaryRepositoryProvider),
  );
});

/// Provider for recent searches repository
final recentSearchesRepositoryProvider =
    Provider<RecentSearchesRepository>((ref) {
  return RecentSearchesRepositoryImpl(ref.watch(sharedPreferencesProvider));
});

/// Provider for search state management
final searchStateProvider =
    StateNotifierProvider<SearchStateNotifier, SearchState>((ref) {
  return SearchStateNotifier(
    ref.watch(textSearchRepositoryProvider),
    ref.watch(recentSearchesRepositoryProvider),
  );
});
