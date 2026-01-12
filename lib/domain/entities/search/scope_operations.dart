import '../../../core/constants/constants.dart';
import '../navigation/tipitaka_tree_node.dart';

/// Consolidated utility class for all search scope operations.
///
/// This is the SINGLE SOURCE OF TRUTH for scope logic, providing:
/// - Pattern mapping (node key → database filename patterns)
/// - Hierarchy navigation (ancestor/descendant relationships)
/// - Chip operations (validation, normalization)
/// - Key operations (toggle, contains checks)
/// - Tree operations (checkbox state, node toggling)
///
/// All methods are pure functions operating on [Set<String>] scope values.
/// This makes the logic UI-independent and easily testable.
///
/// Example usage:
/// ```dart
/// // Get patterns for SQL filtering
/// final patterns = ScopeOperations.getPatternsForScope({'sp', 'vp'});
///
/// // Check if scope needs "custom" indicator in UI
/// final isCustom = ScopeOperations.hasCustomSelections(scope);
///
/// // Toggle keys (for chip-like behavior)
/// final newScope = ScopeOperations.toggleKeys(scope, {'sp'});
///
/// // Toggle tree node (for dialog-like behavior)
/// final newScope = ScopeOperations.toggleNodeSelection(node, scope);
///
/// // Get checkbox state for a node
/// final checkState = ScopeOperations.getCheckboxState(node, scope);
/// ```
class ScopeOperations {
  // Private constructor - use static methods only
  ScopeOperations._();

  // ============================================================================
  // CONSTANTS
  // ============================================================================

  /// Root node keys that need expansion to multiple filename prefixes.
  ///
  /// Most tree node keys map directly to filename prefixes (e.g., 'dn' → 'dn-').
  /// However, some root nodes don't match filename conventions directly:
  /// - 'sp' (Sutta Pitaka) → files are named dn-*, mn-*, sn-*, an-*, kn-*
  /// - 'atta-sp' (Sutta Commentary) → files are named atta-dn-*, atta-mn-*, etc.
  ///
  /// Other roots like 'vp', 'ap', 'anya' work naturally because files match
  /// their node keys directly (vp-*, ap-*, anya-*).
  static const Map<String, List<String>> _expandedPatterns = {
    // Sutta Pitaka: tree key 'sp' but files use nikaya prefixes
    TipitakaNodeKeys.suttaPitaka: [
      '${TipitakaNodeKeys.dighaNikaya}-',
      '${TipitakaNodeKeys.majjhimaNikaya}-',
      '${TipitakaNodeKeys.samyuttaNikaya}-',
      '${TipitakaNodeKeys.anguttaraNikaya}-',
      '${TipitakaNodeKeys.khuddakaNikaya}-',
    ],
    // Sutta Commentary: tree key 'atta-sp' but files use nikaya prefixes
    TipitakaNodeKeys.suttaAtthakatha: [
      'atta-${TipitakaNodeKeys.dighaNikaya}-',
      'atta-${TipitakaNodeKeys.majjhimaNikaya}-',
      'atta-${TipitakaNodeKeys.samyuttaNikaya}-',
      'atta-${TipitakaNodeKeys.anguttaraNikaya}-',
      'atta-${TipitakaNodeKeys.khuddakaNikaya}-',
    ],
  };

  /// Chip key groupings - defines how root scope keys are grouped for quick selection.
  ///
  /// This is the domain-level knowledge that UI chips implement.
  /// Each inner set represents one chip's nodeKeys:
  /// - Single pitakas: {'sp'}, {'vp'}, {'ap'}
  /// - Commentaries grouped together: {'atta-sp', 'atta-vp', 'atta-ap'}
  /// - Treatises: {'anya'}
  ///
  /// UI layer (SearchScopeChip) consumes these groupings to build chips.
  /// This inverts the dependency: Domain defines structure, UI implements display.
  static const List<Set<String>> chipKeyGroups = [
    {TipitakaNodeKeys.suttaPitaka},
    {TipitakaNodeKeys.vinayaPitaka},
    {TipitakaNodeKeys.abhidhammaPitaka},
    TipitakaNodeKeys.commentaries,
    {TipitakaNodeKeys.treatises},
  ];

