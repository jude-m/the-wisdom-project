/// Dictionary Filter Flow E2E Integration Test
///
/// Tests the complete dictionary filtering flow in the search results panel:
///   1. Search for a word and check definitions (All dictionaries)
///   2. Click "English" filter chip → only English dictionary results
///   3. Open Refine, add one Sinhala dictionary → mixed results
///   4. Open Refine, add the other Sinhala dictionary → "All" auto-selects,
///      count matches step 1
///
/// Uses real FTS database and dictionary — no mocks.
///
/// Run with:
///   flutter test integration_test/dictionary_filter_flow_test.dart -d macos
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_wisdom_project/domain/entities/dictionary/dictionary_filter_operations.dart';
import 'package:the_wisdom_project/domain/entities/dictionary/dictionary_info.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result_type.dart';

import 'search_test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Dictionary filter flow', () {
    testWidgets(
      '1. Search → Definitions → English chip → Refine add Sinhala dicts → All restores',
      (tester) async {
        await tester.pumpSearchApp(prefs);

        // ---------------------------------------------------------------
        // STEP 1: Search for "waasawa" and switch to Definitions tab
        // ---------------------------------------------------------------
        await tester.searchFor('waasawa');
        await tester.switchToTab('Definitions');

        // ASSERT: "All" chip is selected (default state — no filter)
        expect(tester.isDictFilterChipSelected('All'), isTrue,
            reason: 'All chip should be selected by default');

        // Record the baseline count with all dictionaries.
        final allCount = tester.getResultCounts();
        final allDefinitions = allCount[SearchResultType.definition]!;
        expect(allDefinitions, equals(23),
            reason: '"waasawa" should have 23 definitions across all dicts');

        // ---------------------------------------------------------------
        // STEP 2: Click "English" filter chip
        // ---------------------------------------------------------------
        await tester.tapDictFilterChip('English');

        // ASSERT: English chip is selected, All is NOT selected
        expect(tester.isDictFilterChipSelected('English'), isTrue,
            reason: 'English chip should be selected after tap');
        expect(tester.isDictFilterChipSelected('All'), isFalse,
            reason: 'All chip should NOT be selected when English is active');
        expect(tester.isDictFilterChipSelected('Sinhala'), isFalse,
            reason: 'Sinhala chip should NOT be selected');

        // ASSERT: Provider state has exactly the English dictionary IDs
        final stateAfterEnglish = tester.getSearchState();
        expect(
          stateAfterEnglish.selectedDictionaryIds,
          equals(DictionaryFilterOperations.englishIds),
          reason: 'Selected IDs should be exactly the English dictionary set',
        );

        // ASSERT: Fewer definitions than "All"
        final englishCount = tester.getResultCounts();
        final englishDefinitions = englishCount[SearchResultType.definition]!;
        expect(englishDefinitions, lessThan(allDefinitions),
            reason: 'English-only should have fewer definitions than All');
        expect(englishDefinitions, greaterThan(0),
            reason: 'English-only should still have some definitions');

        // ASSERT: All returned results are from English dictionaries
        final englishResults = stateAfterEnglish.fullResults.value;
        expect(englishResults, isNotNull,
            reason: 'Full results should be loaded');
        for (final result in englishResults!) {
          expect(
            DictionaryFilterOperations.englishIds.contains(result.editionId),
            isTrue,
            reason:
                'Result ${result.editionId} should be an English dictionary',
          );
        }

        // ---------------------------------------------------------------
        // STEP 3: Open Refine dialog, add first Sinhala dictionary (BUS)
        // ---------------------------------------------------------------
        await tester.refineDictionaries([DictionaryInfo.getDisplayName('BUS')]);

        // ASSERT: Count increased (English + 1 Sinhala > English only)
        final afterFirstSinhalaCount = tester.getResultCounts();
        final afterFirstSinhala =
            afterFirstSinhalaCount[SearchResultType.definition]!;
        expect(afterFirstSinhala, greaterThan(englishDefinitions),
            reason:
                'Adding one Sinhala dict should increase definitions count');
        expect(afterFirstSinhala, lessThan(allDefinitions),
            reason:
                'English + 1 Sinhala should still be less than All (missing Sumangala)');

        // ASSERT: All chip is NOT selected (custom selection)
        expect(tester.isDictFilterChipSelected('All'), isFalse,
            reason: 'All should not be selected with partial Sinhala dicts');

        // ---------------------------------------------------------------
        // STEP 4: Open Refine dialog, add second Sinhala dictionary (MS)
        //         This completes all dictionaries → "All" auto-selects
        // ---------------------------------------------------------------
        await tester.refineDictionaries([DictionaryInfo.getDisplayName('MS')]);

        // ASSERT: "All" chip is now selected (normalization kicked in)
        expect(tester.isDictFilterChipSelected('All'), isTrue,
            reason:
                'All chip should auto-select when all dictionaries are included');

        // ASSERT: Provider state normalized to empty set (= "All")
        final stateAfterAll = tester.getSearchState();
        expect(stateAfterAll.selectedDictionaryIds, isEmpty,
            reason:
                'Selected IDs should normalize to empty set when all are selected');

        // ASSERT: Definition count matches the original "All" count from step 1
        final restoredCount = tester.getResultCounts();
        final restoredDefinitions =
            restoredCount[SearchResultType.definition]!;
        expect(restoredDefinitions, equals(allDefinitions),
            reason:
                'Restored "All" count ($restoredDefinitions) should match '
                'original All count ($allDefinitions)');
      },
    );

    testWidgets(
      '2. Edge case: unchecking all dicts snaps back to "All"',
      (tester) async {
        await tester.pumpSearchApp(prefs);

        // ---------------------------------------------------------------
        // SETUP: Search and go to Definitions tab, record baseline
        // ---------------------------------------------------------------
        await tester.searchFor('waasawa');
        await tester.switchToTab('Definitions');

        final baselineCount = tester.getResultCounts();
        final baselineDefinitions =
            baselineCount[SearchResultType.definition]!;
        expect(baselineDefinitions, equals(23));

        // ---------------------------------------------------------------
        // STEP 1: Tap "Sinhala" chip (= uncheck English, keep only Sinhala)
        // ---------------------------------------------------------------
        await tester.tapDictFilterChip('Sinhala');

        expect(tester.isDictFilterChipSelected('Sinhala'), isTrue,
            reason: 'Sinhala chip should be selected');
        expect(tester.isDictFilterChipSelected('All'), isFalse,
            reason: 'All should not be selected');
        expect(tester.isDictFilterChipSelected('English'), isFalse,
            reason: 'English should not be selected');

        // Provider should hold exactly the 2 Sinhala IDs
        final stateAfterSinhala = tester.getSearchState();
        expect(
          stateAfterSinhala.selectedDictionaryIds,
          equals(DictionaryFilterOperations.sinhalaIds),
          reason: 'Selected IDs should be exactly the Sinhala dictionary set',
        );

        final sinhalaDefinitions =
            tester.getResultCounts()[SearchResultType.definition]!;
        expect(sinhalaDefinitions, lessThan(baselineDefinitions),
            reason: 'Sinhala-only should have fewer results than All');
        expect(sinhalaDefinitions, greaterThan(0),
            reason: 'Sinhala-only should still have some results');

        // ---------------------------------------------------------------
        // STEP 2: Refine → tap BUS.
        //
        // Because the entire Sinhala parent group {BUS, MS} is fully
        // selected, the dialog NARROWS the selection to just {BUS} (it
        // does not unselect BUS). This matches the search refine UX:
        // tapping a child of a fully-selected parent narrows down rather
        // than removes — see _toggleDictionary in refine_dictionary_dialog.dart.
        // ---------------------------------------------------------------
        await tester.refineDictionaries([DictionaryInfo.getDisplayName('BUS')]);

        final afterNarrowToBus =
            tester.getResultCounts()[SearchResultType.definition]!;
        expect(afterNarrowToBus, lessThan(sinhalaDefinitions),
            reason: 'Narrowing to one Sinhala dict should reduce count');
        expect(afterNarrowToBus, greaterThan(0),
            reason: 'BUS alone should still have some results');

        // Provider should hold only {BUS} after the narrow-down.
        final stateAfterNarrow = tester.getSearchState();
        expect(stateAfterNarrow.selectedDictionaryIds, equals({'BUS'}),
            reason:
                'Tapping BUS while {BUS, MS} is fully selected should '
                'narrow to {BUS} (parent-fully-selected → narrow-down)');

        // ---------------------------------------------------------------
        // STEP 3: Refine → tap BUS again → {} → snaps back to "All".
        //
        // This is the edge case: now {BUS} is the only selection, so its
        // parent group is NOT fully selected. The dialog falls through to
        // the remove-branch, producing an empty set, which the convention
        // treats as "All". The UI should snap back to all-checked instead
        // of showing "nothing selected".
        // ---------------------------------------------------------------
        await tester.refineDictionaries([DictionaryInfo.getDisplayName('BUS')]);

        // ASSERT: Snapped back to "All"
        expect(tester.isDictFilterChipSelected('All'), isTrue,
            reason:
                'Unchecking the last dictionary should snap back to "All"');

        final stateAfterEmpty = tester.getSearchState();
        expect(stateAfterEmpty.selectedDictionaryIds, isEmpty,
            reason: 'Empty set should remain empty (= "All" convention)');

        // ASSERT: Count matches the original baseline
        final restoredDefinitions =
            tester.getResultCounts()[SearchResultType.definition]!;
        expect(restoredDefinitions, equals(baselineDefinitions),
            reason:
                'After snapping back to All, count ($restoredDefinitions) '
                'should match baseline ($baselineDefinitions)');
      },
    );
  });
}
