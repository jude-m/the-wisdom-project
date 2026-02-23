import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/presentation/models/reader_tab.dart';
import 'package:the_wisdom_project/presentation/providers/tab_provider.dart';
import 'package:the_wisdom_project/presentation/providers/document_provider.dart';
import 'package:the_wisdom_project/presentation/providers/navigation_tree_provider.dart';
import 'package:the_wisdom_project/presentation/widgets/multi_pane_reader_widget.dart';
import 'package:the_wisdom_project/presentation/widgets/tab_bar_widget.dart';
import 'package:the_wisdom_project/data/datasources/bjt_document_local_datasource.dart';

/// Integration tests for the "Scroll to top / Previous sutta" navigation button.
///
/// Tree structure used (DFS order of readable nodes in Digha Nikaya):
///   sp         → Sutta Pitaka        (fileId: dn-1,    page:[0,0])
///   dn         → දීඝනිකාය           (fileId: dn-1,    page:[0,0])
///   dn-1       → සීලක්ඛන්ධවග්ගො     (fileId: dn-1,    page:[0,2])
///   dn-1-1     → බ්රහ්මජාලසුත්තං     (fileId: dn-1,    page:[0,4])
///   dn-1-2     → සාමඤ්ඤඵලසුත්තං     (fileId: dn-1,    page:[40,0])
///   dn-1-11    → කෙවඩ්ඪසුත්තං       (fileId: dn-1-11, page:[0,0])
///   ...
///   dn-1-13    → තෙවිජ්ජසුත්තං      (fileId: dn-1-11, page:[55,0])
///   dn-1-3     → අම්බට්ඨසුත්තං      (fileId: dn-1-3,  page:[0,0])
///
/// First readable node in entire tree:
///   vp         → විනයපිටක            (fileId: vp-prj,  page:[0,0])

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Previous Sutta Navigation', () {
    // ---------------------------------------------------------------
    // Helper: pumps the test app and returns the ProviderContainer.
    // Includes localization delegates (needed for tooltip strings)
    // and the real BJT data source + real navigation tree.
    // ---------------------------------------------------------------
    Future<ProviderContainer> pumpReaderApp(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bjtDocumentDataSourceProvider.overrideWithValue(
              BJTDocumentLocalDataSourceImpl(),
            ),
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

      // Wait for the navigation tree to finish loading from assets
      await container.read(navigationTreeProvider.future);

      return container;
    }

    // ---------------------------------------------------------------
    // Helper: creates a ReaderTab for the given node at its beginning.
    // Uses the real node from the tree to set correct pagination.
    // ---------------------------------------------------------------
    ReaderTab tabAtBeginning(ProviderContainer container, String nodeKey) {
      final node = container.read(nodeByKeyProvider(nodeKey));
      if (node == null) {
        throw StateError('Node "$nodeKey" not found in tree');
      }
      return ReaderTab(
        label: node.paliName.length > 20
            ? '${node.paliName.substring(0, 20)}...'
            : node.paliName,
        fullName: '${node.paliName} / ${node.sinhalaName}',
        contentFileId: node.contentFileId,
        nodeKey: node.nodeKey,
        paliName: node.paliName,
        sinhalaName: node.sinhalaName,
        pageStart: node.entryPageIndex,
        pageEnd: node.entryPageIndex + 1,
        entryStart: node.entryIndexInPage,
      );
    }

    // ---------------------------------------------------------------
    // Helper: opens a tab and waits for content to load.
    // ---------------------------------------------------------------
    Future<void> openTab(
      WidgetTester tester,
      ProviderContainer container,
      ReaderTab tab,
    ) async {
      container.read(tabsProvider.notifier).addTab(tab);
      container.read(activeTabIndexProvider.notifier).state = 0;
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    // =================================================================
    // Test 1: FTS mid-sutta
    // =================================================================
    testWidgets(
      '1. FTS mid-sutta: shows scroll-to-top icon and scrolls to sutta beginning',
      (tester) async {
        final container = await pumpReaderApp(tester);

        // Open බ්රහ්මජාලසුත්තං mid-sutta (simulating FTS result at page 5)
        // Real node is at page 0, entry 4 — so pageStart=5 is "after beginning"
        const tab = ReaderTab(
          label: 'බ්රහ්මජාලසුත්තං',
          fullName: 'බ්රහ්මජාලසුත්තං / බ්‍රහ්මජාල සූත්‍රය',
          contentFileId: 'dn-1',
          nodeKey: 'dn-1-1',
          paliName: 'බ්රහ්මජාලසුත්තං',
          sinhalaName: 'බ්‍රහ්මජාල සූත්‍රය',
          pageStart: 5,
          pageEnd: 6,
          entryStart: 3,
        );

        await openTab(tester, container, tab);

        // ASSERT: vertical_align_top icon visible (scroll-to-beginning mode)
        expect(find.byIcon(Icons.vertical_align_top), findsOneWidget,
            reason: 'Mid-sutta should show scroll-to-top icon');
        expect(find.byIcon(Icons.skip_previous), findsNothing,
            reason: 'Mid-sutta should NOT show skip-previous icon');

        // ACT: Tap the button
        await tester.tap(find.byIcon(Icons.vertical_align_top));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // ASSERT: Pagination reset to node's beginning (page 0, entry 4)
        expect(container.read(activePageStartProvider), 0,
            reason: 'pageStart should reset to node entryPageIndex');
        expect(container.read(activeEntryStartProvider), 4,
            reason: 'entryStart should reset to node entryIndexInPage');
        expect(container.read(activeNodeKeyProvider), 'dn-1-1',
            reason: 'nodeKey should remain the same');
      },
    );

    // =================================================================
    // Test 2: At sutta beginning — previous sutta button
    // =================================================================
    testWidgets(
      '2. At sutta beginning: shows skip-previous icon with previous sutta tooltip',
      (tester) async {
        final container = await pumpReaderApp(tester);

        // Open බ්රහ්මජාලසුත්තං at its beginning
        final tab = tabAtBeginning(container, 'dn-1-1');
        await openTab(tester, container, tab);

        // ASSERT: skip_previous icon visible (previous sutta mode)
        expect(find.byIcon(Icons.skip_previous), findsOneWidget,
            reason: 'At sutta beginning should show skip-previous icon');
        expect(find.byIcon(Icons.vertical_align_top), findsNothing,
            reason: 'At sutta beginning should NOT show scroll-to-top icon');

        // ASSERT: Tooltip contains the previous sutta's Pali name
        // Previous of dn-1-1 is dn-1 (සීලක්ඛන්ධවග්ගො)
        final tooltip = tester.widget<Tooltip>(
          find.ancestor(
            of: find.byIcon(Icons.skip_previous),
            matching: find.byType(Tooltip),
          ),
        );
        expect(tooltip.message, contains('සීලක්ඛන්ධවග්ගො'),
            reason:
                'Tooltip should contain the previous node name (සීලක්ඛන්ධවග්ගො)');

        // ACT: Tap the button
        await tester.tap(find.byIcon(Icons.skip_previous));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // ASSERT: Now at the previous sutta (dn-1)
        expect(container.read(activeNodeKeyProvider), 'dn-1',
            reason: 'Should navigate to previous sutta dn-1');
      },
    );

    // =================================================================
    // Test 3: Repeated navigation — multiple sequential taps
    // =================================================================
    testWidgets(
      '3. Repeated navigation: sequential backward navigation through suttas',
      (tester) async {
        final container = await pumpReaderApp(tester);

        // Start at බ්රහ්මජාලසුත්තං (dn-1-1)
        final tab = tabAtBeginning(container, 'dn-1-1');
        await openTab(tester, container, tab);

        // --- First tap: dn-1-1 → dn-1 ---
        expect(find.byIcon(Icons.skip_previous), findsOneWidget);
        await tester.tap(find.byIcon(Icons.skip_previous));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(container.read(activeNodeKeyProvider), 'dn-1',
            reason: 'First tap: should navigate to dn-1');

        // --- Second tap: dn-1 → dn ---
        expect(find.byIcon(Icons.skip_previous), findsOneWidget);
        await tester.tap(find.byIcon(Icons.skip_previous));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(container.read(activeNodeKeyProvider), 'dn',
            reason: 'Second tap: should navigate to dn');

        // --- Third tap: dn → sp ---
        expect(find.byIcon(Icons.skip_previous), findsOneWidget);
        await tester.tap(find.byIcon(Icons.skip_previous));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(container.read(activeNodeKeyProvider), 'sp',
            reason: 'Third tap: should navigate to sp');
      },
    );

    // =================================================================
    // Test 4: Cross-file navigation
    // =================================================================
    testWidgets(
      '4. Cross-file: navigates to previous sutta in a different content file',
      (tester) async {
        final container = await pumpReaderApp(tester);

        // Open කෙවඩ්ඪසුත්තං (dn-1-11, fileId: dn-1-11)
        // Its previous node in DFS order is dn-1-10 (fileId: dn-1-6) — different file
        final tab = tabAtBeginning(container, 'dn-1-11');
        await openTab(tester, container, tab);

        // Verify starting state
        expect(container.read(activeContentFileIdProvider), 'dn-1-11',
            reason: 'Should start with contentFileId dn-1-11');

        // ACT: Tap the previous sutta button
        expect(find.byIcon(Icons.skip_previous), findsOneWidget);
        await tester.tap(find.byIcon(Icons.skip_previous));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // ASSERT: Now at dn-1-10, in a different content file (dn-1-6)
        expect(container.read(activeNodeKeyProvider), 'dn-1-10',
            reason: 'Should navigate to dn-1-10');
        expect(container.read(activeContentFileIdProvider), 'dn-1-6',
            reason: 'Content file should change to dn-1-6 (cross-file)');
      },
    );

    // =================================================================
    // Test 5: First sutta in tree — button hidden
    // =================================================================
    testWidgets(
      '5. First sutta in tree: navigation button is hidden',
      (tester) async {
        final container = await pumpReaderApp(tester);

        // Open the very first readable node in the tree: vp (Vinaya Pitaka)
        final tab = tabAtBeginning(container, 'vp');
        await openTab(tester, container, tab);

        // Verify that previousReadableNodeProvider returns null
        final previousNode =
            container.read(previousReadableNodeProvider('vp'));
        expect(previousNode, isNull,
            reason: 'vp is the first readable node — no previous exists');

        // ASSERT: Neither navigation icon is visible
        expect(find.byIcon(Icons.skip_previous), findsNothing,
            reason: 'No skip-previous at the very first sutta');
        expect(find.byIcon(Icons.vertical_align_top), findsNothing,
            reason: 'No scroll-to-top at beginning of first sutta');
      },
    );

    // =================================================================
    // Test 6: Tab label updates after navigating to previous sutta
    // =================================================================
    testWidgets(
      '6. Tab label: updates to previous sutta name after navigation',
      (tester) async {
        final container = await pumpReaderApp(tester);

        // Open බ්රහ්මජාලසුත්තං (dn-1-1)
        final tab = tabAtBeginning(container, 'dn-1-1');
        await openTab(tester, container, tab);

        // Verify starting tab state
        final tabsBefore = container.read(tabsProvider);
        expect(tabsBefore[0].paliName, 'බ්රහ්මජාලසුත්තං');

        // ACT: Navigate to previous
        await tester.tap(find.byIcon(Icons.skip_previous));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // ASSERT: Tab entity updated to the previous node's data
        final tabsAfter = container.read(tabsProvider);
        expect(tabsAfter[0].nodeKey, 'dn-1',
            reason: 'Tab nodeKey should update to dn-1');
        expect(tabsAfter[0].paliName, 'සීලක්ඛන්ධවග්ගො',
            reason: 'Tab paliName should update to dn-1 pali name');
        expect(tabsAfter[0].sinhalaName, 'සීලස්කන්‍ධ වර්‍ගය',
            reason: 'Tab sinhalaName should update to dn-1 sinhala name');
        expect(tabsAfter[0].fullName,
            'සීලක්ඛන්ධවග්ගො / සීලස්කන්‍ධ වර්‍ගය',
            reason: 'Tab fullName should update');
      },
    );

    // =================================================================
    // Test 7: Navigator sync — tree highlights the new sutta
    // =================================================================
    testWidgets(
      '7. Navigator sync: tree selection updates after navigating to previous',
      (tester) async {
        final container = await pumpReaderApp(tester);

        // Open බ්රහ්මජාලසුත්තං (dn-1-1)
        final tab = tabAtBeginning(container, 'dn-1-1');
        await openTab(tester, container, tab);

        // ACT: Navigate to previous
        await tester.tap(find.byIcon(Icons.skip_previous));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // ASSERT: Navigator selection updated to dn-1
        expect(container.read(selectedNodeProvider), 'dn-1',
            reason: 'Navigator should select the new sutta (dn-1)');

        // ASSERT: Path to dn-1 should be expanded in the tree
        final expanded = container.read(expandedNodesProvider);
        expect(expanded, contains('dn'),
            reason: 'Parent node "dn" should be expanded');
      },
    );

    // =================================================================
    // Test 8: User scrolled down — button switches to "Go to beginning"
    // =================================================================
    testWidgets(
      '8. User scrolled down: button changes from skip-previous to scroll-to-top',
      (tester) async {
        final container = await pumpReaderApp(tester);

        // Open බ්රහ්මජාලසුත්තං (dn-1-1) at its beginning with many pages
        // loaded, so there is enough content to scroll past one viewport.
        final node = container.read(nodeByKeyProvider('dn-1-1'));
        final tab = ReaderTab(
          label: node!.paliName,
          fullName: '${node.paliName} / ${node.sinhalaName}',
          contentFileId: node.contentFileId,
          nodeKey: node.nodeKey,
          paliName: node.paliName,
          sinhalaName: node.sinhalaName,
          pageStart: node.entryPageIndex,
          pageEnd: node.entryPageIndex + 15, // Load 15 pages for scrolling
          entryStart: node.entryIndexInPage,
        );

        await openTab(tester, container, tab);

        // VERIFY: At the beginning, button is skip_previous
        expect(find.byIcon(Icons.skip_previous), findsOneWidget,
            reason: 'Initially at sutta beginning → skip-previous icon');

        // Get the CONTENT ListView's scroll controller (not the TabBarWidget's
        // horizontal ListView). The content ListView is vertical (default axis).
        final contentListViewFinder = find.byWidgetPredicate(
          (widget) =>
              widget is ListView && widget.scrollDirection == Axis.vertical,
        );
        expect(contentListViewFinder, findsOneWidget,
            reason: 'Should find the vertical content ListView');
        final listView = tester.widget<ListView>(contentListViewFinder);
        final controller = listView.controller!;

        // Verify content is scrollable past one viewport
        final maxExtent = controller.position.maxScrollExtent;
        final vpDim = controller.position.viewportDimension;
        expect(maxExtent, greaterThan(vpDim),
            reason:
                'Content must be scrollable past viewport (max=$maxExtent, vp=$vpDim)');

        // ACT: Scroll down past one viewport height.
        // Use the controller directly + explicit pump cycle to ensure the
        // scroll listener fires and setState triggers a rebuild.
        controller.jumpTo(vpDim + 200);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // Verify the scroll actually happened
        expect(controller.position.pixels, greaterThan(vpDim),
            reason:
                'Scroll position should be past viewport (actual=${controller.position.pixels})');

        // ASSERT: Button switches to vertical_align_top (Go to beginning)
        expect(find.byIcon(Icons.vertical_align_top), findsOneWidget,
            reason:
                'After scrolling past one viewport → scroll-to-top icon');
        expect(find.byIcon(Icons.skip_previous), findsNothing,
            reason:
                'Scroll-to-top should replace skip-previous when scrolled down');

        // ACT: Tap the scroll-to-top button
        await tester.tap(find.byIcon(Icons.vertical_align_top));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // ASSERT: Back at the top, button reverts to skip_previous
        expect(find.byIcon(Icons.skip_previous), findsOneWidget,
            reason:
                'After scrolling back to top → skip-previous icon returns');
      },
    );
  });
}
