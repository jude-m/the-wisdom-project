import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/utils/text_utils.dart';

void main() {
  group('normalizeSearchText', () {
    test('returns identity mapping for text without ZWJ', () {
      // "කර්ම" - 4 characters, no ZWJ
      const text = 'කර්ම';
      final result = normalizeSearchText(text);

      // Map should have 5 entries: positions 0-3 + end position
      expect(result.positionMap.length, 5);
      expect(result.positionMap, [0, 1, 2, 3, 4]);
      expect(result.normalized, 'කර්ම');
    });

    test('රකාරාංශය (rakaranshaya): skips ZWJ in ර් combinations', () {
      // "ක්‍ර" with ZWJ (ka + virama + ZWJ + ra) - rakaranshaya form
      // Unicode: ක (0) + ් (1) + ZWJ (2) + ර (3) = 4 code units
      // Normalized: ක්ර (3 characters, ZWJ removed)
      const textWithZWJ = 'ක්\u200Dර'; // ක් + ZWJ + ර

      final result = normalizeSearchText(textWithZWJ);

      // Normalized text has 3 chars, so map has 4 entries (3 + end)
      // Position 0 → original 0 (ක)
      // Position 1 → original 1 (්)
      // Position 2 → original 3 (ර) - skips ZWJ at position 2
      // End → original 4
      expect(result.positionMap.length, 4);
      expect(result.positionMap, [0, 1, 3, 4]);
      expect(result.normalized, 'ක්ර');
    });

    test('දකාරාංශය (dakaranshaya): skips ZWJ in ද් combinations', () {
      // "ද්‍ධ" with ZWJ (da + virama + ZWJ + dha) - dakaranshaya form
      // Unicode: ද (0) + ් (1) + ZWJ (2) + ධ (3) = 4 code units
      // Normalized: ද්ධ (3 characters, ZWJ removed)
      const textWithZWJ = 'ද්\u200Dධ'; // ද් + ZWJ + ධ

      final result = normalizeSearchText(textWithZWJ);

      // Normalized text has 3 chars, so map has 4 entries (3 + end)
      // Position 0 → original 0 (ද)
      // Position 1 → original 1 (්)
      // Position 2 → original 3 (ධ) - skips ZWJ at position 2
      // End → original 4
      expect(result.positionMap.length, 4);
      expect(result.positionMap, [0, 1, 3, 4]);
      expect(result.normalized, 'ද්ධ');
    });

    test('handles multiple ZWJ characters in text', () {
      // Text with two ZWJ: "ක්‍ර ද්‍ව" (rakaranshaya + space + dakaranshaya)
      const text = 'ක්\u200Dර ද්\u200Dව';
      // Original positions: ක(0) ්(1) ZWJ(2) ර(3) space(4) ද(5) ්(6) ZWJ(7) ව(8)
      // Normalized: ක්ර ද්ව (7 chars)

      final result = normalizeSearchText(text);

      expect(result.positionMap.length, 8); // 7 normalized chars + end
      expect(result.positionMap, [0, 1, 3, 4, 5, 6, 8, 9]);
      expect(result.normalized, 'ක්ර ද්ව');
    });

    test('handles empty string', () {
      final result = normalizeSearchText('');
      expect(result.positionMap, [0]); // Only end position
      expect(result.normalized, '');
    });

    test('strips sentence punctuation (.;!) from text', () {
      // "16. ස" - period between number and Sinhala character
      const text = '16. ස';
      // Original: 1(0) 6(1) .(2) space(3) ස(4)
      // Normalized: "16 ස" - period stripped, space kept

      final result = normalizeSearchText(text);

      expect(result.normalized, '16 ස');
      expect(result.positionMap, [0, 1, 3, 4, 5]);
    });

    test('strips semicolons and exclamation marks', () {
      const text = 'abc; def! ghi';
      final result = normalizeSearchText(text);

      // Semicolon and ! stripped, whitespace collapsed
      expect(result.normalized, 'abc def ghi');
    });
  });

  group('normalizeText', () {
    test('removes ZWJ from රකාරාංශය', () {
      const withZWJ = 'ක්\u200Dර'; // rakaranshaya form
      const withoutZWJ = 'ක්ර'; // basic form

      expect(normalizeText(withZWJ), withoutZWJ);
      expect(normalizeText(withZWJ), normalizeText(withoutZWJ));
    });

    test('removes ZWJ from දකාරාංශය', () {
      const withZWJ = 'ද්\u200Dධ'; // dakaranshaya form
      const withoutZWJ = 'ද්ධ'; // basic form

      expect(normalizeText(withZWJ), withoutZWJ);
      expect(normalizeText(withZWJ), normalizeText(withoutZWJ));
    });

    test('both forms match after normalization for search', () {
      // Simulating search scenario: query without ZWJ, text with ZWJ
      const query = 'කර්ම'; // User types "karma" → converted to this
      const textInDB = 'කර්\u200Dම'; // Text in DB has ZWJ (repaya form)

      final normalizedQuery = normalizeText(query, toLowerCase: true);
      final normalizedText = normalizeText(textInDB, toLowerCase: true);

      // Both should match after normalization
      expect(normalizedText.contains(normalizedQuery), true);
    });
  });
}