  // ============================================================================
  // PATTERN CONFIGURATION (from ScopeFilterConfig)
  // ============================================================================

  /// Converts a tree node key to filename prefix patterns.
  ///
  /// Most node keys map directly to filename prefixes:
  /// - 'dn' → ['dn-'] (all Digha Nikaya files)
  /// - 'dn-1' → ['dn-1-'] (Silakkhandhavagga suttas)
  /// - 'vp' → ['vp-'] (all Vinaya Pitaka files)
  /// - 'ap' → ['ap-'] (all Abhidhamma Pitaka files)
  /// - 'anya' → ['anya-'] (all Treatises)
  ///
  /// Root nodes that don't match filenames are expanded:
  /// - 'sp' → ['dn-', 'mn-', 'sn-', 'an-', 'kn-']
  /// - 'atta-sp' → ['atta-dn-', 'atta-mn-', 'atta-sn-', 'atta-an-', 'atta-kn-']
  ///
  /// Note: The SQL LIKE wildcard (%) is added by the service layer.
  ///
  /// Example:
  /// ```dart
  /// getPatternsForNodeKey('dn')   // Returns: ['dn-']
  /// getPatternsForNodeKey('sp')   // Returns: ['dn-', 'mn-', 'sn-', 'an-', 'kn-']
  /// getPatternsForNodeKey('vp')   // Returns: ['vp-']
  /// ```
  static List<String> getPatternsForNodeKey(String nodeKey) {
    // Check if this is a root node that needs expansion
    if (_expandedPatterns.containsKey(nodeKey)) {
      return _expandedPatterns[nodeKey]!;
    }
    // Standard case: node key maps directly to filename prefix
    // Note: % wildcard is added by the service layer, not here
    return ['$nodeKey-'];
  }

  /// Converts a set of tree node keys to filename prefix patterns.
  ///
  /// Returns empty list if [searchScope] is empty (no filter = search all).
  ///
  /// Note: The SQL LIKE wildcard (%) is added by the service layer.
  ///
  /// Example:
  /// ```dart
  /// getPatternsForScope({'dn', 'mn'})
  /// // Returns: ['dn-', 'mn-']
  /// getPatternsForScope({'sp'})
  /// // Returns: ['dn-', 'mn-', 'sn-', 'an-', 'kn-']
  /// getPatternsForScope({'sp', 'vp'})
  /// // Returns: ['dn-', 'mn-', 'sn-', 'an-', 'kn-', 'vp-']
  /// ```
  static List<String> getPatternsForScope(Set<String> searchScope) {
    if (searchScope.isEmpty) return [];
    // Use expand() since some nodes return multiple patterns
    return searchScope.expand(getPatternsForNodeKey).toList();
  }

  // ============================================================================
  // HIERARCHY NAVIGATION (from ScopeFilterConfig)
  // ============================================================================

  /// Check if [childNodeKey] is covered by (is a descendant of) [ancestorNodeKey].
  ///
  /// A node is "covered" if all of its filename patterns are prefixed by
  /// at least one of the ancestor's patterns.
  ///
  /// Examples:
  /// - isNodeCoveredBy('dn', 'sp') → true (dn- is in sp's expanded patterns)
  /// - isNodeCoveredBy('dn-1', 'dn') → true (dn-1- starts with dn-)
  /// - isNodeCoveredBy('mn', 'dn') → false (mn- doesn't start with dn-)
  /// - isNodeCoveredBy('sp', 'sp') → true (a node covers itself)
  static bool isNodeCoveredBy(String childNodeKey, String ancestorNodeKey) {
    final childPatterns = getPatternsForNodeKey(childNodeKey);
    final ancestorPatterns = getPatternsForNodeKey(ancestorNodeKey);

    // Child is covered if ALL of its patterns start with at least one ancestor pattern
    return childPatterns.every(
      (childPattern) => ancestorPatterns.any(
        (ancestorPattern) => childPattern.startsWith(ancestorPattern),
      ),
    );
  }

