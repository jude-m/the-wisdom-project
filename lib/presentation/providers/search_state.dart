import 'dart:async';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/singlish_transliterator.dart';
import '../../domain/entities/search/grouped_search_result.dart';
import '../../domain/entities/search/recent_search.dart';
import '../../domain/entities/search/search_result_type.dart';
import '../../domain/entities/search/search_query.dart';
import '../../domain/entities/search/search_result.dart';
import '../../domain/entities/search/search_scope.dart';
import '../../domain/repositories/recent_searches_repository.dart';
import '../../domain/repositories/text_search_repository.dart';

part 'search_state.freezed.dart';

/// State for the search feature with simplified UX flow
///
/// Flow:
/// 1. Focus search bar (empty) → Show recent searches overlay
/// 2. Type any character → Overlay hides, results panel opens with "All" tab
/// 3. Click result → Panel closes, but query text stays in search bar
/// 4. Focus search bar again → Panel reopens with previous results
/// 5. Clear search bar completely → Panel closes
@freezed
class SearchState with _$SearchState {
  const SearchState._();

  const factory SearchState({
    /// Current search query text
    @Default('') String queryText,

    /// Recent search history
    @Default([]) List<RecentSearch> recentSearches,

    /// Currently selected category in results view
    @Default(SearchResultType.topResults) SearchResultType selectedResultType,

    /// Categorized results for "Top Results" tab (grouped by category)
    GroupedSearchResult? groupedResults,

    /// Full results for the selected category (async state)
    @Default(AsyncValue.data([])) AsyncValue<List<SearchResult>> fullResults,

    /// Whether results are currently loading
    @Default(false) bool isLoading,

    /// Selected editions to search (empty = default to BJT)
    @Default({}) Set<String> selectedEditions,

    /// Whether to search in Pali text
    @Default(true) bool searchInPali,

    /// Whether to search in Sinhala text
    @Default(true) bool searchInSinhala,

    /// Selected scope to filter search results.
    /// Empty set = "All" is selected (search everything).
    /// Non-empty = search only within selected scope (OR logic).
    @Default({}) Set<SearchScope> selectedScope,

    /// Whether the panel was dismissed (user clicked result or close button)
    /// Panel reopens when user focuses the search bar again
    @Default(false) bool isPanelDismissed,

    /// Whether exact match is enabled (default: false = prefix matching)
    /// When false: "සති" matches "සතිපට්ඨානය", "සතිපට්ඨාන", etc.
    /// When true: "සති" matches only "සති" exactly
    @Default(false) bool isExactMatch,

    /// Result counts per category (for tab badges)
    /// Updated independently from categorized results
    @Default({}) Map<SearchResultType, int> countByResultType,
  }) = _SearchState;

  /// Computed property: Results panel is visible when query is not empty
  /// and panel hasn't been dismissed
  bool get isResultsPanelVisible =>
      queryText.trim().isNotEmpty && !isPanelDismissed;

  /// True if "All" is effectively selected (no specific scope chosen)
  bool get isAllSelected => selectedScope.isEmpty;
}

/// Manages search state with simplified UX flow
///
/// The panel visibility is computed from queryText.length >= 2,
/// eliminating the need for explicit mode tracking.
class SearchStateNotifier extends StateNotifier<SearchState> {
  final TextSearchRepository _searchRepository;
  final RecentSearchesRepository _recentSearchesRepository;
  Timer? _debounceTimer;

  SearchStateNotifier(
    this._searchRepository,
    this._recentSearchesRepository,
  ) : super(const SearchState());

  /// Called when search bar receives focus
  /// Loads recent searches and reopens panel if there's a query
  Future<void> onFocus() async {
    final recentSearches = await _recentSearchesRepository.getRecentSearches();
    state = state.copyWith(
      recentSearches: recentSearches,
      isPanelDismissed: false, // Reopen panel if there's query text
    );
  }

  /// Called when search bar loses focus
  /// Does nothing special - panel visibility is computed from queryText
  void onBlur() {
    _debounceTimer?.cancel();
  }

  /// Update search query text (debounced search)
  void updateQuery(String query) {
    state = state.copyWith(queryText: query);
    _debounceTimer?.cancel();

    // If query is empty, clear results (panel will auto-hide via computed getter)
    if (query.trim().isEmpty) {
      state = state.copyWith(
        groupedResults: null,
        fullResults: const AsyncValue.data([]),
        isLoading: false,
      );
      return;
    }

    // Set loading state
    state = state.copyWith(isLoading: true);

    // Debounce search (300ms)
    _debounceTimer = Timer(
      const Duration(milliseconds: 300),
      _performSearch,
    );
  }

  /// Execute search based on selected category
  /// Always loads counts for tab badges, then loads results for current tab
  Future<void> _performSearch() async {
    // Always load counts for tab badges (runs in parallel with results)
    unawaited(_loadCounts());

    if (state.selectedResultType == SearchResultType.topResults) {
      await _loadTopResults();
    } else {
      await _loadResultsForType();
    }
  }

  /// Load result counts for tab badges (independent of selected category)
  Future<void> _loadCounts() async {
    final query = _buildSearchQuery();
    final result = await _searchRepository.countByResultType(query);

    result.fold(
      (failure) {
        // Keep existing counts on failure
      },
      (counts) {
        state = state.copyWith(countByResultType: counts);
      },
    );
  }

