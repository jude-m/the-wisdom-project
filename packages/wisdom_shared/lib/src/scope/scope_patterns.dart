import '../constants/tipitaka_node_keys.dart';

/// Pure pattern-mapping logic for Tipitaka scope filtering.
///
/// Maps tree node keys to filename prefix patterns used in database queries.
/// This is the shared single source of truth for scope-to-pattern conversion,
/// used by both the Flutter client and the Dart server.
class ScopePatterns {
  ScopePatterns._();

  /// Root node keys that need expansion to multiple filename prefixes.
  ///
  /// Most tree node keys map directly to filename prefixes (e.g., 'dn' -> 'dn-').
  /// However, some root nodes don't match filename conventions directly:
  /// - 'sp' (Sutta Pitaka) -> files are named dn-*, mn-*, sn-*, an-*, kn-*
  /// - 'atta-sp' (Sutta Commentary) -> files are named atta-dn-*, atta-mn-*, etc.
  ///
  /// Other roots like 'vp', 'ap', 'anya' work naturally because files match
  /// their node keys directly (vp-*, ap-*, anya-*).
  static const Map<String, List<String>> expandedPatterns = {
    TipitakaNodeKeys.suttaPitaka: [
      '${TipitakaNodeKeys.dighaNikaya}-',
      '${TipitakaNodeKeys.majjhimaNikaya}-',
      '${TipitakaNodeKeys.samyuttaNikaya}-',
      '${TipitakaNodeKeys.anguttaraNikaya}-',
      '${TipitakaNodeKeys.khuddakaNikaya}-',
    ],
    TipitakaNodeKeys.suttaAtthakatha: [
      'atta-${TipitakaNodeKeys.dighaNikaya}-',
      'atta-${TipitakaNodeKeys.majjhimaNikaya}-',
      'atta-${TipitakaNodeKeys.samyuttaNikaya}-',
      'atta-${TipitakaNodeKeys.anguttaraNikaya}-',
      'atta-${TipitakaNodeKeys.khuddakaNikaya}-',
    ],
  };

  /// Converts a tree node key to filename prefix patterns.
  ///
  /// Most node keys map directly to filename prefixes:
  /// - 'dn' -> ['dn-'] (all Digha Nikaya files)
  /// - 'dn-1' -> ['dn-1-'] (Silakkhandhavagga suttas)
  /// - 'vp' -> ['vp-'] (all Vinaya Pitaka files)
  ///
  /// Root nodes that don't match filenames are expanded:
  /// - 'sp' -> ['dn-', 'mn-', 'sn-', 'an-', 'kn-']
  /// - 'atta-sp' -> ['atta-dn-', 'atta-mn-', 'atta-sn-', 'atta-an-', 'atta-kn-']
  ///
  /// Note: The SQL LIKE wildcard (%) is added by [ScopeFilterSql], not here.
  static List<String> getPatternsForNodeKey(String nodeKey) {
    if (expandedPatterns.containsKey(nodeKey)) {
      return expandedPatterns[nodeKey]!;
    }
    return ['$nodeKey-'];
  }

  /// Converts a set of tree node keys to filename prefix patterns.
  ///
  /// Returns empty list if [searchScope] is empty (no filter = search all).
  static List<String> getPatternsForScope(Set<String> searchScope) {
    if (searchScope.isEmpty) return [];
    return searchScope.expand(getPatternsForNodeKey).toList();
  }

  /// Check if [childNodeKey] is covered by (is a descendant of) [ancestorNodeKey].
  ///
  /// A node is "covered" if all of its filename patterns are prefixed by
  /// at least one of the ancestor's patterns.
  ///
  /// Examples:
  /// - isNodeCoveredBy('dn', 'sp') -> true (dn- is in sp's expanded patterns)
  /// - isNodeCoveredBy('dn-1', 'dn') -> true (dn-1- starts with dn-)
  /// - isNodeCoveredBy('mn', 'dn') -> false (mn- doesn't start with dn-)
  /// - isNodeCoveredBy('sp', 'sp') -> true (a node covers itself)
  static bool isNodeCoveredBy(String childNodeKey, String ancestorNodeKey) {
    final childPatterns = getPatternsForNodeKey(childNodeKey);
    final ancestorPatterns = getPatternsForNodeKey(ancestorNodeKey);

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
  static Set<String> findCoveringAncestors(
    String nodeKey,
    Set<String> candidateAncestors,
  ) {
    return candidateAncestors
        .where((ancestor) => isNodeCoveredBy(nodeKey, ancestor))
        .toSet();
  }
}
