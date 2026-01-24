import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/l10n/app_localizations.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/entities/search/scope_operations.dart';
import '../../../domain/entities/search/search_scope_chip.dart';
import '../../providers/search_provider.dart';
import 'refine_search_dialog.dart';

/// Horizontally scrollable scope filter chips for search results.
///
/// Implements Pattern 2: "All" as default anchor with multi-select support.
///
/// Behavior:
/// - Default: "All" is selected (empty selectedScopes)
/// - Tap specific scope: deselects "All", selects that scope
/// - Tap another scope: adds to selection (multi-select)
/// - Tap selected scope: deselects it
/// - Tap "All": clears all specific selections
/// - All 5 scopes selected: auto-collapses to "All"
class ScopeFilterChips extends ConsumerStatefulWidget {
  const ScopeFilterChips({super.key});

  @override
  ConsumerState<ScopeFilterChips> createState() => _ScopeFilterChipsState();
}

class _ScopeFilterChipsState extends ConsumerState<ScopeFilterChips> {
  // Create controller once in state, not in build
  final _scrollController = ScrollController();

  @override
  void dispose() {
    // Clean up the controller when the widget is removed
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchStateProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Check if scope contains custom selections (not covered by predefined chips)
    // This is true only when the refine dialog was used to select sub-nodes
    final hasCustomScope =
        ScopeOperations.hasCustomSelections(searchState.scope);
    final isAllSelected = searchState.isAllSelected;

    return SizedBox(
      height: 48,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
          scrollbars: false,
        ),
        child: ListView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: [
            // "All" chip - always first
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _ScopeChip(
                label: l10n.scopeAll,
                isSelected: isAllSelected,
                theme: theme,
                onTap: () => ref.read(searchStateProvider.notifier).selectAll(),
              ),
            ),

            // Scope chips from predefined list
            ...searchScopeChips.map((chip) {
              // Use ScopeOperations to check if chip is selected
              final isSelected = ScopeOperations.containsAllKeys(
                searchState.scope,
                chip.nodeKeys,
              );
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _ScopeChip(
                  label: chip.label(context),
                  isSelected: isSelected,
                  theme: theme,
                  // Use toggleScopeKeys with extracted nodeKeys
                  onTap: () => ref
                      .read(searchStateProvider.notifier)
                      .toggleScopeKeys(chip.nodeKeys),
                ),
              );
            }),

            // Refine chip - opens advanced search dialog
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _RefineChip(
                hasActiveFilters: hasCustomScope,
                theme: theme,
                onTap: () => RefineSearchDialog.show(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom pill-shaped chip with uniform sizing for scope filters.
class _ScopeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ThemeData theme;
  final VoidCallback onTap;

  const _ScopeChip({
    required this.label,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 56),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: isSelected
              ? theme.colorScheme.secondaryContainer
              : theme.colorScheme.surfaceContainerHigh,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.secondaryContainer
                : theme.colorScheme.outline.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: isSelected
                ? typography.chipLabelSelected
                : typography.chipLabel,
          ),
        ),
      ),
    );
  }
}

/// Refine chip with tune icon - opens advanced search dialog.
/// Shows an active indicator dot when advanced filters are applied.
class _RefineChip extends StatelessWidget {
  final bool hasActiveFilters;
  final ThemeData theme;
  final VoidCallback onTap;

  const _RefineChip({
    required this.hasActiveFilters,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 56),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          // Outline style to distinguish from scope chips
          color: hasActiveFilters
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          border: Border.all(
            color: hasActiveFilters
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune,
              size: 16,
              color: hasActiveFilters
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              'Refine',
              style: hasActiveFilters
                  ? typography.chipLabelSelected.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    )
                  : typography.chipLabel,
            ),
            // Active indicator dot
            if (hasActiveFilters) ...[
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
