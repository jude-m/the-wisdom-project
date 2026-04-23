import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_wisdom_project/presentation/widgets/settings_menu_button.dart';
import 'package:the_wisdom_project/presentation/providers/navigation_tree_provider.dart';
import 'package:the_wisdom_project/domain/entities/navigation/navigation_language.dart';

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
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Font Size'), findsOneWidget);
      expect(find.text('Navigation Language'), findsOneWidget);

      // Verify all theme options
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Warm'), findsOneWidget);

      // Verify language options
      expect(find.text('Pali'), findsOneWidget);
      expect(find.text('සිංහල'), findsOneWidget);
    });

    testWidgets('should update providers when options selected',
        (tester) async {
      // Use a container so we can read providers directly.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SettingsMenuButton(),
            ),
          ),
        ),
      );

      // Open menu
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Change Navigation Language to Pali
      await tester.tap(find.text('Pali').first);
      await tester.pumpAndSettle();
      expect(
          container.read(navigationLanguageProvider), NavigationLanguage.pali);

      // Re-open the menu (PopupMenu closes after a selection).
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Change Navigation Language to Sinhala
      await tester.tap(find.text('සිංහල'));
      await tester.pumpAndSettle();
      expect(container.read(navigationLanguageProvider),
          NavigationLanguage.sinhala);
    });
  });
}
