import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/search/grouped_fts_match.dart';
import '../../../domain/entities/search/grouped_search_result.dart';
import '../../../domain/entities/search/search_result_type.dart';
import '../../../domain/entities/search/search_result.dart';
import '../../providers/search_provider.dart';
import 'grouped_fts_tile.dart';
import 'highlighted_search_text.dart';
import 'scope_filter_chips.dart';

/// Slide-out panel for displaying full search results
/// Used as a side panel on desktop and full-screen overlay on mobile
class SearchResultsPanel extends ConsumerWidget {
  /// Callback when the panel should be closed
  final VoidCallback onClose;

  /// Callback when a search result is tapped
  final void Function(SearchResult result)? onResultTap;

  const SearchResultsPanel({
    super.key,
    required this.onClose,
    this.onResultTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchStateProvider);
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          // Header with scope filters and close button
          _PanelHeader(
            onClose: onClose,
          ),
          // Category tabs
          _SearchResultsTabBar(
            selectedResultType: searchState.selectedResultType,
            countByResultType: searchState.countByResultType,
            onResultTypeSelected: (renameType) {
              ref.read(searchStateProvider.notifier).selectResultType(renameType);
            },
          ),
          // Results list - different view for "All" tab vs specific category
          Expanded(
            child: searchState.selectedResultType == SearchResultType.topResults
                ? _buildTopResultsTabContent(
                    context,
                    theme,
                    searchState.isLoading,
                    searchState.groupedResults,
                    searchState.effectiveQueryText,
                    searchState.isPhraseSearch,
                    searchState.isExactMatch,
                  )
                : _buildResultTypeTabContent(
                    context,
                    ref,
                    theme,
                    searchState.fullResults,
                    searchState.selectedResultType,
                    searchState.effectiveQueryText,
                    searchState
                        .countByResultType[searchState.selectedResultType],
                    searchState.isPhraseSearch,
                    searchState.isExactMatch,
                  ),
          ),
        ],
      ),
    );
  }

  /// Builds the content for the "All" tab showing categorized results
  Widget _buildTopResultsTabContent(
    BuildContext context,
    ThemeData theme,
    bool isLoading,
    GroupedSearchResult? categorizedResults,
    String effectiveQuery,
    bool isPhraseSearch,
    bool isExactMatch,
  ) {
    // Loading state
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Invalid query - didn't search
    if (categorizedResults == null) {
      return _buildEmptyState(theme, isInvalidQuery: true);
    }

    // Valid query - searched but no results
    if (categorizedResults.isEmpty) {
      return _buildEmptyState(theme, isInvalidQuery: false);
    }

    // Build categorized results - use grouped tiles for fullText, regular for others
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...categorizedResults.categoriesWithResults
              .where((resultType) =>
                  resultType != SearchResultType.definition &&
                  resultType != SearchResultType.topResults)
              .map((resultType) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section header
                      _sectionHeader(theme, resultType.displayName.toUpperCase()),
                      // Use grouped tiles for fullText, regular tiles for others
                      if (resultType == SearchResultType.fullText)
                        ..._buildGroupedFTSResults(
                          categorizedResults.getResultsByType(resultType),
                          effectiveQuery,
                          isPhraseSearch,
                          isExactMatch,
                        )
                      else
                        ...categorizedResults
                            .getResultsByType(resultType)
                            .map((result) => _SearchResultTile(
                                  searchResult: result,
                                  effectiveQuery: effectiveQuery,
                                  isPhraseSearch: isPhraseSearch,
                                  isExactMatch: isExactMatch,
                                  onTap: () => onResultTap?.call(result),
                                )),
                    ],
                  )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Builds grouped FTS result tiles from a list of search results
  List<Widget> _buildGroupedFTSResults(
    List<SearchResult> results,
    String effectiveQuery,
    bool isPhraseSearch,
    bool isExactMatch,
  ) {
    final groupedResults = GroupedFTSMatch.fromSearchResults(results);
    return groupedResults
        .map((group) => GroupedFTSTile(
              group: group,
              effectiveQuery: effectiveQuery,
              isPhraseSearch: isPhraseSearch,
              isExactMatch: isExactMatch,
              onPrimaryTap: (result) => onResultTap?.call(result),
              onSecondaryTap: (result) => onResultTap?.call(result),
            ))
        .toList();
  }

  /// Builds the content for specific category tabs (Title, Content, Definition)
  Widget _buildResultTypeTabContent(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    AsyncValue<List<SearchResult>?> fullResults,
    SearchResultType selectedResultType,
    String effectiveQuery,
    int? totalCount,
    bool isPhraseSearch,
    bool isExactMatch,
  ) {
    return fullResults.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load results',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  ref
                      .read(searchStateProvider.notifier)
                      .selectResultType(selectedResultType);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (results) {
        // Invalid query - didn't search
        if (results == null) {
          return _buildEmptyState(theme, isInvalidQuery: true);
        }
        // Valid query - no results
        if (results.isEmpty) {
          return _buildEmptyState(
            theme,
            isInvalidQuery: false,
            resultTypeName: selectedResultType.displayName.toLowerCase(),
          );
        }

        // Check if DB has more results than currently displayed.
        // When true, we append a footer row showing "Viewing X out of Y".
        final hasMoreResults =
            totalCount != null && totalCount > results.length;

        // Use grouped tiles for fullText tab
        if (selectedResultType == SearchResultType.fullText) {
          final groupedResults = GroupedFTSMatch.fromSearchResults(results);
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount:
                hasMoreResults ? groupedResults.length + 1 : groupedResults.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: 72,
              color: theme.colorScheme.outlineVariant,
            ),
            itemBuilder: (context, index) {
              // Render footer as the last item when results are truncated
              if (hasMoreResults && index == groupedResults.length) {
                return _footer(theme, results.length, totalCount);
              }

              return GroupedFTSTile(
                group: groupedResults[index],
                effectiveQuery: effectiveQuery,
                isPhraseSearch: isPhraseSearch,
                isExactMatch: isExactMatch,
                onPrimaryTap: (result) => onResultTap?.call(result),
                onSecondaryTap: (result) => onResultTap?.call(result),
              );
            },
          );
        }

        // Regular tiles for other result types (title, definition)
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          // Add +1 for footer row when results are truncated
          itemCount: hasMoreResults ? results.length + 1 : results.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            indent: 72,
            color: theme.colorScheme.outlineVariant,
          ),
          itemBuilder: (context, index) {
            // Render footer as the last item when results are truncated
            if (hasMoreResults && index == results.length) {
              return _footer(theme, results.length, totalCount);
            }

            return _SearchResultTile(
              searchResult: results[index],
              effectiveQuery: effectiveQuery,
              isPhraseSearch: isPhraseSearch,
              isExactMatch: isExactMatch,
              onTap: () => onResultTap?.call(results[index]),
            );
          },
        );
      },
    );
  }

  /// Footer widget showing truncation info when results exceed display limit.
  ///
  /// Displayed at the bottom of the results list when [totalCount] > [displayedCount].
  /// Shows "Viewing X out of Y results" with decorative dividers on each side.
  Widget _footer(ThemeData theme, int displayedCount, int totalCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant,
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Viewing $displayedCount out of $totalCount results',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant,
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  /// Section header widget
  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// Builds empty state widget for invalid query or no results
  Widget _buildEmptyState(
    ThemeData theme, {
    required bool isInvalidQuery,
    String? resultTypeName,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isInvalidQuery ? Icons.edit_note : Icons.search_off,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              isInvalidQuery
                  ? 'Enter a valid search query'
                  : resultTypeName != null
                      ? 'No $resultTypeName found'
                      : 'No results found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Header for the search results panel
/// Contains close button (for mobile full-screen) and scope filter chips
class _PanelHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _PanelHeader({
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
            tooltip: 'Close',
          ),
          // Scope filter chips (scrollable)
          const Expanded(
            child: ScopeFilterChips(),
          ),
        ],
      ),
    );
  }
}

