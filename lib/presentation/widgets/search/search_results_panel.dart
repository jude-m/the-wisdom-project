import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/l10n/app_localizations.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../domain/entities/reader/reader_unit.dart';
import '../../../domain/entities/search/grouped_fts_match.dart';
import '../../../domain/entities/search/grouped_search_result.dart';
import '../../../domain/entities/search/search_result_type.dart';
import '../../../domain/entities/search/search_result.dart';
import '../../providers/dictionary_provider.dart'
    show selectedDictionaryWordProvider;
import '../../providers/reader_unit_provider.dart';
import '../../providers/reference_search_provider.dart';
import '../../providers/search_provider.dart';
import '../../utils/search_result_labels.dart';
import '../common/status_message_view.dart';
import '../dictionary/dictionary_filter_chips.dart';
import '../dictionary/refine_dictionary_dialog.dart';
import 'dictionary_search_result_tile.dart';
import 'grouped_fts_tile.dart';
import 'match_options_menu.dart';
import 'result_badge.dart';
import 'scope_filter_chips.dart';
import 'search_link_button.dart';
import 'search_result_tile.dart';

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
    // Which sutta each FTS row belongs to — null until the tree loads, and the
    // stored key stands in until it does.
    final resolver = ref.watch(readerUnitResolverProvider).valueOrNull;

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
            onResultTypeSelected: (type) =>
                ref.read(searchStateProvider.notifier).selectResultType(type),
          ),
          // Pinned canonical-reference jump (e.g. "SN 15.3" → open that sutta).
          // In-memory lookup, so it appears instantly above the FTS results,
          // independent of the active tab or whether FTS has finished loading.
          _ReferenceResultRow(onResultTap: onResultTap),
          // Results list - different view for "All" tab vs specific category
          Expanded(
            child: searchState.selectedResultType == SearchResultType.topResults
                ? _buildTopResultsTabContent(
                    context,
                    ref,
                    searchState.isLoading,
                    searchState.groupedResults,
                    searchState.countByResultType,
                    searchState.effectiveQueryText,
                    searchState.isPhraseSearch,
                    searchState.isExactMatch,
                    resolver,
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
                    resolver,
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
    bool isLoading,
    GroupedSearchResult? categorizedResults,
    Map<SearchResultType, int> countByResultType,
    String effectiveQuery,
    bool isPhraseSearch,
    bool isExactMatch,
    ReaderUnitResolver? resolver,
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

    // One badge decision for the whole tab. Dictionary tiles always keep theirs.
    final showEditionBadge = _hasMixedEditions(categorizedResults
        .resultsByType.entries
        .where((entry) => entry.key != SearchResultType.definition)
        .expand((entry) => entry.value));

    // Build categorized results - use grouped tiles for fullText, dictionary tiles for definitions
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...categorizedResults.categoriesWithResults
              .where((resultType) => resultType != SearchResultType.topResults)
              .map((resultType) {
            final results = categorizedResults.getResultsByType(resultType);
            final count = countByResultType[resultType];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  label: searchResultTypeLabel(
                      resultType, AppLocalizations.of(context)),
                  // Hidden until counts load, and when the section shows them all.
                  onSeeAll: count != null && count > results.length
                      ? () => ref
                          .read(searchStateProvider.notifier)
                          .selectResultType(resultType)
                      : null,
                ),
                // Use appropriate tile type for each result type
                if (resultType == SearchResultType.fullText)
                  ..._buildGroupedFTSResults(
                    results,
                    effectiveQuery,
                    isPhraseSearch,
                    isExactMatch,
                    resolver,
                    showEditionBadge,
                  )
                else if (resultType == SearchResultType.definition)
                  ...results.map((result) => DictionarySearchResultTile(
                        result: result,
                        onTap: () => _showDictionaryBottomSheet(ref, result),
                      ))
                else
                  ...results.map((result) => SearchResultTile(
                        searchResult: result,
                        effectiveQuery: effectiveQuery,
                        isPhraseSearch: isPhraseSearch,
                        isExactMatch: isExactMatch,
                        showEditionBadge: showEditionBadge,
                        onTap: () => onResultTap?.call(result),
                      )),
              ],
            );
          }),
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
    ReaderUnitResolver? resolver,
    bool showEditionBadge,
  ) {
    final groupedResults =
        GroupedFTSMatch.fromSearchResults(results, resolver: resolver);
    return groupedResults
        .map((group) => GroupedFTSTile(
              group: group,
              effectiveQuery: effectiveQuery,
              isPhraseSearch: isPhraseSearch,
              isExactMatch: isExactMatch,
              showEditionBadge: showEditionBadge,
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
    ReaderUnitResolver? resolver,
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
              searchResultTypeLabel(selectedResultType, l10n).toLowerCase(),
            ),
          );
        }

        // Check if DB has more results than currently displayed.
        // When true, we append a footer row showing "Viewing X out of Y".
        final hasMoreResults =
            totalCount != null && totalCount > results.length;

        // Titles and full text drop the edition badge when it tells no rows
        // apart; the divider then starts where the text does. Definitions
        // always keep their dictionary badge.
        final showEditionBadge =
            selectedResultType != SearchResultType.definition &&
                _hasMixedEditions(results);
        final dividerIndent = ResultBadge.textStart(showEditionBadge);

        // Use grouped tiles for fullText tab
        if (selectedResultType == SearchResultType.fullText) {
          final groupedResults =
              GroupedFTSMatch.fromSearchResults(results, resolver: resolver);
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: hasMoreResults
                ? groupedResults.length + 1
                : groupedResults.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: dividerIndent,
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
                showEditionBadge: showEditionBadge,
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
              indent: ResultBadge.textStart(true),
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
            indent: dividerIndent,
            color: theme.colorScheme.outlineVariant,
          ),
          itemBuilder: (context, index) {
            // Render footer as the last item when results are truncated
            if (hasMoreResults && index == results.length) {
              return _footer(context, results.length, totalCount);
            }

            return SearchResultTile(
              searchResult: results[index],
              effectiveQuery: effectiveQuery,
              isPhraseSearch: isPhraseSearch,
              isExactMatch: isExactMatch,
              showEditionBadge: showEditionBadge,
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
              AppLocalizations.of(context)
                  .viewingResults(displayedCount, totalCount),
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
}

/// True when [results] come from two or more editions, so the edition badge
/// tells rows apart. Stops at the first difference.
bool _hasMixedEditions(Iterable<SearchResult> results) {
  String? first;
  for (final result in results) {
    first ??= result.editionId;
    if (result.editionId != first) return true;
  }
  return false;
}

/// Top results section header: "TITLES", plus "See all →" when [onSeeAll]
/// is set.
class _SectionHeader extends StatelessWidget {
  final String label;
  final VoidCallback? onSeeAll;

  const _SectionHeader({required this.label, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final onSeeAll = this.onSeeAll;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      // Same height with or without "See all"; grows with large text.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: context.typography.sectionHeader,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onSeeAll != null)
              SearchLinkButton(
                onPressed: onSeeAll,
                icon: Icons.arrow_forward,
                label: AppLocalizations.of(context).seeAll,
              ),
          ],
        ),
      ),
    );
  }
}

