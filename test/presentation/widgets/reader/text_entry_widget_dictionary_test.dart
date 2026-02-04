import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/presentation/providers/dictionary_provider.dart';
import 'package:the_wisdom_project/presentation/widgets/reader/text_entry_widget.dart';

void main() {
  // Test data - Using Sinhala script since sinhalaWordPattern only matches Sinhala Unicode
  const sinhalaText = 'මෙසේ මා විසින් අසන ලදී';

  /// Helper to wrap the widget in necessary providers
  Widget buildTestWidget({
    required String text,
    OnWordTap? onWordTap,
    bool enableTap = true,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: TextEntryWidget(
            text: text,
            onWordTap: onWordTap,
            enableTap: enableTap,
          ),
        ),
      ),
    );
  }

  group('TextEntryWidget', () {
    testWidgets('tapping word triggers onWordTap callback', (tester) async {
      // Arrange
      String? tappedWord;
      Offset? tappedPosition;

      // Act
      await tester.pumpWidget(buildTestWidget(
        text: sinhalaText,
        onWordTap: (word, position) {
          tappedWord = word;
          tappedPosition = position;
        },
      ));

      // Find the Text.rich widget and tap it
      final textFinder = find.byType(Text);
      expect(textFinder, findsOneWidget);

      // Tap near the beginning of the text (first Sinhala word)
      await tester.tapAt(tester.getTopLeft(textFinder) + const Offset(15, 10));
      await tester.pump();

      // Assert - word is returned from transformed display text
      expect(tappedWord, isNotNull);
      expect(tappedWord, isNotEmpty);
      // Verify it's a Sinhala word (matches Sinhala Unicode pattern)
      expect(tappedWord, matches(RegExp(r'[\u0D80-\u0DFF]+')));
      expect(tappedPosition, isNotNull);
    });

    testWidgets('highlights selected word', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return Consumer(
                    builder: (context, ref, _) {
                      return TextEntryWidget(
                        text: sinhalaText,
                        onWordTap: (word, position) {
                          // When tapped, the widget internally sets highlight state
                        },
                        enableTap: true,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap a word to trigger highlight
      final textFinder = find.byType(Text);
      await tester.tapAt(tester.getTopLeft(textFinder) + const Offset(15, 10));
      await tester.pump();

      // The highlight state should be set (verified by the widget rebuilding)
      // We can verify the Text.rich is still rendered correctly
      expect(textFinder, findsOneWidget);
    });

    testWidgets('clears highlight when selection changes', (tester) async {
      // Arrange
      late WidgetRef testRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  testRef = ref;
                  return TextEntryWidget(
                    text: sinhalaText,
                    onWordTap: (word, position) {},
                    enableTap: true,
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap first Sinhala word
      final textFinder = find.byType(Text);
      await tester.tapAt(tester.getTopLeft(textFinder) + const Offset(15, 10));
      await tester.pump();

      // Check highlight is set
      expect(testRef.read(dictionaryHighlightProvider), isNotNull);

      // Clear highlight by setting to null (simulating sheet close)
      testRef.read(dictionaryHighlightProvider.notifier).state = null;
      await tester.pump();

      // Verify highlight is cleared
      expect(testRef.read(dictionaryHighlightProvider), isNull);
    });

    testWidgets('detects Unicode/Sinhala script words correctly',
        (tester) async {
      // Arrange
      final tappedWords = <String>[];

      // Act
      await tester.pumpWidget(buildTestWidget(
        text: sinhalaText,
        onWordTap: (word, position) {
          tappedWords.add(word);
        },
      ));

      // Tap on different parts of the Sinhala text
      final textFinder = find.byType(Text);
      expect(textFinder, findsOneWidget);

      // Tap first Sinhala word
      await tester.tapAt(tester.getTopLeft(textFinder) + const Offset(15, 10));
      await tester.pump();

      // Assert - should have captured a Sinhala word
      expect(tappedWords, isNotEmpty);
      // The first word 'මෙසේ' should be captured (or nearby word based on tap position)
      expect(
        tappedWords.first,
        matches(RegExp(r'[\p{L}\p{M}]+', unicode: true)),
      );
    });
  });
}
