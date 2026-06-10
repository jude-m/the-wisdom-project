/// Represents a search scope chip for quick scope selection.
///
/// Search scope chips are predefined shortcuts that select specific
/// tree node keys for filtering. They provide a simplified UI for
/// common filtering operations.
///
/// Each chip maps to one or more tree node keys which are used
/// for scope filtering.
///
/// Pure domain data: the chip carries only its stable [id] and [nodeKeys].
/// The localized label is resolved in the presentation layer — see
/// `scopeChipLabel` in `presentation/utils/scope_chip_labels.dart`.
class SearchScopeChip {
  /// Unique identifier for this chip (also the key for its localized label).
  final String id;

  /// Tree node keys this chip selects (e.g., {'sp'} for Sutta Pitaka)
  final Set<String> nodeKeys;

  const SearchScopeChip({
    required this.id,
    required this.nodeKeys,
  });
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
const List<SearchScopeChip> searchScopeChips = [
  SearchScopeChip(id: 'sutta', nodeKeys: {'sp'}),
  SearchScopeChip(id: 'vinaya', nodeKeys: {'vp'}),
  SearchScopeChip(id: 'abhidhamma', nodeKeys: {'ap'}),
  SearchScopeChip(
    id: 'commentaries',
    nodeKeys: {'atta-vp', 'atta-sp', 'atta-ap'},
  ),
  SearchScopeChip(id: 'treatises', nodeKeys: {'anya'}),
];
