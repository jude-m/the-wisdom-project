import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:the_wisdom_project/data/repositories/dictionary_repository_impl.dart';
import 'package:the_wisdom_project/domain/entities/dictionary/dictionary_entry.dart';
import 'package:the_wisdom_project/domain/entities/failure.dart';

import '../../helpers/mocks.mocks.dart';

void main() {
  late DictionaryRepositoryImpl repository;
  late MockDictionaryDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockDictionaryDataSource();
    repository = DictionaryRepositoryImpl(mockDataSource);
  });

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
      meaning: 'බුද්ධිමත්, ප්‍රබුද්ධ',
      targetLanguage: 'si',
      sourceLanguage: 'pali',
      rank: 4,
    ),
  ];

  group('lookupWord', () {
    test('returns entries on success', () async {
      // Arrange
      when(mockDataSource.lookupWord(
        testWord,
        exactMatch: false,
        targetLanguage: null,
        limit: 50,
      )).thenAnswer((_) async => testEntries);

      // Act
      final result = await repository.lookupWord(testWord);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected Right but got Left'),
        (entries) {
          expect(entries, equals(testEntries));
          expect(entries.length, equals(2));
        },
      );
    });

    test('returns failure on datasource error', () async {
      // Arrange
      when(mockDataSource.lookupWord(
        testWord,
        exactMatch: false,
        targetLanguage: null,
        limit: 50,
      )).thenThrow(Exception('Database error'));

      // Act
      final result = await repository.lookupWord(testWord);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<DataLoadFailure>());
          expect(failure.userMessage, contains('Failed to lookup word'));
        },
        (entries) => fail('Expected Left but got Right'),
      );
    });

    test('returns empty list for whitespace input', () async {
      // Act
      final result = await repository.lookupWord('   ');

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected Right'),
        (entries) => expect(entries, isEmpty),
      );

      // Verify datasource was never called
      verifyNever(mockDataSource.lookupWord(
        any,
        exactMatch: anyNamed('exactMatch'),
        targetLanguage: anyNamed('targetLanguage'),
        limit: anyNamed('limit'),
      ));
    });
  });
}
