import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchStateProvider);
    final theme = Theme.of(context);

    final hasRecentSearches = searchState.recentSearches.isNotEmpty;
    final hasPreviewResults = searchState.previewResults?.isNotEmpty ?? false;
    final isLoading = searchState.isPreviewLoading;
    final hasContent = hasRecentSearches || hasPreviewResults || isLoading;

    if (!hasContent) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: width,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainer,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isLoading)
                    _buildLoading()
                  else if (hasPreviewResults)
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
        ...previewResults.categoriesWithResults.map((category) => Column(
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
                          subtitle: Text(
                            result.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            ref
                                .read(searchStateProvider.notifier)
                                .clearSearch();
                            onDismiss();
                            onResultTap?.call(result);
                          },
                        )),
              ],
            )),
      ],
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
