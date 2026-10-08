import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/l10n/app_localizations.dart';
import '../../../domain/entities/search/scope_operations.dart';
import '../../../domain/entities/search/search_scope_chip.dart';
import '../../providers/content_language_provider.dart';
import '../../providers/search_provider.dart';
import '../../utils/scope_chip_labels.dart';
import '../common/pill_chip.dart';
import '../common/pill_chip_row.dart';
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
class ScopeFilterChips extends ConsumerWidget {
  /// Widgets before the chips, scrolling with them.
  final List<Widget> leading;

  const ScopeFilterChips({super.key, this.leading = const []});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scope = ref.watch(searchStateProvider.select((s) => s.scope));
    final searchInPali =
        ref.watch(searchStateProvider.select((s) => s.searchInPali));
    final searchInSinhala =
        ref.watch(searchStateProvider.select((s) => s.searchInSinhala));

    // Check if scope contains custom selections (not covered by predefined chips)
    // This is true only when the refine dialog was used to select sub-nodes
    final hasCustomScope = ScopeOperations.hasCustomSelections(scope);

    // A single-language narrowing is a saved user preference (the default is
    // both languages on), so surface it on the Refine chip alongside custom
    // scope. Guarded on availableContentLanguages: an edition that ships only
    // one language never shows the toggle, so it must never look "narrowed".
    final availableLanguages = ref.watch(availableContentLanguagesProvider);
    final languageNarrowed =
        availableLanguages.length >= 2 && !(searchInPali && searchInSinhala);
    final hasActiveFilters = hasCustomScope || languageNarrowed;

    return PillChipRow(
      children: [
        ...leading,

        // "All" chip - always first
        PillChip(
          label: l10n.scopeAll,
          selected: scope.isEmpty,
          onPressed: () => ref.read(searchStateProvider.notifier).selectAll(),
        ),

        // Scope chips from predefined list
        for (final chip in searchScopeChips)
          PillChip(
            label: scopeChipLabel(chip, l10n),
            selected: ScopeOperations.containsAllKeys(scope, chip.nodeKeys),
            onPressed: () => ref
                .read(searchStateProvider.notifier)
                .toggleScopeKeys(chip.nodeKeys),
          ),

        // Refine chip - opens advanced search dialog
        PillChip.refine(
          label: l10n.refine,
          selected: hasActiveFilters,
          onPressed: () => RefineSearchDialog.show(context),
        ),
      ],
    );
  }
}
