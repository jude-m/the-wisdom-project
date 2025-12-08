import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:the_wisdom_project/presentation/providers/document_provider.dart';
import 'package:the_wisdom_project/presentation/widgets/multi_pane_reader_widget.dart';

import '../../helpers/mocks.mocks.dart';
import '../../helpers/test_data.dart';
import '../../helpers/pump_app.dart';

void main() {
  late MockBJTDocumentDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockBJTDocumentDataSource();
  });

  // ============================================================
  // Empty State Tests
  // ============================================================
  group('Empty state', () {
    testWidgets('should show placeholder when no content selected',
        (tester) async {
      // ACT - No content file ID set (default)
      await tester.pumpApp(
        const MultiPaneReaderWidget(),
        overrides: [
          TestProviderOverrides.bjtDocumentDataSource(mockDataSource),
          currentContentFileIdProvider.overrideWith((ref) => null),
        ],
      );
      await tester.pump();

      // ASSERT
      expect(
        find.text('Select a sutta from the tree to begin reading'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    });
  });

  // ============================================================
  // Header Controls Tests
  // ============================================================
  group('Header controls', () {
    testWidgets('should show "Reader" header', (tester) async {
      // ACT
      await tester.pumpApp(
        const MultiPaneReaderWidget(),
        overrides: [
          TestProviderOverrides.bjtDocumentDataSource(mockDataSource),
          currentContentFileIdProvider.overrideWith((ref) => null),
        ],
      );
      await tester.pump();

      // ASSERT
      expect(find.text('Reader'), findsOneWidget);
    });

    testWidgets('should have column mode selector buttons', (tester) async {
      // ACT
      await tester.pumpApp(
        const MultiPaneReaderWidget(),
        overrides: [
          TestProviderOverrides.bjtDocumentDataSource(mockDataSource),
          currentContentFileIdProvider.overrideWith((ref) => null),
        ],
      );
      await tester.pump();

      // ASSERT - Column mode buttons (P, P+S, S)
      expect(find.text('P'), findsOneWidget);
      expect(find.text('P+S'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
    });

    testWidgets('should have theme selector icons', (tester) async {
      // ACT
      await tester.pumpApp(
        const MultiPaneReaderWidget(),
        overrides: [
          TestProviderOverrides.bjtDocumentDataSource(mockDataSource),
          currentContentFileIdProvider.overrideWith((ref) => null),
        ],
      );
      await tester.pump();

      // ASSERT - Theme icons
      expect(find.byIcon(Icons.light_mode), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
      expect(find.byIcon(Icons.wb_twilight), findsOneWidget);
    });
  });

  // ============================================================
  // Error State Tests
  // ============================================================
  group('Error state', () {
    testWidgets('should show error when document loading fails',
        (tester) async {
      // ARRANGE
      when(mockDataSource.loadDocument('dn-1'))
          .thenThrow(Exception('Network error'));

      // ACT
      await tester.pumpApp(
        const MultiPaneReaderWidget(),
        overrides: [
          TestProviderOverrides.bjtDocumentDataSource(mockDataSource),
          currentContentFileIdProvider.overrideWith((ref) => 'dn-1'),
        ],
      );
      await tester.pumpAndSettle();

      // ASSERT
      expect(find.text('Error loading content'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  // ============================================================
  // Content Loading Tests
  // ============================================================
  group('Content loading', () {
    testWidgets('should show loading indicator initially', (tester) async {
      // ARRANGE - Set up a delayed response
      when(mockDataSource.loadDocument('dn-1')).thenAnswer(
        (_) async {
          await Future.delayed(Duration.zero);
          return TestData.sampleDocument;
        },
      );

      // ACT
      await tester.pumpApp(
        const MultiPaneReaderWidget(),
        overrides: [
          TestProviderOverrides.bjtDocumentDataSource(mockDataSource),
          currentContentFileIdProvider.overrideWith((ref) => 'dn-1'),
        ],
      );

      // Initial pump shows loading
      await tester.pump();

      // ASSERT
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Clean up
      await tester.pumpAndSettle();
    });

    testWidgets('should hide placeholder when content loads', (tester) async {
      // ARRANGE
      when(mockDataSource.loadDocument('dn-1'))
          .thenAnswer((_) async => TestData.sampleDocument);

      // ACT
      await tester.pumpApp(
        const MultiPaneReaderWidget(),
        overrides: [
          TestProviderOverrides.bjtDocumentDataSource(mockDataSource),
          currentContentFileIdProvider.overrideWith((ref) => 'dn-1'),
        ],
      );
      await tester.pumpAndSettle();

      // ASSERT - Placeholder should be gone
      expect(
        find.text('Select a sutta from the tree to begin reading'),
        findsNothing,
      );
    });
  });
}
