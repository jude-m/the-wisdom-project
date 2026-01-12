import '../../domain/entities/search/scope_operations.dart';

/// Service that converts search scope (tree node keys) into SQL WHERE clauses.
///
/// This service centralizes all scope-to-SQL logic, making it easy to:
/// - Update filtering logic in one place
/// - Test filtering independently
/// - Reuse across different datasources
///
/// Example usage:
/// ```dart
/// final scope = {'sp', 'vp'};  // Sutta Pitaka + Vinaya Pitaka
/// final whereClause = ScopeFilterService.buildWhereClause(scope);
/// // Returns: '(m.filename LIKE ? OR m.filename LIKE ? OR ... OR m.filename LIKE ?)'
///
/// final params = ScopeFilterService.getWhereParams(scope);
/// // Returns: ['dn-%', 'mn-%', 'sn-%', 'an-%', 'kn-%', 'vp-%']
/// ```
class ScopeFilterService {
  // Private constructor - use static methods only
  ScopeFilterService._();

  /// Builds SQL WHERE clause fragment for scope filtering.
  ///
  /// Uses tree node keys (e.g., 'sp', 'dn', 'kn-dhp') to filter by
  /// specific locations in the text hierarchy.
  ///
  /// Returns `null` if no filter should be applied (empty scope = search all).
  ///
  /// Parameters:
  /// - [searchScope]: Set of tree node keys to filter by. Empty set means "search all".
  /// - [tableAlias]: SQL table alias (default: 'm' for meta table)
  /// - [columnName]: Column to filter on (default: 'filename')
  ///
  /// Example:
  /// ```dart
  /// buildWhereClause({'dn', 'mn'})
  /// // Returns: '(m.filename LIKE ? OR m.filename LIKE ?)'
  ///
  /// buildWhereClause({'sp'})
  /// // Returns: '(m.filename LIKE ? OR m.filename LIKE ? OR m.filename LIKE ? OR m.filename LIKE ? OR m.filename LIKE ?)'
  /// // (expanded to 5 patterns for dn, mn, sn, an, kn)
  /// ```
  static String? buildWhereClause(
    Set<String> searchScope, {
    String tableAlias = 'm',
    String columnName = 'filename',
  }) {
    if (searchScope.isEmpty) return null; // No filter = search all

    final patterns = ScopeOperations.getPatternsForScope(searchScope);
    if (patterns.isEmpty) return null;

    final conditions = patterns
        .map((_) => '$tableAlias.$columnName LIKE ?')
        .join(' OR ');

    return '($conditions)';
  }

  /// Gets the SQL parameters (pattern values with % wildcard) for scope filtering.
  ///
  /// Returns empty list if [scope] is empty (no parameters needed).
  ///
  /// Example:
  /// ```dart
  /// getWhereParams({'sp'})
  /// // Returns: ['dn-%', 'mn-%', 'sn-%', 'an-%', 'kn-%']
  ///
  /// getWhereParams({'dn', 'mn'})
  /// // Returns: ['dn-%', 'mn-%']
  ///
  /// getWhereParams({'dn-1'})
  /// // Returns: ['dn-1-%']
  /// ```
  static List<String> getWhereParams(Set<String> scope) {
    if (scope.isEmpty) return [];
    // Add SQL LIKE wildcard (%)
    return ScopeOperations.getPatternsForScope(scope)
        .map((pattern) => '$pattern%')
        .toList();
  }
}
