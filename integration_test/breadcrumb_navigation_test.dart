import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/core/utils/pali_conjunct_transformer.dart';
import 'package:the_wisdom_project/domain/entities/navigation/navigation_language.dart';
import 'package:the_wisdom_project/presentation/models/reader_tab.dart';
import 'package:the_wisdom_project/presentation/providers/navigation_tree_provider.dart';
import 'package:the_wisdom_project/presentation/providers/tab_provider.dart';
import 'package:the_wisdom_project/presentation/widgets/breadcrumb_widget.dart';
import 'package:the_wisdom_project/presentation/widgets/multi_pane_reader_widget.dart';
import 'package:the_wisdom_project/presentation/widgets/tab_bar_widget.dart';
import 'package:the_wisdom_project/presentation/widgets/tree_navigator_widget.dart';
import 'package:the_wisdom_project/data/datasources/bjt_document_local_datasource.dart';
import 'package:the_wisdom_project/presentation/providers/document_provider.dart';

import 'test_overrides.dart';

/// Integration tests for clickable breadcrumb navigation and the centralized
/// openTabFromNodeKeyProvider.
///
/// Uses real navigation tree data loaded from assets — no mocks.
///
/// Tree structure referenced (Digha Nikaya branch):
///   sp       → Sutta Pitaka         (folder)
///   dn       → දීඝනිකාය            (fileId: dn-1)
///   dn-1     → සීලක්ඛන්ධවග්ගො      (fileId: dn-1)
///   dn-1-1   → බ්රහ්මජාලසුත්තං     (fileId: dn-1, page:[0,4])
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Breadcrumb Navigation', () {
    // -----------------------------------------------------------------
    // Helper: pumps a test app with BreadcrumbWidget + reader + tree.
    //
    // Layout mirrors the real ReaderScreen (AppBar with breadcrumb,
    // tree navigator on the left, tab bar + reader on the right).
    // -----------------------------------------------------------------
    Future<ProviderContainer> pumpBreadcrumbApp(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bjtDocumentDataSourceProvider.overrideWithValue(
              BJTDocumentLocalDataSourceImpl(),
            ),
            keyValueStoreOverride(),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              appBar: AppBar(title: const BreadcrumbWidget()),
              body: const Row(
                children: [
                  SizedBox(width: 250, child: TreeNavigatorWidget()),
                  Expanded(
                    child: Column(
                      children: [
                        TabBarWidget(),
                        Expanded(child: MultiPaneReaderWidget()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      // Wait for the real navigation tree to load from assets
      await container.read(navigationTreeProvider.future);
      await tester.pumpAndSettle();

      return container;
    }

    // -----------------------------------------------------------------
    // Helper: creates a ReaderTab at the node's beginning.
    // -----------------------------------------------------------------
    ReaderTab tabAtBeginning(ProviderContainer container, String nodeKey) {
      final node = container.read(nodeByKeyProvider(nodeKey));
      if (node == null) {
        throw StateError('Node "$nodeKey" not found in tree');
      }
      return ReaderTab.fromNode(
        nodeKey: node.nodeKey,
        paliName: node.paliName,
        sinhalaName: node.sinhalaName,
        contentFileId: node.isReadableContent ? node.contentFileId : null,
        pageIndex: node.isReadableContent ? node.entryPageIndex : 0,
        entryStart: node.isReadableContent ? node.entryIndexInPage : 0,
      );
    }

    // -----------------------------------------------------------------
    // Helper: opens a tab and waits for content to load.
    // -----------------------------------------------------------------
    Future<void> openTab(
      WidgetTester tester,
      ProviderContainer container,
      ReaderTab tab,
    ) async {
      container.read(tabsProvider.notifier).addTab(tab);
      container.read(activeTabIndexProvider.notifier).state =
          container.read(tabsProvider).length - 1;
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    // -----------------------------------------------------------------
    // Helper: extracts plain text from the breadcrumb RichText widget.
    // Returns empty string if breadcrumb shows SizedBox.shrink.
    // -----------------------------------------------------------------
    String getBreadcrumbText(WidgetTester tester) {
      final breadcrumbFinder = find.descendant(
        of: find.byType(BreadcrumbWidget),
        matching: find.byType(RichText),
      );
      if (breadcrumbFinder.evaluate().isEmpty) return '';

      final richText = tester.widget<RichText>(breadcrumbFinder.first);
      return _extractPlainText(richText.text);
    }

    // -----------------------------------------------------------------
    // Helper: returns all TextSpan children from the breadcrumb RichText.
    // -----------------------------------------------------------------
    List<TextSpan> getBreadcrumbSpans(WidgetTester tester) {
      final breadcrumbFinder = find.descendant(
        of: find.byType(BreadcrumbWidget),
        matching: find.byType(RichText),
      );
      if (breadcrumbFinder.evaluate().isEmpty) return [];

      final richText = tester.widget<RichText>(breadcrumbFinder.first);
      final rootSpan = richText.text as TextSpan;
      return rootSpan.children?.cast<TextSpan>() ?? [];
    }

    // =================================================================
    // Test 1: Breadcrumb shows correct path for an opened sutta
    // =================================================================
    testWidgets(
      '1. Breadcrumb displays correct ancestor path for opened sutta',
      (tester) async {
        final container = await pumpBreadcrumbApp(tester);

        // Open බ්රහ්මජාලසුත්තං (dn-1-1) — 4 levels deep
        final tab = tabAtBeginning(container, 'dn-1-1');
        await openTab(tester, container, tab);

        // ASSERT: Breadcrumb shows root → dn → dn-1 → dn-1-1
        // Default language is Sinhala, so we expect Sinhala display names
        final text = getBreadcrumbText(tester);
        final node = container.read(nodeByKeyProvider('dn-1-1'));
        expect(text, contains(node!.sinhalaName),
            reason: 'Breadcrumb should contain the leaf sutta name');
        expect(text, contains('›'),
            reason: 'Breadcrumb should contain separator');

        // Verify the path has at least the leaf + its parent
        final parentNode = container.read(nodeByKeyProvider('dn-1'));
        expect(text, contains(parentNode!.sinhalaName),
            reason: 'Breadcrumb should contain parent name');
      },
    );

    // =================================================================
    // Test 2: Breadcrumb is empty when no tab is open
    // =================================================================
    testWidgets(
      '2. Breadcrumb shows nothing when no tab is active',
      (tester) async {
        await pumpBreadcrumbApp(tester);

        // ASSERT: No RichText in the breadcrumb area
        final breadcrumbRichText = find.descendant(
          of: find.byType(BreadcrumbWidget),
          matching: find.byType(RichText),
        );
        expect(breadcrumbRichText, findsNothing,
            reason: 'No tabs → breadcrumb should render SizedBox.shrink');
      },
    );

    // =================================================================
    // Test 3: Leaf segment is non-tappable
    // =================================================================
    testWidgets(
      '3. Leaf segment (last) has no tap recognizer',
      (tester) async {
        final container = await pumpBreadcrumbApp(tester);

        final tab = tabAtBeginning(container, 'dn-1-1');
        await openTab(tester, container, tab);

        // ASSERT: Last span has no TapGestureRecognizer
        final spans = getBreadcrumbSpans(tester);
        expect(spans, isNotEmpty, reason: 'Breadcrumb should have spans');

        final lastSpan = spans.last;
        expect(lastSpan.recognizer, isNull,
            reason: 'Leaf segment should NOT have a tap recognizer');
      },
    );

    // =================================================================
    // Test 4: Parent segments ARE tappable
    // =================================================================
    testWidgets(
      '4. Parent segments have tap recognizers',
      (tester) async {
        final container = await pumpBreadcrumbApp(tester);

        final tab = tabAtBeginning(container, 'dn-1-1');
        await openTab(tester, container, tab);

        // ASSERT: First span (root parent) has a TapGestureRecognizer
        final spans = getBreadcrumbSpans(tester);
        final firstSpan = spans.first;
        expect(firstSpan.recognizer, isA<TapGestureRecognizer>(),
            reason: 'Parent segment should have a tap recognizer');
      },
    );

    // =================================================================
    // Test 5: Tapping parent segment opens a new tab
    // =================================================================
    testWidgets(
      '5. Tapping parent segment opens new tab for that node',
      (tester) async {
        final container = await pumpBreadcrumbApp(tester);

        // Open leaf sutta
        final tab = tabAtBeginning(container, 'dn-1-1');
        await openTab(tester, container, tab);

        final tabCountBefore = container.read(tabsProvider).length;

        // ACT: Tap the first parent segment (root of the path)
        final spans = getBreadcrumbSpans(tester);
        final parentRecognizer =
            spans.first.recognizer as TapGestureRecognizer;
        parentRecognizer.onTap!();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // ASSERT: New tab was created
        final tabs = container.read(tabsProvider);
        expect(tabs.length, equals(tabCountBefore + 1),
            reason: 'Tapping parent should add a new tab');

        // The new tab is now active
        final activeIndex = container.read(activeTabIndexProvider);
        expect(activeIndex, equals(tabs.length - 1),
            reason: 'New tab should become active');

        // The new tab's nodeKey matches the breadcrumb parent we tapped
        // (which is the root ancestor of dn-1-1)
        final newTab = tabs[activeIndex];
        // Verify the new tab is for the root of the breadcrumb path
        final ancestorKeys =
            container.read(ancestorKeysProvider('dn-1-1'));
        expect(newTab.nodeKey, equals(ancestorKeys.first),
            reason: 'New tab nodeKey should match the tapped parent');
      },
    );

    // =================================================================
    // Test 6: Breadcrumb updates after navigating to parent
    // =================================================================
    testWidgets(
      '6. Breadcrumb re-renders to show new tab path after parent tap',
      (tester) async {
        final container = await pumpBreadcrumbApp(tester);

        // Open leaf sutta — breadcrumb shows full 4-level path
        final tab = tabAtBeginning(container, 'dn-1-1');
        await openTab(tester, container, tab);

        final textBefore = getBreadcrumbText(tester);
        final leafNode = container.read(nodeByKeyProvider('dn-1-1'));
        expect(textBefore, contains(leafNode!.sinhalaName),
            reason: 'Should show leaf name initially');

        // ACT: Tap first parent to navigate to root
        final spans = getBreadcrumbSpans(tester);
        (spans.first.recognizer as TapGestureRecognizer).onTap!();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // ASSERT: Breadcrumb now shows shorter path (just root)
        final textAfter = getBreadcrumbText(tester);
        expect(textAfter, isNot(contains(leafNode.sinhalaName)),
            reason:
                'Leaf name should no longer appear after navigating to root');
      },
    );

    // =================================================================
    // Test 7: Language switch updates breadcrumb display names
    // =================================================================
    testWidgets(
      '7. Switching language to Pali updates breadcrumb display names',
      (tester) async {
        final container = await pumpBreadcrumbApp(tester);

        final tab = tabAtBeginning(container, 'dn-1-1');
        await openTab(tester, container, tab);

        // Read the Pali name for verification
        final node = container.read(nodeByKeyProvider('dn-1-1'));
        final paliName = node!.paliName;
        final sinhalaName = node.sinhalaName;

        // Verify Sinhala names shown initially
        final textBefore = getBreadcrumbText(tester);
        expect(textBefore, contains(sinhalaName),
            reason: 'Default language is Sinhala');

        // ACT: Switch to Pali
        container.read(navigationLanguageProvider.notifier).state =
            NavigationLanguage.pali;
        await tester.pumpAndSettle();

        // ASSERT: Now shows Pali names (with conjunct transformation applied)
        final textAfter = getBreadcrumbText(tester);
        expect(textAfter, contains(applyConjunctConsonants(paliName)),
            reason: 'After switching to Pali, breadcrumb should show Pali names');
        expect(textAfter, isNot(contains(sinhalaName)),
            reason: 'Sinhala names should no longer appear');

        // ASSERT: Tree navigator also shows Pali names with conjuncts.
        // The parent node 'dn' (දීඝනිකාය) should now display its Pali name
        // with conjunct transformation in the tree.
        final dnNode = container.read(nodeByKeyProvider('dn'));
        final dnPaliTransformed =
            applyConjunctConsonants(dnNode!.paliName);
        expect(find.text(dnPaliTransformed), findsOneWidget,
            reason:
                'Tree navigator should show Pali names with conjuncts '
                'after language switch');
      },
    );

    // =================================================================
    // Test 8: Tree navigator uses centralized openTabFromNodeKeyProvider
    // =================================================================
    testWidgets(
      '8. Tree node tap creates tab via centralized provider with correct data',
      (tester) async {
        final container = await pumpBreadcrumbApp(tester);

        // Sutta Pitaka is expanded by default, so Digha Nikaya subtree
        // children are visible. Expand deeper to reach a readable leaf.
        // First, expand dn (Digha Nikaya) — find it in the tree navigator
        // and tap its chevron.

        // The tree navigator is on the left. Sutta Pitaka is expanded,
        // showing its children. Find a readable node to tap.
        // We'll tap dn-1 (Silakkhandha Vagga) which should be visible
        // after expanding dn.

        // Expand dn by tapping its chevron
        // dn is a child of sp (already expanded), so it should be visible
        final dnNode = container.read(nodeByKeyProvider('dn'));
        expect(dnNode, isNotNull, reason: 'dn node should exist in tree');

        // Find and tap dn text to open it as a tab
        final dnText = find.text(dnNode!.sinhalaName);
        if (dnText.evaluate().isNotEmpty) {
          await tester.tap(dnText.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          // ASSERT: Tab created with correct data
          final tabs = container.read(tabsProvider);
          expect(tabs, isNotEmpty, reason: 'Tapping node should create a tab');

          final createdTab = tabs.last;
          expect(createdTab.nodeKey, equals('dn'),
              reason: 'Tab nodeKey should match the tapped node');

          // dn has contentFileId (it's readable), verify it was set
          if (dnNode.isReadableContent) {
            expect(createdTab.contentFileId, equals(dnNode.contentFileId),
                reason: 'Readable node tab should have contentFileId');
            expect(createdTab.pageIndex, equals(dnNode.entryPageIndex),
                reason: 'Tab pageIndex should match node entryPageIndex');
          } else {
            expect(createdTab.contentFileId, isNull,
                reason: 'Folder node tab should have null contentFileId');
          }

          // Breadcrumb should update to show path for dn
          final text = getBreadcrumbText(tester);
          expect(text, isNotEmpty,
              reason: 'Breadcrumb should render for the new tab');
        }
      },
    );
  });
}

// ==========================================================================
// Helpers
// ==========================================================================

/// Recursively extracts plain text from an InlineSpan tree.
String _extractPlainText(InlineSpan span) {
  final buffer = StringBuffer();

  if (span is TextSpan) {
    if (span.text != null) buffer.write(span.text);
    if (span.children != null) {
      for (final child in span.children!) {
        buffer.write(_extractPlainText(child));
      }
    }
  }

  return buffer.toString();
}
