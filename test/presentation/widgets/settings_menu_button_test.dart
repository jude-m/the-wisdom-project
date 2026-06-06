import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_wisdom_project/presentation/widgets/app/settings_menu_button.dart';
import 'package:the_wisdom_project/presentation/providers/content_language_provider.dart';
import 'package:the_wisdom_project/domain/entities/content/content_language.dart';
import 'package:the_wisdom_project/domain/entities/content/edition.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/core/storage/key_value_store_provider.dart';
import 'package:the_wisdom_project/core/storage/storage_keys.dart';

import '../../helpers/fake_key_value_store.dart';
import '../../helpers/pump_app.dart';

void main() {
  group('SettingsMenuButton', () {
    testWidgets('should render complete settings menu structure', (tester) async {
      await tester.pumpApp(const SettingsMenuButton());

      // Initially menu is closed
      expect(find.byType(PopupMenuItem), findsNothing);

      // Open menu
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Verify all sections present. The reader layout (P/P+S/S)
      // selector lives per-tab now, so it is no longer in this menu.
      // "Navigation Language" was split into two independent axes:
      // App Language (UI chrome) and Content Language (text labels).
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Font Size'), findsOneWidget);
      expect(find.text('App Language'), findsOneWidget);
      expect(find.text('Content Language'), findsOneWidget);

      // Verify theme options. Dark/Warm are temporarily commented out
      // in `_ThemeSelector` until light/dark theming is reworked, so only
      // 'Light' is asserted today.
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsNothing);
      expect(find.text('Warm'), findsNothing);

      // Verify language options (English UI locale labels):
      //  - App Language segments:     'English' + 'සිංහල' (self-labelled)
      //  - Content Language segments: 'Pali' + 'Sinhala' (localized)
      expect(find.text('English'), findsOneWidget);
      expect(find.text('සිංහල'), findsOneWidget);
      expect(find.text('Pali'), findsOneWidget);
      expect(find.text('Sinhala'), findsOneWidget);
    });

    testWidgets('should update providers when options selected',
        (tester) async {
      // Use a container so we can read providers directly.
      // createTestContainer() supplies the in-memory KeyValueStore that the
      // Content Language provider reads from.
      final container = createTestContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            // The menu now resolves its section labels via AppLocalizations,
            // so the delegates must be wired up.
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SettingsMenuButton(),
            ),
          ),
        ),
      );

      // Open menu
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Change Content Language to Pali. The enclosing PopupMenuItem is
      // disabled (enabled: false), so selecting a SegmentedButton option
      // updates the provider but does NOT dismiss the popup — the menu stays
      // open and we can switch directly back to Sinhala without re-opening.
      // (The English-locale Content Language labels are 'Pali' / 'Sinhala'.)
      await tester.tap(find.text('Pali'));
      await tester.pumpAndSettle();
      expect(container.read(contentLanguageProvider), ContentLanguage.pali);

      // Change Content Language back to Sinhala (menu still open).
      await tester.tap(find.text('Sinhala'));
      await tester.pumpAndSettle();
      expect(container.read(contentLanguageProvider), ContentLanguage.sinhala);
    });

    // Test plan 2.3 — the only non-obvious content-selector assertion beyond
    // the existing "lists options / selecting updates provider" coverage: the
    // selector's segments and highlight follow the EFFECTIVE (clamped) value,
    // never the raw saved preference. Ties the UI to effectiveContentLanguage.
    testWidgets('content selector shows the effective (clamped) value, not raw',
        (tester) async {
      // Saved raw = Pali, but this edition only offers Sinhala.
      const sinhalaOnlyEdition = Edition(
        editionId: 'stub-si',
        displayName: 'Sinhala Only',
        abbreviation: 'SI',
        type: EditionType.local,
        availableLanguages: ['si'],
      );
      final container = createTestContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(
            InMemoryKeyValueStore({StorageKeys.contentLanguage: 'pali'}),
          ),
          currentEditionProvider.overrideWithValue(sinhalaOnlyEdition),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SettingsMenuButton()),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      final selector = tester.widget<SegmentedButton<ContentLanguage>>(
        find.byType(SegmentedButton<ContentLanguage>),
      );

      // Segments are exactly the edition's available languages (Sinhala only)...
      expect(
        selector.segments.map((s) => s.value).toList(),
        equals(const [ContentLanguage.sinhala]),
      );
      // ...and the highlight is the clamped effective value, NOT the raw Pali.
      expect(selector.selected, equals({ContentLanguage.sinhala}));
      // Sanity: the raw saved preference really is the unsupported Pali.
      expect(container.read(contentLanguageProvider), ContentLanguage.pali);
    });
  });
}
