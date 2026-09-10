import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/presentation/models/reader_tab.dart';
import 'package:the_wisdom_project/presentation/providers/tab_provider.dart';
import 'package:the_wisdom_project/presentation/providers/document_provider.dart';
import 'package:the_wisdom_project/presentation/providers/navigation_tree_provider.dart';
import 'package:the_wisdom_project/presentation/providers/reader_unit_provider.dart';
import 'package:the_wisdom_project/presentation/widgets/reader/multi_pane_reader_widget.dart';
import 'package:the_wisdom_project/presentation/widgets/navigation/tab_bar_widget.dart';
import 'package:the_wisdom_project/data/datasources/bjt_document_local_datasource.dart';

import 'test_overrides.dart';

/// Integration tests for the "Scroll to top / Previous sutta" navigation button.
///
/// **The button steps between leaves, not between readable nodes.** A container
/// is a unit here — tapping සීලක්ඛන්ධවග්ගො renders the whole vagga — so leaving
/// one is a single stop to the sutta on the other side of it, and no tap can
/// land the reader on සුත්තපිටක. `neighbourLeafProvider` is the rule.
///
/// Leaf order used (the stops, in reading order):
///   dn-1-1     → බ්රහ්මජාලසුත්තං     (fileId: dn-1,    page:[0,4])
///   dn-1-2     → සාමඤ්ඤඵලසුත්තං     (fileId: dn-1,    page:[40,0])
///   dn-1-3     → අම්බට්ඨසුත්තං      (fileId: dn-1-3,  page:[0,0])
///   dn-1-4     → සොණදණ්ඩසුත්තං      (fileId: dn-1-3)
///   ...
///   dn-1-10    → සුභසුත්තං          (fileId: dn-1-6)
///   dn-1-11    → කෙවඩ්ඪසුත්තං       (fileId: dn-1-11, page:[0,0])
///
/// dn-1-1 is the first leaf of the Sutta Pitaka, so the leaf before it is the
/// last one of the Vinaya — which is why the tests that want a neighbour they
/// can name start at dn-1-2 or later.
///
/// First leaf in the entire tree:
///   vp-prj-1   → වෙරඤ්ජකණ්ඩො         (fileId: vp-prj), inside vp විනයපිටක

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

      // Wait for the navigation tree to finish loading from assets
      await container.read(navigationTreeProvider.future);

      return container;
    }

    // =================================================================
    // Test 1: FTS mid-sutta
    // =================================================================
    testWidgets(
      '1. FTS mid-sutta: shows scroll-to-top icon and scrolls to sutta beginning',
      (tester) async {
        final container = await pumpReaderApp(tester);

        // An FTS hit inside බ්රහ්මජාලසුත්තං. The tab is still the whole
        // sutta — page 5 entry 3 is only where to stop scrolling, and the
        // reader spends it on the first frame that can reach the row. So
        // "mid-sutta" is now a scroll position and nothing else, which is
        // exactly what the two modes below key off.
        final tab = ReaderTab.fromNode(
          nodeKey: 'dn-1-1',
          paliName: 'බ්රහ්මජාලසුත්තං',
          sinhalaName: 'බ්‍රහ්මජාල සූත්‍රය',
          landingPageIndex: 5,
          landingEntryIndex: 3,
        );

        await openTab(tester, container, tab);

        final scrollable = find.byWidgetPredicate(
          (w) => w is ListView && w.scrollDirection == Axis.vertical,
        );
        expect(scrollable, findsOneWidget,
            reason: 'The reader must be showing the sutta — without the '
                'ListView the line below throws an opaque StateError instead '
                'of saying what went missing');
        final controller = tester.widget<ListView>(scrollable).controller!;
        expect(controller.offset, greaterThan(0),
            reason: 'The landing row is pages into the sutta, so opening '
                'the tab must have scrolled down to it');

        // Scrolled down shows the expandable FAB (Mode 2) instead of the
        // pill (Mode 1). The scroll-to-top icon is inside the collapsed FAB.
        // ASSERT: FAB trigger visible, pill icons hidden
        expect(find.byIcon(Icons.more_vert), findsOneWidget,
            reason: 'Mid-sutta should show the expandable FAB trigger');
        expect(find.byIcon(Icons.skip_previous).hitTestable(), findsNothing,
            reason: 'Mid-sutta should NOT show skip-previous icon');

        // Expand the FAB to reveal the scroll-to-top action
        await tester.tap(find.byIcon(Icons.more_vert));
        await pumpForSettle(tester);

        // ASSERT: vertical_align_top icon now visible inside the expanded FAB
        expect(find.byIcon(Icons.vertical_align_top), findsOneWidget,
            reason: 'Expanded FAB should show scroll-to-top icon');

        // ACT: Tap the scroll-to-top button
        await tester.tap(find.byIcon(Icons.vertical_align_top));
        await pumpForSettle(tester, const Duration(seconds: 2));

        // ASSERT: back at the unit's own first row — a plain scroll now,
        // since the unit was never paginated to begin with.
        expect(controller.offset, 0.0,
            reason: 'Scroll-to-top should return to the top of the unit');
        expect(container.read(activeNodeKeyProvider), 'dn-1-1',
            reason: 'nodeKey should remain the same');
        // `.hitTestable()` matters: Mode 1 is always in the tree, kept out of
        // reach by IgnorePointer and faded to zero. Without it this passes
        // whether or not the mode actually came back — see the same finder at
        // the top of this test, which needs it to prove the opposite.
        expect(find.byIcon(Icons.skip_previous).hitTestable(), findsOneWidget,
            reason: 'At the beginning again, Mode 1 comes back');
      },
    );

    // =================================================================
    // Test 2: At sutta beginning — previous sutta button
    // =================================================================
    testWidgets(
      '2. At sutta beginning: shows skip-previous icon with previous sutta tooltip',
      (tester) async {
        final container = await pumpReaderApp(tester);

        // Open සාමඤ්ඤඵලසුත්තං at its beginning. The leaf before it is
        // බ්රහ්මජාලසුත්තං — a sutta, not the vagga holding them both.
        final tab = tabFromNode(container, 'dn-1-2');
        await openTab(tester, container, tab);

        // ASSERT: skip_previous icon visible (previous sutta mode)
        expect(find.byIcon(Icons.skip_previous), findsOneWidget,
            reason: 'At sutta beginning should show skip-previous icon');
        expect(find.byIcon(Icons.vertical_align_top), findsNothing,
            reason: 'At sutta beginning should NOT show scroll-to-top icon');

        // ASSERT: Tooltip contains the previous sutta's Pali name
        final tooltip = tester.widget<Tooltip>(
          find.ancestor(
            of: find.byIcon(Icons.skip_previous),
            matching: find.byType(Tooltip),
          ),
        );
        expect(tooltip.message, contains('බ්රහ්මජාලසුත්තං'),
            reason: 'Tooltip should name the previous leaf, not its parent');

        // ACT: Tap the button
        await tester.tap(find.byIcon(Icons.skip_previous));
        await pumpForSettle(tester, const Duration(seconds: 2));

        // ASSERT: Now at the previous sutta (dn-1-1)
        expect(container.read(activeNodeKeyProvider), 'dn-1-1',
            reason: 'Should navigate to previous sutta dn-1-1');
      },
    );

    // =================================================================
    // Test 3: Repeated navigation — multiple sequential taps
    // =================================================================
    testWidgets(
      '3. Repeated navigation: sequential backward navigation through suttas',
      (tester) async {
        final container = await pumpReaderApp(tester);

        // Start at සොණදණ්ඩසුත්තං (dn-1-4). Three taps walk back through the
        // suttas of the vagga — never up into the vagga itself, which is the
        // whole difference from the readable-node walk this replaced.
        final tab = tabFromNode(container, 'dn-1-4');
        await openTab(tester, container, tab);

        // --- First tap: dn-1-4 → dn-1-3 ---
        expect(find.byIcon(Icons.skip_previous), findsOneWidget);
        await tester.tap(find.byIcon(Icons.skip_previous));
        await pumpForSettle(tester, const Duration(seconds: 2));
        expect(container.read(activeNodeKeyProvider), 'dn-1-3',
            reason: 'First tap: should navigate to dn-1-3');

        // --- Second tap: dn-1-3 → dn-1-2, and across a content file ---
        expect(find.byIcon(Icons.skip_previous), findsOneWidget);
        await tester.tap(find.byIcon(Icons.skip_previous));
        await pumpForSettle(tester, const Duration(seconds: 2));
        expect(container.read(activeNodeKeyProvider), 'dn-1-2',
            reason: 'Second tap: should navigate to dn-1-2');

        // --- Third tap: dn-1-2 → dn-1-1 ---
        expect(find.byIcon(Icons.skip_previous), findsOneWidget);
        await tester.tap(find.byIcon(Icons.skip_previous));
        await pumpForSettle(tester, const Duration(seconds: 2));
        expect(container.read(activeNodeKeyProvider), 'dn-1-1',
            reason: 'Third tap: should navigate to dn-1-1');
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
        final tab = tabFromNode(container, 'dn-1-11');
        await openTab(tester, container, tab);

        // Verify starting state
        expect(container.read(activeContentFileIdProvider), 'dn-1-11',
            reason: 'Should start with contentFileId dn-1-11');

        // ACT: Tap the previous sutta button
        expect(find.byIcon(Icons.skip_previous), findsOneWidget);
        await tester.tap(find.byIcon(Icons.skip_previous));
        await pumpForSettle(tester, const Duration(seconds: 2));

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
        final tab = tabFromNode(container, 'vp');
        await openTab(tester, container, tab);

        // Guard: the assertions below are both "findsNothing", so they
        // would also pass on a reader showing no text at all.
        expect(
          find.byWidgetPredicate(
            (w) => w is ListView && w.scrollDirection == Axis.vertical,
          ),
          findsOneWidget,
          reason: 'vp must actually render text for a hidden button to mean '
              'anything',
        );

        // Guard: the provider answers null for "nothing before it" and for
        // "the resolver never loaded" alike, so a key that does have a
        // previous leaf has to separate them first.
        expect(
          container.read(neighbourLeafProvider(('dn-1-2', ReaderStep.previous))),
          isNotNull,
          reason: 'The leaf walk must be working for vp\'s null to mean '
              '"first in the corpus" rather than "resolver not loaded"',
        );

        // Verify that the previous leaf really is absent
        final previousNode =
            container.read(neighbourLeafProvider(('vp', ReaderStep.previous)));
        expect(previousNode, isNull,
            reason: 'vp holds the first leaf in the corpus — nothing before it');

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

        // Open සාමඤ්ඤඵලසුත්තං (dn-1-2)
        final tab = tabFromNode(container, 'dn-1-2');
        await openTab(tester, container, tab);

        // Verify starting tab state
        final tabsBefore = container.read(tabsProvider);
        expect(tabsBefore[0].paliName, 'සාමඤ්ඤඵලසුත්තං');

        // ACT: Navigate to previous
        await tester.tap(find.byIcon(Icons.skip_previous));
        await pumpForSettle(tester, const Duration(seconds: 2));

        // ASSERT: Tab entity updated to the previous node's data
        final tabsAfter = container.read(tabsProvider);
        expect(tabsAfter[0].nodeKey, 'dn-1-1',
            reason: 'Tab nodeKey should update to dn-1-1');
        expect(tabsAfter[0].paliName, 'බ්රහ්මජාලසුත්තං',
            reason: 'Tab paliName should update to dn-1-1 pali name');
        expect(tabsAfter[0].sinhalaName, 'බ්‍රහ්මජාල සූත්‍රය',
            reason: 'Tab sinhalaName should update to dn-1-1 sinhala name');
        expect(tabsAfter[0].fullName,
            'බ්රහ්මජාලසුත්තං / බ්‍රහ්මජාල සූත්‍රය',
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

        // Open සාමඤ්ඤඵලසුත්තං (dn-1-2)
        final tab = tabFromNode(container, 'dn-1-2');
        await openTab(tester, container, tab);

        // ACT: Navigate to previous
        await tester.tap(find.byIcon(Icons.skip_previous));
        await pumpForSettle(tester, const Duration(seconds: 2));

        // ASSERT: Navigator selection updated to dn-1-1
        expect(container.read(selectedNodeProvider), 'dn-1-1',
            reason: 'Navigator should select the new sutta (dn-1-1)');

        // ASSERT: Path to dn-1-1 should be expanded in the tree
        final expanded = container.read(expandedNodesProvider);
        expect(expanded, contains('dn-1'),
            reason: 'Parent node "dn-1" should be expanded');
      },
    );

    // =================================================================
    // Test 8: User scrolled down — button switches to "Go to beginning"
    // =================================================================
    testWidgets(
      '8. User scrolled down: button changes from skip-previous to scroll-to-top',
      (tester) async {
        final container = await pumpReaderApp(tester);

        // Open බ්රහ්මජාලසුත්තං (dn-1-1) at its beginning. The unit runs to
        // the sutta's end, which is far more than the one viewport this
        // test needs to scroll past.
        final tab = tabFromNode(container, 'dn-1-1');

        await openTab(tester, container, tab);

        // VERIFY: At the beginning, button is skip_previous. `.hitTestable()`
        // like the two assertions further down — the icon is in the tree in
        // either mode, so a bare finder would let this test start from an
        // unproven premise.
        expect(find.byIcon(Icons.skip_previous).hitTestable(), findsOneWidget,
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

        // ASSERT: Scrolling switches from Mode 1 (pill) to Mode 2 (FAB)
        // The FAB trigger (more_vert) should be visible; the pill's
        // skip_previous should be hidden.
        expect(find.byIcon(Icons.more_vert), findsOneWidget,
            reason:
                'After scrolling past one viewport → expandable FAB visible');
        // Mode 1 widget is still in the tree (AnimatedOpacity fades it out),
        // but IgnorePointer makes it non-interactive. Use hitTestable() to
        // verify it's effectively hidden.
        expect(find.byIcon(Icons.skip_previous).hitTestable(), findsNothing,
            reason:
                'Scroll-to-top FAB should replace skip-previous when scrolled down');

        // Expand the FAB to reveal the scroll-to-top action
        await tester.tap(find.byIcon(Icons.more_vert));
        await pumpForSettle(tester);

        // ASSERT: vertical_align_top icon now visible inside the expanded FAB
        expect(find.byIcon(Icons.vertical_align_top), findsOneWidget,
            reason:
                'Expanded FAB should show scroll-to-top icon');

        // ACT: Tap the scroll-to-top button
        await tester.tap(find.byIcon(Icons.vertical_align_top));
        await pumpForSettle(tester, const Duration(seconds: 2));

        // ASSERT: Back at the top, button reverts to skip_previous (Mode 1)
        // `.hitTestable()` for the same reason the absence above needs it:
        // Mode 1 never leaves the tree, so a bare finder passes whether or
        // not it came back.
        expect(find.byIcon(Icons.skip_previous).hitTestable(), findsOneWidget,
            reason:
                'After scrolling back to top → skip-previous icon returns');
      },
    );
  });
}
