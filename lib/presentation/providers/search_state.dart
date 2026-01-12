import 'dart:async';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/singlish_transliterator.dart';
import '../../core/utils/text_utils.dart';
import '../../domain/entities/search/grouped_search_result.dart';
import '../../domain/entities/search/recent_search.dart';
import '../../domain/entities/search/search_result_type.dart';
import '../../domain/entities/search/search_query.dart';
import '../../domain/entities/search/search_result.dart';
import '../../domain/entities/search/scope_operations.dart';
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
    /// Current search query text (raw user input)
    @Default('') String rawQueryText,

    /// Effective query text (sanitized + converted to Sinhala if Singlish)
    /// This is computed once when query changes and used for:
    /// - Repository searches (via SearchQuery)
    /// - UI highlighting (avoids re-conversion per result row)
    @Default('') String effectiveQueryText,

    /// Recent search history
    @Default([]) List<RecentSearch> recentSearches,

    /// Currently selected category in results view
    @Default(SearchResultType.topResults) SearchResultType selectedResultType,

    /// Categorized results for "Top Results" tab (grouped by category)
    GroupedSearchResult? groupedResults,

    /// Full results for the selected category (async state)
    /// null = invalid query (didn't search), [] = valid query with no results
    @Default(AsyncValue.data(null)) AsyncValue<List<SearchResult>?> fullResults,

    /// Whether results are currently loading
    @Default(false) bool isLoading,

    /// Selected editions to search (empty = default to BJT)
    @Default({}) Set<String> selectedEditions,

    /// Whether to search in Pali text
    @Default(true) bool searchInPali,

    /// Whether to search in Sinhala text
    @Default(true) bool searchInSinhala,

    /// Search scope using tree node keys (e.g., 'sp', 'dn', 'kn-dhp').
    ///
    /// Empty set = search all content (no scope filter applied).
    /// Non-empty = search only within the selected scope (OR logic).
    ///
    /// This is set by:
    /// - Quick filter chips (e.g., clicking "Sutta" sets {'sp'})
    /// - Refine dialog tree selection (e.g., {'dn', 'mn'})
    @Default({}) Set<String> scope,

    /// Whether to search as a phrase (consecutive words) or separate words.
    /// - true (DEFAULT) = phrase search (words must be adjacent)
    /// - false = separate-word search (words within proximity distance)
    @Default(true) bool isPhraseSearch,

    /// Whether to ignore proximity and search anywhere in the same text unit.
    /// Only applies when [isPhraseSearch] is false.
    /// - true = search for words anywhere in the text (uses very large proximity)
    /// - false (DEFAULT) = use [proximityDistance] for proximity constraint
    @Default(false) bool isAnywhereInText,

    /// Proximity distance for multi-word separate-word queries.
    /// Only applies when [isPhraseSearch] is false and [isAnywhereInText] is false.
    /// Default 10 = words within 10 tokens (NEAR/10).
    /// Range: 1-100.
    @Default(10) int proximityDistance,

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
      rawQueryText.trim().isNotEmpty && !isPanelDismissed;

  /// True if "All" is effectively selected (no specific scope chosen)
  bool get isAllSelected => scope.isEmpty;
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
  /// Computes effectiveQueryText once here, avoiding per-row conversion later.
  void updateQuery(String query) {
    _debounceTimer?.cancel();

    // Compute effective query (sanitized + Singlish→Sinhala)
    final effectiveQuery = _computeEffectiveQuery(query);

    // Update both rawQueryText and effectiveQueryText together
    state = state.copyWith(
      rawQueryText: query,
      effectiveQueryText: effectiveQuery,
    );

    // If query is empty or invalid, clear results
    if (query.trim().isEmpty || effectiveQuery.isEmpty) {
      state = state.copyWith(
        groupedResults: null,
        fullResults: const AsyncValue.data([]),
        isLoading: false,
      );
      return;
    }

    // Set loading state and debounce search (300ms)
    state = state.copyWith(isLoading: true);
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
    if (query == null) {
      // Invalid query - clear counts
      state = state.copyWith(countByResultType: {});
      return;
    }

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
    if (query == null) {
      // Invalid query - set empty results, don't call repository
      state = state.copyWith(
        isLoading: false,
        groupedResults: null,
      );
      return;
    }

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
    if (query == null) {
      state = state.copyWith(
        fullResults: const AsyncValue.data(null),
        isLoading: false,
      );
      return;
    }

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
    if (state.rawQueryText.trim().isEmpty) return;

    // Save to recent searches (user found what they wanted)
    await _recentSearchesRepository.addRecentSearch(state.rawQueryText);

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
  Future<void> selectRecentSearch(String query) async {
    // Compute effective query (sanitized + Singlish→Sinhala)
    final effectiveQuery = _computeEffectiveQuery(query);

    state = state.copyWith(
      rawQueryText: query,
      effectiveQueryText: effectiveQuery,
      isLoading: true,
    );

    // Debounce not needed for direct selection
    await _performSearch();

    // Save to recent (bumps it to top)
    await _recentSearchesRepository.addRecentSearch(query);
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

  /// Computes the effective query from raw input.
  /// Sanitizes and converts Singlish to Sinhala if needed.
  /// Returns empty string if query is invalid.
  String _computeEffectiveQuery(String query) {
    final sanitized = sanitizeSearchQuery(query);
    if (sanitized == null) return '';

    final transliterator = SinglishTransliterator.instance;
    return transliterator.isSinglishQuery(sanitized)
        ? transliterator.convert(sanitized)
        : sanitized;
  }

  /// Builds validated [SearchQuery] from current state, or `null` if invalid.
  /// Uses pre-computed effectiveQueryText from state.
  SearchQuery? _buildSearchQuery() {
    if (state.effectiveQueryText.isEmpty) {
      return null; // Invalid query - no valid content
    }

    return SearchQuery(
      queryText: state.effectiveQueryText,
      isExactMatch: state.isExactMatch,
      editionIds: state.selectedEditions,
      searchInPali: state.searchInPali,
      searchInSinhala: state.searchInSinhala,
      scope: state.scope,
      isPhraseSearch: state.isPhraseSearch,
      isAnywhereInText: state.isAnywhereInText,
      proximityDistance: state.proximityDistance,
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
  // SCOPE SELECTION METHODS
  // ============================================================================

  /// Set scope from tree node keys.
  ///
  /// Used by both quick filter chips and the refine dialog.
  /// [nodeKeys] - Set of tree node keys (e.g., {'sp'} for Sutta, {'dn', 'mn'} for specific nikayas)
  /// Empty set = search all content.
  ///
  /// Automatically normalizes: if all chip scopes are selected, collapses to "All".
  void setScope(Set<String> nodeKeys) {
    final normalizedScope = ScopeOperations.normalize(nodeKeys);
    state = state.copyWith(scope: normalizedScope);
    _refreshSearchIfNeeded();
  }

  /// Toggle scope keys on/off (multi-select behavior).
  ///
  /// This is a UI-agnostic method that only accepts `Set<String>` keys.
  /// The widget is responsible for extracting keys from chip entities.
  ///
  /// - If all [keys] are in scope: removes them
  /// - If any [keys] are missing: adds them all
  /// - Auto-collapse: if all chips are selected, reverts to "All" (empty set)
  void toggleScopeKeys(Set<String> keys) {
    final newScope = ScopeOperations.toggleKeys(state.scope, keys);
    state = state.copyWith(scope: newScope);
    _refreshSearchIfNeeded();
  }

  /// Select "All" - clears scope filter.
  void selectAll() {
    state = state.copyWith(scope: {});
    _refreshSearchIfNeeded();
  }

  /// Clear all filters (reset to defaults)
  void clearFilters() {
    state = state.copyWith(
      selectedEditions: {},
      searchInPali: true,
      searchInSinhala: true,
      scope: {},
      isPhraseSearch: true,
      isAnywhereInText: false,
      proximityDistance: 10,
      isExactMatch: false,
    );
    _refreshSearchIfNeeded();
  }

  // ============================================================================
  // PHRASE/PROXIMITY SETTINGS
  // ============================================================================

  /// Toggle phrase search mode.
  /// When enabled (default), searches for consecutive words.
  /// When disabled, searches for words within proximity distance.
  void setPhraseSearch(bool isPhraseSearch) {
    state = state.copyWith(isPhraseSearch: isPhraseSearch);
    _refreshSearchIfNeeded();
  }

  /// Toggle "anywhere in text" mode.
  /// Only applies when [isPhraseSearch] is false.
  /// When enabled, ignores proximity distance and searches anywhere in the text.
  void setAnywhereInText(bool isAnywhereInText) {
    state = state.copyWith(isAnywhereInText: isAnywhereInText);
    _refreshSearchIfNeeded();
  }

  /// Set proximity distance for multi-word separate-word searches.
  /// [distance] = 1-100 for NEAR/n proximity.
  /// Only applies when [isPhraseSearch] is false and [isAnywhereInText] is false.
  void setProximityDistance(int distance) {
    state = state.copyWith(proximityDistance: distance);
    _refreshSearchIfNeeded();
  }

  /// Refresh search if query is active
  void _refreshSearchIfNeeded() {
    if (state.rawQueryText.trim().isEmpty) return;
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
