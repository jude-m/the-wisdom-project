import 'package:wisdom_shared/wisdom_shared.dart';

/// Service that converts search scope (tree node keys) into SQL WHERE clauses.
///
/// Delegates to [ScopeFilterSql] from the shared package.
/// Kept as a wrapper so existing imports and call sites continue to work.
class ScopeFilterService {
  ScopeFilterService._();

  /// Builds SQL WHERE clause fragment for scope filtering.
  /// Returns `null` if no filter should be applied (empty scope = search all).
  static String? buildWhereClause(
    Set<String> searchScope, {
    String tableAlias = 'm',
    String columnName = 'filename',
  }) =>
      ScopeFilterSql.buildWhereClause(
        searchScope,
        tableAlias: tableAlias,
        columnName: columnName,
      );

  /// Gets the SQL parameters (pattern values with % wildcard) for scope filtering.
  /// Returns empty list if [scope] is empty (no parameters needed).
  static List<String> getWhereParams(Set<String> scope) =>
      ScopeFilterSql.getWhereParams(scope);

  /// Builds SQL WHERE clause fragment for the language filter (පාළි / සිංහල
  /// toggle). Returns `null` when [language] is null (= search both languages).
  static String? buildLanguageClause(
    String? language, {
    String tableAlias = 'm',
    String columnName = 'language',
  }) =>
      ScopeFilterSql.buildLanguageClause(
        language,
        tableAlias: tableAlias,
        columnName: columnName,
      );

  /// The bound parameter(s) for the language filter (empty when no filter).
  static List<String> getLanguageParams(String? language) =>
      ScopeFilterSql.getLanguageParams(language);
}
