import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/domain/entities/search/search_language_scope.dart';

// Tests the ONE place that interprets the පාළි / සිංහල toggle flags. Every
// consumer (FTS filter, title gating, result-label language) derives its
// behaviour from SearchLanguageScope.fromFlags, so locking this truth table
// here guards all three against drift.
void main() {
  group('SearchLanguageScope.fromFlags', () {
    // The four possible (searchInPali, searchInSinhala) combinations — exhaustive.

    test('both toggles on → both (the default)', () {
      expect(
        SearchLanguageScope.fromFlags(
          searchInPali: true,
          searchInSinhala: true,
        ),
        SearchLanguageScope.both,
      );
    });

    test('only Pali on → pali', () {
      expect(
        SearchLanguageScope.fromFlags(
          searchInPali: true,
          searchInSinhala: false,
        ),
        SearchLanguageScope.pali,
      );
    });

    test('only Sinhala on → sinhala', () {
      expect(
        SearchLanguageScope.fromFlags(
          searchInPali: false,
          searchInSinhala: true,
        ),
        SearchLanguageScope.sinhala,
      );
    });

    test('both off (unreachable) degrades to both, not "search nothing"', () {
      // both-off can't happen at runtime (the SegmentedButton uses
      // emptySelectionAllowed:false and the flags aren't persisted, so they
      // default to true/true). If it somehow occurred, fromFlags maps it to
      // `both` — i.e. search everything rather than return an empty screen.
      expect(
        SearchLanguageScope.fromFlags(
          searchInPali: false,
          searchInSinhala: false,
        ),
        SearchLanguageScope.both,
      );
    });
  });
}
