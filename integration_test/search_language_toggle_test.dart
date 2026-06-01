/// Search-language toggle (පාළි / සිංහල) — E2E smoke test.
///
/// Runs against the **real** FTS database + navigation tree (no mocks). This is
/// the ONE integration test for the feature: it proves the whole chain is wired
/// with real dependencies — open Refine → tap a language segment → re-search →
/// real SQLite `m.language` filter → tab badge updates. Every logic permutation
/// is already covered by the unit/widget tests, so one end-to-end flow suffices.
///
/// Assertions are INVARIANTS, not absolute numbers (the bundled DB content can
/// change between builds): the two single-language counts must partition the
/// both-languages total, because every FTS row is tagged with exactly one
/// language (pali | sinh). That also catches a filter that is silently ignored
/// (then pali == sinh == both, so pali + sinh = 2·both ≠ both for a non-empty
/// baseline).
///
/// Run with:
///   flutter test integration_test/all_tests.dart -d macos
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result_type.dart';

import 'search_test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  int ftsCount(WidgetTester tester) =>
      tester.getResultCounts()[SearchResultType.fullText] ?? 0;

  group('Search language toggle (පාළි / සිංහල)', () {
    testWidgets(
      'narrowing the search language re-filters FTS counts end-to-end',
      (tester) async {
        await tester.pumpSearchApp(prefs);

        // "dhamma" (Sinhala script) — a common term with matches in both the
        // Pali source and the Sinhala translation.
        await tester.searchFor('ධම්ම');
        final both = ftsCount(tester);
        expect(both, greaterThan(0),
            reason: 'baseline (both languages) should find FTS matches');

        // Narrow to Pali only.
        await tester.setSearchLanguages(pali: true, sinhala: false);
        final paliOnly = ftsCount(tester);

        // Narrow to Sinhala only.
        await tester.setSearchLanguages(pali: false, sinhala: true);
        final sinhalaOnly = ftsCount(tester);

        // A single-language subset can't exceed the both-languages total...
        expect(paliOnly, lessThanOrEqualTo(both));
        expect(sinhalaOnly, lessThanOrEqualTo(both));
        // ...and the two subsets must partition it exactly (one language per
        // row). This fails loudly if the language filter is ignored.
        //
        // Assumes the bundled DB's integrity: every FTS row has exactly one
        // meta partner whose language is pali|sinh. `both` is a bare MATCH count
        // (no meta join) while the singles JOIN meta — so an orphan FTS row (no
        // meta partner) or a stray third language would inflate `both` and break
        // this exact `==` first. If the DB-build pipeline ever changes and this
        // flakes, relax to `>=`; don't delete it — the `<=` guards above stay
        // valid regardless, but only this `==` catches a silently-dropped filter.
        expect(paliOnly + sinhalaOnly, equals(both));

        // Restoring both languages returns to the baseline count.
        await tester.setSearchLanguages(pali: true, sinhala: true);
        expect(ftsCount(tester), equals(both));
      },
    );
  });
}