  /// Find which of the [candidateAncestors] cover the given [nodeKey].
  ///
  /// Returns the set of ancestor keys that cover the node.
  /// A node covers itself (e.g., 'sp' is covered by {'sp'}).
  ///
  /// Example:
  /// - findCoveringAncestors('dn', {'sp', 'vp', 'ap'}) → {'sp'}
  /// - findCoveringAncestors('dn-1', {'sp', 'dn'}) → {'sp', 'dn'}
  static Set<String> findCoveringAncestors(
    String nodeKey,
    Set<String> candidateAncestors,
  ) {
    return candidateAncestors
        .where((ancestor) => isNodeCoveredBy(nodeKey, ancestor))
        .toSet();
  }

  // ============================================================================
  // CHIP OPERATIONS (from ScopeUtils)
  // ============================================================================

  /// Get all node keys from predefined chip groupings.
  ///
  /// Returns the combined set of nodeKeys from all chip groups.
  /// Used to detect when all chips are selected (triggers auto-collapse to "All").
  ///
  /// Returns: {'sp', 'vp', 'ap', 'atta-sp', 'atta-vp', 'atta-ap', 'anya'}
  static Set<String> getAllChipNodeKeys() {
    return chipKeyGroups.expand((group) => group).toSet();
  }

  /// Check if the scope contains only predefined chip-level selections.
  ///
  /// Returns true if every nodeKey in [scope] belongs to at least one
  /// chip group whose keys are all contained within [scope].
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

