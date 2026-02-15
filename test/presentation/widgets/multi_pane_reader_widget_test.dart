import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:the_wisdom_project/domain/entities/failure.dart';
import 'package:the_wisdom_project/presentation/providers/tab_provider.dart';
import 'package:the_wisdom_project/presentation/widgets/multi_pane_reader_widget.dart';

import '../../helpers/mocks.mocks.dart';
import '../../helpers/test_data.dart';
import '../../helpers/pump_app.dart';

void main() {
  late MockBJTDocumentRepository mockRepository;

  setUp(() {
    mockRepository = MockBJTDocumentRepository();
  });

  // ============================================================
  // Empty State Tests
  // ============================================================
  group('Empty state', () {
    testWidgets('should show placeholder when no content selected',
        (tester) async {
      // ACT - No content file ID set (no active tab)
      await tester.pumpApp(
        const MultiPaneReaderWidget(),
        overrides: [
          TestProviderOverrides.bjtDocumentRepository(mockRepository),
          // Override the derived provider to return null (no active tab)
          activeContentFileIdProvider.overrideWith((ref) => null),
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
  // Error State Tests
  // ============================================================
  group('Error state', () {
    testWidgets('should show error when document loading fails',
        (tester) async {
      // ARRANGE - Mock repository to return a Failure wrapped in Either
      when(mockRepository.loadDocument('dn-1')).thenAnswer(
        (_) async => const Left(
          Failure.dataLoadFailure(
            message: 'Failed to load document',
            error: 'Network error',
          ),
        ),
      );

      // ACT
      await tester.pumpApp(
        const MultiPaneReaderWidget(),
        overrides: [
          TestProviderOverrides.bjtDocumentRepository(mockRepository),
          // Override derived provider to simulate active tab with content
          activeContentFileIdProvider.overrideWith((ref) => 'dn-1'),
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
      // ARRANGE - Set up a delayed response with Either<Failure, BJTDocument>
      when(mockRepository.loadDocument('dn-1')).thenAnswer(
        (_) async {
          await Future.delayed(Duration.zero);
          return Right(TestData.sampleDocument);
        },
      );

      // ACT
      await tester.pumpApp(
        const MultiPaneReaderWidget(),
        overrides: [
          TestProviderOverrides.bjtDocumentRepository(mockRepository),
          // Override derived provider to simulate active tab with content
          activeContentFileIdProvider.overrideWith((ref) => 'dn-1'),
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
      // ARRANGE - Mock repository to return successful Either
      when(mockRepository.loadDocument('dn-1'))
          .thenAnswer((_) async => Right(TestData.sampleDocument));

      // ACT
      await tester.pumpApp(
        const MultiPaneReaderWidget(),
        overrides: [
          TestProviderOverrides.bjtDocumentRepository(mockRepository),
          // Override derived provider to simulate active tab with content
          activeContentFileIdProvider.overrideWith((ref) => 'dn-1'),
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
