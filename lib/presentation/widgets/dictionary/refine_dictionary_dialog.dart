import 'package:flutter/material.dart';

import '../../../core/localization/l10n/app_localizations.dart';
import '../../../domain/entities/dictionary/dictionary_filter_operations.dart';
import '../../../domain/entities/dictionary/dictionary_info.dart';

/// Dialog for refining dictionary search with individual dictionary selection.
///
/// Features:
/// - 2-level tree: language groups (Sinhala, English) → individual dictionaries
/// - Tristate group checkboxes (all/some/none children selected)
/// - Live updates as dictionaries are toggled via [onFilterChanged] callback
///
/// Callback-based design so it can be used in both:
/// - Search results panel (backed by SearchState)
/// - Dictionary bottom sheet (backed by its own provider)
///
/// Empty selectedDictionaryIds = "All" = all checkboxes checked.
class RefineDictionaryDialog extends StatefulWidget {
  /// Current selected dictionary IDs (empty = all).
  final Set<String> selectedIds;

  /// Called whenever the user toggles a dictionary or group.
  final ValueChanged<Set<String>> onFilterChanged;

  const RefineDictionaryDialog({
    super.key,
    required this.selectedIds,
    required this.onFilterChanged,
  });

  /// Show the dialog with the given filter state and callback.
  static Future<void> show(
    BuildContext context, {
    required Set<String> selectedIds,
    required ValueChanged<Set<String>> onFilterChanged,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => RefineDictionaryDialog(
        selectedIds: selectedIds,
        onFilterChanged: onFilterChanged,
      ),
    );
  }

  @override
  State<RefineDictionaryDialog> createState() => _RefineDictionaryDialogState();
}