    // Collect all nodeKeys from chip groups that are fully "selected"
    // (i.e., all of the group's keys are in the scope)
    final coveredKeys = <String>{};
    for (final group in chipKeyGroups) {
      if (scope.containsAll(group)) {
        coveredKeys.addAll(group);
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

  // ============================================================================
  // STATE CHECKS (from ScopeUtils)
  // ============================================================================

  /// Check if "All" is effectively selected (no specific scope chosen).
  ///
  /// Returns true when scope is empty, meaning search should include all content.
  static bool isAllSelected(Set<String> scope) {
    return scope.isEmpty;
  }

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

  // ============================================================================
  // KEY OPERATIONS (NEW - decoupled from chips)
  // ============================================================================

  /// Toggle a set of keys in/out of scope.
  ///
  /// If all [keysToToggle] are present in [currentScope], removes them.
  /// Otherwise, adds them. Auto-normalizes the result.
  ///
  /// This is used by UI chips to toggle their associated keys without
  /// the state layer needing to know about chip entities.
  ///
  /// Example:
  /// ```dart
  /// toggleKeys({}, {'sp'})         // → {'sp'} (add Sutta)
  /// toggleKeys({'sp'}, {'sp'})     // → {} (remove Sutta → All)
  /// toggleKeys({'sp'}, {'vp'})     // → {'sp', 'vp'} (add Vinaya)
  /// toggleKeys({'sp', 'vp'}, {'sp'}) // → {'vp'} (remove Sutta)
  /// ```
  static Set<String> toggleKeys(
    Set<String> currentScope,
    Set<String> keysToToggle,
  ) {
    final newScope = Set<String>.from(currentScope);
    final allPresent = keysToToggle.every((key) => currentScope.contains(key));

    if (allPresent) {
      newScope.removeAll(keysToToggle);
    } else {
      newScope.addAll(keysToToggle);

      // Remove any existing keys that are covered by the newly added keys.
      // e.g., if adding 'sp' (Sutta Pitaka), remove 'mn' (Majjima Nikaya)
      // because 'sp' already covers 'mn' in the hierarchy.
      final keysToRemove = <String>{};
      for (final existingKey in newScope) {
        if (keysToToggle.contains(existingKey)) continue; // Skip added keys

        for (final addedKey in keysToToggle) {
          if (isNodeCoveredBy(existingKey, addedKey)) {
            keysToRemove.add(existingKey);
            break;
          }
        }
      }
      newScope.removeAll(keysToRemove);
    }

    return normalize(newScope);
  }

  /// Check if scope contains all specified keys.
  ///
  /// Returns false if scope is empty ("All" selected - no individual keys match).
  /// This is used by UI to determine if a chip/option is selected.
  ///
  /// Example:
  /// ```dart
  /// containsAllKeys({}, {'sp'})       // → false ("All" has no specific selection)
  /// containsAllKeys({'sp'}, {'sp'})   // → true
  /// containsAllKeys({'sp', 'vp'}, {'sp'}) // → true
  /// containsAllKeys({'sp'}, {'sp', 'vp'}) // → false (missing 'vp')
  /// ```
  static bool containsAllKeys(Set<String> scope, Set<String> keys) {
    if (scope.isEmpty) return false;
    return scope.containsAll(keys);
  }

  // ============================================================================
  // TREE OPERATIONS (moved from RefineSearchDialog)
  // ============================================================================

  // --- Parent-Child Collapse Operations ---

  /// Collapse children to parent if all direct children are selected.
  ///
  /// If all direct children of [parent] are in [scope], removes the children
  /// and adds the parent key instead.
  ///
  /// Example:
  /// - scope: {'dn', 'mn', 'sn', 'an', 'kn'}, parent: Sutta Pitaka node
  /// - Returns: {'sp'}
  static Set<String> collapseChildrenToParent(
    TipitakaTreeNode parent,
    Set<String> scope,
  ) {
    // If parent has no children, nothing to collapse
    if (parent.childNodes.isEmpty) return scope;

    // Check if ALL direct children are in scope
    final allChildrenSelected = parent.childNodes.every(
      (child) => scope.contains(child.nodeKey),
    );

    if (!allChildrenSelected) return scope;

    // All children selected - collapse to parent
    final newScope = Set<String>.from(scope);
    for (final child in parent.childNodes) {
      newScope.remove(child.nodeKey);
    }
    newScope.add(parent.nodeKey);

    return newScope;
  }

  /// Recursively collapse children to parents up the tree.
  ///
  /// Starting from [node], traverses up through ancestors and collapses
  /// any level where all children are selected.
  ///
  /// This ensures that selecting the last sibling auto-selects the parent,
  /// and continues up the tree as needed.
  static Set<String> collapseToAncestors(
    TipitakaTreeNode node,
    Set<String> scope,
    List<TipitakaTreeNode> treeRoots,
  ) {
    var currentScope = scope;

    // Find the parent node
    final parentKey = node.parentNodeKey;
    if (parentKey == null) {
      // Node is a root - check if all roots are selected (handled by normalize)
      return currentScope;
    }

    // Find parent in tree
    TipitakaTreeNode? parent;
    for (final root in treeRoots) {
      parent = root.findDescendantByKey(parentKey);
      if (parent != null) break;
    }

    if (parent == null) return currentScope;

    // Try to collapse children to parent
    currentScope = collapseChildrenToParent(parent, currentScope);

    // If collapse happened (parent is now in scope), continue up the tree
    if (currentScope.contains(parent.nodeKey)) {
      currentScope = collapseToAncestors(parent, currentScope, treeRoots);
    }

    return currentScope;
  }

  // --- Descendant Operations ---

  /// Check if any descendant of [node] is in [scope].
  ///
  /// Used to determine tristate checkbox state (partial selection).
  /// Returns true if any direct or nested child is selected.
  static bool hasSelectedDescendant(TipitakaTreeNode node, Set<String> scope) {
    for (final child in node.childNodes) {
      if (scope.contains(child.nodeKey)) {
        return true;
      }
      if (hasSelectedDescendant(child, scope)) {
        return true;
      }
    }
    return false;
  }

  /// Determine which nodes should be expanded to show currently selected nodes.
  ///
  /// Used to auto-expand tree when dialog opens with existing selection.
  /// Returns the set of root node keys that should be expanded.
  static Set<String> getNodesNeedingExpansion(Set<String> selectedKeys) {
    final rootNodes = getAllChipNodeKeys();
    final nodesToExpand = <String>{};

    for (final selectedKey in selectedKeys) {
      // If it's a root node itself, expand it to show children
      if (rootNodes.contains(selectedKey)) {
        nodesToExpand.add(selectedKey);
        continue;
      }

      // Find which root node covers this selected key
      for (final rootKey in rootNodes) {
        if (isNodeCoveredBy(selectedKey, rootKey)) {
          nodesToExpand.add(rootKey);
          break;
        }
      }
    }

    return nodesToExpand;
  }

  /// Remove all descendant keys of [node] from [scope].
  ///
  /// Returns a new Set with descendants removed.
  /// Used when selecting a parent node (parent supersedes children).
  static Set<String> removeDescendantsFromScope(
    TipitakaTreeNode node,
    Set<String> scope,
  ) {
    final result = Set<String>.from(scope);

    void removeDescendants(TipitakaTreeNode n) {
      for (final child in n.childNodes) {
        result.remove(child.nodeKey);
        removeDescendants(child);
      }
    }

    removeDescendants(node);
    return result;
  }

  /// Toggle a node's selection state and return the new scope.
  ///
  /// Logic:
  /// - If scope is empty ("All"), selecting any node focuses on just that node
  /// - If node is directly selected, deselect it and all descendants
  /// - If node is covered by an ancestor, remove the ancestor (narrow down)
  /// - Otherwise, select the node and remove any selected descendants
  /// - If [treeRoots] is provided and all siblings are now selected, auto-selects parent
  ///
  /// The [treeRoots] parameter enables auto-collapse behavior:
  /// when all children of a parent are selected, they collapse to the parent.
  ///
  /// Example:
  /// ```dart
  /// // From "All", select Sutta Pitaka
  /// toggleNodeSelection(suttaNode, {})  // → {'sp'}
  ///
  /// // Narrow down from Sutta to just Digha Nikaya
  /// toggleNodeSelection(dighaNode, {'sp'})  // → {'dn'}
  ///
  /// // Deselect Digha Nikaya
  /// toggleNodeSelection(dighaNode, {'dn'})  // → {}
  ///
  /// // With treeRoots: selecting last nikaya auto-selects pitaka
  /// toggleNodeSelection(knNode, {'dn','mn','sn','an'}, treeRoots: tree) // → {'sp'}
  /// ```
  static Set<String> toggleNodeSelection(
    TipitakaTreeNode node,
    Set<String> currentScope, {
    List<TipitakaTreeNode>? treeRoots,
  }) {
    var newScope = Set<String>.from(currentScope);

    // Special case: "All" selected - clicking any node means focus on just this node
    if (newScope.isEmpty) {
      return {node.nodeKey};
    }

    if (newScope.contains(node.nodeKey)) {
      // Deselect: remove this node and all its descendants
      newScope.remove(node.nodeKey);
      return removeDescendantsFromScope(node, newScope);
    } else {
      // Check if this node is covered by an ancestor
      final coveringAncestors = findCoveringAncestors(node.nodeKey, newScope);
      if (coveringAncestors.isNotEmpty) {
        // Remove ancestors (user wants to narrow down)
        newScope.removeAll(coveringAncestors);
      }

      // Select this node
      newScope.add(node.nodeKey);

      // Remove any selected descendants (parent supersedes children)
      newScope = removeDescendantsFromScope(node, newScope);

      // Auto-collapse: if all siblings are now selected, collapse to parent
      if (treeRoots != null) {
        newScope = collapseToAncestors(node, newScope, treeRoots);
      }

      return newScope;
    }
  }

  /// Get the checkbox state for a tree node.
  ///
  /// Returns:
  /// - `true` if node is selected (directly, implicitly via ancestor, or "All")
  /// - `null` if node has partial selection (some descendants selected)
  /// - `false` if node is not selected
  ///
  /// This tristate value can be used directly with Flutter's Checkbox widget.
  static bool? getCheckboxState(TipitakaTreeNode node, Set<String> scope) {
    final isAllSel = isAllSelected(scope);
    final isDirectlySelected = scope.contains(node.nodeKey);
    final isImplicitlySelected =
        findCoveringAncestors(node.nodeKey, scope).isNotEmpty;
    final hasSelectedDesc = hasSelectedDescendant(node, scope);

    if (isAllSel || isDirectlySelected || isImplicitlySelected) {
      return true;
    } else if (hasSelectedDesc) {
      return null; // Partial/tristate
    } else {
      return false;
    }
  }
}
