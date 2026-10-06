import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/l10n/app_localizations.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../providers/search_provider.dart';
import '../../providers/singlish_preview_provider.dart';
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
  ///
  /// Mobile: fill the available height (minus safe-area insets and a small
  /// gap for the search bar above). Tablet/desktop: cap at 66% so the
  /// overlay doesn't dominate the viewport.
  double _calculateMaxHeight(BuildContext context) {
    // Safe-area insets (status bar, home indicator) — not a responsive
    // decision, so MediaQuery is still the right source here.
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;
    final screenHeight = ResponsiveUtils.screenHeight(context);

    if (ResponsiveUtils.isMobile(context)) {
      return screenHeight - topPadding - bottomPadding - 100;
    } else {
      return screenHeight * 0.66;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only the list, so unrelated search-state changes don't rebuild the rows.
    final recentSearches =
        ref.watch(searchStateProvider.select((s) => s.recentSearches));
    final theme = Theme.of(context);

    if (recentSearches.isEmpty) {
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
              child: _buildRecentSearches(context, ref, recentSearches),
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
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, ref, l10n.recentSearches.toUpperCase()),
        ...recentSearches.map((search) {
          final queryText = search.queryText;
          // Singlish rows show the Sinhala first, the typed text underneath.
          // Sinhala and references ("SN 15.3") stay as typed.
          final sinhala = ref.watch(singlishPreviewProvider(queryText));

          return ListTile(
            dense: true,
            leading: Icon(
              Icons.history,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(
              sinhala ?? queryText,
              style: context.typography.listRowTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: sinhala == null
                ? null
                : Text(
                    queryText,
                    style: context.typography.resultSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: theme.colorScheme.onSurfaceVariant,
              visualDensity: VisualDensity.compact,
              tooltip: l10n.removeRecentSearch,
              onPressed: () {
                ref
                    .read(searchStateProvider.notifier)
                    .removeRecentSearch(queryText);
              },
            ),
            onTap: () {
              // Dismiss overlay first
              onDismiss();
              // Then trigger search with this query
              ref
                  .read(searchStateProvider.notifier)
                  .selectRecentSearch(queryText);
            },
          );
        }),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, WidgetRef ref, String title) {
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
          _ClearAllButton(
            onTap: () {
              ref.read(searchStateProvider.notifier).clearRecentSearches();
            },
          ),
        ],
      ),
    );
  }
}

/// "Clear All" action in the recent-searches header.
///
/// Idle: muted `linkLabel` color (onSurfaceVariant) — reads as quiet helper text.
/// Hover: pill-shaped highlight + label recolored to `primary` so it reads
/// as an actionable affordance.
class _ClearAllButton extends StatefulWidget {
  final VoidCallback onTap;

  const _ClearAllButton({required this.onTap});

  @override
  State<_ClearAllButton> createState() => _ClearAllButtonState();
}

class _ClearAllButtonState extends State<_ClearAllButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = context.typography.linkLabel;
    // Large radius makes the InkWell's hover overlay + splash clip to a
    // stadium (pill) shape instead of the default rectangle.
    final pillRadius = BorderRadius.circular(100);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: pillRadius,
        onHover: (h) => setState(() => _hovered = h),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            AppLocalizations.of(context).clearAll,
            style: _hovered
                ? baseStyle.copyWith(color: theme.colorScheme.primary)
                : baseStyle,
          ),
        ),
      ),
    );
  }
}
