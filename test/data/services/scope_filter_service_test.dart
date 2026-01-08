import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/constants/constants.dart';
import 'package:the_wisdom_project/data/services/scope_filter_service.dart';

void main() {
  group('ScopeFilterService -', () {
    group('buildWhereClause', () {
      // Test 1: Empty scope returns null (no filter)
      test('should return null when scope set is empty', () {
        // ACT
        final whereClause = ScopeFilterService.buildWhereClause({});

        // ASSERT - null means "search all content"
        expect(whereClause, isNull);
      });

      // Test 2: Single node key generates correct SQL
      test('should generate SQL with single condition for single node', () {
        // ACT
        final whereClause = ScopeFilterService.buildWhereClause({
          TipitakaNodeKeys.vinayaPitaka,
        });

        // ASSERT
        expect(whereClause, equals('(m.filename LIKE ?)'));
      });

      // Test 3: Multiple node keys generate OR logic
      test('should generate SQL with OR conditions for multiple nodes', () {
        // ACT
        final whereClause = ScopeFilterService.buildWhereClause({
          TipitakaNodeKeys.suttaPitaka,
          TipitakaNodeKeys.suttaAtthakatha,
        });

        // ASSERT - 5 patterns for sp + 5 for atta-sp = 10 OR conditions
        expect(whereClause, contains('OR'));
        expect(
          whereClause,
          equals(
            '(m.filename LIKE ? OR m.filename LIKE ? OR m.filename LIKE ? OR '
            'm.filename LIKE ? OR m.filename LIKE ? OR m.filename LIKE ? OR '
            'm.filename LIKE ? OR m.filename LIKE ? OR m.filename LIKE ? OR '
            'm.filename LIKE ?)',
          ),
        );
      });

      // Test 4: Specific nikaya keys
      test('should generate SQL for specific nikaya keys', () {
        // ACT
        final whereClause = ScopeFilterService.buildWhereClause({
          TipitakaNodeKeys.dighaNikaya,
          TipitakaNodeKeys.majjhimaNikaya,
        });

        // ASSERT - 2 patterns = 2 OR conditions
        expect(whereClause, contains('OR'));
        expect(
          whereClause,
          equals('(m.filename LIKE ? OR m.filename LIKE ?)'),
        );
      });

      // Test 5: Custom table alias and column name
      test('should use custom table alias and column name', () {
        // ACT
        final whereClause = ScopeFilterService.buildWhereClause(
          {TipitakaNodeKeys.vinayaPitaka},
          tableAlias: 'meta',
          columnName: 'file_path',
        );

        // ASSERT
        expect(whereClause, equals('(meta.file_path LIKE ?)'));
      });
    });

    group('getWhereParams', () {
      // Test 6: Empty scope returns empty params
      test('should return empty list when scope set is empty', () {
        // ACT
        final params = ScopeFilterService.getWhereParams({});

        // ASSERT
        expect(params, isEmpty);
      });

      // Test 7: Single node key returns params with % wildcard
      test('should return params with wildcard for single node', () {
        // ACT
        final params = ScopeFilterService.getWhereParams({
          TipitakaNodeKeys.vinayaPitaka,
        });

        // ASSERT
        expect(params, equals(['vp-%']));
      });

      // Test 8: Sutta Pitaka expands to nikaya patterns
      test('should return all nikaya params for sp key', () {
        // ACT
        final params = ScopeFilterService.getWhereParams({
          TipitakaNodeKeys.suttaPitaka,
        });

        // ASSERT
        expect(params, equals(['dn-%', 'mn-%', 'sn-%', 'an-%', 'kn-%']));
      });

      // Test 9: Multiple node keys return all params
      test('should return all params with wildcards for multiple nodes', () {
        // ACT
        final params = ScopeFilterService.getWhereParams({
          TipitakaNodeKeys.dighaNikaya,
          TipitakaNodeKeys.majjhimaNikaya,
        });

        // ASSERT
        expect(params, equals(['dn-%', 'mn-%']));
      });

      // Test 10: Commentary expansion
      test('should expand atta-sp to commentary patterns', () {
        // ACT
        final params = ScopeFilterService.getWhereParams({
          TipitakaNodeKeys.suttaAtthakatha,
        });

        // ASSERT
        expect(
          params,
          equals([
            'atta-dn-%',
            'atta-mn-%',
            'atta-sn-%',
            'atta-an-%',
            'atta-kn-%'
          ]),
        );
      });
    });
  });
}
