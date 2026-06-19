import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/core/storage/key_value_store_provider.dart';
import 'package:the_wisdom_project/presentation/providers/pali_letter_options_provider.dart';
import 'package:the_wisdom_project/presentation/widgets/reader/text_entry_widget.dart';

import '../../helpers/fake_key_value_store.dart';

// Test plan §File 3 — TextEntryWidget cache-invalidation.
//
// Target: the hand-rolled display-text cache at _TextEntryWidgetState lines
// ~117-128 and the build-time cache-bust at lines ~241-246.
//
// The cache stores a (text, options) key. Flipping a Pali-letter switch must
// cause build() to detect `options != _options`, call _disposeRecognizers /
// _createRecognizers, and serve the newly computed display string — NOT the
// stale cached one from the previous options.
//
// This is the only path no pure unit test can cover, because the cache and
// its invalidation live inside a ConsumerStatefulWidget lifecycle.
//
// Harness mirrors tab_bar_widget_test.dart:
//   - ProviderContainer constructed manually so tests can flip notifiers
//   - UncontrolledProviderScope wraps the widget tree
//   - MaterialApp + AppLocalizations delegates for localization resolution
//   - keyValueStoreProvider overridden with InMemoryKeyValueStore
//
// Unicode landmarks:
//   ZWJ = U+200D ('‍') — Zero-Width Joiner
//   hal = U+0DCA ('්')  — Sinhala virama
//
//   Default (S2 off): බුද + ZWJ + ්ධ  = 'බුද‍්ධ'   (touching)
//   All-on  (S2 on ): බුද + ් + ZWJ + ධ = 'බුද්‍ධ'  (special-ligated)
void main() {
  // ---------------------------------------------------------------------------
  // Helper: pump the widget under test inside the standard harness.
  //
  // We need direct access to the ProviderContainer to flip notifiers mid-test,
  // so we use UncontrolledProviderScope instead of the pumpApp() extension (which
  // builds its own internal ProviderScope that callers cannot reach).
  // ---------------------------------------------------------------------------
  Future<ProviderContainer> pumpTextEntry(
    WidgetTester tester, {
    required String text,
    InMemoryKeyValueStore? store,
    List<Override> extraOverrides = const [],
  }) async {
    final kvStore = store ?? InMemoryKeyValueStore();

    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(kvStore),
        ...extraOverrides,
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TextEntryWidget(
              text: text,
              // enableTap: true is required so the widget takes the Text.rich
              // branch (which uses _displayText with ZWJ transforms applied).
              // onWordTap must also be non-null to avoid the short-circuit at
              // build() line 272: `(!widget.enableTap || widget.onWordTap == null)`
              enableTap: true,
              onWordTap: (_, __) {},
            ),
          ),
        ),
      ),
    );

    return container;
  }

  // ---------------------------------------------------------------------------
  // Cache-invalidation: S2 off → touching form, then S2 on → special-ligated
  // ---------------------------------------------------------------------------
  //
  // Step 1 — pump with defaults (S2 off). The cache computes the touching form.
  // Step 2 — flip specialConjuncts to true via the notifier. build() watches
  //           paliLetterOptionsProvider; detecting options != _options it busts
  //           the cache and recomputes the display string.
  // Step 3 — assert the widget now renders the special-ligated form, not the
  //           stale touching form from step 1.
  group('Cache invalidation on Pali-letter switch flip -', () {
    testWidgets(
        'starts with the default touching form, '
        'then re-renders the special-ligated form after S2 is enabled',
        (tester) async {
      // ARRANGE — pump with the default options (specialConjuncts = false).
      // Default S3+S1 on, S2 off: ද්ධ is NOT in the special list, so it falls
      // through to the S1 touching pass → ZWJ before hal → 'බුද‍්ධ'.
      const paliWord = 'බුද්ධ';

      // Touching form:  'බ' 'ු' 'ද' ZWJ '්' 'ධ'
      const touchingForm = 'බුද‍්ධ';
      // Special-ligated: 'බ' 'ු' 'ද' '්' ZWJ 'ධ'
      const ligatedForm = 'බුද්‍ධ';

      final container = await pumpTextEntry(tester, text: paliWord);

      // ACT (step 1) — settle after initial pump.
      await tester.pump();

      // ASSERT — The default touching form is rendered. The RichText that
      // Text.rich produces has a toPlainText() equal to the display string.
      expect(find.text(touchingForm), findsOneWidget,
          reason: 'Default options (S2 off) must render the touching form');

      // Confirm the ligated form is NOT present yet.
      expect(find.text(ligatedForm), findsNothing,
          reason: 'Special-ligated form must not appear before S2 is enabled');

      // ACT (step 2) — flip specialConjuncts to true.
      await container.read(specialConjunctsProvider.notifier).set(true);

      // A single pump triggers the reactive rebuild (ref.watch fires).
      await tester.pump();

      // ASSERT — The cache was busted. The widget now renders the special-ligated
      // form, proving the stale cached string was discarded.
      expect(find.text(ligatedForm), findsOneWidget,
          reason: 'After S2 enabled, the special-ligated form must be rendered');

      expect(find.text(touchingForm), findsNothing,
          reason: 'The stale touching form must not persist after cache bust');
    });

    testWidgets(
        'toggling S2 back off restores the touching form '
        '(round-trip cache invalidation)',
        (tester) async {
      const paliWord = 'බුද්ධ';
      const touchingForm = 'බුද‍්ධ';
      const ligatedForm = 'බුද්‍ධ';

      final container = await pumpTextEntry(tester, text: paliWord);
      await tester.pump();

      // Enable S2 — go to ligated form.
      await container.read(specialConjunctsProvider.notifier).set(true);
      await tester.pump();
      expect(find.text(ligatedForm), findsOneWidget);

      // Disable S2 again — must revert to touching form.
      await container.read(specialConjunctsProvider.notifier).set(false);
      await tester.pump();

      expect(find.text(touchingForm), findsOneWidget,
          reason: 'Disabling S2 must revert to the touching form');
      expect(find.text(ligatedForm), findsNothing);
    });

    testWidgets(
        'disabling S1 (touching) removes ZWJ entirely — all-off baseline',
        (tester) async {
      const paliWord = 'බුද්ධ';
      const bare = 'බුද්ධ'; // no ZWJ at all
      const touchingForm = 'බුද‍්ධ';

      final container = await pumpTextEntry(tester, text: paliWord);
      await tester.pump();

      // Confirm default touching form is present.
      expect(find.text(touchingForm), findsOneWidget);

      // Disable S3 (standard ligatures) and S1 (touching) — S2 already off.
      await container.read(standardLigaturesProvider.notifier).set(false);
      await container.read(touchingProvider.notifier).set(false);
      await tester.pump();

      // With all switches off the transformer only strips existing ZWJ.
      // Input has none, so output == input.
      expect(find.text(bare), findsOneWidget,
          reason: 'All switches off must render bare text with no ZWJ');
      expect(find.text(touchingForm), findsNothing);
    });
  });
}