class _RefineDictionaryDialogState extends State<RefineDictionaryDialog> {
  /// Local copy of the selected IDs so the dialog rebuilds on changes.
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.selectedIds;
  }

  @override
  void didUpdateWidget(covariant RefineDictionaryDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIds != widget.selectedIds) {
      _selectedIds = widget.selectedIds;
    }
  }

  /// Build language groups with localized labels.
  static List<_LanguageGroup> _buildLanguageGroups(AppLocalizations l10n) {
    return [
      _LanguageGroup(
        label: l10n.dictFilterSinhala,
        dictIds: DictionaryFilterOperations.sinhalaIds.toList(),
      ),
      _LanguageGroup(
        label: l10n.dictFilterEnglish,
        dictIds: DictionaryFilterOperations.englishIds.toList(),
      ),
    ];
  }

  /// Get the effective set for UI display.
  /// Empty set is treated as "all selected" — returns all dict IDs for checkbox logic.
  static Set<String> _effectiveSelection(Set<String> selectedIds) =>
      selectedIds.isEmpty ? DictionaryFilterOperations.allIds : selectedIds;

  void _resetToDefaults() {
    _commitSelection({});
  }

  /// Commit the selection. Normalizes (all → empty = "All") and notifies parent.
  void _commitSelection(Set<String> selection) {
    final normalized = DictionaryFilterOperations.normalize(selection);
    setState(() => _selectedIds = normalized);
    widget.onFilterChanged(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 600,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(theme, l10n),
              const SizedBox(height: 16),

              // Dictionary tree section
              Expanded(
                child: _buildDictionarySection(theme, l10n, _selectedIds),
              ),

              const SizedBox(height: 16),

              // Action buttons
              _buildActionButtons(theme, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, AppLocalizations l10n) {
    return Row(
      children: [
        Icon(
          Icons.tune,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          l10n.dictRefineTitle,
          style: theme.textTheme.titleLarge,
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: l10n.close,
        ),
      ],
    );
  }

  Widget _buildDictionarySection(
    ThemeData theme,
    AppLocalizations l10n,
    Set<String> selectedIds,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.dictRefineSectionLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            // Show Clear button only when a custom filter is active
            if (!DictionaryFilterOperations.isAllSelected(selectedIds))
              TextButton(
                onPressed: () => _commitSelection({}),
                child: Text(
                  l10n.clear,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SingleChildScrollView(
                child: Column(
                  children: _buildLanguageGroups(l10n)
                      .map((group) =>
                          _buildLanguageGroup(theme, group, selectedIds))
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageGroup(
    ThemeData theme,
    _LanguageGroup group,
    Set<String> selectedIds,
  ) {
    // Use effective selection: empty = all checked (matches scope refine pattern)
    final effective = _effectiveSelection(selectedIds);

    // Compute tristate: null = some selected, true = all, false = none
    final selectedCount =
        group.dictIds.where((id) => effective.contains(id)).length;
    final bool? checkboxValue;
    if (selectedCount == 0) {
      checkboxValue = false;
    } else if (selectedCount == group.dictIds.length) {
      checkboxValue = true;
    } else {
      checkboxValue = null; // partial
    }

    return Column(
      children: [
        // Group header row
        InkWell(
          onTap: () => _toggleGroup(group, selectedIds),
          child: Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Row(
              children: [
                // No expand/collapse icon needed — children always visible
                const SizedBox(width: 20),
                Checkbox(
                  value: checkboxValue,
                  tristate: true,
                  onChanged: (_) => _toggleGroup(group, selectedIds),
                ),
                Expanded(
                  child: Text(
                    group.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Individual dictionary rows
        ...group.dictIds.map((dictId) {
          final info = DictionaryInfo.getById(dictId);
          final isSelected = effective.contains(dictId);

          return InkWell(
            onTap: () => _toggleDictionary(dictId, selectedIds),
            child: Padding(
              padding: const EdgeInsets.only(left: 24, right: 8),
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleDictionary(dictId, selectedIds),
                  ),
                  Expanded(
                    child: Text(
                      info?.name ?? dictId,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _toggleGroup(_LanguageGroup group, Set<String> currentSelection) {
    // Special case: "All" selected — clicking a group focuses on just this group
    // (matches scope refine: empty scope + click node → only that node)
    if (currentSelection.isEmpty) {
      _commitSelection(group.dictIds.toSet());
      return;
    }

    final groupIds = group.dictIds.toSet();
    final allSelected = groupIds.every(currentSelection.contains);

    Set<String> newSelection;
    if (allSelected) {
      // Deselect all in this group
      newSelection = {...currentSelection}..removeAll(groupIds);
    } else {
      // Select all in this group
      newSelection = {...currentSelection}..addAll(groupIds);
    }

    _commitSelection(newSelection);
  }

  void _toggleDictionary(String dictId, Set<String> currentSelection) {
    // Special case: "All" selected — clicking a dictionary focuses on just that one
    // (matches scope refine: empty scope + click node → only that node)
    if (currentSelection.isEmpty) {
      _commitSelection({dictId});
      return;
    }

    final newSelection = {...currentSelection};
    if (newSelection.contains(dictId)) {
      // Check if this dict's entire group is selected — if so, narrow to just
      // this dict instead of deselecting it (matches search refine behavior
      // where clicking a child of a fully-selected parent narrows down).
      final parentGroup = _findParentGroup(dictId);
      if (parentGroup != null &&
          parentGroup.every(currentSelection.contains)) {
        _commitSelection({dictId});
        return;
      }
      newSelection.remove(dictId);
    } else {
      newSelection.add(dictId);
    }

    _commitSelection(newSelection);
  }

  /// Find the group (language) that contains [dictId], or null if not found.
  static Set<String>? _findParentGroup(String dictId) {
    for (final group in DictionaryFilterOperations.chipKeyGroups) {
      if (group.contains(dictId)) return group;
    }
    return null;
  }

  Widget _buildActionButtons(ThemeData theme, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _resetToDefaults,
          child: Text(l10n.reset),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.done),
        ),
      ],
    );
  }
}

/// Represents a language group in the dictionary tree.
class _LanguageGroup {
  final String label;
  final List<String> dictIds;

  const _LanguageGroup({required this.label, required this.dictIds});
}