/// The panel's top row: close, the match options button, then the filter
/// chips (dictionary chips on the Definitions tab, scope chips elsewhere).
/// The match button and chips scroll together.
class _PanelHeader extends ConsumerWidget {
  final VoidCallback onClose;

  const _PanelHeader({
    required this.onClose,
  });

  /// Scrolls with the chips, ahead of them.
  static const _leading = [MatchOptionsButton(), _ChipDivider()];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // Phones keep the ✕ until the app bar's back arrow closes search there.
    final isMobile = ResponsiveUtils.isMobile(context);
    final isDefinitionTab = ref.watch(
      searchStateProvider.select(
        (s) => s.selectedResultType == SearchResultType.definition,
      ),
    );
    final selectedDictionaryIds = ref.watch(
      searchStateProvider.select((s) => s.selectedDictionaryIds),
    );

    return Container(
      height: 56,
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
            // → slides the panel away to the right, where it came from.
            icon: Icon(isMobile ? Icons.close : Icons.arrow_forward),
            onPressed: onClose,
            tooltip: isMobile ? l10n.close : l10n.closePanel,
          ),
          Expanded(
            child: isDefinitionTab
                ? DictionaryFilterChips(
                    leading: _leading,
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
                : const ScopeFilterChips(leading: _leading),
          ),
        ],
      ),
    );
  }
}

