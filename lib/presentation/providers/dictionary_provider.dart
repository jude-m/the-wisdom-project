import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/dictionary_datasource.dart';
import '../../data/repositories/dictionary_repository_impl.dart';
import '../../domain/entities/dictionary/dictionary_entry.dart';
import '../../domain/entities/dictionary/dictionary_params.dart';
import '../../domain/repositories/dictionary_repository.dart';

// ============================================================================
// UI STATE PROVIDERS
// ============================================================================

/// Holds the currently selected word for dictionary lookup.
/// When non-null, the dictionary bottom sheet is shown.
/// Set to null to hide the bottom sheet.
final selectedDictionaryWordProvider = StateProvider<String?>((ref) => null);

/// Tracks which specific word is currently highlighted across all text widgets.
/// Stores (widgetHashCode, wordPosition) to uniquely identify a tapped word.
/// When null, no word is highlighted.
/// This ensures only one word is highlighted at a time across all paragraphs.
///
/// Note: This is cleared when the dictionary sheet closes.
final dictionaryHighlightProvider = StateProvider<({int widgetId, int position})?>((ref) => null);

/// Tracks whether there's an active text selection.
/// When true, word taps should be ignored to prevent dictionary from
/// interfering with selection gestures (drag-to-select or clearing selection).
final hasActiveSelectionProvider = StateProvider<bool>((ref) => false);

// ============================================================================
// DATASOURCE & REPOSITORY PROVIDERS
// ============================================================================

/// Provides the DictionaryDataSource singleton
final dictionaryDataSourceProvider = Provider<DictionaryDataSource>((ref) {
  return DictionaryDataSourceImpl();
});

/// Provides the DictionaryRepository
final dictionaryRepositoryProvider = Provider<DictionaryRepository>((ref) {
  final dataSource = ref.watch(dictionaryDataSourceProvider);
  return DictionaryRepositoryImpl(dataSource);
});

// ============================================================================
// LOOKUP PROVIDERS
// ============================================================================

/// Lookup a word in the dictionary
/// Returns a list of dictionary entries ordered by relevance
/// Uses autoDispose to clean up when no listeners remain (prevents memory leaks).
final dictionaryLookupProvider =
    FutureProvider.autoDispose.family<List<DictionaryEntry>, DictionaryLookupParams>(
        (ref, params) async {
  final repository = ref.watch(dictionaryRepositoryProvider);

  final result = await repository.lookupWord(
    params.word,
    exactMatch: params.exactMatch,
    targetLanguage: params.targetLanguage,
    limit: params.limit,
  );

  return result.fold(
    (failure) => throw Exception(failure.userMessage),
    (entries) => entries,
  );
});

/// Simple lookup provider for tap-on-word feature
/// Uses default parameters (prefix match, all languages, limit 50)
/// Uses autoDispose to clean up when no listeners remain (prevents memory leaks).
final wordLookupProvider =
    FutureProvider.autoDispose.family<List<DictionaryEntry>, String>((ref, word) async {
  final repository = ref.watch(dictionaryRepositoryProvider);

  final result = await repository.lookupWord(
    word,
    exactMatch: false,
    limit: 50,
  );

  return result.fold(
    (failure) => throw Exception(failure.userMessage),
    (entries) => entries,
  );
});

// ============================================================================
// SEARCH PROVIDERS (for search tab integration)
// ============================================================================

/// Search definitions for a query (used in search tab)
/// Uses autoDispose to clean up when no listeners remain (prevents memory leaks).
final dictionarySearchProvider =
    FutureProvider.autoDispose.family<List<DictionaryEntry>, DictionarySearchParams>(
        (ref, params) async {
  final repository = ref.watch(dictionaryRepositoryProvider);

  final result = await repository.searchDefinitions(
    params.query,
    isExactMatch: params.isExactMatch,
    targetLanguage: params.targetLanguage,
    limit: params.limit,
  );

  return result.fold(
    (failure) => throw Exception(failure.userMessage),
    (entries) => entries,
  );
});

/// Count definitions for a query (for tab badge)
/// Uses autoDispose to clean up when no listeners remain (prevents memory leaks).
final dictionaryCountProvider =
    FutureProvider.autoDispose.family<int, DictionarySearchParams>((ref, params) async {
  final repository = ref.watch(dictionaryRepositoryProvider);

  final result = await repository.countDefinitions(
    params.query,
    isExactMatch: params.isExactMatch,
    targetLanguage: params.targetLanguage,
  );

  return result.fold(
    (failure) => throw Exception(failure.userMessage),
    (count) => count,
  );
});
