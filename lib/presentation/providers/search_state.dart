import 'dart:async';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/search/categorized_search_result.dart';
import '../../domain/entities/search/recent_search.dart';
import '../../domain/entities/search/search_category.dart';
import '../../domain/entities/search/search_query.dart';
import '../../domain/entities/search/search_result.dart';
import '../../domain/repositories/recent_searches_repository.dart';
import '../../domain/repositories/text_search_repository.dart';
import 'search_mode.dart';

part 'search_state.freezed.dart';

/// State for the search feature with mode-based UI flow
@freezed
class SearchState with _$SearchState {
  const factory SearchState({
    /// Current search query text
    @Default('') String queryText,

    /// Current search mode (idle, recentSearches, previewResults, fullResults)
    @Default(SearchMode.idle) SearchMode mode,

    /// Recent search history
    @Default([]) List<RecentSearch> recentSearches,

    /// Categorized preview results (for dropdown, max 3 per category)
    CategorizedSearchResult? previewResults,

    /// Whether preview is loading
    @Default(false) bool isPreviewLoading,

    /// Currently selected category in full results view
    @Default(SearchCategory.title) SearchCategory selectedCategory,

    /// Full results for the selected category (async state)
    @Default(AsyncValue.data([])) AsyncValue<List<SearchResult>> fullResults,

    /// Selected editions to search (empty = default to BJT)
    @Default({}) Set<String> selectedEditions,

    /// Whether to search in Pali text
    @Default(true) bool searchInPali,

    /// Whether to search in Sinhala text
    @Default(true) bool searchInSinhala,

    /// Nikaya filters (e.g., ['dn', 'mn'])
    @Default([]) List<String> nikayaFilters,

    /// Whether the filter panel is visible
    @Default(false) bool filtersVisible,

    /// Whether the current query was submitted (user pressed Enter)
    /// Used to determine if we should reopen the full results panel on focus
    @Default(false) bool wasQuerySubmitted,
  }) = _SearchState;
}

/// Manages search state with mode-based UX flow
///
/// Flow:
/// 1. idle → Focus search bar → recentSearches (load recent)
/// 2. recentSearches → Start typing → previewResults (debounced categorized search)
/// 3. previewResults → Press Enter → fullResults (full category search)
/// 4. Any mode → Click result → Navigate directly
/// 5. Any mode → Blur/Escape → idle
class SearchStateNotifier extends StateNotifier<SearchState> {
  final TextSearchRepository _searchRepository;
  final RecentSearchesRepository _recentSearchesRepository;
  Timer? _debounceTimer;

  SearchStateNotifier(
    this._searchRepository,
    this._recentSearchesRepository,
  ) : super(const SearchState());

  /// Called when search bar receives focus
  /// Returns the mode after focus handling (for UI to decide what to show)
  Future<SearchMode> onFocus() async {
    // Load recent searches
    final recentSearches = await _recentSearchesRepository.getRecentSearches();

    // If user had previously submitted this query, reopen full results panel
    if (state.wasQuerySubmitted && state.queryText.trim().length >= 2) {
      state = state.copyWith(
        mode: SearchMode.fullResults,
        recentSearches: recentSearches,
        fullResults: const AsyncValue.loading(),
      );
      // Load results (don't await - let UI show loading state)
      _loadFullResultsForCategory();
      return SearchMode.fullResults;
    }

    // Otherwise show recent searches
    state = state.copyWith(
      mode: SearchMode.recentSearches,
      recentSearches: recentSearches,
    );
    return SearchMode.recentSearches;
  }

  /// Called when search bar loses focus (unless in fullResults mode)
  void onBlur() {
    if (state.mode != SearchMode.fullResults) {
      _debounceTimer?.cancel();
      state = state.copyWith(
        mode: SearchMode.idle,
        previewResults: null,
        isPreviewLoading: false,
      );
    }
  }

  /// Update search query text (debounced preview search)
  void updateQuery(String query) {
    // Check if query changed - if so, reset submitted state
    final queryChanged = query != state.queryText;

    state = state.copyWith(
      queryText: query,
      // Reset wasQuerySubmitted if user is typing a different query
      wasQuerySubmitted: queryChanged ? false : state.wasQuerySubmitted,
    );
    _debounceTimer?.cancel();

    // If query is too short, show recent searches
    if (query.trim().length < 2) {
      state = state.copyWith(
        mode: SearchMode.recentSearches,
        previewResults: null,
        isPreviewLoading: false,
      );
      return;
    }

    // Set loading state for preview
    state = state.copyWith(
      mode: SearchMode.previewResults,
      isPreviewLoading: true,
    );

    // Debounce preview search (300ms)
    _debounceTimer = Timer(
      const Duration(milliseconds: 300),
      _performPreviewSearch,
    );
  }

  /// Execute categorized preview search
  Future<void> _performPreviewSearch() async {
    final query = _buildSearchQuery();
    final result = await _searchRepository.searchCategorizedPreview(query);

    result.fold(
      (failure) {
        state = state.copyWith(
          isPreviewLoading: false,
          previewResults: null,
        );
      },
      (categorizedResult) {
        state = state.copyWith(
          isPreviewLoading: false,
          previewResults: categorizedResult,
        );
      },
    );
  }

