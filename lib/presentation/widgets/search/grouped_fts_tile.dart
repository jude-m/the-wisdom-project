import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../domain/entities/search/grouped_fts_match.dart';
import '../../../domain/entities/search/search_result.dart';
import '../../../domain/entities/search/search_result_type.dart';
import '../../providers/search_provider.dart';
import 'highlighted_search_text.dart';
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
    this.onPrimaryTap,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final searchState = ref.watch(searchStateProvider);
    final isExpanded = searchState.expandedFTSGroups.contains(group.nodeKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary result tile (looks like standard _SearchResultTile)
        _buildPrimaryTile(context, theme),

        // "See X more" / "Collapse" link (only if there are secondary matches)
        if (group.hasSecondaryMatches)
          _buildExpandCollapseLink(context, ref, theme, isExpanded),

        // Secondary matches (shown when expanded)
        if (isExpanded && group.hasSecondaryMatches)
          _buildSecondaryMatches(context, theme),
      ],
    );
  }

  /// Builds the primary result tile (identical to _SearchResultTile appearance)
  Widget _buildPrimaryTile(BuildContext context, ThemeData theme) {
    final result = group.primaryMatch;
    final typography = context.typography;

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
            result.editionId.toUpperCase(),
            style: typography.badgeLabel,
          ),
        ),
      ),
      title: Text(
        result.title,
        style: typography.resultTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            result.subtitle,
            style: typography.resultSubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Show highlighted text for fullText results
          if (result.resultType == SearchResultType.fullText &&
              result.matchedText.isNotEmpty) ...[
            const SizedBox(height: 4),
            HighlightedSearchText(
              matchedText: result.matchedText,
              effectiveQuery: effectiveQuery,
              isPhraseSearch: isPhraseSearch,
              isExactMatch: isExactMatch,
            ),
          ],
        ],
      ),
      onTap: () => onPrimaryTap?.call(result),
    );
  }

  /// Builds the subtle "See X more" / "Collapse" link
  Widget _buildExpandCollapseLink(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    bool isExpanded,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 72, bottom: 8),
      child: GestureDetector(
        onTap: () {
          ref
              .read(searchStateProvider.notifier)
              .toggleFTSGroupExpansion(group.nodeKey);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isExpanded
                  ? 'Show Less'
                  : 'View ${group.secondaryMatchCount} more',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the container with secondary matches
  Widget _buildSecondaryMatches(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
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
