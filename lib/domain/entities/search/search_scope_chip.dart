import 'package:flutter/widgets.dart';
import '../../../core/localization/l10n/app_localizations.dart';

/// Represents a search scope chip for quick scope selection.
///
/// Search scope chips are predefined shortcuts that select specific
/// tree node keys for filtering. They provide a simplified UI for
/// common filtering operations.
///
/// Each chip maps to one or more tree node keys which are used
/// for scope filtering.
class SearchScopeChip {
  /// Unique identifier for this chip
  final String id;

  /// Tree node keys this chip selects (e.g., {'sp'} for Sutta Pitaka)
  final Set<String> nodeKeys;

  /// Function to get localized label from AppLocalizations
  final String Function(AppLocalizations) getLabel;

  const SearchScopeChip({
    required this.id,
    required this.nodeKeys,
    required this.getLabel,
  });

  /// Get the display label for this chip
  String label(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return getLabel(l10n);
  }
}

/// Predefined search scope chips for the search UI.
///
/// These chips provide shortcuts to common scope selections:
/// - Individual pitakas (Sutta, Vinaya, Abhidhamma)
/// - All commentaries combined
/// - Treatises and other texts
///
/// Selecting a chip sets the search scope to the chip's nodeKeys.
/// The "All" state is represented by an empty scope set.
final List<SearchScopeChip> searchScopeChips = [
  SearchScopeChip(
    id: 'sutta',
    nodeKeys: const {'sp'},
    getLabel: (l10n) => l10n.scopeSutta,
  ),
  SearchScopeChip(
    id: 'vinaya',
    nodeKeys: const {'vp'},
    getLabel: (l10n) => l10n.scopeVinaya,
  ),
  SearchScopeChip(
    id: 'abhidhamma',
    nodeKeys: const {'ap'},
    getLabel: (l10n) => l10n.scopeAbhidhamma,
  ),
  SearchScopeChip(
    id: 'commentaries',
    nodeKeys: const {'atta-vp', 'atta-sp', 'atta-ap'},
    getLabel: (l10n) => l10n.scopeCommentaries,
  ),
  SearchScopeChip(
    id: 'treatises',
    nodeKeys: const {'anya'},
    getLabel: (l10n) => l10n.scopeTreatises,
  ),
];

/// Extension for chip lookup operations.
///
/// Note: Scope-related operations (validation, normalization) are in [ScopeUtils].
/// This extension only handles chip lookup by various criteria.
extension SearchScopeChipListX on List<SearchScopeChip> {
  /// Find a chip that exactly matches the given node keys.
  /// Returns null if no chip matches.
  SearchScopeChip? findByNodeKeys(Set<String> nodeKeys) {
    for (final chip in this) {
      if (chip.nodeKeys.length == nodeKeys.length &&
          chip.nodeKeys.containsAll(nodeKeys)) {
        return chip;
      }
    }
    return null;
  }

  /// Check if the given node keys match any chip exactly.
  bool matchesAnyChip(Set<String> nodeKeys) {
    return findByNodeKeys(nodeKeys) != null;
  }

  /// Find a chip by its id.
  SearchScopeChip? findById(String id) {
    for (final chip in this) {
      if (chip.id == id) {
        return chip;
      }
    }
    return null;
  }
}
