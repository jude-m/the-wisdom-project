import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n/app_localizations.dart';
import '../../../domain/entities/search/grouped_fts_match.dart';
import '../../../domain/entities/search/search_result.dart';
import '../../providers/search_provider.dart';
import 'result_badge.dart';
import 'search_link_button.dart';
import 'search_result_tile.dart';
import 'secondary_match_tile.dart';

/// A search result tile that groups multiple FTS matches from the same text.
///
/// Displays the primary match like a normal search result tile, with an optional
/// "See X more" link that expands to reveal secondary matches from the same text.
///
/// The main tile is fully clickable for navigation - only the expand/collapse
/// link triggers the expansion behavior.
class GroupedFTSTile extends ConsumerWidget {
  /// The grouped FTS match to display
  final GroupedFTSMatch group;

  /// Pre-computed effective query for highlighting
  final String effectiveQuery;

  /// Whether phrase search mode is active
  final bool isPhraseSearch;

  /// Whether exact match mode is active
  final bool isExactMatch;

  /// Off when every row in the list is from one edition.
  final bool showEditionBadge;

  /// Callback when the primary result is tapped (navigates to first match)
  final void Function(SearchResult result)? onPrimaryTap;

  /// Callback when a secondary result is tapped (navigates to that specific match)
  final void Function(SearchResult result)? onSecondaryTap;

  const GroupedFTSTile({
    super.key,
    required this.group,
    required this.effectiveQuery,
    required this.isPhraseSearch,
    required this.isExactMatch,
    required this.showEditionBadge,
    this.onPrimaryTap,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Only this group's flag. The panel still rebuilds every tile: see item 5
    // in docs/todo/perf-top10-killers.md.
    final isExpanded = ref.watch(searchStateProvider
        .select((s) => s.expandedFTSGroups.contains(group.nodeKey)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchResultTile(
          searchResult: group.primaryMatch,
          effectiveQuery: effectiveQuery,
          isPhraseSearch: isPhraseSearch,
          isExactMatch: isExactMatch,
          showEditionBadge: showEditionBadge,
          onTap: () => onPrimaryTap?.call(group.primaryMatch),
        ),

        // "See X more" / "Collapse" link (only if there are secondary matches)
        if (group.hasSecondaryMatches)
          _buildExpandCollapseLink(context, ref, isExpanded),

        // Secondary matches (shown when expanded)
        if (isExpanded && group.hasSecondaryMatches)
          _buildSecondaryMatches(context, theme),
      ],
    );
  }

  /// Builds the "View X more" / "Show less" button
  Widget _buildExpandCollapseLink(
    BuildContext context,
    WidgetRef ref,
    bool isExpanded,
  ) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      // Lines the button's label up with the tile text.
      padding: EdgeInsets.only(
        left:
            ResultBadge.textStart(showEditionBadge) - SearchLinkButton.padding,
        bottom: 4,
      ),
      child: SearchLinkButton(
        onPressed: () => ref
            .read(searchStateProvider.notifier)
            .toggleFTSGroupExpansion(group.nodeKey),
        icon: isExpanded ? Icons.expand_less : Icons.expand_more,
        label: isExpanded
            ? l10n.showLess
            : l10n.viewMore(group.secondaryMatchCount),
      ),
    );
  }

  /// Builds the container with secondary matches
  Widget _buildSecondaryMatches(BuildContext context, ThemeData theme) {
    return Container(
      // Starts where the badge ends, or at the text when there is no badge.
      margin: EdgeInsets.only(
        left: showEditionBadge ? ResultBadge.end : ResultBadge.rowPadding,
        right: 16,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 3,
          ),
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < group.secondaryMatches.length; i++) ...[
            SecondaryMatchTile(
              result: group.secondaryMatches[i],
              effectiveQuery: effectiveQuery,
              isPhraseSearch: isPhraseSearch,
              isExactMatch: isExactMatch,
              onTap: () => onSecondaryTap?.call(group.secondaryMatches[i]),
            ),
            // Divider between secondary matches (not after the last one)
            if (i < group.secondaryMatches.length - 1)
              Divider(
                height: 1,
                indent: 12,
                endIndent: 12,
                color: theme.colorScheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}
