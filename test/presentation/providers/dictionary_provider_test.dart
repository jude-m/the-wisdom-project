import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:the_wisdom_project/domain/entities/dictionary/dictionary_entry.dart';
import 'package:the_wisdom_project/domain/entities/dictionary/dictionary_params.dart';
import 'package:the_wisdom_project/presentation/providers/dictionary_provider.dart';

import '../../helpers/mocks.mocks.dart';

void main() {
  // Test data
  const testWord = 'බුද්ධ';
  const testQuery = 'meditation';

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
      meaning: 'බුද්ධිමත්, ප්‍රබුද්ධ',
      targetLanguage: 'si',
      sourceLanguage: 'pali',
      rank: 4,
    ),
  ];

  group('wordLookupProvider', () {
    test('fetches entries for word', () async {
      // Arrange
      final mockRepository = MockDictionaryRepository();
      when(mockRepository.lookupWord(
        testWord,
        exactMatch: false,
        limit: 50,
      )).thenAnswer((_) async => Right(testEntries));

      final container = ProviderContainer(
        overrides: [
          dictionaryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final result = await container.read(wordLookupProvider(testWord).future);

      // Assert
      expect(result, equals(testEntries));
      expect(result.length, equals(2));
      verify(mockRepository.lookupWord(
        testWord,
        exactMatch: false,
        limit: 50,
      )).called(1);
    });
  });

  group('dictionarySearchProvider', () {
    test('returns search results', () async {
      // Arrange
      final mockRepository = MockDictionaryRepository();
      const params = DictionarySearchParams(query: testQuery);
      when(mockRepository.searchDefinitions(
        testQuery,
        isExactMatch: false,
        targetLanguage: null,
        limit: 50,
      )).thenAnswer((_) async => Right(testEntries));

      final container = ProviderContainer(
        overrides: [
          dictionaryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final result =
          await container.read(dictionarySearchProvider(params).future);

      // Assert
      expect(result, equals(testEntries));
      verify(mockRepository.searchDefinitions(
        testQuery,
        isExactMatch: false,
        targetLanguage: null,
        limit: 50,
      )).called(1);
    });
  });
}
