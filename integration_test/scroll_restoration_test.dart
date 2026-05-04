import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/presentation/models/reader_tab.dart';
import 'package:the_wisdom_project/presentation/providers/tab_provider.dart';
import 'package:the_wisdom_project/presentation/providers/document_provider.dart';
import 'package:the_wisdom_project/presentation/widgets/multi_pane_reader_widget.dart';
import 'package:the_wisdom_project/presentation/widgets/tab_bar_widget.dart';
import 'package:the_wisdom_project/data/datasources/bjt_document_local_datasource.dart';

import 'test_overrides.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Scroll position now lives on the [ReaderTab] entity itself
  // (`tab.scrollOffset`) — the standalone scroll-position providers
  // were removed in commit 264b79d. These helpers read/write the
  // offset through the canonical [tabsProvider] surface so each test
  // touches the same state path the production widget uses.
  double readScrollOffset(ProviderContainer container, int tabIndex) {
    final tabs = container.read(tabsProvider);
    if (tabIndex < 0 || tabIndex >= tabs.length) return 0.0;
    return tabs[tabIndex].scrollOffset;
  }

  void writeScrollOffset(
    ProviderContainer container,
    int tabIndex,
    double offset,
  ) {
    container
        .read(tabsProvider.notifier)
        .updateTabScrollOffset(tabIndex, offset);
  }

  group('Scroll Restoration Integration Tests', () {
    testWidgets(
      'should restore scroll position when switching between tabs via UI',
      (tester) async {
        // ARRANGE - Create test app with real providers
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bjtDocumentDataSourceProvider.overrideWithValue(
                BJTDocumentLocalDataSourceImpl(),
              ),
              keyValueStoreOverride(),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Column(
                  children: [
                    TabBarWidget(),
                    Expanded(child: MultiPaneReaderWidget()),
                  ],
                ),
              ),
            ),
          ),
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );

        // Create two tabs with real content file IDs
        const tabA = ReaderTab(
          label: 'DN 1',
          fullName: 'Brahmajāla Sutta',
          contentFileId: 'dn-1',
          nodeKey: 'node-dn-1',
          paliName: 'Brahmajāla Sutta',
          sinhalaName: 'බ්‍රහ්මජාල සූත්‍රය',
        );

        const tabB = ReaderTab(
          label: 'DN 2',
          fullName: 'Sāmaññaphala Sutta',
          contentFileId: 'dn-2',
          nodeKey: 'node-dn-2',
          paliName: 'Sāmaññaphala Sutta',
          sinhalaName: 'සාමඤ්ඤඵල සූත්‍රය',
        );

        // Add both tabs and activate Tab A
        // Content file ID is now derived automatically from the active tab
        container.read(tabsProvider.notifier).addTab(tabA);
        container.read(tabsProvider.notifier).addTab(tabB);
        container.read(activeTabIndexProvider.notifier).state = 0;

        await tester.pumpAndSettle(const Duration(seconds: 2));

        // STEP 1: Scroll Tab A to 300 using the controller
        // SingleColumnPane uses ListView.builder (vertical); TabBarWidget uses horizontal ListView
        final scrollableA = find.byWidgetPredicate(
          (widget) => widget is ListView && widget.scrollDirection == Axis.vertical,
        );
        expect(scrollableA, findsOneWidget,
            reason: 'Should find vertical ListView for content');
        final controllerA =
            tester.widget<ListView>(scrollableA).controller;
        if (controllerA != null && controllerA.hasClients) {
          controllerA.jumpTo(300);
          await tester.pumpAndSettle();
        }

        // STEP 2: Tap Tab B to switch (simulating real user action)
        await tester.tap(find.text('DN 2'));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify Tab A's position was saved when we switched away
        final tabAPositionAfterSwitch = readScrollOffset(container, 0);
        expect(tabAPositionAfterSwitch, greaterThan(0),
            reason:
                'Tab A scroll position should be saved when switching away');

        // Verify Tab B is now active
        expect(container.read(activeTabIndexProvider), 1,
            reason: 'Tab B should now be active');

        // STEP 3: Scroll Tab B to 600
        final scrollableB = find.byWidgetPredicate(
          (widget) => widget is ListView && widget.scrollDirection == Axis.vertical,
        );
        expect(scrollableB, findsOneWidget);
        final controllerB =
            tester.widget<ListView>(scrollableB).controller;
        if (controllerB != null && controllerB.hasClients) {
          controllerB.jumpTo(600);
          await tester.pumpAndSettle();
        }

        // STEP 4: Tap Tab A to switch back (simulating real user action)
        await tester.tap(find.text('DN 1'));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // ASSERT - Each tab should have its own scroll position preserved
        final tabAPosition = readScrollOffset(container, 0);
        final tabBPosition = readScrollOffset(container, 1);

        expect(tabAPosition, greaterThan(0),
            reason: 'Tab A should have a non-zero position');
        expect(tabBPosition, greaterThan(0),
            reason: 'Tab B should have a non-zero position');

        // Tab B was scrolled further than Tab A
        expect(tabBPosition, greaterThan(tabAPosition),
            reason: 'Tab B should have larger scroll position than Tab A');

        // STEP 5: Tap Tab B again to verify its position is also preserved
        await tester.tap(find.text('DN 2'));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify Tab B's scroll position is still preserved
        final tabBPositionAfterReturn = readScrollOffset(container, 1);
        expect(tabBPositionAfterReturn, greaterThan(0),
            reason:
                'Tab B scroll position should be preserved after switching back');
      },
    );

    testWidgets(
      'should not inherit scroll position when closing active tab',
      (tester) async {
        // This tests the bug: Open Tab A, Open Tab B, Go to Tab A and scroll,
        // Close Tab A -> Tab B should NOT inherit Tab A's scroll position

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bjtDocumentDataSourceProvider.overrideWithValue(
                BJTDocumentLocalDataSourceImpl(),
              ),
              keyValueStoreOverride(),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Column(
                  children: [
                    TabBarWidget(),
                    Expanded(child: MultiPaneReaderWidget()),
                  ],
                ),
              ),
            ),
          ),
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );

        // Create two tabs
        const tabA = ReaderTab(
          label: 'Tab A',
          fullName: 'Tab A Full',
          contentFileId: 'dn-1',
          nodeKey: 'node-a',
          paliName: 'Tab A',
          sinhalaName: 'Tab A',
        );

        const tabB = ReaderTab(
          label: 'Tab B',
          fullName: 'Tab B Full',
          contentFileId: 'dn-2',
          nodeKey: 'node-b',
          paliName: 'Tab B',
          sinhalaName: 'Tab B',
        );

        // STEP 1: Open Tab A
        // Content file ID is now derived automatically from the active tab
        container.read(tabsProvider.notifier).addTab(tabA);
        container.read(activeTabIndexProvider.notifier).state = 0;
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // STEP 2: Open Tab B (tap to switch)
        container.read(tabsProvider.notifier).addTab(tabB);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tab B'));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify Tab B is active and at scroll position 0
        expect(container.read(activeTabIndexProvider), 1);
        expect(readScrollOffset(container, 1), 0.0,
            reason: 'Tab B should start at scroll position 0');

        // STEP 3: Go back to Tab A and scroll down
        await tester.tap(find.text('Tab A'));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Scroll Tab A down
        final scrollable = find.byWidgetPredicate(
          (widget) => widget is ListView && widget.scrollDirection == Axis.vertical,
        );
        if (scrollable.evaluate().isNotEmpty) {
          final controller =
              tester.widget<ListView>(scrollable).controller;
          if (controller != null && controller.hasClients) {
            controller.jumpTo(500);
            await tester.pumpAndSettle();
          }
        }

        // STEP 4: Close Tab A (tap close button on Tab A)
        // Find the close button in Tab A's tab item
        final closeButtons = find.byIcon(Icons.close);
        expect(closeButtons, findsNWidgets(2),
            reason: 'Should find 2 close buttons (one for each tab)');
        await tester.tap(closeButtons.first); // Close Tab A
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // ASSERT: Tab B should now be the only tab and at index 0
        expect(container.read(tabsProvider).length, 1);
        expect(container.read(activeTabIndexProvider), 0);

        // CRITICAL: Tab B should still be at scroll position 0, NOT 500
        final tabBScrollPosition = readScrollOffset(container, 0);
        expect(tabBScrollPosition, 0.0,
            reason:
                'Tab B should NOT inherit Tab A\'s scroll position after Tab A is closed');
      },
    );

    testWidgets(
      'should start with scroll position 0 for new tabs',
      (tester) async {
        // ARRANGE
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bjtDocumentDataSourceProvider.overrideWithValue(
                BJTDocumentLocalDataSourceImpl(),
              ),
              keyValueStoreOverride(),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Column(
                  children: [
                    TabBarWidget(),
                    Expanded(child: MultiPaneReaderWidget()),
                  ],
                ),
              ),
            ),
          ),
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );

        // Create and add a new tab
        const tab = ReaderTab(
          label: 'New Tab',
          fullName: 'New Tab Full',
          contentFileId: 'dn-1',
          nodeKey: 'node-new',
          paliName: 'New Tab',
          sinhalaName: 'New Tab',
        );

        // Content file ID is now derived automatically from the active tab
        container.read(tabsProvider.notifier).addTab(tab);
        container.read(activeTabIndexProvider.notifier).state = 0;

        await tester.pumpAndSettle(const Duration(seconds: 2));

        // ASSERT - New tab should start with scroll position 0
        final scrollPosition = readScrollOffset(container, 0);
        expect(scrollPosition, 0.0,
            reason: 'New tabs should start with scroll position 0');
      },
    );

    testWidgets(
      'should clear scroll position when tab is closed',
      (tester) async {
        // ARRANGE
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bjtDocumentDataSourceProvider.overrideWithValue(
                BJTDocumentLocalDataSourceImpl(),
              ),
              keyValueStoreOverride(),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Column(
                  children: [
                    TabBarWidget(),
                    Expanded(child: MultiPaneReaderWidget()),
                  ],
                ),
              ),
            ),
          ),
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );

        // Create and add a tab
        const tab = ReaderTab(
          label: 'Tab to Close',
          fullName: 'Tab to Close Full',
          contentFileId: 'dn-1',
          nodeKey: 'node-close',
          paliName: 'Tab to Close',
          sinhalaName: 'Tab to Close',
        );

        // Content file ID is now derived automatically from the active tab
        container.read(tabsProvider.notifier).addTab(tab);
        container.read(activeTabIndexProvider.notifier).state = 0;

        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Scroll and save position
        final scrollable = find.byWidgetPredicate(
          (widget) => widget is ListView && widget.scrollDirection == Axis.vertical,
        );
        if (scrollable.evaluate().isNotEmpty) {
          final controller =
              tester.widget<ListView>(scrollable).controller;
          if (controller != null && controller.hasClients) {
            controller.jumpTo(250);
            await tester.pumpAndSettle();
          }
        }
        writeScrollOffset(container, 0, 250.0);

        // Verify it was saved
        expect(readScrollOffset(container, 0), 250.0);

        // Close the tab by tapping the close button
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        // ASSERT — closing the only tab leaves an empty list. Scroll offset
        // is stored on the tab entity itself, so removing the tab is the
        // clear; there's no separate "scroll positions" map any more.
        expect(container.read(tabsProvider), isEmpty,
            reason: 'Closing the only tab should leave no tabs');
      },
    );
  });
}
