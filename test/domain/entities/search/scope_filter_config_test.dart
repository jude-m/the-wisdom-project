import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/domain/entities/search/search_scope.dart';
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

      // Test 2: Single scope returns correct patterns
      test('should return correct patterns for sutta scope', () {
        // ACT
        final patterns =
            ScopeFilterConfig.getPatternsForScope({SearchScope.sutta});

        // ASSERT
        expect(patterns, equals(['dn-', 'mn-', 'sn-', 'an-', 'kn-']));
      });

      // Test 3: Multiple scopes combine patterns (OR logic)
      test('should combine patterns for multiple scopes', () {
        // ACT
        final patterns = ScopeFilterConfig.getPatternsForScope({
          SearchScope.sutta,
          SearchScope.vinaya,
        });

        // ASSERT
        expect(
            patterns, containsAll(['dn-', 'mn-', 'sn-', 'an-', 'kn-', 'vp-']));
        expect(patterns.length, equals(6)); // 5 sutta + 1 vinaya
      });

      // Test 4: All scopes combine correctly
      test('should return all patterns when all scopes selected', () {
        // ACT
        final patterns = ScopeFilterConfig.getPatternsForScope(
          SearchScope.values.toSet(),
        );

        // ASSERT
        expect(patterns, containsAll(['dn-', 'vp-', 'ap-', 'atta-', 'anya-']));
        expect(patterns.length, equals(9)); // 5+1+1+1+1
      });
    });

    group('hasSubCategories', () {
      // Test 5: Only Sutta has sub-categories currently
      test('should return true for sutta scope', () {
        expect(ScopeFilterConfig.hasSubCategories(SearchScope.sutta), isTrue);
      });

      test('should return false for other scopes', () {
        expect(
            ScopeFilterConfig.hasSubCategories(SearchScope.vinaya), isFalse);
        expect(
            ScopeFilterConfig.hasSubCategories(SearchScope.abhidhamma), isFalse);
        expect(ScopeFilterConfig.hasSubCategories(SearchScope.commentaries),
            isFalse);
        expect(
            ScopeFilterConfig.hasSubCategories(SearchScope.treatises), isFalse);
      });
    });
  });
}
