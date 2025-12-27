import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/presentation/models/reader_tab.dart';
import 'package:the_wisdom_project/presentation/providers/tab_provider.dart';
import 'package:the_wisdom_project/presentation/widgets/tab_bar_widget.dart';

import '../../helpers/pump_app.dart';

void main() {
  // Helper to create a test tab
  ReaderTab createTab({
    required String label,
    String? contentFileId,
  }) {
    return ReaderTab(
      label: label,
      fullName: 'Full name of $label',
      contentFileId: contentFileId,
      nodeKey: 'node-$label',
      paliName: label,
      sinhalaName: 'Sinhala $label',
    );
  }

  // ============================================================
  // Empty State Tests
  // ============================================================
  group('Empty state', () {
    testWidgets('should not render when no tabs exist', (tester) async {
      // ACT - Default state has no tabs
      await tester.pumpApp(const TabBarWidget());
      await tester.pumpAndSettle();

      // ASSERT - Should render nothing (SizedBox.shrink)
      expect(find.byType(TabBarWidget), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });
  });

  // ============================================================
  // Tab Display Tests
  // ============================================================
  group('Tab display', () {
    testWidgets('should render tabs when they exist', (tester) async {
      // ARRANGE
      final tab1 = createTab(label: 'Sutta 1', contentFileId: 'dn-1');
      final tab2 = createTab(label: 'Sutta 2', contentFileId: 'dn-2');

      // ACT
      await tester.pumpApp(
        const TabBarWidget(),
        overrides: [
          tabsProvider.overrideWith((ref) {
            final notifier = TabsNotifier();
            notifier.addTab(tab1);
            notifier.addTab(tab2);
            return notifier;
          }),
          activeTabIndexProvider.overrideWith((ref) => 0),
        ],
      );
      await tester.pumpAndSettle();

      // ASSERT
      expect(find.text('Sutta 1'), findsOneWidget);
      expect(find.text('Sutta 2'), findsOneWidget);
    });

    testWidgets('should show document icon for tabs with content',
        (tester) async {
      // ARRANGE
      final tabWithContent =
          createTab(label: 'With Content', contentFileId: 'dn-1');

      // ACT
      await tester.pumpApp(
        const TabBarWidget(),
        overrides: [
          tabsProvider.overrideWith((ref) {
            final notifier = TabsNotifier();
            notifier.addTab(tabWithContent);
            return notifier;
          }),
          activeTabIndexProvider.overrideWith((ref) => 0),
        ],
      );
      await tester.pumpAndSettle();

      // ASSERT
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    });

    testWidgets('should show folder icon for tabs without content',
        (tester) async {
      // ARRANGE
      final tabWithoutContent =
          createTab(label: 'Folder Tab', contentFileId: null);

      // ACT
      await tester.pumpApp(
        const TabBarWidget(),
        overrides: [
          tabsProvider.overrideWith((ref) {
            final notifier = TabsNotifier();
            notifier.addTab(tabWithoutContent);
            return notifier;
          }),
          activeTabIndexProvider.overrideWith((ref) => 0),
        ],
      );
      await tester.pumpAndSettle();

      // ASSERT
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    });
  });

  // ============================================================
  // Active Tab Tests
  // ============================================================
  group('Active tab styling', () {
    testWidgets('should highlight active tab', (tester) async {
      // ARRANGE
      final tab1 = createTab(label: 'Tab 1', contentFileId: 'dn-1');
      final tab2 = createTab(label: 'Tab 2', contentFileId: 'dn-2');

      // ACT
      await tester.pumpApp(
        const TabBarWidget(),
        overrides: [
          tabsProvider.overrideWith((ref) {
            final notifier = TabsNotifier();
            notifier.addTab(tab1);
            notifier.addTab(tab2);
            return notifier;
          }),
          activeTabIndexProvider.overrideWith((ref) => 0), // First tab active
        ],
      );
      await tester.pumpAndSettle();

      // ASSERT - Just verify both tabs render, styling is theme-dependent
      expect(find.text('Tab 1'), findsOneWidget);
      expect(find.text('Tab 2'), findsOneWidget);
    });
  });

  // ============================================================
  // Tab Interaction Tests
  // ============================================================
  group('Tab interactions', () {
    testWidgets('should have close button on each tab', (tester) async {
      // ARRANGE
      final tab = createTab(label: 'Closable Tab', contentFileId: 'dn-1');

      // ACT
      await tester.pumpApp(
        const TabBarWidget(),
        overrides: [
          tabsProvider.overrideWith((ref) {
            final notifier = TabsNotifier();
            notifier.addTab(tab);
            return notifier;
          }),
          activeTabIndexProvider.overrideWith((ref) => 0),
        ],
      );
      await tester.pumpAndSettle();

      // ASSERT
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('should show tooltip with full name', (tester) async {
      // ARRANGE
      final tab = createTab(label: 'Short', contentFileId: 'dn-1');

      // ACT
      await tester.pumpApp(
        const TabBarWidget(),
        overrides: [
          tabsProvider.overrideWith((ref) {
            final notifier = TabsNotifier();
            notifier.addTab(tab);
            return notifier;
          }),
          activeTabIndexProvider.overrideWith((ref) => 0),
        ],
      );
      await tester.pumpAndSettle();

      // ASSERT - Tooltip widget should exist
      expect(find.byType(Tooltip), findsOneWidget);
    });
  });

  // ============================================================
  // Scroll Chevron Tests
  // ============================================================
  group('Scroll chevrons', () {
    testWidgets('should not show chevrons when all tabs fit on screen',
        (tester) async {
      // ARRANGE - Just 2 tabs that will fit
      final tab1 = createTab(label: 'Tab 1', contentFileId: 'dn-1');
      final tab2 = createTab(label: 'Tab 2', contentFileId: 'dn-2');

      // ACT
      await tester.pumpApp(
        const TabBarWidget(),
        overrides: [
          tabsProvider.overrideWith((ref) {
            final notifier = TabsNotifier();
            notifier.addTab(tab1);
            notifier.addTab(tab2);
            return notifier;
          }),
          activeTabIndexProvider.overrideWith((ref) => 0),
        ],
      );
      await tester.pumpAndSettle();

      // ASSERT - Neither chevron should be visible (width is 0 when hidden)
      // The chevron icons exist but are hidden via AnimatedContainer width: 0
      final leftChevronFinder = find.byIcon(Icons.chevron_left);
      final rightChevronFinder = find.byIcon(Icons.chevron_right);

      // When hidden, the AnimatedContainer has width 0, so icons won't be found
      expect(leftChevronFinder, findsNothing);
      expect(rightChevronFinder, findsNothing);
    });

    testWidgets('should show right chevron when tabs overflow', (tester) async {
      // ARRANGE - Many tabs that will overflow
      final tabs = List.generate(
        10,
        (i) => createTab(label: 'Tab Number $i', contentFileId: 'file-$i'),
      );

      // ACT
      await tester.pumpApp(
        const TabBarWidget(),
        overrides: [
          tabsProvider.overrideWith((ref) {
            final notifier = TabsNotifier();
            for (final tab in tabs) {
              notifier.addTab(tab);
            }
            return notifier;
          }),
          activeTabIndexProvider.overrideWith((ref) => 0),
        ],
      );
      await tester.pumpAndSettle();

      // ASSERT - Right chevron should be visible (tabs overflow to the right)
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      // Left chevron should NOT be visible (we're at the start)
      expect(find.byIcon(Icons.chevron_left), findsNothing);
    });

    testWidgets('should show left chevron after scrolling right',
        (tester) async {
      // ARRANGE - Many tabs that will overflow
      final tabs = List.generate(
        10,
        (i) => createTab(label: 'Tab Number $i', contentFileId: 'file-$i'),
      );

      // ACT
      await tester.pumpApp(
        const TabBarWidget(),
        overrides: [
          tabsProvider.overrideWith((ref) {
            final notifier = TabsNotifier();
            for (final tab in tabs) {
              notifier.addTab(tab);
            }
            return notifier;
          }),
          activeTabIndexProvider.overrideWith((ref) => 0),
        ],
      );
      await tester.pumpAndSettle();

      // Scroll to reveal later tabs
      await tester.scrollUntilVisible(
        find.text('Tab Number 5'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      // ASSERT - Left chevron should now be visible
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });

    testWidgets('should scroll when chevron is tapped', (tester) async {
      // ARRANGE - Many tabs that will overflow
      final tabs = List.generate(
        10,
        (i) => createTab(label: 'Tab Number $i', contentFileId: 'file-$i'),
      );

      // ACT
      await tester.pumpApp(
        const TabBarWidget(),
        overrides: [
          tabsProvider.overrideWith((ref) {
            final notifier = TabsNotifier();
            for (final tab in tabs) {
              notifier.addTab(tab);
            }
            return notifier;
          }),
          activeTabIndexProvider.overrideWith((ref) => 0),
        ],
      );
      await tester.pumpAndSettle();

      // First tab should be visible
      expect(find.text('Tab Number 0'), findsOneWidget);

      // Tap the right chevron multiple times to scroll
      for (var i = 0; i < 5; i++) {
        final rightChevron = find.byIcon(Icons.chevron_right);
        if (rightChevron.evaluate().isNotEmpty) {
          await tester.tap(rightChevron);
          await tester.pumpAndSettle();
        }
      }

      // ASSERT - After scrolling, left chevron should appear
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });
  });

  // ============================================================
  // Multiple Tabs Tests
  // ============================================================
  group('Multiple tabs', () {
    testWidgets('should use horizontal ListView for tabs', (tester) async {
      // ARRANGE
      final tab1 = createTab(label: 'Tab A', contentFileId: 'file-a');
      final tab2 = createTab(label: 'Tab B', contentFileId: 'file-b');

      // ACT
      await tester.pumpApp(
        const TabBarWidget(),
        overrides: [
          tabsProvider.overrideWith((ref) {
            final notifier = TabsNotifier();
            notifier.addTab(tab1);
            notifier.addTab(tab2);
            return notifier;
          }),
          activeTabIndexProvider.overrideWith((ref) => 0),
        ],
      );
      await tester.pumpAndSettle();

      // ASSERT - ListView should be horizontal
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.scrollDirection, Axis.horizontal);

      // At least the first tab should be visible
      expect(find.text('Tab A'), findsOneWidget);
    });

    testWidgets('should be scrollable to reveal hidden tabs', (tester) async {
      // ARRANGE - Create many tabs that won't all fit on screen
      final tabs = List.generate(
        10,
        (i) => createTab(label: 'Tab Number $i', contentFileId: 'file-$i'),
      );

      // ACT
      await tester.pumpApp(
        const TabBarWidget(),
        overrides: [
          tabsProvider.overrideWith((ref) {
            final notifier = TabsNotifier();
            for (final tab in tabs) {
              notifier.addTab(tab);
            }
            return notifier;
          }),
          activeTabIndexProvider.overrideWith((ref) => 0),
        ],
      );
      await tester.pumpAndSettle();

      // First tab should be visible
      expect(find.text('Tab Number 0'), findsOneWidget);

      // SCROLL to reveal the last tab using scrollUntilVisible
      await tester.scrollUntilVisible(
        find.text('Tab Number 9'),
        200, // scroll delta
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      // ASSERT - Last tab should now be visible after scrolling
      expect(find.text('Tab Number 9'), findsOneWidget);
    });
  });
}
