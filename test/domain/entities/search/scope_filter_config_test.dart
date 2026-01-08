import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/constants/constants.dart';
import 'package:the_wisdom_project/domain/entities/search/scope_filter_config.dart';

void main() {
  group('ScopeFilterConfig -', () {
    group('getPatternsForScope', () {
      // Test 1: Empty set returns empty list (search all content)
      test('should return empty list when scope set is empty', () {
        // ACT
        final patterns = ScopeFilterConfig.getPatternsForScope({});

        // ASSERT
        expect(patterns, isEmpty);
      });

      // Test 2: Single root node key returns correct patterns
      test('should return correct patterns for sutta pitaka (sp)', () {
        // ACT
        final patterns = ScopeFilterConfig.getPatternsForScope(
            {TipitakaNodeKeys.suttaPitaka});

        // ASSERT
        expect(patterns, equals(['dn-', 'mn-', 'sn-', 'an-', 'kn-']));
      });

      // Test 3: Multiple node keys combine patterns (OR logic)
      test('should combine patterns for multiple node keys', () {
        // ACT
        final patterns = ScopeFilterConfig.getPatternsForScope({
          TipitakaNodeKeys.suttaPitaka,
          TipitakaNodeKeys.vinayaPitaka,
        });

        // ASSERT
        expect(
            patterns, containsAll(['dn-', 'mn-', 'sn-', 'an-', 'kn-', 'vp-']));
        expect(patterns.length, equals(6)); // 5 sutta + 1 vinaya
      });

      // Test 4: Specific nikaya returns single pattern
      test('should return single pattern for specific nikaya', () {
        // ACT
        final patterns = ScopeFilterConfig.getPatternsForScope(
            {TipitakaNodeKeys.dighaNikaya, TipitakaNodeKeys.majjhimaNikaya});

        // ASSERT
        expect(patterns, equals(['dn-', 'mn-']));
      });

      // Test 5: Sub-node keys work correctly
      test('should return pattern for sub-node key', () {
        // ACT
        final patterns = ScopeFilterConfig.getPatternsForScope({'dn-1'});

        // ASSERT
        expect(patterns, equals(['dn-1-']));
      });

      // Test 6: Commentary expansion works
      test('should expand atta-sp to commentary patterns', () {
        // ACT
        final patterns = ScopeFilterConfig.getPatternsForScope(
            {TipitakaNodeKeys.suttaAtthakatha});

        // ASSERT
        expect(
            patterns,
            equals(
                ['atta-dn-', 'atta-mn-', 'atta-sn-', 'atta-an-', 'atta-kn-']));
      });
    });

    group('getPatternsForNodeKey', () {
      // Test 7: Root node that needs expansion
      test('should expand sp to nikaya patterns', () {
        // ACT
        final patterns = ScopeFilterConfig.getPatternsForNodeKey(
            TipitakaNodeKeys.suttaPitaka);

        // ASSERT
        expect(patterns, equals(['dn-', 'mn-', 'sn-', 'an-', 'kn-']));
      });

      // Test 8: Direct mapping node keys
      test('should return direct pattern for vp', () {
        // ACT
        final patterns = ScopeFilterConfig.getPatternsForNodeKey(
            TipitakaNodeKeys.vinayaPitaka);

        // ASSERT
        expect(patterns, equals(['vp-']));
      });

      test('should return direct pattern for ap', () {
        // ACT
        final patterns = ScopeFilterConfig.getPatternsForNodeKey(
            TipitakaNodeKeys.abhidhammaPitaka);

        // ASSERT
        expect(patterns, equals(['ap-']));
      });

      test('should return direct pattern for anya', () {
        // ACT
        final patterns =
            ScopeFilterConfig.getPatternsForNodeKey(TipitakaNodeKeys.treatises);

        // ASSERT
        expect(patterns, equals(['anya-']));
      });

      // Test 9: Specific node key
      test('should return pattern for specific node like dn', () {
        // ACT
        final patterns = ScopeFilterConfig.getPatternsForNodeKey(
            TipitakaNodeKeys.dighaNikaya);

        // ASSERT
        expect(patterns, equals(['dn-']));
      });
    });
  });
}
