import 'search_scope_chip.dart';

/// Utility class for scope-related operations.
///
/// Centralizes all scope validation, normalization, and comparison logic
/// used across the search feature. This is the single entry point for
/// scope operations.
///
/// Responsibilities:
/// - Scope normalization (auto-collapse to "All" when all chips selected)
/// - Checking if "All" is selected
/// - Getting all chip node keys
/// - Validating if scope uses only chip-level selections
/// - Checking for custom (sub-node) selections
class ScopeUtils {
  // Private constructor - use static methods only
  ScopeUtils._();

  // ===========================================================================
  // CHIP NODE KEY OPERATIONS
  // ===========================================================================

  /// Get all node keys from predefined chips.
  ///
  /// Returns the combined set of nodeKeys from all chips in [searchScopeChips].
  /// Used to detect when all chips are selected (triggers auto-collapse to "All").
  ///
  /// Returns: {'vp', 'sp', 'ap', 'atta-vp', 'atta-sp', 'atta-ap', 'anya'}
  static Set<String> getAllChipNodeKeys() {
    return searchScopeChips.expand((chip) => chip.nodeKeys).toSet();
  }

  // ===========================================================================
  // SCOPE STATE CHECKS
  // ===========================================================================

  /// Check if "All" is effectively selected (no specific scope chosen).
  ///
  /// Returns true when scope is empty, meaning search should include all content.
  static bool isAllSelected(Set<String> scope) {
    return scope.isEmpty;
  }

  /// Check if the scope contains only predefined chip-level selections.
  ///
  /// Returns true if every nodeKey in [scope] belongs to at least one
  /// chip whose nodeKeys are all contained within [scope].
  ///
  /// Returns false if scope contains sub-nodes selected via Refine dialog
  /// (like 'dn', 'mn' which are not top-level chip keys).
  ///
  /// Example:
  /// - `{}` → true ("All" is always valid)
  /// - `{'sp'}` → true (covered by Sutta chip)
  /// - `{'sp', 'vp'}` → true (covered by Sutta + Vinaya chips)
  /// - `{'sp', 'dn'}` → false ('dn' is a sub-node, not a chip's nodeKey)
  /// - `{'dn', 'mn'}` → false (sub-nodes only)
  static bool isChipSelectionOnly(Set<String> scope) {
    if (scope.isEmpty) return true; // "All" is always valid

    // Collect all nodeKeys from chips that are fully "selected"
    // (i.e., all of the chip's nodeKeys are in the scope)
    final coveredKeys = <String>{};
    for (final chip in searchScopeChips) {
      if (scope.containsAll(chip.nodeKeys)) {
        coveredKeys.addAll(chip.nodeKeys);
      }
    }

    // Scope is covered if the covered keys exactly match the scope
    return coveredKeys.length == scope.length &&
        coveredKeys.containsAll(scope);
  }

  /// Check if the scope contains custom selections beyond predefined chips.
  ///
  /// Returns true when the scope includes sub-nodes (like 'dn', 'mn') that
  /// were selected via the Refine dialog rather than chip shortcuts.
  ///
  /// This is the inverse of [isChipSelectionOnly].
  ///
  /// Example:
  /// - `{}` → false ("All" has no custom selections)
  /// - `{'sp'}` → false (covered by Sutta chip)
  /// - `{'sp', 'vp'}` → false (covered by Sutta + Vinaya chips)
  /// - `{'dn', 'mn'}` → true (sub-nodes, not chip selections)
  /// - `{'sp', 'dn'}` → true ('dn' is not part of any chip's nodeKeys)
  static bool hasCustomSelections(Set<String> scope) {
    return !isChipSelectionOnly(scope);
  }

  // ===========================================================================
  // SCOPE NORMALIZATION
  // ===========================================================================

  /// Normalize scope: collapse to empty set if all chips are selected.
  ///
  /// This ensures consistent behavior whether scope is set via:
  /// - Individual chip toggles
  /// - Refine dialog selections
  /// - Programmatic updates
  ///
  /// Example:
  /// - `{'sp', 'vp', 'ap', 'atta-vp', 'atta-sp', 'atta-ap', 'anya'}` → `{}`
  /// - `{'sp', 'vp'}` → `{'sp', 'vp'}`
  /// - `{}` → `{}`
  static Set<String> normalize(Set<String> scope) {
    if (scope.isEmpty) return scope;

    final allChipNodeKeys = getAllChipNodeKeys();

    // Check if scope exactly equals all chip node keys
    if (scope.length == allChipNodeKeys.length &&
        scope.containsAll(allChipNodeKeys)) {
      return const {}; // Collapse to "All"
    }
    return scope;
  }
}