/// Thin upright line between the match button and the chips.
class _ChipDivider extends StatelessWidget {
  const _ChipDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

/// The result tabs, in order. [SearchResultType.reference] is never a tab.
const _tabTypes = [
  SearchResultType.topResults,
  SearchResultType.title,
  SearchResultType.fullText,
  SearchResultType.definition,
];

/// Category tabs, sized to their labels, each with a count but Top results.
/// A tab with no results looks like the others: its "0" badge says so.
class _SearchResultsTabBar extends StatefulWidget {
  final SearchResultType selectedResultType;
  final Map<SearchResultType, int> countByResultType;
  final void Function(SearchResultType) onResultTypeSelected;

  const _SearchResultsTabBar({
    required this.selectedResultType,
    required this.onResultTypeSelected,
    required this.countByResultType,
  });

  @override
  State<_SearchResultsTabBar> createState() => _SearchResultsTabBarState();
}

class _SearchResultsTabBarState extends State<_SearchResultsTabBar>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: _tabTypes.length,
      vsync: this,
      initialIndex: _tabTypes.indexOf(widget.selectedResultType),
    );
  }

  @override
  void didUpdateWidget(covariant _SearchResultsTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // "See all" changes the tab from outside the bar.
    final index = _tabTypes.indexOf(widget.selectedResultType);
    if (index != _controller.index) _controller.animateTo(index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TabBar(
      controller: _controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      padding: const EdgeInsets.only(left: 8),
      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      // Keep the divider: with dividerHeight 0, a scrollable TabBar shrinks
      // to its tabs and sits in the middle of a wide panel.
      dividerColor: theme.colorScheme.outlineVariant,
      dividerHeight: 1,
      onTap: (index) => widget.onResultTypeSelected(_tabTypes[index]),
      tabs: [
        for (final resultType in _tabTypes) _buildTab(context, resultType),
      ],
    );
  }

  Tab _buildTab(BuildContext context, SearchResultType resultType) {
    final theme = Theme.of(context);
    final typography = context.typography;
    final isSelected = resultType == widget.selectedResultType;
    // Null while counts load: no badge.
    final count = widget.countByResultType[resultType];

    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            searchResultTypeLabel(resultType, AppLocalizations.of(context)),
            style: (isSelected
                    ? typography.tabLabelActive
                    : typography.tabLabelInactive)
                .copyWith(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (resultType != SearchResultType.topResults && count != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _CountBadge(count: count),
            ),
        ],
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
    final style = context.typography.countBadge;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      // An invisible "100+" keeps every badge at the widest width, so the
      // tabs don't slide sideways as counts change while typing.
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0, child: Text('100+', style: style)),
          Text(displayText, style: style),
        ],
      ),
    );
  }
}

/// Watches [referenceSearchResultProvider] and renders a pinned "jump to this
/// sutta" tile when the current query is a canonical reference (e.g. "SN 15.3");
/// otherwise nothing. Kept above the FTS results so a reference jump is always
/// the first thing offered.
class _ReferenceResultRow extends ConsumerWidget {
  final void Function(SearchResult result)? onResultTap;

  const _ReferenceResultRow({this.onResultTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(referenceSearchResultProvider);
    if (result == null) return const SizedBox.shrink();
    return _ReferenceResultTile(
      result: result,
      onTap: () => onResultTap?.call(result),
    );
  }
}

/// Distinct tile for a canonical-reference jump: a "SN 15.3" badge plus the
/// resolved sutta's name + path (re-derived from `nodeKey`, so it follows the
/// Content Language like every other result), and a jump affordance. Tapping
/// reuses the standard [onResultTap] open-in-tab path.
class _ReferenceResultTile extends ConsumerWidget {
  final SearchResult result;
  final VoidCallback? onTap;

  const _ReferenceResultTile({required this.result, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final typography = context.typography;
    final labels = searchResultLabels(ref, result);

    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.22),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            result.title, // the display reference, e.g. "SN 15.3"
            style: typography.badgeLabel
                .copyWith(color: theme.colorScheme.onPrimary),
          ),
        ),
        title: Text(
          labels.title,
          style: typography.resultTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: labels.path.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  labels.path,
                  style: typography.resultSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
        trailing: Icon(
          Icons.arrow_forward,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        onTap: onTap,
      ),
    );
  }
}
