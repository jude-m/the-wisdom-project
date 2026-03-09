import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/presentation/models/reader_tab.dart';
import 'package:the_wisdom_project/presentation/providers/dictionary_provider.dart';
import 'package:the_wisdom_project/presentation/providers/tab_provider.dart';
import 'package:the_wisdom_project/presentation/providers/document_provider.dart';
import 'package:the_wisdom_project/presentation/providers/navigation_tree_provider.dart';
import 'package:the_wisdom_project/presentation/widgets/dictionary/dictionary_bottom_sheet.dart';
import 'package:the_wisdom_project/presentation/widgets/multi_pane_reader_widget.dart';
import 'package:the_wisdom_project/presentation/widgets/tab_bar_widget.dart';
import 'package:the_wisdom_project/data/datasources/bjt_document_local_datasource.dart';
import 'package:the_wisdom_project/core/utils/pali_conjunct_transformer.dart';

/// Integration tests for the editable dictionary word feature.
///
/// Covers:
///   - Word tap opens dictionary bottom sheet
///   - Editing the word triggers a new lookup (300ms debounce)
///   - Pinned header stays visible at all scroll/snap positions
///   - Singlish transliteration works in the editable field
///
/// Uses real navigation tree + real dictionary database — no mocks.
///
/// Tree node used:
///   mn-1-1-1  → මූලපරියායසුත්තං  (fileId: mn-1, page:[0,3])

// =====================================================================
// Top-level helpers (must be outside group for recursive calls)
// =====================================================================

/// Recursively searches [span] for a [TextSpan] whose text matches [target]
/// and has a [TapGestureRecognizer] attached.
/// Strips ZWJ/ZWNJ before comparing because [applyConjunctConsonants] inserts
/// them into the rendered text for proper Pali typography.
TapGestureRecognizer? _findRecognizerInSpan(InlineSpan span, String target) {
  if (span is TextSpan) {
    if (span.text != null &&
        removeConjunctFormatting(span.text!) == target &&
        span.recognizer is TapGestureRecognizer) {
      return span.recognizer as TapGestureRecognizer;
    }
    if (span.children != null) {
      for (final child in span.children!) {
        final found = _findRecognizerInSpan(child, target);
        if (found != null) return found;
      }
    }
  }
  return null;
}

/// Walks all [RichText] widgets on screen and returns the first
/// [TapGestureRecognizer] whose span text matches [targetWord].
TapGestureRecognizer? findWordRecognizer(
  WidgetTester tester,
  String targetWord,
) {
  final richTexts = tester.widgetList<RichText>(find.byType(RichText));
  for (final richText in richTexts) {
    final recognizer = _findRecognizerInSpan(richText.text, targetWord);
    if (recognizer != null) return recognizer;
  }
  return null;
}

/// Finder for the [TextField] inside the [DictionaryBottomSheet] header.
Finder findDictionaryTextField() => find.descendant(
      of: find.byType(DictionaryBottomSheet),
      matching: find.byType(TextField),
    );

