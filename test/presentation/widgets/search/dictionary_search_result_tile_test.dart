import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result_type.dart';
import 'package:the_wisdom_project/presentation/widgets/search/dictionary_search_result_tile.dart';

void main() {
  // Test data - a dictionary search result
  const testResult = SearchResult(
    id: 'dict-1',
    editionId: 'DPD',
    resultType: SearchResultType.definition,
    title: 'buddha',
    subtitle: 'Digital Pali Dictionary',
    matchedText: '<b>awakened</b>, enlightened, one who has attained bodhi',
    contentFileId: '',
    pageIndex: 0,
    entryIndex: 0,
    nodeKey: '',
    language: 'en',
  );

  /// Helper to wrap the widget in a MaterialApp
  Widget buildTestWidget({
    required SearchResult result,
    VoidCallback? onTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: DictionarySearchResultTile(
          result: result,
          onTap: onTap,
        ),
      ),
    );
  }

  group('DictionarySearchResultTile', () {
    testWidgets('renders word, dictionary name, and meaning', (tester) async {
      // Act
      await tester.pumpWidget(buildTestWidget(result: testResult));

      // Assert
      // Word (title)
      expect(find.text('buddha'), findsOneWidget);
      // Dictionary name (subtitle)
      expect(find.text('Digital Pali Dictionary'), findsOneWidget);
      // Meaning is stripped of HTML and shown
      expect(find.textContaining('awakened'), findsOneWidget);
      expect(find.textContaining('enlightened'), findsOneWidget);
    });

    testWidgets('shows badge with correct abbreviation', (tester) async {
      // Act
      await tester.pumpWidget(buildTestWidget(result: testResult));

      // Assert
      // DPD abbreviation should be shown in badge
      expect(find.text('DPD'), findsOneWidget);

      // The badge container should have the dictionary color
      // (We verify by finding the container with the abbreviation)
      final badgeFinder = find.ancestor(
        of: find.text('DPD'),
        matching: find.byType(Container),
      );
      expect(badgeFinder, findsWidgets);
    });

    testWidgets('triggers onTap callback when tapped', (tester) async {
      // Arrange
      var tapped = false;

      // Act
      await tester.pumpWidget(buildTestWidget(
        result: testResult,
        onTap: () => tapped = true,
      ));

      // Find and tap the ListTile
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      // Assert
      expect(tapped, isTrue);
    });
  });
}
