// Tests for the pure conjunct-transformation pipeline.
//
// Test plan §File 1 (priority):
//   1. Behaviour grid — 4 representative states over a single sentence
//   2. Vowel shortening (S1 side-effect)
//   3. Idempotency
//   4. Deliberate exclusions
//   5. Position-map round-trip (applyConjunctsWithRangeMapping)
//   6. removeConjunctFormatting
//
// Readability note: the only invisible character these tests hinge on is the
// Zero-Width Joiner. To keep every expected string unambiguous it is written as
// the explicit escape \u200D rather than pasted in invisibly. Visible Sinhala
// letters and the hal mark `්` (U+0DCA) are written as ordinary literals.
//
//   Ligated form:  X ් \u200D Y   (ZWJ AFTER the hal)  — Switch 3 / Switch 2
//   Touching form: X \u200D ් Y   (ZWJ BEFORE the hal) — Switch 1
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/utils/pali_conjunct_transformer.dart';
import 'package:the_wisdom_project/core/utils/pali_letter_options.dart';

void main() {
  // ---------------------------------------------------------------------------
  // 1. Behaviour grid — 4 states over one rich sentence
  // ---------------------------------------------------------------------------
  //
  // Grid sentence: ධර්ම බුද්ධ ධම්ම චන්ද
  //   ධර්ම  — contains a repaya cluster (ර is the FIRST consonant of the cluster).
  //   බුද්ධ — its cluster is a "special" pair, NOT one of the common pairs.
  //   ධම්ම  — its cluster has no pair entry at all (general-only).
  //   චන්ද  — its cluster IS one of the 8 common pairs.
  //
  // What each row proves:
  //   Default  — repaya + common ligate; the special cluster stays un-ligated
  //              (Switch 2 off) so it is "touched" instead; the general-only
  //              cluster is touched; the common cluster ligates AND is shielded
  //              from the touching pass.
  //   All on   — the ONLY change vs Default is the special cluster ligating.
  //   Touching — every cluster is touched, nothing ligates (Switch 1 alone).
  //   All off  — bare text; only zero-width chars are stripped, nothing added.
  group('Behaviour grid -', () {
    const sentence = 'ධර්ම බුද්ධ ධම්ම චන්ද';

    test(
        'Default (S3 on, S2 off, S1 on) — repaya+common ligated; special stays touching',
        () {
      // repaya ligated; special cluster touched (S2 off); general-only touched;
      // common cluster ligated.
      const expected = 'ධර්\u200Dම බුද\u200D්ධ ධම\u200D්ම චන්\u200Dද';

      expect(
        beautifyPaliText(sentence, PaliLetterOptions.defaults),
        equals(expected),
      );
    });

    test(
        'All on (S3 on, S2 on, S1 on) — only delta vs Default is the special cluster',
        () {
      // With Switch 2 on the special cluster ligates (hal then ZWJ), which also
      // shields it from the touching pass. Everything else matches Default.
      const allOn = PaliLetterOptions(
        standardLigatures: true,
        specialConjuncts: true,
        touching: true,
      );

      const expected = 'ධර්\u200Dම බුද්\u200Dධ ධම\u200D්ම චන්\u200Dද';

      expect(beautifyPaliText(sentence, allOn), equals(expected));
    });

    test(
        'Touching only (S3 off, S2 off, S1 on) — every cluster touched, none ligated',
        () {
      // No ligation tiers run, so every hal gets a ZWJ inserted before it.
      const touchingOnly = PaliLetterOptions(
        standardLigatures: false,
        specialConjuncts: false,
        touching: true,
      );

      const expected = 'ධර\u200D්ම බුද\u200D්ධ ධම\u200D්ම චන\u200D්ද';

      expect(beautifyPaliText(sentence, touchingOnly), equals(expected));
    });

    test('All off (PaliLetterOptions.baseline) — bare text, no ZWJ inserted', () {
      // All three switches off: the input has no zero-width chars to strip, so
      // the output must equal the raw input exactly.
      expect(
        beautifyPaliText(sentence, PaliLetterOptions.baseline),
        equals(sentence),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Vowel shortening (S1 side-effect)
  // ---------------------------------------------------------------------------
  //
  // Switch 1 also shortens long vowels: ේ (U+0DDA) → ෙ (U+0DD9) and
  // ෝ (U+0DDD) → ො (U+0DDC). With Switch 1 off the long vowels are left alone.
  group('Vowel shortening (S1) -', () {
    const longVowelText = 'තේ සෝ';

    test('S1 on → long vowels shortened; S1 off → unchanged', () {
      const withS1 = PaliLetterOptions(
        standardLigatures: false,
        specialConjuncts: false,
        touching: true,
      );
      const expected = 'තෙ සො';

      expect(beautifyPaliText(longVowelText, withS1), equals(expected));

      // With Switch 1 off (baseline) the long vowels are preserved.
      expect(
        beautifyPaliText(longVowelText, PaliLetterOptions.baseline),
        equals(longVowelText),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Idempotency
  // ---------------------------------------------------------------------------
  //
  // Every call strips existing zero-width chars first, so applying the defaults
  // twice must give the same result as applying them once.
  group('Idempotency -', () {
    test('beautifyPaliText applied twice equals applying it once', () {
      const sample = 'ධර්ම බුද්ධ ධම්ම චන්ද';

      final once = beautifyPaliText(sample, PaliLetterOptions.defaults);
      final twice = beautifyPaliText(once, PaliLetterOptions.defaults);

      expect(twice, equals(once));
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Deliberate exclusions
  // ---------------------------------------------------------------------------
  //
  // Two clusters are intentionally kept OUT of the special list (see the plan
  // doc, §3). Options here are S3 off, S2 ON, S1 off, so ONLY the special tier
  // runs and we can observe whether it (wrongly) binds these clusters.
  group('Deliberate exclusions -', () {
    const specialOnly = PaliLetterOptions(
      standardLigatures: false,
      specialConjuncts: true,
      touching: false,
    );

    test('ම්බ is not in the special list — left unchanged', () {
      // ම (U+0DB8) + hal (U+0DCA) + බ (U+0DB6). The special tier must not bind it.
      const input = 'ම්බ'; // ම ් බ
      expect(beautifyPaliText(input, specialOnly), equals(input));
    });

    // Guards the prenasalisation exclusion (plan doc §3): the cluster
    // ඞ + hal + ග (plain ga, U+0D9C) must NOT be silently collapsed into
    // the single prenasalised letter ඟ (U+0D9F) — that substitution can
    // change a word's meaning, so it is deliberately out of scope. With only
    // the special tier running, the cluster must stay exactly as written.
    test('ඞ්ග is not collapsed into the single letter ඟ', () {
      const input = 'ඞ්ග'; // ඞ ් ග  (plain ga, U+0D9C)
      final result = beautifyPaliText(input, specialOnly);
      expect(result, equals(input));
      // Explicitly: the special tier must not have produced ඟ.
      expect(result.contains('ඟ'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Position-map round-trip (highest-risk math)
  // ---------------------------------------------------------------------------
  //
  // Transforming the text inserts a ZWJ, which shifts every later index by +1.
  // applyConjunctsWithRangeMapping must remap a raw range onto the display text
  // so a highlight still covers the same letters.
  group('Position map round-trip -', () {
    test(
        'common conjunct inserts ZWJ and remapped range slices the new display span',
        () {
      // raw "චන්ද" (ච න ් ද, length 4). Defaults ligate the common cluster,
      // giving display "චන්\u200Dද" (ච න ් ZWJ ද, length 5).
      //
      // The inserted ZWJ pushes ද from index 3 → 4, so the raw range (1,4)
      // covering "න්ද" remaps to (1,5) on the display text.
      const raw = 'චන්ද';
      const ranges = [(start: 1, end: 4)];

      final (displayText, remappedRanges) =
          applyConjunctsWithRangeMapping(raw, ranges, PaliLetterOptions.defaults);

      const expectedDisplay = 'චන්\u200Dද';
      expect(displayText, equals(expectedDisplay));

      expect(remappedRanges, hasLength(1));
      expect(remappedRanges.first.start, equals(1));
      expect(remappedRanges.first.end, equals(5));

      // Slicing the display with the remapped range still yields "න්ද" (+ ZWJ).
      const expectedSlice = 'න්\u200Dද';
      expect(
        displayText.substring(
            remappedRanges.first.start, remappedRanges.first.end),
        equals(expectedSlice),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 6. removeConjunctFormatting
  // ---------------------------------------------------------------------------
  //
  // Strips ZWJ/ZWNJ to restore plain text for dictionary lookup. It does NOT
  // reverse vowel shortening.
  group('removeConjunctFormatting -', () {
    test('ZWJ is stripped from a ligated form', () {
      // "චන්\u200Dද" (common ligated) → "චන්ද" (ZWJ removed).
      const ligated = 'චන්\u200Dද';
      const bare = 'චන්ද';

      expect(removeConjunctFormatting(ligated), equals(bare));
    });

    test('a shortened vowel is left as-is — not restored to the long form', () {
      // removeConjunctFormatting only strips ZWJ/ZWNJ; a short vowel stays short.
      const shortened = 'තෙ';
      expect(removeConjunctFormatting(shortened), equals(shortened));
    });
  });
}
