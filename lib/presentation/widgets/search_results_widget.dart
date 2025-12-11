import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/search/search_result.dart';
import '../../domain/entities/reader_tab.dart';
import '../providers/search_provider.dart';
import '../providers/tab_provider.dart';
import '../providers/document_provider.dart';

/// Displays search results with loading, empty, and error states
class SearchResultsWidget extends ConsumerWidget {
  const SearchResultsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(
      searchStateProvider.select((s) => s.fullResults),
    );

    return resultsAsync.when(
      data: (results) {
        if (results.isEmpty) {
          return _EmptyState();
        }
        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: results.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            return SearchResultItem(result: results[index]);
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => _ErrorState(error: error),
    );
  }
}

/// Empty state when no results found
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
          ),
        ],
      ),
    );
  }
}

/// Error state when search fails
class _ErrorState extends StatelessWidget {
  final Object error;

  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Search failed',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Single search result item
class SearchResultItem extends ConsumerWidget {
  final SearchResult result;

  const SearchResultItem({super.key, required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: _EditionBadge(editionId: result.editionId),
      title: Text(
        result.title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            result.subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          if (result.matchedText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              result.matchedText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
      onTap: () => _navigateToResult(context, ref),
    );
  }

  void _navigateToResult(BuildContext context, WidgetRef ref) {
    // Create a new tab for the search result
    final newTab = ReaderTab.fromNode(
      nodeKey: result.nodeKey,
      paliName: result.title,
      sinhalaName: result.title,
      contentFileId: result.contentFileId,
      pageIndex: result.pageIndex,
    );

    // Add tab and make it active
    final newIndex = ref.read(tabsProvider.notifier).addTab(newTab);
    ref.read(activeTabIndexProvider.notifier).state = newIndex;

    // Set the content file
    ref.read(currentContentFileIdProvider.notifier).state =
        result.contentFileId;
    ref.read(currentPageIndexProvider.notifier).state = result.pageIndex;

    // If it's a content search (not just name), we want to scroll to the entry
    // TODO: Implement scrolling to specific entry index
    // For now, opening at the correct page is sufficient

    // Close search on mobile
    if (MediaQuery.of(context).size.width < 1024) {
      Navigator.of(context).pop();
    }
  }
}

/// Edition badge indicator
class _EditionBadge extends StatelessWidget {
  final String editionId;

  const _EditionBadge({required this.editionId});

  @override
  Widget build(BuildContext context) {
    final color = _getEditionColor(editionId);
    final label = editionId.toUpperCase();

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getEditionColor(String editionId) {
    switch (editionId.toLowerCase()) {
      case 'bjt':
        return Colors.blue;
      case 'sc':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
