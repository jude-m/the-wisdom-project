import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/utils/search_query_utils.dart';

void main() {
  group('singlishPreviewText', () {
    test('converts Singlish to Sinhala', () {
      expect(singlishPreviewText('dukkha'), 'ඩුක්ඛ');
    });

    test('keeps the joiner that search drops', () {
      // The ZWJ makes the rakaransha render joined, not with a visible hal.
      expect(singlishPreviewText('tatra'), 'ටට්\u200Dර');
      expect(computeEffectiveQuery('tatra'), 'ටට්ර');
    });

    test('is null for Sinhala input, even with a trailing space', () {
      // Trimming changes the text, but it is not a conversion.
      expect(singlishPreviewText('සති '), isNull);
    });

    test('is null for a sutta reference', () {
      expect(singlishPreviewText('SN 15.3'), isNull);
      expect(singlishPreviewText('sn15.3'), isNull);
    });
  });
}
