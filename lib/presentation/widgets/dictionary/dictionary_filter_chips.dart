import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/l10n/app_localizations.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/entities/dictionary/dictionary_filter_operations.dart';

/// Horizontally scrollable dictionary filter chips.
///
/// Displays: All | Sinhala | English | Refine
///
/// Uses [DictionaryFilterOperations] to derive chip states from
/// [selectedDictionaryIds], following the same single-source-of-truth
/// pattern as [ScopeFilterChips].
///
/// Reusable across search results panel and dictionary bottom sheet.
/// Uses callbacks so it is not coupled to any specific provider.
class DictionaryFilterChips extends StatefulWidget {
  final Set<String> selectedDictionaryIds;
  final ValueChanged<Set<String>> onToggleKeys;
  final VoidCallback onSelectAll;
  final VoidCallback onRefineTap;

  const DictionaryFilterChips({
    super.key,
    required this.selectedDictionaryIds,
    required this.onToggleKeys,
    required this.onSelectAll,
    required this.onRefineTap,
  });

  @override
  State<DictionaryFilterChips> createState() => _DictionaryFilterChipsState();
}

class _DictionaryFilterChipsState extends State<DictionaryFilterChips> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ids = widget.selectedDictionaryIds;

    // Derive chip states from the single source of truth
    final isAllSelected = DictionaryFilterOperations.isAllSelected(ids);
    final isSinhalaSelected = DictionaryFilterOperations.containsAllKeys(
      ids,
      DictionaryFilterOperations.sinhalaIds,
    );
    final isEnglishSelected = DictionaryFilterOperations.containsAllKeys(
      ids,
      DictionaryFilterOperations.englishIds,
    );
    final hasCustomScope =
        DictionaryFilterOperations.hasCustomSelections(ids);

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
            // "All" chip
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _FilterChip(
                label: l10n.dictFilterAll,
                isSelected: isAllSelected,
                theme: theme,
                onTap: widget.onSelectAll,
              ),
            ),

            // "Sinhala" chip
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _FilterChip(
                label: l10n.dictFilterSinhala,
                isSelected: isSinhalaSelected,
                theme: theme,
                onTap: () => widget.onToggleKeys(
                  DictionaryFilterOperations.sinhalaIds,
                ),
              ),
            ),

            // "English" chip
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _FilterChip(
                label: l10n.dictFilterEnglish,
                isSelected: isEnglishSelected,
                theme: theme,
                onTap: () => widget.onToggleKeys(
                  DictionaryFilterOperations.englishIds,
                ),
              ),
            ),

            // "Refine" chip - opens dictionary selection dialog
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _RefineChip(
                hasActiveFilters: hasCustomScope,
                theme: theme,
                onTap: widget.onRefineTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill-shaped filter chip matching scope_filter_chips.dart styling.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ThemeData theme;
  final VoidCallback onTap;

  const _FilterChip({
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
              ? theme.colorScheme.secondary
              : theme.colorScheme.surfaceContainer,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.secondary
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

/// Refine chip with tune icon - opens dictionary selection dialog.
/// Shows an active indicator when custom dictionary selections are applied.
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
          color: hasActiveFilters
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHigh,
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
              AppLocalizations.of(context).refine,
              style: hasActiveFilters
                  ? typography.chipLabelSelected.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    )
                  : typography.chipLabel,
            ),
          ],
        ),
      ),
    );
  }
}
