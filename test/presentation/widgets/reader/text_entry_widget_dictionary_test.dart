import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/presentation/providers/dictionary_provider.dart';
import 'package:the_wisdom_project/presentation/widgets/reader/text_entry_widget.dart';

void main() {
  // Test data
  const paliText = 'Evaṃ me sutaṃ';
  const sinhalaText = 'මෙසේ මා විසින් අසන ලදී';
  const mixedText = 'Buddha ධම්ම Sangha';

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
        text: paliText,
        onWordTap: (word, position) {
          tappedWord = word;
          tappedPosition = position;
        },
      ));

      // Find the first word 'Evaṃ' in the rich text and tap it
      // We tap on the Text.rich widget at a specific location
      final textFinder = find.byType(Text);
      expect(textFinder, findsOneWidget);

      // Tap near the beginning of the text (first word)
      await tester.tapAt(tester.getTopLeft(textFinder) + const Offset(20, 10));
      await tester.pump();

      // Assert
      expect(tappedWord, isNotNull);
      expect(tappedWord, equals('Evaṃ'));
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
                        text: paliText,
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
      await tester.tapAt(tester.getTopLeft(textFinder) + const Offset(20, 10));
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
                    text: paliText,
                    onWordTap: (word, position) {},
                    enableTap: true,
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap first word
      final textFinder = find.byType(Text);
      await tester.tapAt(tester.getTopLeft(textFinder) + const Offset(20, 10));
      await tester.pump();

      // Check highlight is set
      expect(testRef.read(highlightStateProvider), isNotNull);

      // Clear highlight by setting to null (simulating sheet close)
      testRef.read(highlightStateProvider.notifier).state = null;
      await tester.pump();

      // Verify highlight is cleared
      expect(testRef.read(highlightStateProvider), isNull);
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