/// Finder for the backspace icon button inside the dictionary sheet.
Finder findBackspaceButton() => find.descendant(
      of: find.byType(DictionaryBottomSheet),
      matching: find.byIcon(Icons.backspace_outlined),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Dictionary editable word lookup', () {
    // -----------------------------------------------------------------
    // Helpers (same pattern as previous_sutta_navigation_test.dart)
    // -----------------------------------------------------------------
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

      await container.read(navigationTreeProvider.future);
      return container;
    }

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
    // Test 1: Word tap → sheet opens → edit word → results update
    // =================================================================
    testWidgets(
      '1. Tap word, verify result, edit via backspace, verify updated result',
      (tester) async {
        final container = await pumpReaderApp(tester);

        // Open මූලපරියායසුත්තං (mn-1-1-1)
        final tab = tabAtBeginning(container, 'mn-1-1-1');
        await openTab(tester, container, tab);

        // ASSERT: Tab header shows Pali name with conjunct transformation.
        // Scope to TabBarWidget — the same text also appears in the reading
        // pane's sutta title, so an unscoped find.text would match twice.
        final tabLabel = applyConjunctConsonants(tab.label);
        expect(
          find.descendant(
            of: find.byType(TabBarWidget),
            matching: find.text(tabLabel),
          ),
          findsOneWidget,
          reason: 'Tab label should display with Pali conjunct formatting',
        );

        // STEP 1: Tap "භික්ඛවෙ" in the Pali text
        final recognizer = findWordRecognizer(tester, 'භික්ඛවෙ');
        expect(recognizer, isNotNull,
            reason: 'Should find TapGestureRecognizer for භික්ඛවෙ');
        recognizer!.onTap!();
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // ASSERT: Dictionary bottom sheet is visible
        expect(find.byType(DictionaryBottomSheet), findsOneWidget,
            reason: 'Dictionary sheet should appear after word tap');

        // ASSERT: selectedDictionaryWordProvider holds the word with conjuncts
        final selectedWord = container.read(selectedDictionaryWordProvider);
        expect(selectedWord, isNotNull,
            reason: 'Provider should hold the selected word');
        expect(selectedWord, contains('\u200D'),
            reason: 'Selected word should contain ZWJ for conjunct display');
        expect(removeConjunctFormatting(selectedWord!), 'භික්ඛවෙ',
            reason: 'Stripping ZWJ should yield the raw Pali word');

        // STEP 2: Verify first result contains expected definition
        expect(find.textContaining('monks'), findsWidgets,
            reason: 'First result for භික්ඛවෙ should contain "monks"');

        // STEP 3: Backspace twice to change word from භික්ඛවෙ → භික්ඛ
        // (removing ෙ then ව — each backspace deletes one char)
        await tester.tap(findBackspaceButton());
        await tester.pump();
        await tester.tap(findBackspaceButton());
        await tester.pump();

        // Wait for 300ms debounce + lookup
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // ASSERT: TextField shows භික්ඛ (with conjunct ZWJ formatting).
        // The backspace button removes one code unit at a time, preserving
        // the ZWJ characters inserted by applyConjunctConsonants.
        final textField =
            tester.widget<TextField>(findDictionaryTextField());
        expect(
            removeConjunctFormatting(textField.controller!.text), 'භික්ඛ',
            reason:
                'TextField should show "භික්ඛ" (with conjuncts) after 2 backspaces');

        // ASSERT: Results updated — first record should contain bhikkha definition
        expect(find.textContaining('භු යාචනෙ'), findsWidgets,
            reason:
                'After editing to භික්ඛ, results should contain භු යාචනෙ');
      },
    );

    // =================================================================
    // Test 2: Pinned header stays visible at all scroll positions
    // =================================================================
    testWidgets(
      '2. Pinned header stays visible when scrolled to max and content changes',
      (tester) async {
        final container = await pumpReaderApp(tester);

        final tab = tabAtBeginning(container, 'mn-1-1-1');
        await openTab(tester, container, tab);

        // Tap a word to open sheet
        final recognizer = findWordRecognizer(tester, 'භික්ඛවෙ');
        recognizer!.onTap!();
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Target the Scrollable inside the sheet (not DictionaryBottomSheet
        // itself, whose LayoutBuilder center falls on content text spans).
        // .first targets the CustomScrollView's Scrollable, skipping the
        // TextField's internal Scrollable.
        final sheetScrollable = find.descendant(
          of: find.byType(DictionaryBottomSheet),
          matching: find.byType(Scrollable),
        ).first;

        // Drag the sheet up to max via its Scrollable (DraggableScrollableSheet
        // intercepts scroll events to expand before scrolling content)
        await tester.drag(sheetScrollable, const Offset(0, -500));
        await tester.pumpAndSettle();

        // ASSERT: TextField (pinned header) is still visible after expansion
        expect(findDictionaryTextField(), findsOneWidget,
            reason:
                'Editable word field should be visible after dragging sheet up');
        expect(tester.getTopLeft(findDictionaryTextField()).dy >= 0, isTrue,
            reason: 'TextField should not be above the screen top');

        // Now scroll through results (fling up in the sheet content)
        await tester.fling(sheetScrollable, const Offset(0, -300), 800);
        await tester.pumpAndSettle();

        // ASSERT: Header is STILL visible (pinned) even after scrolling content
        expect(findDictionaryTextField(), findsOneWidget,
            reason:
                'Pinned header should remain visible after scrolling results');

        // Verify header doesn't go behind the tab bar:
        // TabBarWidget should be above the TextField
        final tabBarBottom =
            tester.getBottomLeft(find.byType(TabBarWidget)).dy;
        final textFieldTop =
            tester.getTopLeft(findDictionaryTextField()).dy;
        expect(textFieldTop, greaterThanOrEqualTo(tabBarBottom),
            reason: 'Dictionary header must not go behind the tab bar');

        // Edit the word to trigger content change while scrolled
        await tester.tap(findBackspaceButton());
        await tester.pump();
        await tester.tap(findBackspaceButton());
        await tester.pump();
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // ASSERT: Header still visible after content change
        expect(findDictionaryTextField(), findsOneWidget,
            reason:
                'Pinned header should remain visible after content changes');
      },
    );

    // =================================================================
    // Test 3: Singlish input triggers Sinhala lookup
    // =================================================================
    testWidgets(
      '3. Clear word, type Singlish "abhinandhathi", verify result',
      (tester) async {
        final container = await pumpReaderApp(tester);

        final tab = tabAtBeginning(container, 'mn-1-1-1');
        await openTab(tester, container, tab);

        // Tap a word to open sheet
        final recognizer = findWordRecognizer(tester, 'භික්ඛවෙ');
        recognizer!.onTap!();
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Clear the text field and type Singlish
        await tester.tap(findDictionaryTextField());
        await tester.pumpAndSettle();

        // Select all and delete
        final textField =
            tester.widget<TextField>(findDictionaryTextField());
        textField.controller!.clear();
        await tester.pump();

        // Type Singlish "abhinandhathi"
        await tester.enterText(findDictionaryTextField(), 'abhinandhathi');
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // ASSERT: Singlish "abhinandhathi" → අභිනන්දති via conversion.
        // Verify the lookup returned results (not the "no results" state)
        // and that the converted Sinhala word appears in the result tiles.
        expect(find.byIcon(Icons.search_off), findsNothing,
            reason:
                'Should NOT show "no results" icon after Singlish lookup');
        expect(find.textContaining('අභිනන්දති'), findsWidgets,
            reason:
                'Singlish "abhinandhathi" should convert to අභිනන්දති '
                'and find dictionary results');

        // Scroll through results to find "delighting" (appears in the DPD
        // prefix-match entries further down the list). Target the Scrollable
        // inside the sheet — NOT DictionaryBottomSheet itself, whose center
        // falls above the visible sheet and misses hit-tests.
        // Flinging the Scrollable first expands the DraggableScrollableSheet
        // (since both share a ScrollController), then scrolls the content.
        // .first targets the CustomScrollView's Scrollable (the outer one),
        // skipping the TextField's internal Scrollable (for text input).
        final sheetScrollable = find.descendant(
          of: find.byType(DictionaryBottomSheet),
          matching: find.byType(Scrollable),
        ).first;

        var found = false;
        for (var i = 0; i < 15; i++) {
          if (tester
              .widgetList(find.textContaining('delighting'))
              .isNotEmpty) {
            found = true;
            break;
          }
          await tester.fling(sheetScrollable, const Offset(0, -300), 800);
          await tester.pumpAndSettle();
        }

        expect(found, isTrue,
            reason:
                'Scrolling through results should reveal "delighting" '
                'from a DPD prefix-match entry');
      },
    );
  });
}