  /// Load categorized results for "All" tab
  Future<void> _loadTopResults() async {
    final query = _buildSearchQuery();
    final result = await _searchRepository.searchTopResults(query);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          groupedResults: null,
        );
      },
      (categorizedResult) {
        state = state.copyWith(
          isLoading: false,
          groupedResults: categorizedResult,
        );
      },
    );
  }

  /// Load full results for the selected result type
  Future<void> _loadResultsForType() async {
    final query = _buildSearchQuery();
    state = state.copyWith(
      fullResults: const AsyncValue.loading(),
      isLoading: true,
    );

    final result = await _searchRepository.searchByResultType(
      query,
      state.selectedResultType,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          fullResults: AsyncValue.error(failure, StackTrace.current),
          isLoading: false,
        );
      },
      (results) {
        state = state.copyWith(
          fullResults: AsyncValue.data(results),
          isLoading: false,
        );
      },
    );
  }

  /// Called when user selects a search result
  /// Saves to recent searches and dismisses the panel
  Future<void> saveRecentSearchAndDismiss() async {
    if (state.queryText.trim().isEmpty) return;

    // Save to recent searches (user found what they wanted)
    await _recentSearchesRepository.addRecentSearch(state.queryText);

    // Update recent searches list for next time
    final recentSearches = await _recentSearchesRepository.getRecentSearches();
    state = state.copyWith(
      recentSearches: recentSearches,
      isPanelDismissed: true, // Dismiss the panel
    );
  }

  /// Select a category tab in results view
  Future<void> selectResultType(SearchResultType resultType) async {
    if (state.selectedResultType == resultType) return;

    state = state.copyWith(
      selectedResultType: resultType,
      isLoading: true,
    );

    // Trigger search for new category
    await _performSearch();
  }

  /// Handle clicking on a recent search
  Future<void> selectRecentSearch(String queryText) async {
    state = state.copyWith(queryText: queryText, isLoading: true);

    // Debounce not needed for direct selection
    await _performSearch();

    // Save to recent (bumps it to top)
    await _recentSearchesRepository.addRecentSearch(queryText);
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
    // Convert Singlish to Sinhala if needed (single point of conversion)
    final transliterator = SinglishTransliterator.instance;
    final effectiveQuery = transliterator.isSinglishQuery(state.queryText)
        ? transliterator.convert(state.queryText)
        : state.queryText;

    return SearchQuery(
      queryText: effectiveQuery,
      isExactMatch: state.isExactMatch,
      editionIds: state.selectedEditions,
      searchInPali: state.searchInPali,
      searchInSinhala: state.searchInSinhala,
      scope: state.selectedScope,
    );
  }

  /// Toggle exact match mode
  /// When enabled, searches for exact word matches only (no prefix matching)
  void toggleExactMatch() {
    state = state.copyWith(isExactMatch: !state.isExactMatch);
    _refreshSearchIfNeeded();
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

  // ============================================================================
  // SCOPE SELECTION METHODS (Pattern 2: "All" as default anchor)
  // ============================================================================

  /// Select a specific scope. Automatically deselects "All".
  /// If all scopes become selected, auto-collapses to "All".
  void selectScope(SearchScope scope) {
    final newScope = {...state.selectedScope, scope};

    // Auto-collapse to "All" if all scopes are selected
    if (newScope.length == SearchScope.values.length) {
      state = state.copyWith(selectedScope: {});
    } else {
      state = state.copyWith(selectedScope: newScope);
    }
    _refreshSearchIfNeeded();
  }

  /// Deselect a specific scope. If none remain, "All" becomes selected.
  void deselectScope(SearchScope scope) {
    final newScope = {...state.selectedScope}..remove(scope);
    state = state.copyWith(selectedScope: newScope);
    // Empty set = "All" selected, which is valid
    _refreshSearchIfNeeded();
  }

  /// Toggle a scope on/off.
  void toggleScope(SearchScope scope) {
    if (state.selectedScope.contains(scope)) {
      deselectScope(scope);
    } else {
      selectScope(scope);
    }
  }

  /// Select "All" - clears all specific scope selections.
  void selectAll() {
    state = state.copyWith(selectedScope: {});
    _refreshSearchIfNeeded();
  }

  /// Clear all filters (reset to defaults)
  void clearFilters() {
    state = state.copyWith(
      selectedEditions: {},
      searchInPali: true,
      searchInSinhala: true,
      selectedScope: {},
      isExactMatch: false,
    );
    _refreshSearchIfNeeded();
  }

  /// Refresh search if query is active
  void _refreshSearchIfNeeded() {
    if (state.queryText.trim().isEmpty) return;
    _performSearch();
  }

  /// Clear search and reset state
  void clearSearch() {
    _debounceTimer?.cancel();
    state = const SearchState();
  }

  /// Dismiss the results panel but keep the query text
  /// Used when user clicks a result, clicks outside, or presses Escape
  /// Panel will reopen when user focuses the search bar again
  void dismissResultsPanel() {
    _debounceTimer?.cancel();
    state = state.copyWith(isPanelDismissed: true);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
