import 'scope_patterns.dart';

/// Converts search scope (tree node keys) into SQL WHERE clause fragments.
///
/// Used by both the Flutter client (sqflite) and the Dart server (sqlite3)
/// to filter FTS search results by Tipitaka location.
class ScopeFilterSql {
  ScopeFilterSql._();

  /// Builds SQL WHERE clause fragment for scope filtering.
  ///
  /// Returns `null` if no filter should be applied (empty scope = search all).
  ///
  /// Example:
  /// ```dart
  /// buildWhereClause({'dn', 'mn'})
  /// // Returns: '(m.filename LIKE ? OR m.filename LIKE ?)'
  ///
  /// buildWhereClause({'sp'})
  /// // Returns: '(m.filename LIKE ? OR ... OR m.filename LIKE ?)'
  /// // (expanded to 5 patterns for dn, mn, sn, an, kn)
  /// ```
  static String? buildWhereClause(
    Set<String> searchScope, {
    String tableAlias = 'm',
    String columnName = 'filename',
  }) {
    if (searchScope.isEmpty) return null;

    final patterns = ScopePatterns.getPatternsForScope(searchScope);
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
  /// ```
  static List<String> getWhereParams(Set<String> scope) {
    if (scope.isEmpty) return [];
    return ScopePatterns.getPatternsForScope(scope)
        .map((pattern) => '$pattern%')
        .toList();
  }

  /// Builds the SQL WHERE clause fragment for the language filter (the
  /// පාළි / සිංහල search toggle), or `null` when [language] is null
  /// (= search both languages, the default).
  ///
  /// Like [buildWhereClause], the column lives on the meta table, so the
  /// caller prefixes this with `' AND '` and joins that table as [tableAlias].
  ///
  /// IMPORTANT: the DB stores Sinhala as `'sinh'` (not `'sinhala'`) and Pali as
  /// `'pali'`. Keeping this clause here means that column contract lives in one
  /// place for both the Flutter client and the Dart server.
  static String? buildLanguageClause(
    String? language, {
    String tableAlias = 'm',
    String columnName = 'language',
  }) {
    if (language == null) return null;
    return '$tableAlias.$columnName = ?';
  }

  /// The bound parameter(s) for the language filter: a single-element list with
  /// the DB language code, or empty when [language] is null (no filter).
  static List<String> getLanguageParams(String? language) =>
      language == null ? const [] : [language];
}
