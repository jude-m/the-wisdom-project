import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/l10n/app_localizations.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../providers/search_provider.dart';
import '../../../domain/entities/search/recent_search.dart';

/// Simplified overlay that only shows recent searches
/// Displayed when search bar is focused with an empty query
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
  /// Mobile: fill the available height (minus safe-area insets, the keyboard
  /// and a small gap for the search bar above). Tablet/desktop: also cap at
  /// 66% so the overlay doesn't dominate the viewport.
  double _calculateMaxHeight(BuildContext context) {
    // Safe-area insets (status bar, home indicator) and the keyboard — not a
    // responsive decision, so MediaQuery is still the right source here.
    final padding = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = ResponsiveUtils.screenHeight(context);

    final available =
        screenHeight - padding.top - padding.bottom - keyboard - 100;
    final maxHeight = ResponsiveUtils.isMobile(context)
        ? available
        : math.min(available, screenHeight * 0.66);
    // A negative max height would fail BoxConstraints' assert.
    return math.max(0, maxHeight);
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
    // Below desktop width: edge to edge under the app bar, so square corners.
    final borderRadius =
        BorderRadius.circular(ResponsiveUtils.isDesktop(context) ? 12 : 0);

    return SizedBox(
      width: width,
      child: Material(
        elevation: 8,
        borderRadius: borderRadius,
        color: theme.colorScheme.surfaceContainer,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ClipRRect(
            borderRadius: borderRadius,
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
          // Singlish searches are saved as their Sinhala
          // (saveRecentSearchAndDismiss), so the saved text is what we show.
          final queryText = search.queryText;

          return ListTile(
            dense: true,
            leading: Icon(
              Icons.history,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(
              queryText,
              style: context.typography.listRowTitle,
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
