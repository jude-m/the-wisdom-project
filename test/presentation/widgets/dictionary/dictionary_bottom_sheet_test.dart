import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/domain/entities/dictionary/dictionary_entry.dart';
import 'package:the_wisdom_project/domain/entities/failure.dart';
import 'package:the_wisdom_project/presentation/providers/dictionary_provider.dart';
import 'package:the_wisdom_project/presentation/widgets/dictionary/dictionary_bottom_sheet.dart';

import '../../../helpers/mocks.mocks.dart';

void main() {
  // Test data
  const testWord = 'බුද්ධ';

  final testEntries = [
    const DictionaryEntry(
      id: 1,
      word: 'බුද්ධ',
      dictionaryId: 'DPD',
      meaning: 'awakened, enlightened',
      targetLanguage: 'en',
      sourceLanguage: 'pali',
      rank: 5,
    ),
    const DictionaryEntry(
      id: 2,
      word: 'බුද්ධ',
      dictionaryId: 'BUS',
      meaning: '<b>බුද්ධිමත්</b>, ප්‍රබුද්ධ',
      targetLanguage: 'si',
      sourceLanguage: 'pali',
      rank: 4,
    ),
  ];

  /// Helper to build the widget wrapped in necessary providers
  /// Uses MediaQuery to provide a realistic screen size
  Widget buildTestWidget({
    required MockDictionaryRepository mockRepository,
    String? selectedWord,
    VoidCallback? onClose,
  }) {
    return ProviderScope(
      overrides: [
        dictionaryRepositoryProvider.overrideWithValue(mockRepository),
        selectedDictionaryWordProvider.overrideWith((ref) => selectedWord),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(800, 1200)),
          child: Scaffold(
            body: SizedBox(
              width: 800,
              height: 1200,
              child: Stack(
                children: [
                  const SizedBox.expand(),
                  DictionaryBottomSheet(onClose: onClose),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('DictionaryBottomSheet', () {
    testWidgets('renders loading state while fetching', (tester) async {
      // Arrange
      final mockRepository = MockDictionaryRepository();
      // Use a completer that never completes to show loading state
      final completer = Completer<Either<Failure, List<DictionaryEntry>>>();
      when(mockRepository.lookupWord(
        testWord,
        exactMatch: false,
        limit: 50,
      )).thenAnswer((_) => completer.future);

      // Act
      await tester.pumpWidget(buildTestWidget(
        mockRepository: mockRepository,
        selectedWord: testWord,
      ));
      await tester.pump(); // Let initial build complete

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to clean up
      completer.complete(Right(testEntries));
      await tester.pumpAndSettle();
    });

    testWidgets('renders entries when loaded', (tester) async {
      // Arrange
      final mockRepository = MockDictionaryRepository();
      when(mockRepository.lookupWord(
        testWord,
        exactMatch: false,
        limit: 50,
      )).thenAnswer((_) async => Right(testEntries));

      // Act
      await tester.pumpWidget(buildTestWidget(
        mockRepository: mockRepository,
        selectedWord: testWord,
      ));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text(testWord), findsWidgets); // Word in header and entries
      expect(find.text('DPD'), findsOneWidget); // Dictionary badge
      expect(find.text('BUS'), findsOneWidget); // Dictionary badge
      expect(find.textContaining('awakened'), findsOneWidget);
    });

    testWidgets('renders empty state when no definitions', (tester) async {
      // Arrange
      final mockRepository = MockDictionaryRepository();
      when(mockRepository.lookupWord(
        testWord,
        exactMatch: false,
        limit: 50,
      )).thenAnswer((_) async => const Right([]));

      // Act
      await tester.pumpWidget(buildTestWidget(
        mockRepository: mockRepository,
        selectedWord: testWord,
      ));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.search_off), findsOneWidget);
      expect(find.text('No definitions found'), findsOneWidget);
    });

    testWidgets('closes and clears highlight on close button tap',
        (tester) async {
      // Arrange
      final mockRepository = MockDictionaryRepository();
      var closeCallbackCalled = false;
      when(mockRepository.lookupWord(
        testWord,
        exactMatch: false,
        limit: 50,
      )).thenAnswer((_) async => Right(testEntries));

      // Act
      await tester.pumpWidget(buildTestWidget(
        mockRepository: mockRepository,
        selectedWord: testWord,
        onClose: () => closeCallbackCalled = true,
      ));
      await tester.pumpAndSettle();

      // Find and tap close button
      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // Assert
      expect(closeCallbackCalled, isTrue);
    });

    testWidgets('shows error state on failure', (tester) async {
      // Arrange
      final mockRepository = MockDictionaryRepository();
      const failure = Failure.dataLoadFailure(message: 'Database error');
      when(mockRepository.lookupWord(
        testWord,
        exactMatch: false,
        limit: 50,
      )).thenAnswer((_) async => const Left(failure));

      // Act
      await tester.pumpWidget(buildTestWidget(
        mockRepository: mockRepository,
        selectedWord: testWord,
      ));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Error loading definitions'), findsOneWidget);
    });
  });
}
