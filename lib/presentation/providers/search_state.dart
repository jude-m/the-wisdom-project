import 'dart:async';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/search_query_utils.dart'
    show computeEffectiveQuery, querySinglishConverted;
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

    /// Tracks which FTS result groups are expanded (by nodeKey)
    /// Used to show/hide secondary matches in grouped FTS results
    @Default({}) Set<String> expandedFTSGroups,
  }) = _SearchState;

  /// Computed property: Results panel is visible when query is not empty
  /// and panel hasn't been dismissed
  bool get isResultsPanelVisible =>
      rawQueryText.trim().isNotEmpty && !isPanelDismissed;

  /// Whether a Singlish conversion was applied
  bool get isSinglishConverted =>
      querySinglishConverted(rawQueryText, effectiveQueryText);

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

  /// Request ID for tracking in-flight searches.
  /// Incremented on each new search to invalidate stale async results.
  int _searchRequestId = 0;

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
  ///
  /// Uses single atomic state update per path to minimize widget rebuilds:
  /// - Path 1 (empty/invalid query): Update query text + clear results in one update
  /// - Path 2 (valid query): Update query text + set loading in one update
  void updateQuery(String query) {
    _debounceTimer?.cancel();
    _searchRequestId++; // Invalidate any in-flight searches

    // Compute effective query (sanitized + Singlish→Sinhala)
    final effectiveQuery = _computeEffectiveQuery(query);

    // Path 1: Empty/invalid query - single atomic update
    if (query.trim().isEmpty || effectiveQuery.isEmpty) {
      state = state.copyWith(
        rawQueryText: query,
        effectiveQueryText: effectiveQuery,
        groupedResults: null,
        fullResults: const AsyncValue.data(null), // null = didn't search
        countByResultType: {},
        isLoading: false,
      );
      return;
    }

    // Path 2: Valid query - single atomic update
    // IMPORTANT: Must also reset fullResults to loading state!
    // The Full Text tab uses fullResults.when() which doesn't check isLoading.
    // Without this, old results render with new effectiveQueryText → RangeError
    state = state.copyWith(
      rawQueryText: query,
      effectiveQueryText: effectiveQuery,
      isLoading: true,
      fullResults: const AsyncValue.loading(),
    );

    _debounceTimer = Timer(
      const Duration(milliseconds: 300),
      _performSearch,
    );
  }

  /// Execute search based on selected category.
  /// Counts load in background (unawaited), results are awaited.
  Future<void> _performSearch() async {
    final currentRequestId = _searchRequestId;

    // Fire-and-forget counts (UX feature, not critical path)
    // _loadCounts only updates countByResultType - never touches loading/results
    unawaited(_loadCounts(currentRequestId));

    // Await the main results (owns isLoading lifecycle)
    if (state.selectedResultType == SearchResultType.topResults) {
      await _loadTopResults(currentRequestId);
    } else {
      await _loadResultsForType(currentRequestId);
    }
  }

  /// Load result counts for tab badges.
  /// FIELD OWNERSHIP: Only updates [countByResultType]. Never touches isLoading/results.
  Future<void> _loadCounts(int requestId) async {
    final query = _buildSearchQuery();
    if (query == null) {
      if (_searchRequestId == requestId) {
        state = state.copyWith(countByResultType: {});
      }
      return;
    }

    final result = await _searchRepository.countByResultType(query);

    // Validate: discard if newer search started
    if (_searchRequestId != requestId) return;

    result.fold(
      (failure) {
        // Keep existing counts on failure
      },
      (counts) {
        state = state.copyWith(countByResultType: counts);
      },
    );
  }

  /// Load grouped results for "Top Results" tab.
  /// FIELD OWNERSHIP: Only updates [isLoading] and [groupedResults].
  Future<void> _loadTopResults(int requestId) async {
    final query = _buildSearchQuery();
    if (query == null) {
      if (_searchRequestId == requestId) {
        state = state.copyWith(isLoading: false, groupedResults: null);
      }
      return;
    }

    final result = await _searchRepository.searchTopResults(query);

    // Validate: discard if newer search started
    if (_searchRequestId != requestId) return;

    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, groupedResults: null);
      },
      (groupedResult) {
        state = state.copyWith(isLoading: false, groupedResults: groupedResult);
      },
    );
  }

  /// Load full results for the selected result type.
  /// FIELD OWNERSHIP: Only updates [isLoading] and [fullResults].
  Future<void> _loadResultsForType(int requestId) async {
    final query = _buildSearchQuery();
    if (query == null) {
      if (_searchRequestId == requestId) {
        state = state.copyWith(isLoading: false, fullResults: const AsyncValue.data(null));
      }
      return;
    }

    final result = await _searchRepository.searchByResultType(
      query,
      state.selectedResultType,
    );

    // Validate: discard if newer search started
    if (_searchRequestId != requestId) return;

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          fullResults: AsyncValue.error(failure, StackTrace.current),
        );
      },
      (results) {
        state = state.copyWith(
          isLoading: false,
          fullResults: AsyncValue.data(results),
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

    _searchRequestId++; // Invalidate any in-flight searches

    // Reset fullResults to loading to prevent stale data rendering
    state = state.copyWith(
      selectedResultType: resultType,
      isLoading: true,
      fullResults: const AsyncValue.loading(),
    );

    // Trigger search for new category
    await _performSearch();
  }

  /// Handle clicking on a recent search
  Future<void> selectRecentSearch(String query) async {
    _searchRequestId++; // Invalidate any in-flight searches

    // Compute effective query (sanitized + Singlish→Sinhala)
    final effectiveQuery = _computeEffectiveQuery(query);

    // Reset fullResults to loading to prevent stale data rendering
    state = state.copyWith(
      rawQueryText: query,
      effectiveQueryText: effectiveQuery,
      isLoading: true,
      fullResults: const AsyncValue.loading(),
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

  /// Delegates to shared [computeEffectiveQuery] for consistent
  /// query processing across FTS and in-page search.
  String _computeEffectiveQuery(String query) =>
      computeEffectiveQuery(query);

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

  // ============================================================================
  // FTS GROUP EXPANSION
  // ============================================================================

  /// Toggle expansion state of an FTS result group.
  /// Used to show/hide secondary matches in grouped FTS results.
  void toggleFTSGroupExpansion(String nodeKey) {
    final current = state.expandedFTSGroups;
    final updated = current.contains(nodeKey)
        ? ({...current}..remove(nodeKey))
        : {...current, nodeKey};
    state = state.copyWith(expandedFTSGroups: updated);
  }

  /// Collapse all expanded FTS groups.
  void collapseAllFTSGroups() {
    state = state.copyWith(expandedFTSGroups: {});
  }

  /// Refresh search if query is active
  /// Used when filters change (scope, language, etc.)
  void _refreshSearchIfNeeded() {
    if (state.rawQueryText.trim().isEmpty) return;

    _searchRequestId++; // Invalidate any in-flight searches
    // Reset fullResults to loading to prevent stale data rendering
    state = state.copyWith(
      isLoading: true,
      fullResults: const AsyncValue.loading(),
    );
    _performSearch();
  }

  /// Clear search and reset state
  void clearSearch() {
    _debounceTimer?.cancel();
    _searchRequestId++; // Invalidate any in-flight searches
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
