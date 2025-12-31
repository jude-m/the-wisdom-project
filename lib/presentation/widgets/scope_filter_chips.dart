import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/search/search_scope.dart';
import '../providers/search_provider.dart';

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
    final selectedScope = ref.watch(
      searchStateProvider.select((s) => s.selectedScope),
    );
    final isAllSelected = selectedScope.isEmpty;
    final theme = Theme.of(context);

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
                label: 'All',
                isSelected: isAllSelected,
                theme: theme,
                onTap: () => ref.read(searchStateProvider.notifier).selectAll(),
              ),
            ),

            // Scope chips
            ...SearchScope.values.map((scope) {
              final isSelected = selectedScope.contains(scope);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _ScopeChip(
                  label: scope.displayName,
                  isSelected: isSelected,
                  theme: theme,
                  onTap: () =>
                      ref.read(searchStateProvider.notifier).toggleScope(scope),
                ),
              );
            }),
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
            style: theme.textTheme.labelSmall?.copyWith(
              color: isSelected
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
