import 'package:flutter/material.dart';

import '../../../core/localization/l10n/app_localizations.dart';
import '../../../domain/entities/dictionary/dictionary_filter_operations.dart';
import '../common/pill_chip.dart';
import '../common/pill_chip_row.dart';

/// Horizontally scrollable dictionary filter chips.
///
/// Displays: All | Sinhala | English | Refine
///
/// Uses [DictionaryFilterOperations] to derive chip states from
/// [selectedDictionaryIds], following the same single-source-of-truth
/// pattern as [ScopeFilterChips].
///
/// Uses callbacks so it is not coupled to any specific provider.
class DictionaryFilterChips extends StatelessWidget {
  final Set<String> selectedDictionaryIds;
  final ValueChanged<Set<String>> onToggleKeys;
  final VoidCallback onSelectAll;
  final VoidCallback onRefineTap;

  /// Widgets before the chips, scrolling with them.
  final List<Widget> leading;

  const DictionaryFilterChips({
    super.key,
    required this.selectedDictionaryIds,
    required this.onToggleKeys,
    required this.onSelectAll,
    required this.onRefineTap,
    this.leading = const [],
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ids = selectedDictionaryIds;

    return PillChipRow(
      children: [
        ...leading,
        PillChip(
          label: l10n.dictFilterAll,
          selected: DictionaryFilterOperations.isAllSelected(ids),
          onPressed: onSelectAll,
        ),
        PillChip(
          label: l10n.dictFilterSinhala,
          selected: DictionaryFilterOperations.containsAllKeys(
            ids,
            DictionaryFilterOperations.sinhalaIds,
          ),
          onPressed: () => onToggleKeys(DictionaryFilterOperations.sinhalaIds),
        ),
        PillChip(
          label: l10n.dictFilterEnglish,
          selected: DictionaryFilterOperations.containsAllKeys(
            ids,
            DictionaryFilterOperations.englishIds,
          ),
          onPressed: () => onToggleKeys(DictionaryFilterOperations.englishIds),
        ),
        // Opens the dictionary selection dialog
        PillChip.refine(
          label: l10n.refine,
          selected: DictionaryFilterOperations.hasCustomSelections(ids),
          onPressed: onRefineTap,
        ),
      ],
    );
  }
}
