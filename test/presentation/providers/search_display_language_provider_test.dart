import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/domain/entities/content/content_language.dart';
import 'package:the_wisdom_project/presentation/providers/content_language_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_display_language_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_state.dart';

/// A no-op [SearchStateNotifier] stand-in that just holds a fixed [SearchState].
/// The provider under test only reads `searchInPali` / `searchInSinhala`, so we
/// don't need the real notifier (which requires repositories).
class _FakeSearchStateNotifier extends StateNotifier<SearchState>
    implements SearchStateNotifier {
  _FakeSearchStateNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'Not needed for this test: ${invocation.memberName}',
      );
}

void main() {
  /// Builds a container where the two language toggles and the global reading
  /// language are pinned, then returns the resolved search-display language.
  ContentLanguage resolve({
    required bool pali,
    required bool sinhala,
    required ContentLanguage readingPreference,
  }) {
    final container = ProviderContainer(
      overrides: [
        searchStateProvider.overrideWith(
          (ref) => _FakeSearchStateNotifier(
            SearchState(
              rawQueryText: 'metta',
              searchInPali: pali,
              searchInSinhala: sinhala,
            ),
          ),
        ),
        // The "both on" branch falls back to this global reading preference.
        effectiveContentLanguageProvider.overrideWithValue(readingPreference),
      ],
    );
    addTearDown(container.dispose);
    return container.read(effectiveSearchDisplayLanguageProvider);
  }

  group('effectiveSearchDisplayLanguageProvider', () {
    test('both toggles on → follows the reading preference (Sinhala)', () {
      expect(
        resolve(
            pali: true,
            sinhala: true,
            readingPreference: ContentLanguage.sinhala),
        ContentLanguage.sinhala,
      );
    });

    test('both toggles on → follows the reading preference (Pali)', () {
      expect(
        resolve(
            pali: true, sinhala: true, readingPreference: ContentLanguage.pali),
        ContentLanguage.pali,
      );
    });

    test('Pali-only → Pali, overriding a Sinhala reading preference', () {
      // Narrowing the search to one language wins over the reading pref, so the
      // label contains the matched term (and agrees with the FTS snippet).
      expect(
        resolve(
            pali: true,
            sinhala: false,
            readingPreference: ContentLanguage.sinhala),
        ContentLanguage.pali,
      );
    });

    test('Sinhala-only → Sinhala, overriding a Pali reading preference', () {
      expect(
        resolve(
            pali: false,
            sinhala: true,
            readingPreference: ContentLanguage.pali),
        ContentLanguage.sinhala,
      );
    });

    test('both off (defensive) → falls back to the reading preference', () {
      // The UI prevents this (SegmentedButton emptySelectionAllowed:false), but
      // the provider must not crash — fromFlags maps (false,false) → both.
      expect(
        resolve(
            pali: false,
            sinhala: false,
            readingPreference: ContentLanguage.sinhala),
        ContentLanguage.sinhala,
      );
    });
  });
}
