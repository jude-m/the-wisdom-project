import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../domain/entities/search/search_result.dart';
import '../../../domain/entities/search/search_result_type.dart';
import '../../utils/search_result_labels.dart';
import 'highlighted_fts_search_text.dart';
import 'result_badge.dart';

/// Individual search result tile with highlighting support. Also the primary
/// row of a `GroupedFTSTile`.
class SearchResultTile extends ConsumerWidget {
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

  /// Off when every row in the list is from one edition.
  final bool showEditionBadge;

  final VoidCallback? onTap;

  const SearchResultTile({
    super.key,
    required this.searchResult,
    required this.effectiveQuery,
    required this.isPhraseSearch,
    required this.isExactMatch,
    required this.showEditionBadge,
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
      contentPadding: const EdgeInsets.symmetric(
          horizontal: ResultBadge.rowPadding, vertical: 8),
      leading: showEditionBadge
          ? ResultBadge(
              label: searchResult.editionId.toUpperCase(),
              backgroundColor:
                  theme.colorScheme.tertiary.withValues(alpha: 0.3),
            )
          : null,
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
