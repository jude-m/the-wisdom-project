import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/presentation/models/in_page_search_state.dart';

void main() {
  group('InPageMatch -', () {
    test('equality and hashCode based on all fields', () {
      const a = InPageMatch(
        pageIndex: 0, entryIndex: 2, languageCode: 'pi', matchIndexInEntry: 1,
      );
      const same = InPageMatch(
        pageIndex: 0, entryIndex: 2, languageCode: 'pi', matchIndexInEntry: 1,
      );
      const different = InPageMatch(
        pageIndex: 0, entryIndex: 2, languageCode: 'si', matchIndexInEntry: 1,
      );

      expect(a, equals(same));
      expect(a.hashCode, equals(same.hashCode));
      expect(a, isNot(equals(different)));
    });
  });

  group('InPageSearchState -', () {
    test('copyWith updates specified fields and preserves others', () {
      final original = InPageSearchState(
        isVisible: true,
        rawQuery: 'ධම්ම',
        effectiveQuery: 'ධම්ම',
        matches: const [
          InPageMatch(
            pageIndex: 0, entryIndex: 0, languageCode: 'pi', matchIndexInEntry: 0,
          ),
        ],
        currentMatchIndex: 0,
      );

      final updated = original.copyWith(currentMatchIndex: -1);

      expect(updated.currentMatchIndex, -1);
      expect(updated.isVisible, true);
      expect(updated.rawQuery, 'ධම්ම');
      expect(updated.matches.length, 1);
    });

    test('isSinglishConverted requires both queries non-empty and different', () {
      // True: different queries
      expect(
        InPageSearchState(rawQuery: 'dhamma', effectiveQuery: 'ධම්ම')
            .isSinglishConverted,
        true,
      );
      // False: same queries
      expect(
        InPageSearchState(rawQuery: 'ධම්ම', effectiveQuery: 'ධම්ම')
            .isSinglishConverted,
        false,
      );
      // False: either empty
      expect(
        InPageSearchState(rawQuery: '', effectiveQuery: 'ධම්ම')
            .isSinglishConverted,
        false,
      );
    });

    test('hasActiveQuery requires both visible and non-empty effectiveQuery', () {
      expect(
        InPageSearchState(isVisible: true, effectiveQuery: 'සුතං').hasActiveQuery,
        true,
      );
      expect(
        InPageSearchState(isVisible: false, effectiveQuery: 'සුතං').hasActiveQuery,
        false,
      );
      expect(
        InPageSearchState(isVisible: true, effectiveQuery: '').hasActiveQuery,
        false,
      );
    });

    test('currentMatch returns null for invalid index, match for valid', () {
      const matches = [
        InPageMatch(pageIndex: 0, entryIndex: 0, languageCode: 'pi', matchIndexInEntry: 0),
        InPageMatch(pageIndex: 1, entryIndex: 2, languageCode: 'si', matchIndexInEntry: 0),
      ];

      expect(
        InPageSearchState(matches: matches, currentMatchIndex: 1).currentMatch,
        equals(matches[1]),
      );
      expect(
        InPageSearchState(matches: matches, currentMatchIndex: -1).currentMatch,
        isNull,
      );
      expect(
        InPageSearchState(matches: matches, currentMatchIndex: 5).currentMatch,
        isNull,
      );
    });

    test('matchedEntries deduplicates and hasMatchInEntry checks correctly', () {
      final state = InPageSearchState(
        matches: const [
          InPageMatch(pageIndex: 0, entryIndex: 1, languageCode: 'pi', matchIndexInEntry: 0),
          InPageMatch(pageIndex: 0, entryIndex: 1, languageCode: 'pi', matchIndexInEntry: 1),
          InPageMatch(pageIndex: 2, entryIndex: 0, languageCode: 'si', matchIndexInEntry: 0),
        ],
      );

      // Two matches in same entry → only one tuple
      expect(state.matchedEntries.length, 2);
      expect(state.hasMatchInEntry(0, 1, 'pi'), true);
      expect(state.hasMatchInEntry(2, 0, 'si'), true);
      // Non-matching lookups
      expect(state.hasMatchInEntry(0, 0, 'pi'), false);
      expect(state.hasMatchInEntry(0, 1, 'si'), false);

      // Empty state
      expect(InPageSearchState().matchedEntries, isEmpty);
    });
  });
}
