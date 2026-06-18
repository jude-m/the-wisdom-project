import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/utils/pali_conjunct_transformer.dart';
import 'package:the_wisdom_project/core/utils/pali_letter_options.dart';
import 'package:the_wisdom_project/domain/entities/content/content_language.dart';
import 'package:the_wisdom_project/presentation/utils/content_text_formatter.dart';

// Test plan 1.1 — `formatContentLabel` is the single rendering seam that every
// data label (tree, breadcrumbs, search, tabs) routes through. It must apply
// Pali conjunct ligatures ONLY on the Pali branch and leave Sinhala untouched.
// We assert this once here; every other layer trusts this seam.
void main() {
  group('formatContentLabel -', () {
    // A Pali word (in Sinhala script) that genuinely contains a consonant
    // cluster, so the conjunct transform actually changes it. ධම්ම → ධම්‍ම.
    const sampleWithConjunct = 'ධම්ම';

    test('Pali branch routes through the conjunct transformer (and changes it)',
        () {
      final result = formatContentLabel(
          sampleWithConjunct, ContentLanguage.pali, PaliLetterOptions.defaults);

      // Matches the production transformer exactly...
      expect(
        result,
        equals(beautifyPaliText(sampleWithConjunct, PaliLetterOptions.defaults)),
      );
      // ...and is genuinely different from the raw input (the branch is real,
      // not an accidental no-op).
      expect(result, isNot(equals(sampleWithConjunct)));
    });

    test('Sinhala branch returns the text unchanged (never applies conjuncts)',
        () {
      final result = formatContentLabel(sampleWithConjunct,
          ContentLanguage.sinhala, PaliLetterOptions.defaults);

      // Conjuncts must NEVER bind a Sinhala translation, so the same input that
      // changed under Pali is returned verbatim here.
      expect(result, equals(sampleWithConjunct));
    });
  });
}
