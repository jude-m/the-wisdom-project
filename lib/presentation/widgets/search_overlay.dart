import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/text_utils.dart';
import '../providers/search_provider.dart';
import '../providers/search_state.dart';
import '../../domain/entities/search/recent_search.dart';
import '../../domain/entities/search/search_result.dart';
import '../../domain/entities/search/search_category.dart';

/// Search overlay dropdown content (without barrier)
/// Displays recent searches or preview results based on search state
class SearchOverlayContent extends ConsumerWidget {
  /// Callback when a search result is tapped
  final void Function(SearchResult result)? onResultTap;

  /// Callback when the overlay should be dismissed
  final VoidCallback onDismiss;

  /// Width of the dropdown
  final double width;

  const SearchOverlayContent({
    super.key,
    this.onResultTap,
    required this.onDismiss,
    this.width = 350,
  });

  /// Calculate max height based on screen size.
  /// - Mobile (width < 600): full screen height minus safe areas
  /// - Larger screens: 66% of screen height
  double _calculateMaxHeight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    // Mobile breakpoint
    const mobileBreakpoint = 600.0;

    if (screenWidth < mobileBreakpoint) {
      // Mobile: use available height (minus safe areas and some margin)
      return screenHeight - topPadding - bottomPadding - 100;
    } else {
      // Larger screens: 66% of screen height
      return screenHeight * 0.66;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchStateProvider);
    final theme = Theme.of(context);

    final hasRecentSearches = searchState.recentSearches.isNotEmpty;
    final hasPreviewResults = searchState.previewResults?.isNotEmpty ?? false;
    final isLoading = searchState.isPreviewLoading;
    final isQueryValid = searchState.queryText.length >= 2;
    // Show overlay if:
    // 1. We have content (recent searches or preview results)
    // 2. We are loading
    // 3. We have a valid query that yielded no results (to show "No results found")
    final hasContent = hasRecentSearches ||
        hasPreviewResults ||
        isLoading ||
        (isQueryValid && !isLoading);

    if (!hasContent) {
      return const SizedBox.shrink();
    }

    final maxHeight = _calculateMaxHeight(context);

    return SizedBox(
      width: width,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainer,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isLoading)
                    _buildLoading()
                  else if (hasPreviewResults || (isQueryValid && !isLoading))
                    _buildPreviewResults(context, ref, searchState)
                  else if (hasRecentSearches && searchState.queryText.isEmpty)
                    _buildRecentSearches(
                        context, ref, searchState.recentSearches),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildRecentSearches(
      BuildContext context, WidgetRef ref, List<RecentSearch> recentSearches) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, 'RECENT SEARCHES'),
        ...recentSearches.map((search) => ListTile(
              dense: true,
              leading: Icon(Icons.history,
                  size: 20, color: theme.colorScheme.onSurfaceVariant),
              title: Text(search.queryText, style: theme.textTheme.bodyMedium),
              trailing: IconButton(
                icon: Icon(Icons.close,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
                onPressed: () {
                  ref
                      .read(searchStateProvider.notifier)
                      .removeRecentSearch(search.queryText);
                },
                tooltip: 'Remove',
              ),
              onTap: () {
                ref
                    .read(searchStateProvider.notifier)
                    .selectRecentSearch(search.queryText);
              },
            )),
      ],
    );
  }

  Widget _buildPreviewResults(
      BuildContext context, WidgetRef ref, SearchState searchState) {
    final theme = Theme.of(context);
    final previewResults = searchState.previewResults;

    if (previewResults == null || previewResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No results found',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...previewResults.categoriesWithResults
            .where((category) => category != SearchCategory.definition)
            .map((category) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(theme, category.displayName.toUpperCase()),
                    ...previewResults
                        .getResultsForCategory(category)
                        .map((result) => ListTile(
                              dense: true,
                              minVerticalPadding: 8,
                              leading: Icon(_categoryIcon(category),
                                  size: 20,
                                  color: theme.colorScheme.onSurfaceVariant),
                              title: Text(
                                result.title,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    result.subtitle,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // Only show matched text snippet for CONTENT results
                                  if (category == SearchCategory.content &&
                                      result.matchedText.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: _buildHighlightedText(
                                        result.matchedText,
                                        searchState.queryText,
                                        theme,
                                      ),
                                    ),
                                ],
                              ),
                              onTap: () {
                                onDismiss();
                                onResultTap?.call(result);
                              },
                            )),
                  ],
                )),
      ],
    );
  }

  /// Creates a snippet of text centered around the first match of the query.
  /// Returns the snippet with "..." indicators if text was truncated.
  String _createSnippet({
    required String text,
    required String query,
    int contextBefore = 50,
    int contextAfter = 100,
  }) {
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerQuery);

    if (matchIndex == -1) {
      // No match, return beginning of text
      final end = (contextBefore + contextAfter).clamp(0, text.length);
      return text.length > end ? '${text.substring(0, end)}...' : text;
    }

    final snippetStart = (matchIndex - contextBefore).clamp(0, text.length);
    final snippetEnd =
        (matchIndex + query.length + contextAfter).clamp(0, text.length);

    var snippet = text.substring(snippetStart, snippetEnd);

    // Add ellipsis indicators
    if (snippetStart > 0) {
      snippet = '...$snippet';
    }
    if (snippetEnd < text.length) {
      snippet = '$snippet...';
    }

    return snippet;
  }

  /// Builds highlighted text spans for all matches of the query in the snippet.
  List<TextSpan> _buildHighlightedSpans({
    required String snippet,
    required String query,
    required TextStyle highlightStyle,
  }) {
    final spans = <TextSpan>[];
    final lowerSnippet = snippet.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;

    while (true) {
      final index = lowerSnippet.indexOf(lowerQuery, start);
      if (index == -1) {
        if (start < snippet.length) {
          spans.add(TextSpan(text: snippet.substring(start)));
        }
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: snippet.substring(start, index)));
      }

      spans.add(TextSpan(
        text: snippet.substring(index, index + query.length),
        style: highlightStyle,
      ));

      start = index + query.length;
    }

    return spans;
  }

  Widget _buildHighlightedText(String text, String query, ThemeData theme) {
    final baseStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    if (query.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final normalizedQuery = normalizeQueryText(query);

    if (normalizedQuery.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final snippet = _createSnippet(text: text, query: normalizedQuery);
    final highlightStyle = TextStyle(
      backgroundColor: theme.colorScheme.primaryContainer,
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.onPrimaryContainer,
    );

    final spans = _buildHighlightedSpans(
      snippet: snippet,
      query: normalizedQuery,
      highlightStyle: highlightStyle,
    );

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

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

  IconData _categoryIcon(SearchCategory category) {
    switch (category) {
      case SearchCategory.title:
        return Icons.title;
      case SearchCategory.content:
        return Icons.article_outlined;
      case SearchCategory.definition:
        return Icons.menu_book_outlined;
    }
  }
}
