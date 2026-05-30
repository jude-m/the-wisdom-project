import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/l10n/app_localizations.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/entities/search/grouped_fts_match.dart';
import '../../../domain/entities/search/grouped_search_result.dart';
import '../../../domain/entities/search/search_result_type.dart';
import '../../../domain/entities/search/search_result.dart';
import '../../providers/dictionary_provider.dart'
    show selectedDictionaryWordProvider;
import '../../providers/search_provider.dart';
import '../../utils/search_result_labels.dart';
import '../common/status_message_view.dart';
import '../dictionary/dictionary_filter_chips.dart';
import '../dictionary/refine_dictionary_dialog.dart';
import 'dictionary_search_result_tile.dart';
import 'grouped_fts_tile.dart';
import 'highlighted_fts_search_text.dart';
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
              ref
                  .read(searchStateProvider.notifier)
                  .selectResultType(renameType);
            },
          ),
          // Results list - different view for "All" tab vs specific category
          Expanded(
            child: searchState.selectedResultType == SearchResultType.topResults
                ? _buildTopResultsTabContent(
                    context,
                    ref,
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
    WidgetRef ref,
    ThemeData theme,
    bool isLoading,
    GroupedSearchResult? categorizedResults,
    String effectiveQuery,
    bool isPhraseSearch,
    bool isExactMatch,
  ) {
    // Loading state
    if (isLoading) {
      return const StatusMessageView(variant: StatusVariant.loading);
    }

    // Invalid query - didn't search
    if (categorizedResults == null) {
      return StatusMessageView(
        variant: StatusVariant.invalid,
        title: AppLocalizations.of(context).statusInvalidQuery,
      );
    }

    // Valid query - searched but no results
    if (categorizedResults.isEmpty) {
      return StatusMessageView(
        variant: StatusVariant.empty,
        title: AppLocalizations.of(context).noResultsFound,
      );
    }

    // Build categorized results - use grouped tiles for fullText, dictionary tiles for definitions
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...categorizedResults.categoriesWithResults
              .where((resultType) => resultType != SearchResultType.topResults)
              .map((resultType) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section header
                      _sectionHeader(
                          context, resultType.displayName.toUpperCase()),
                      // Use appropriate tile type for each result type
                      if (resultType == SearchResultType.fullText)
                        ..._buildGroupedFTSResults(
                          categorizedResults.getResultsByType(resultType),
                          effectiveQuery,
                          isPhraseSearch,
                          isExactMatch,
                        )
                      else if (resultType == SearchResultType.definition)
                        ...categorizedResults
                            .getResultsByType(resultType)
                            .map((result) => DictionarySearchResultTile(
                                  result: result,
                                  onTap: () =>
                                      _showDictionaryBottomSheet(ref, result),
                                ))
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

  /// Shows a dictionary bottom sheet with the word from a definition result
  void _showDictionaryBottomSheet(WidgetRef ref, SearchResult result) {
    ref.read(selectedDictionaryWordProvider.notifier).state = result.title;
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
      loading: () => const StatusMessageView(variant: StatusVariant.loading),
      error: (error, stack) {
        // Decide between offline (server unreachable) and generic error.
        // statusVariantForError unwraps Failure and inspects the inner cause.
        // No Retry button: on web the user can refresh the page; on mobile
        // assets are bundled, so a retry can't fix an inherent failure.
        final variant = statusVariantForError(error);
        final l10n = AppLocalizations.of(context);
        return StatusMessageView(
          variant: variant,
          title: variant == StatusVariant.offline
              ? l10n.statusOfflineTitle
              : l10n.errorLoadingSearch,
          description: variant == StatusVariant.offline
              ? l10n.statusOfflineDescription
              : l10n.statusErrorDescription,
        );
      },
      data: (results) {
        final l10n = AppLocalizations.of(context);
        // Invalid query - didn't search
        if (results == null) {
          return StatusMessageView(
            variant: StatusVariant.invalid,
            title: l10n.statusInvalidQuery,
          );
        }
        // Valid query - no results
        if (results.isEmpty) {
          return StatusMessageView(
            variant: StatusVariant.empty,
            title: l10n.statusNoResultsForCategory(
              selectedResultType.displayName.toLowerCase(),
            ),
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
            itemCount: hasMoreResults
                ? groupedResults.length + 1
                : groupedResults.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: 72,
              color: theme.colorScheme.outlineVariant,
            ),
            itemBuilder: (context, index) {
              // Render footer as the last item when results are truncated
              if (hasMoreResults && index == groupedResults.length) {
                return _footer(context, results.length, totalCount);
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

        // Use DictionarySearchResultTile for definition results
        if (selectedResultType == SearchResultType.definition) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: hasMoreResults ? results.length + 1 : results.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: 72,
              color: theme.colorScheme.outlineVariant,
            ),
            itemBuilder: (context, index) {
              if (hasMoreResults && index == results.length) {
                return _footer(context, results.length, totalCount);
              }

              return DictionarySearchResultTile(
                result: results[index],
                onTap: () => _showDictionaryBottomSheet(ref, results[index]),
              );
            },
          );
        }

        // Regular tiles for other result types (title)
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
              return _footer(context, results.length, totalCount);
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
  Widget _footer(BuildContext context, int displayedCount, int totalCount) {
    final theme = Theme.of(context);
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
              style: context.typography.resultSubtitle,
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
  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: context.typography.sectionHeader,
      ),
    );
  }
}

/// Header for the search results panel
/// Contains close button and filter chips.
/// Shows scope filter chips for Title/FTS tabs, dictionary filter chips for Definitions tab.
class _PanelHeader extends ConsumerWidget {
  final VoidCallback onClose;

  const _PanelHeader({
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDefinitionTab = ref.watch(
      searchStateProvider.select(
        (s) => s.selectedResultType == SearchResultType.definition,
      ),
    );
    final selectedDictionaryIds = ref.watch(
      searchStateProvider.select((s) => s.selectedDictionaryIds),
    );

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
          // Show dictionary filter chips on Definitions tab,
          // scope filter chips on all other tabs
          Expanded(
            child: isDefinitionTab
                ? DictionaryFilterChips(
                    selectedDictionaryIds: selectedDictionaryIds,
                    onToggleKeys: (keys) => ref
                        .read(searchStateProvider.notifier)
                        .toggleDictionaryKeys(keys),
                    onSelectAll: () => ref
                        .read(searchStateProvider.notifier)
                        .selectAllDictionaries(),
                    onRefineTap: () => RefineDictionaryDialog.show(
                      context,
                      selectedIds: selectedDictionaryIds,
                      onFilterChanged: (ids) => ref
                          .read(searchStateProvider.notifier)
                          .setDictionaryFilter(ids),
                    ),
                  )
                : const ScopeFilterChips(),
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
      // IntrinsicHeight measures the tallest tab first and locks the Row to
      // that height. Combined with CrossAxisAlignment.stretch below, every
      // tab cell fills the full height so the 2px selected-indicator butts
      // flush against the outer 1px divider — no gap on the badge-less
      // "Top Results" tab.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: SearchResultType.values.map((resultType) {
            final isSelected = resultType == selectedResultType;
            final count = countByResultType[resultType];

            return Expanded(
              child: InkWell(
                onTap: () => onResultTypeSelected(resultType),
                child: Container(
                  alignment: Alignment.center,
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
                          style: (isSelected
                                  ? context.typography.tabLabelActive
                                  : context.typography.tabLabelInactive)
                              .copyWith(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      // Show badge for non-"Top Results" tabs when count is available
                      if (resultType != SearchResultType.topResults &&
                          count != null)
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
        style: context.typography.countBadge,
      ),
    );
  }
}

/// Individual search result tile with highlighting support
class _SearchResultTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final typography = context.typography;

    // Title + navigation path in the active Content Language (same pipeline as
    // the breadcrumbs and tree), instead of the query-matched language.
    final labels = searchResultLabels(ref, searchResult);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            searchResult.editionId.toUpperCase(),
            style: typography.badgeLabel,
          ),
        ),
      ),
      // Title is never highlighted - just plain text
      title: Text(
        labels.title,
        style: typography.resultTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            labels.path,
            style: typography.resultSubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Only show and highlight matchedText for CONTENT results
          if (searchResult.resultType == SearchResultType.fullText &&
              searchResult.matchedText.isNotEmpty) ...[
            const SizedBox(height: 4),
            HighlightedFtsSearchText(
              matchedText: searchResult.matchedText,
              effectiveQuery: effectiveQuery,
              isPhraseSearch: isPhraseSearch,
              isExactMatch: isExactMatch,
              language: searchResult.language,
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}
