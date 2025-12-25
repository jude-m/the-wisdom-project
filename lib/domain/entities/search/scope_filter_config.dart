import 'search_scope.dart';

/// Configuration that maps [SearchScope]s to database filename patterns.
///
/// This is the SINGLE SOURCE OF TRUTH for how scopes translate to database
/// queries. When adding new content or changing database structure, update
/// this file only.
///
/// Example usage:
/// ```dart
/// final patterns = ScopeFilterConfig.getPatternsForScope({SearchScope.sutta});
/// // Returns: ['dn-', 'mn-', 'sn-', 'an-', 'kn-']
/// ```
class ScopeFilterConfig {
  // Private constructor - use static methods only
  ScopeFilterConfig._();

  /// Filename prefix patterns for each scope.
  ///
  /// These patterns are used with SQL LIKE: `filename LIKE 'pattern%'`
  ///
  /// Database filename examples:
  /// - Sutta: 'dn-1', 'mn-42', 'sn-12-1'
  /// - Vinaya: 'vp-1'
  /// - Abhidhamma: 'ap-1'
  /// - Commentaries: 'atta-dn-1'
  /// - Treatises: 'anya-vism-1'
  static const Map<SearchScope, List<String>> scopePatterns = {
    SearchScope.sutta: ['dn-', 'mn-', 'sn-', 'an-', 'kn-'],
    SearchScope.vinaya: ['vp-'],
    SearchScope.abhidhamma: ['ap-'],
    SearchScope.commentaries: ['atta-'],
    SearchScope.treatises: ['anya-'],
  };

  /// Get all filename patterns for a set of scopes.
  ///
  /// Returns empty list if [scope] is empty, which means "search all content"
  /// (no filter should be applied).
  ///
  /// Example:
  /// ```dart
  /// getPatternsForScope({SearchScope.sutta, SearchScope.commentaries})
  /// // Returns: ['dn-', 'mn-', 'sn-', 'an-', 'kn-', 'atta-']
  /// ```
  static List<String> getPatternsForScope(Set<SearchScope> scope) {
    if (scope.isEmpty) return [];
    return scope
        .expand<String>((s) => scopePatterns[s] ?? [])
        .toList();
  }

  /// Check if a scope has sub-categories available for drill-down.
  ///
  /// Currently only Sutta has sub-categories (DN, MN, SN, AN, KN).
  /// This is used for future drill-down functionality.
  static bool hasSubCategories(SearchScope scope) {
    switch (scope) {
      case SearchScope.sutta:
        return true; // DN, MN, SN, AN, KN
      case SearchScope.vinaya:
      case SearchScope.abhidhamma:
      case SearchScope.commentaries:
      case SearchScope.treatises:
        return false; // No sub-categories yet
    }
  }
}