  /// Called when user presses Enter to submit search
  Future<void> submitQuery() async {
    if (state.queryText.trim().length < 2) return;

    // Save to recent searches
    await _recentSearchesRepository.addRecentSearch(state.queryText);

    // Determine which category to show based on preview results
    // If we have preview results, pick a category that has results
    var categoryToSelect = state.selectedCategory;
    final preview = state.previewResults;
    if (preview != null && preview.isNotEmpty) {
      final categoriesWithResults = preview.categoriesWithResults;
      // If current category has no results, switch to first one that does
      if (!categoriesWithResults.contains(categoryToSelect) &&
          categoriesWithResults.isNotEmpty) {
        categoryToSelect = categoriesWithResults.first;
      }
    }

    // Switch to full results mode and mark as submitted
    state = state.copyWith(
      mode: SearchMode.fullResults,
      wasQuerySubmitted: true,
      selectedCategory: categoryToSelect,
      fullResults: const AsyncValue.loading(),
    );

    // Load full results for the selected category
    await _loadFullResultsForCategory();
  }

  /// Select a category tab in full results view
  Future<void> selectCategory(SearchCategory category) async {
    if (state.selectedCategory == category) return;

    state = state.copyWith(
      selectedCategory: category,
      fullResults: const AsyncValue.loading(),
    );

    await _loadFullResultsForCategory();
  }

  /// Load full results for the selected category
  Future<void> _loadFullResultsForCategory() async {
    final query = _buildSearchQuery();
    final result = await _searchRepository.searchByCategory(
      query,
      state.selectedCategory,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          fullResults: AsyncValue.error(failure, StackTrace.current),
        );
      },
      (results) {
        state = state.copyWith(fullResults: AsyncValue.data(results));
      },
    );
  }

  /// Handle clicking on a recent search
  Future<void> selectRecentSearch(String queryText) async {
    state = state.copyWith(queryText: queryText);
    await submitQuery();
  }

  /// Remove a recent search from history
  Future<void> removeRecentSearch(String query) async {
    await _recentSearchesRepository.removeRecentSearch(query);
    final updated = await _recentSearchesRepository.getRecentSearches();
    state = state.copyWith(recentSearches: updated);
  }

  /// Clear all recent searches
  Future<void> clearRecentSearches() async {
    await _recentSearchesRepository.clearRecentSearches();
    state = state.copyWith(recentSearches: []);
  }

  /// Build search query from current state
  SearchQuery _buildSearchQuery() {
    return SearchQuery(
      queryText: state.queryText,
      editionIds: state.selectedEditions,
      searchInPali: state.searchInPali,
      searchInSinhala: state.searchInSinhala,
      nikayaFilters: state.nikayaFilters,
    );
  }

  /// Toggle an edition in the search
  void toggleEdition(String editionId) {
    final newEditions = Set<String>.from(state.selectedEditions);
    if (newEditions.contains(editionId)) {
      newEditions.remove(editionId);
    } else {
      newEditions.add(editionId);
    }
    state = state.copyWith(selectedEditions: newEditions);
    _refreshSearchIfNeeded();
  }

  /// Toggle language filter
  void setLanguageFilter({bool? pali, bool? sinhala}) {
    state = state.copyWith(
      searchInPali: pali ?? state.searchInPali,
      searchInSinhala: sinhala ?? state.searchInSinhala,
    );
    _refreshSearchIfNeeded();
  }

  /// Add nikaya filter
  void addNikayaFilter(String nikaya) {
    if (!state.nikayaFilters.contains(nikaya)) {
      state = state.copyWith(
        nikayaFilters: [...state.nikayaFilters, nikaya],
      );
      _refreshSearchIfNeeded();
    }
  }

  /// Remove nikaya filter
  void removeNikayaFilter(String nikaya) {
    state = state.copyWith(
      nikayaFilters: state.nikayaFilters.where((n) => n != nikaya).toList(),
    );
    _refreshSearchIfNeeded();
  }

  /// Toggle filter panel visibility
  void toggleFilters() {
    state = state.copyWith(filtersVisible: !state.filtersVisible);
  }

  /// Clear all filters
  void clearFilters() {
    state = state.copyWith(
      selectedEditions: {},
      searchInPali: true,
      searchInSinhala: true,
      nikayaFilters: [],
    );
    _refreshSearchIfNeeded();
  }

  /// Refresh search if query is active
  void _refreshSearchIfNeeded() {
    if (state.queryText.trim().length < 2) return;

    if (state.mode == SearchMode.fullResults) {
      _loadFullResultsForCategory();
    } else if (state.mode == SearchMode.previewResults) {
      _performPreviewSearch();
    }
  }

  /// Clear search and reset to idle state
  void clearSearch() {
    _debounceTimer?.cancel();
    state = const SearchState();
  }

  /// Exit full results and return to idle
  /// Note: Does NOT clear queryText or wasQuerySubmitted so panel can reopen on focus
  void exitFullResults() {
    state = state.copyWith(
      mode: SearchMode.idle,
      fullResults: const AsyncValue.data([]),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
