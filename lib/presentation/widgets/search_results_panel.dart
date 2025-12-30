import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/search/grouped_search_result.dart';
import '../../domain/entities/search/search_result_type.dart';
import '../../domain/entities/search/search_result.dart';
import '../providers/search_provider.dart';
import '../../core/utils/singlish_transliterator.dart';
import '../../core/utils/text_utils.dart';
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
      elevation: 8,
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
                    searchState.queryText,
                  )
                : _buildResultTypeTabContent(
                    context,
                    ref,
                    theme,
                    searchState.fullResults,
                    searchState.selectedResultType,
                    searchState.queryText,
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
    String queryText,
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

    // Build categorized results with _SearchResultTile
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
                      // Results using _SearchResultTile
                      ...categorizedResults
                          .getResultsByType(resultType)
                          .map((result) => _SearchResultTile(
                                searchResult: result,
                                queryText: queryText,
                                onTap: () => onResultTap?.call(result),
                              )),
                    ],
                  )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Builds the content for specific category tabs (Title, Content, Definition)
  Widget _buildResultTypeTabContent(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    AsyncValue<List<SearchResult>?> fullResults,
    SearchResultType selectedResultType,
    String queryText,
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

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: results.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            indent: 72,
            color: theme.colorScheme.outlineVariant,
          ),
          itemBuilder: (context, index) {
            return _SearchResultTile(
              searchResult: results[index],
              queryText: queryText,
              onTap: () => onResultTap?.call(results[index]),
            );
          },
        );
      },
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
  final String queryText;
  final VoidCallback? onTap;

  const _SearchResultTile({
    required this.searchResult,
    required this.queryText,
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
            _buildHighlightedText(
              searchResult.matchedText,
              queryText,
              theme,
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }

  /// Builds highlighted text for content matches
  /// Uses effective query (original or Sinhala conversion) for proper highlighting
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

    // Sanitize query (strips invalid chars like @, #, etc.)
    final sanitizedQuery = sanitizeSearchQuery(query);
    if (sanitizedQuery == null || sanitizedQuery.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Get the effective query to use for highlighting (may be converted to Sinhala)
    final effectiveQuery = _getEffectiveHighlightQuery(text, sanitizedQuery);

    if (effectiveQuery.isEmpty) {
      // No match found, just show the beginning of text
      final end = 150.clamp(0, text.length);
      return Text(
        text.length > end ? '${text.substring(0, end)}...' : text,
        style: baseStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Create snippet centered around the match
    final snippet = _createSnippet(text: text, query: effectiveQuery);

    // Build highlighted spans
    final highlightStyle = TextStyle(
      backgroundColor: theme.colorScheme.primaryContainer,
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.onPrimaryContainer,
    );

    final spans = _buildHighlightedSpans(
      text: snippet,
      query: effectiveQuery,
      highlightStyle: highlightStyle,
    );

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Gets the effective query for highlighting.
  /// Converts Singlish to Sinhala if needed, then checks for match.
  String _getEffectiveHighlightQuery(String text, String query) {
    // Convert Singlish to Sinhala if needed, otherwise use as-is
    final transliterator = SinglishTransliterator.instance;
    final effectiveQuery = transliterator.isSinglishQuery(query)
        ? transliterator.convert(query)
        : query;

    // Check if the (possibly converted) query exists in text
    final normalizedText = normalizeText(text, toLowerCase: true);
    final normalizedQuery = normalizeText(effectiveQuery, toLowerCase: true);

    if (normalizedText.contains(normalizedQuery)) {
      return effectiveQuery;
    }

    // No match found
    return '';
  }

  /// Creates a snippet of text centered around the first match of the query
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

  /// Builds highlighted text spans for all matches of the query
  List<TextSpan> _buildHighlightedSpans({
    required String text,
    required String query,
    required TextStyle highlightStyle,
  }) {
    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: highlightStyle,
      ));

      start = index + query.length;
    }

    return spans;
  }
}
