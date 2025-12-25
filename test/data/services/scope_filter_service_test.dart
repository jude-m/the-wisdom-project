import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/data/services/scope_filter_service.dart';
import 'package:the_wisdom_project/domain/entities/search/search_scope.dart';

void main() {
  group('ScopeFilterService -', () {
    group('buildScopeWhereClause', () {
      // Test 1: Empty scope returns null (no filter)
      test('should return null when scope set is empty', () {
        // ACT
        final whereClause = ScopeFilterService.buildScopeWhereClause({});

        // ASSERT - null means "search all content"
        expect(whereClause, isNull);
      });

      // Test 2: Single scope generates correct SQL
      test('should generate SQL with OR conditions for single scope', () {
        // ACT
        final whereClause = ScopeFilterService.buildScopeWhereClause({
          SearchScope.vinaya,
        });

        // ASSERT
        expect(whereClause, equals('(m.filename LIKE ?)'));
      });

      // Test 3: Multiple scopes generate OR logic
      test('should generate SQL with OR conditions for multiple scopes', () {
        // ACT
        final whereClause = ScopeFilterService.buildScopeWhereClause({
          SearchScope.sutta,
          SearchScope.commentaries,
        });

        // ASSERT - 5 patterns for sutta + 1 for commentaries = 6 OR conditions
        expect(whereClause, contains('OR'));
        expect(
          whereClause,
          equals(
            '(m.filename LIKE ? OR m.filename LIKE ? OR m.filename LIKE ? OR '
            'm.filename LIKE ? OR m.filename LIKE ? OR m.filename LIKE ?)',
          ),
        );
      });

      // Test 4: Custom table alias and column name
      test('should use custom table alias and column name', () {
        // ACT
        final whereClause = ScopeFilterService.buildScopeWhereClause(
          {SearchScope.vinaya},
          tableAlias: 'meta',
          columnName: 'file_path',
        );

        // ASSERT
        expect(whereClause, equals('(meta.file_path LIKE ?)'));
      });
    });

    group('getScopeWhereParams', () {
      // Test 5: Empty scope returns empty params
      test('should return empty list when scope set is empty', () {
        // ACT
        final params = ScopeFilterService.getScopeWhereParams({});

        // ASSERT
        expect(params, isEmpty);
      });

      // Test 6: Single scope returns params with % wildcard
      test('should return params with wildcard for single scope', () {
        // ACT
        final params = ScopeFilterService.getScopeWhereParams({
          SearchScope.vinaya,
        });

        // ASSERT
        expect(params, equals(['vp-%']));
      });

      // Test 7: Multiple scopes return all params
      test('should return all params with wildcards for multiple scopes', () {
        // ACT
        final params = ScopeFilterService.getScopeWhereParams({
          SearchScope.sutta,
          SearchScope.commentaries,
        });

        // ASSERT
        expect(
            params, equals(['dn-%', 'mn-%', 'sn-%', 'an-%', 'kn-%', 'atta-%']));
      });
    });
  });
}