/// Category tab bar for switching between All, Title, Content, and Definition
class _SearchResultsTabBar extends StatelessWidget {
  final SearchResultType selectedResultType;
  final Map<SearchResultType, int> countByResultType;
  final void Function(SearchResultType) onResultTypeSelected;

  const _SearchResultsTabBar({
    required this.selectedResultType,
    required this.onResultTypeSelected,
    required this.countByResultType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: SearchResultType.values.map((resultType) {
          final isSelected = resultType == selectedResultType;
          final count = countByResultType[resultType];

          return Expanded(
            child: InkWell(
              onTap: () => onResultTypeSelected(resultType),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        resultType.displayName,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    // Show badge for non-"Top Results" tabs when count is available
                    if (resultType != SearchResultType.topResults && count != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _CountBadge(count: count),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Pill-shaped badge showing result count for tab headers
class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Format: 0, 56, or 100+
    final displayText = count > 100 ? '100+' : count.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Individual search result tile with highlighting support
class _SearchResultTile extends StatelessWidget {
  final SearchResult searchResult;

  /// Pre-computed effective query (sanitized + Singlish→Sinhala converted)
  /// from SearchState. No per-row conversion needed.
  final String effectiveQuery;

  /// Whether phrase search mode is active.
  /// Affects how multi-word queries are highlighted.
  final bool isPhraseSearch;

  /// Whether exact match mode is active.
  /// When false (default), uses prefix matching for highlighting.
  final bool isExactMatch;

  final VoidCallback? onTap;

  const _SearchResultTile({
    required this.searchResult,
    required this.effectiveQuery,
    required this.isPhraseSearch,
    required this.isExactMatch,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            searchResult.editionId.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      // Title is never highlighted - just plain text
      title: Text(
        searchResult.title,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            searchResult.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Only show and highlight matchedText for CONTENT results
          if (searchResult.resultType == SearchResultType.fullText &&
              searchResult.matchedText.isNotEmpty) ...[
            const SizedBox(height: 4),
            HighlightedSearchText(
              matchedText: searchResult.matchedText,
              effectiveQuery: effectiveQuery,
              isPhraseSearch: isPhraseSearch,
              isExactMatch: isExactMatch,
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}
