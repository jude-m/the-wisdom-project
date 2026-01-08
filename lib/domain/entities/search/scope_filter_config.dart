/// Configuration that maps tree node keys to database filename patterns.
///
/// This is the SINGLE SOURCE OF TRUTH for how search scopes translate to
/// database queries. When adding new content or changing database structure,
/// update this file only.
///
/// Example usage:
/// ```dart
/// final patterns = ScopeFilterConfig.getPatternsForScope({'sp', 'vp'});
/// // Returns: ['dn-', 'mn-', 'sn-', 'an-', 'kn-', 'vp-']
/// ```
class ScopeFilterConfig {
  // Private constructor - use static methods only
  ScopeFilterConfig._();

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
    'sp': ['dn-', 'mn-', 'sn-', 'an-', 'kn-'],
    // Sutta Commentary: tree key 'atta-sp' but files use nikaya prefixes
    'atta-sp': [
      'atta-dn-',
      'atta-mn-',
      'atta-sn-',
      'atta-an-',
      'atta-kn-'
    ],
  };

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
}
