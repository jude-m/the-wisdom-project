import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_wisdom_project/presentation/widgets/settings_menu_button.dart';
import 'package:the_wisdom_project/presentation/providers/document_provider.dart';
import 'package:the_wisdom_project/presentation/providers/navigation_tree_provider.dart';
import 'package:the_wisdom_project/presentation/models/column_display_mode.dart';
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

      // Verify all sections present
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Navigation Language'), findsOneWidget);
      expect(find.text('Sutta Language'), findsOneWidget);

      // Verify all theme options
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Warm'), findsOneWidget);

      // Verify language options
      expect(find.text('Pali'), findsOneWidget);
      expect(find.text('සිංහල'), findsOneWidget);

      // Verify sutta language (column mode) options
      expect(find.text('P'), findsOneWidget);
      expect(find.text('P+S'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
    });

    testWidgets('should update providers when options selected',
        (tester) async {
      // We'll use a container to read providers
      final container = ProviderContainer();

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

      // Change Navigation Language to Sinhala
      await tester.tap(find.text('සිංහල'));
      await tester.pumpAndSettle();
      expect(container.read(navigationLanguageProvider),
          NavigationLanguage.sinhala);

      // Change Sutta Language (Column Mode)
      // Note: 'P' text might be inside the SegmentedButton
      await tester.tap(find.text('S'));
      await tester.pumpAndSettle();
      expect(container.read(columnDisplayModeProvider),
          ColumnDisplayMode.sinhalaOnly);

      await tester.tap(find.text('P+S'));
      await tester.pumpAndSettle();
      expect(container.read(columnDisplayModeProvider), ColumnDisplayMode.both);
    });
  });
}
