import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/fts_datasource.dart';
import '../../data/repositories/recent_searches_repository_impl.dart';
import '../../data/repositories/text_search_repository_impl.dart';
import '../../domain/repositories/recent_searches_repository.dart';
import '../../domain/repositories/text_search_repository.dart';
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

/// Provider for the text search repository
final textSearchRepositoryProvider = Provider<TextSearchRepository>((ref) {
  return TextSearchRepositoryImpl(
    ref.watch(ftsDataSourceProvider),
    ref.watch(navigationTreeRepositoryProvider),
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
