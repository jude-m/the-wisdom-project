import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/presentation/widgets/search/highlighted_search_text.dart';

void main() {
  group('HighlightedSearchText -', () {
    /// Helper to extract TextSpan children from RichText widget.
    List<TextSpan> getSpans(WidgetTester tester) {
      final richText = tester.widget<RichText>(find.byType(RichText));
      final parentSpan = richText.text as TextSpan;
      return parentSpan.children?.cast<TextSpan>() ?? [];
    }

    /// Helper to find highlighted spans (those with bold fontWeight).
    List<String> getHighlightedTexts(List<TextSpan> spans) {
      return spans
          .where((span) => span.style?.fontWeight == FontWeight.bold)
          .map((span) => span.text ?? '')
          .toList();
    }

    testWidgets(
      'Exact phrase mode: highlights entire query as single match',
      (tester) async {
        // ARRANGE - Exact phrase search for "noble truth"
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HighlightedSearchText(
                matchedText: 'The noble truth of suffering is profound.',
                effectiveQuery: 'noble truth',
                isPhraseSearch: true,
                isExactMatch: true,
              ),
            ),
          ),
        );

        // ACT - Extract spans
        final spans = getSpans(tester);
        final highlighted = getHighlightedTexts(spans);

        // ASSERT - "noble truth" should be highlighted as one unit
        expect(highlighted, hasLength(1));
        expect(highlighted.first, equals('noble truth'));
      },
    );

    testWidgets(
      'Phrase with prefix mode: highlights adjacent words with prefix matching',
      (tester) async {
        // ARRANGE - Phrase with prefix: "dhamma" should match "dhammapada"
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HighlightedSearchText(
                matchedText: 'Reading the dhammapada teaches wisdom.',
                effectiveQuery: 'dhamma',
                isPhraseSearch: true,
                isExactMatch: false,
              ),
            ),
          ),
        );

        // ACT
        final spans = getSpans(tester);
        final highlighted = getHighlightedTexts(spans);

        // ASSERT - "dhamma" portion should be highlighted (prefix match)
        // Note: Widget highlights the matched portion, not the entire word
        expect(highlighted, hasLength(1));
        expect(highlighted.first, equals('dhamma'));
      },
    );

    testWidgets(
      'Separate words mode: highlights each word independently',
      (tester) async {
        // ARRANGE - Two separate words that appear in different locations
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HighlightedSearchText(
                matchedText: 'Buddha taught the path to nibbana clearly.',
                effectiveQuery: 'buddha nibbana',
                isPhraseSearch: false,
                isExactMatch: false,
              ),
            ),
          ),
        );

        // ACT
        final spans = getSpans(tester);
        final highlighted = getHighlightedTexts(spans);

        // ASSERT - Both "Buddha" and "nibbana" should be highlighted separately
        expect(highlighted, hasLength(2));
        expect(
          highlighted.map((s) => s.toLowerCase()),
          containsAll(['buddha', 'nibbana']),
        );
      },
    );

    // =========================================================================
    // EDGE CASES
    // =========================================================================
    // Note: Empty query, no-match, and whitespace-only tests are excluded
    // because this widget is only rendered for actual search results.
    // No matches = no results = widget not shown.

    testWidgets(
      'Multiple occurrences: highlights all matches',
      (tester) async {
        // ARRANGE - "dhamma" appears twice in the text
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HighlightedSearchText(
                matchedText: 'The dhamma is the dhamma of Buddha.',
                effectiveQuery: 'dhamma',
                isPhraseSearch: true,
                isExactMatch: true,
              ),
            ),
          ),
        );

        // ACT
        final spans = getSpans(tester);
        final highlighted = getHighlightedTexts(spans);

        // ASSERT - Both occurrences should be highlighted
        expect(highlighted, hasLength(2));
        expect(highlighted, everyElement(equals('dhamma')));
      },
    );

    testWidgets(
      'Case insensitivity: matches regardless of case',
      (tester) async {
        // ARRANGE - Query in lowercase, text has mixed case
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HighlightedSearchText(
                matchedText: 'The BUDDHA taught Buddhism.',
                effectiveQuery: 'buddha',
                isPhraseSearch: true,
                isExactMatch: false,
              ),
            ),
          ),
        );

        // ACT
        final spans = getSpans(tester);
        final highlighted = getHighlightedTexts(spans);

        // ASSERT - Should match despite case difference
        expect(highlighted, isNotEmpty);
        expect(highlighted.first.toLowerCase(), contains('buddha'));
      },
    );

    testWidgets(
      'Sinhala text with ZWJ: correctly highlights normalized text',
      (tester) async {
        // ARRANGE - Sinhala text with Zero-Width Joiner characters
        // ධම්ම (dhamma in Sinhala) - testing ZWJ handling
        const sinhalaText = 'බුද්ධ ධම්ම සංඝ යන රත්නත්‍රය'; // has ZWJ (‍)
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HighlightedSearchText(
                matchedText: sinhalaText,
                effectiveQuery: 'ධම්ම', // dhamma
                isPhraseSearch: true,
                isExactMatch: true,
              ),
            ),
          ),
        );

        // ACT
        final spans = getSpans(tester);
        final highlighted = getHighlightedTexts(spans);

        // ASSERT - Should find match despite ZWJ characters in original text
        expect(highlighted, hasLength(1));
        expect(highlighted.first, contains('ධම්ම'));
      },
    );

    testWidgets(
      'Match at beginning: highlights correctly at text start',
      (tester) async {
        // ARRANGE - Query appears at the very beginning
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HighlightedSearchText(
                matchedText: 'Buddha was born in Lumbini.',
                effectiveQuery: 'buddha',
                isPhraseSearch: true,
                isExactMatch: true,
              ),
            ),
          ),
        );

        // ACT
        final spans = getSpans(tester);
        final highlighted = getHighlightedTexts(spans);

        // ASSERT - First word should be highlighted
        expect(highlighted, hasLength(1));
        expect(highlighted.first.toLowerCase(), equals('buddha'));
      },
    );

    testWidgets(
      'Match at end: highlights correctly at text end',
      (tester) async {
        // ARRANGE - Query appears at the very end
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HighlightedSearchText(
                matchedText: 'The enlightened one is the Buddha',
                effectiveQuery: 'buddha',
                isPhraseSearch: true,
                isExactMatch: true,
              ),
            ),
          ),
        );

        // ACT
        final spans = getSpans(tester);
        final highlighted = getHighlightedTexts(spans);

        // ASSERT - Last word should be highlighted
        expect(highlighted, hasLength(1));
        expect(highlighted.first.toLowerCase(), equals('buddha'));
      },
    );

    testWidgets(
      'Overlapping words in separate mode: merges overlapping ranges',
      (tester) async {
        // ARRANGE - "suffering" and "suffer" overlap in "suffering"
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HighlightedSearchText(
                matchedText: 'Understanding suffering leads to liberation.',
                effectiveQuery: 'suffer suffering',
                isPhraseSearch: false, // separate words mode
                isExactMatch: false, // prefix match
              ),
            ),
          ),
        );

        // ACT
        final spans = getSpans(tester);
        final highlighted = getHighlightedTexts(spans);

        // ASSERT - Overlapping matches should be merged into one highlight
        expect(highlighted, hasLength(1));
        expect(highlighted.first, equals('suffering'));
      },
    );

    testWidgets(
      'Multiple words phrase: highlights adjacent words together',
      (tester) async {
        // ARRANGE - Multi-word phrase search
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HighlightedSearchText(
                matchedText:
                    'The four noble truths are fundamental teachings.',
                effectiveQuery: 'noble truths',
                isPhraseSearch: true,
                isExactMatch: true,
              ),
            ),
          ),
        );

        // ACT
        final spans = getSpans(tester);
        final highlighted = getHighlightedTexts(spans);

        // ASSERT - Should highlight "noble truths" as adjacent phrase
        expect(highlighted, hasLength(1));
        expect(highlighted.first, equals('noble truths'));
      },
    );

    testWidgets(
      'Short text: handles text shorter than context window',
      (tester) async {
        // ARRANGE - Very short text
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HighlightedSearchText(
                matchedText: 'Buddha',
                effectiveQuery: 'buddha',
                isPhraseSearch: true,
                isExactMatch: true,
              ),
            ),
          ),
        );

        // ACT
        final spans = getSpans(tester);
        final highlighted = getHighlightedTexts(spans);

        // ASSERT - Should highlight entire short text
        expect(highlighted, hasLength(1));
        expect(highlighted.first.toLowerCase(), equals('buddha'));
      },
    );

    testWidgets(
      'Separate words with single word: behaves like word search',
      (tester) async {
        // ARRANGE - Single word in separate words mode
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HighlightedSearchText(
                matchedText: 'The path to enlightenment is eightfold.',
                effectiveQuery: 'enlightenment',
                isPhraseSearch: false, // separate words mode
                isExactMatch: false, // prefix match
              ),
            ),
          ),
        );

        // ACT
        final spans = getSpans(tester);
        final highlighted = getHighlightedTexts(spans);

        // ASSERT - Should highlight the single word
        expect(highlighted, hasLength(1));
        expect(highlighted.first, equals('enlightenment'));
      },
    );
  });
}
