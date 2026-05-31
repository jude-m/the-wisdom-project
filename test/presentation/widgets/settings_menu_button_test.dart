import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_wisdom_project/presentation/widgets/app/settings_menu_button.dart';
import 'package:the_wisdom_project/presentation/providers/content_language_provider.dart';
import 'package:the_wisdom_project/domain/entities/content/content_language.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';

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
          child: MaterialApp(
            // The menu now resolves its section labels via AppLocalizations,
            // so the delegates must be wired up.
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
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
      await tester.tap(find.text('Pali').first);
      await tester.pumpAndSettle();
      expect(container.read(contentLanguageProvider), ContentLanguage.pali);

      // Change Content Language back to Sinhala (menu still open).
      await tester.tap(find.text('Sinhala'));
      await tester.pumpAndSettle();
      expect(container.read(contentLanguageProvider), ContentLanguage.sinhala);
    });
  });
}
