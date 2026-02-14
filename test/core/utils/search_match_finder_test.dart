import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/utils/search_match_finder.dart';

void main() {
  group('SearchMatchFinder -', () {
    group('exact phrase mode (isPhraseSearch: true, isExactMatch: true)', () {
      test('finds single occurrence in Pali text', () {
        final finder = SearchMatchFinder(
          queryText: 'සුතං',
          isPhraseSearch: true,
          isExactMatch: true,
        );

        final ranges = finder.findMatchRanges('එවං මෙ සුතං එකං සමයං');
        expect(ranges.length, 1);
      });

      test('finds multiple occurrences', () {
        final finder = SearchMatchFinder(
          queryText: 'ධම්මස්ස',
          isPhraseSearch: true,
          isExactMatch: true,
        );

        final ranges = finder.findMatchRanges(
          'ධම්මස්ස අවණ්ණං භාසති, ධම්මස්ස වණ්ණං භාසති',
        );
        expect(ranges.length, 2);
      });

      test('returns empty list for empty query or no match', () {
        final noMatch = SearchMatchFinder(
          queryText: 'නිබ්බාන',
          isPhraseSearch: true,
          isExactMatch: true,
        );
        expect(noMatch.findMatchRanges('එවං මෙ සුතං'), isEmpty);

        final empty = SearchMatchFinder(
          queryText: '',
          isPhraseSearch: true,
          isExactMatch: true,
        );
        expect(empty.findMatchRanges('එවං මෙ සුතං'), isEmpty);
      });

      test('handles ZWJ characters in Sinhala translation text', () {
        final finder = SearchMatchFinder(
          queryText: 'සූත්ර', // without ZWJ
          isPhraseSearch: true,
          isExactMatch: true,
        );

        // Text with ZWJ conjunct: සූත්‍ර
        final ranges = finder.findMatchRanges('බ්‍රහ්මජාල සූත්‍රය');
        expect(ranges.length, 1);
      });

      test('falls back to phrase search for multi-word query with hyphenated text',
          () {
        final finder = SearchMatchFinder(
          queryText: 'සීල සමාධි',
          isPhraseSearch: true,
          isExactMatch: true,
        );

        final ranges = finder.findMatchRanges('සීල-සමාධි පඤ්ඤා');
        expect(ranges.length, 1);
      });
    });

    group('phrase mode (isPhraseSearch: true, isExactMatch: false)', () {
      test('finds adjacent words within gap', () {
        final finder = SearchMatchFinder(
          queryText: 'එවං සුතං',
          isPhraseSearch: true,
          isExactMatch: false,
        );

        final ranges = finder.findMatchRanges('එවං මෙ සුතං එකං සමයං');
        expect(ranges.length, 1);
        expect(ranges[0].start, 0);
      });

      test('returns empty when words are too far apart', () {
        final finder = SearchMatchFinder(
          queryText: 'එවං සමයං',
          isPhraseSearch: true,
          isExactMatch: false,
          maxGap: 3,
        );

        final ranges = finder.findMatchRanges('එවං මෙ සුතං එකං සමයං');
        expect(ranges, isEmpty);
      });
    });

    group('separate words mode (isPhraseSearch: false)', () {
      test('finds each word independently', () {
        final finder = SearchMatchFinder(
          queryText: 'බුද්ධ සඞ්ඝ',
          isPhraseSearch: false,
          isExactMatch: true,
        );

        final ranges = finder.findMatchRanges('සඞ්ඝස්ස වණ්ණං බුද්ධස්ස');
        expect(ranges.length, 2);
      });

      test('merges overlapping ranges', () {
        final finder = SearchMatchFinder(
          queryText: 'එව එවං',
          isPhraseSearch: false,
          isExactMatch: true,
        );

        final ranges = finder.findMatchRanges('එවං මෙ සුතං');
        expect(ranges.length, 1);
      });
    });
  });

  group('NormalizedTextMatcher -', () {
    test('strips ZWJ and maps positions back to original', () {
      final matcher = NormalizedTextMatcher('සූත්\u200Dරය');
      expect(matcher.normalized, 'සූත්රය');
      expect(matcher.original, 'සූත්\u200Dරය');

      // Verify position mapping with a simpler case
      final simple = NormalizedTextMatcher('අ\u200Dබ');
      expect(simple.normalized, 'අබ');
      // Normalized index 1 ('බ') → original index 2 (skips ZWJ at 1)
      final range = simple.mapToOriginal(1, 2);
      expect(range.start, 2);
      expect(range.end, 3);
    });

    test('lowercases Latin and preserves Sinhala', () {
      expect(NormalizedTextMatcher('Hello WORLD').normalized, 'hello world');
      const sinhala = 'මෙසේ මා විසින්';
      expect(NormalizedTextMatcher(sinhala).normalized, sinhala);
    });
  });

  group('splitQueryWords -', () {
    test('splits on whitespace and normalizes', () {
      expect(splitQueryWords('එවං  මෙ   සුතං'), ['එවං', 'මෙ', 'සුතං']);
      expect(splitQueryWords(''), isEmpty);
    });
  });

  group('mergeOverlappingRanges -', () {
    test('merges overlapping and adjacent ranges', () {
      final merged = mergeOverlappingRanges([
        (start: 0, end: 5),
        (start: 3, end: 8),
      ]);
      expect(merged.length, 1);
      expect(merged[0], (start: 0, end: 8));

      // Adjacent (end == start) also merges
      final adjacent = mergeOverlappingRanges([
        (start: 0, end: 5),
        (start: 5, end: 10),
      ]);
      expect(adjacent.length, 1);
    });

    test('keeps non-overlapping ranges separate', () {
      final merged = mergeOverlappingRanges([
        (start: 0, end: 3),
        (start: 5, end: 8),
      ]);
      expect(merged.length, 2);
    });

    test('handles fully contained range', () {
      final merged = mergeOverlappingRanges([
        (start: 0, end: 10),
        (start: 3, end: 5),
      ]);
      expect(merged.length, 1);
      expect(merged[0], (start: 0, end: 10));
    });
  });
}
