import '../../domain/entities/search/search_scope.dart';
import '../../domain/entities/search/scope_filter_config.dart';

/// Service that converts [SearchScope] selections into SQL WHERE clauses.
///
/// This service centralizes all scope-to-SQL logic, making it easy to:
/// - Update filtering logic in one place
/// - Test filtering independently
/// - Reuse across different datasources
///
/// Example usage:
/// ```dart
/// final scope = {SearchScope.sutta, SearchScope.commentaries};
/// final whereClause = ScopeFilterService.buildScopeWhereClause(scope);
/// // Returns: '(m.filename LIKE ? OR m.filename LIKE ? OR ... OR m.filename LIKE ?)'
///
/// final params = ScopeFilterService.getScopeWhereParams(scope);
/// // Returns: ['dn-%', 'mn-%', 'sn-%', 'an-%', 'kn-%', 'atta-%']
/// ```
class ScopeFilterService {
  // Private constructor - use static methods only
  ScopeFilterService._();

  /// Builds SQL WHERE clause fragment for scope filtering.
  ///
  /// Returns `null` if no filter should be applied (empty scope = search all).
  ///
  /// Parameters:
  /// - [scope]: Set of scopes to filter by. Empty set means "search all".
  /// - [tableAlias]: SQL table alias (default: 'm' for meta table)
  /// - [columnName]: Column to filter on (default: 'filename')
  ///
  /// Example output: `(m.filename LIKE ? OR m.filename LIKE ?)`
  static String? buildScopeWhereClause(
    Set<SearchScope> scope, {
    String tableAlias = 'm',
    String columnName = 'filename',
  }) {
    if (scope.isEmpty) return null; // No filter = search all

    final patterns = ScopeFilterConfig.getPatternsForScope(scope);
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
  /// getScopeWhereParams({SearchScope.sutta})
  /// // Returns: ['dn-%', 'mn-%', 'sn-%', 'an-%', 'kn-%']
  /// ```
  static List<String> getScopeWhereParams(Set<SearchScope> scope) {
    if (scope.isEmpty) return [];

    return ScopeFilterConfig.getPatternsForScope(scope)
        .map((pattern) => '$pattern%')
        .toList();
  }
}
