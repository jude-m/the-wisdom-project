import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_typography.dart';
import '../../providers/search_provider.dart';
import '../../../domain/entities/search/recent_search.dart';

/// Simplified overlay that only shows recent searches
/// Displayed when search bar is focused with empty or short query
class RecentSearchOverlay extends ConsumerWidget {
  /// Callback when the overlay should be dismissed
  final VoidCallback onDismiss;

  /// Width of the dropdown
  final double width;

  const RecentSearchOverlay({
    super.key,
    required this.onDismiss,
    this.width = 350,
  });

  /// Calculate max height based on screen size.
  double _calculateMaxHeight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    const mobileBreakpoint = 600.0;

    if (screenWidth < mobileBreakpoint) {
      return screenHeight - topPadding - bottomPadding - 100;
    } else {
      return screenHeight * 0.66;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchStateProvider);
    final theme = Theme.of(context);

    final hasRecentSearches = searchState.recentSearches.isNotEmpty;

    if (!hasRecentSearches) {
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
              child: _buildRecentSearches(
                context,
                ref,
                searchState.recentSearches,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSearches(
    BuildContext context,
    WidgetRef ref,
    List<RecentSearch> recentSearches,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, ref, 'RECENT SEARCHES'),
        ...recentSearches.map((search) => ListTile(
              dense: true,
              leading: Icon(
                Icons.history,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(search.queryText, style: theme.textTheme.bodyMedium),
              trailing: GestureDetector(
                onTap: () {
                  ref
                      .read(searchStateProvider.notifier)
                      .removeRecentSearch(search.queryText);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              onTap: () {
                // Dismiss overlay first
                onDismiss();
                // Then trigger search with this query
                ref
                    .read(searchStateProvider.notifier)
                    .selectRecentSearch(search.queryText);
              },
            )),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, WidgetRef ref, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: context.typography.sectionHeader,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () {
                ref.read(searchStateProvider.notifier).clearRecentSearches();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Clear All',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
