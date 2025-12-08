import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:the_wisdom_project/data/repositories/bjt_document_repository_impl.dart';
import 'package:the_wisdom_project/domain/entities/failure.dart';

import '../../helpers/mocks.mocks.dart';
import '../../helpers/test_data.dart';

void main() {
  late BJTDocumentRepositoryImpl repository;
  late MockBJTDocumentDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockBJTDocumentDataSource();
    // Create NEW repository for each test to clear the cache
    repository = BJTDocumentRepositoryImpl(mockDataSource);
  });

  // ============================================================
  // loadDocument tests
  // ============================================================
  group('loadDocument', () {
    const testFileId = 'dn-1';

    test('should return document from datasource on first call', () async {
      // ARRANGE
      when(mockDataSource.loadDocument(testFileId))
          .thenAnswer((_) async => TestData.sampleDocument);

      // ACT
      final result = await repository.loadDocument(testFileId);

      // ASSERT
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (document) {
          expect(document.fileId, equals('dn-1'));
          expect(document.pageCount, equals(2));
        },
      );

      verify(mockDataSource.loadDocument(testFileId)).called(1);
    });

    test('should return CACHED document on second call', () async {
      // ARRANGE
      when(mockDataSource.loadDocument(testFileId))
          .thenAnswer((_) async => TestData.sampleDocument);

      // ACT - Call twice
      await repository.loadDocument(testFileId);
      final result = await repository.loadDocument(testFileId);

      // ASSERT
      expect(result.isRight(), true);

      // KEY: DataSource should only be called ONCE
      verify(mockDataSource.loadDocument(testFileId)).called(1);
    });

    test('should cache different documents separately', () async {
      // ARRANGE
      const fileId1 = 'dn-1';
      const fileId2 = 'mn-1';

      when(mockDataSource.loadDocument(fileId1))
          .thenAnswer((_) async => TestData.sampleDocument);
      when(mockDataSource.loadDocument(fileId2))
          .thenAnswer((_) async => TestData.singlePageDocument);

      // ACT - Load both documents
      await repository.loadDocument(fileId1);
      await repository.loadDocument(fileId2);

      // Load again - should use cache
      await repository.loadDocument(fileId1);
      await repository.loadDocument(fileId2);

      // ASSERT - Each should be loaded only once
      verify(mockDataSource.loadDocument(fileId1)).called(1);
      verify(mockDataSource.loadDocument(fileId2)).called(1);
    });

    test('should return DataLoadFailure when datasource throws', () async {
      // ARRANGE
      when(mockDataSource.loadDocument(testFileId))
          .thenThrow(Exception('File not found'));

      // ACT
      final result = await repository.loadDocument(testFileId);

      // ASSERT
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<DataLoadFailure>());
          expect(failure.userMessage, contains('Failed to load'));
        },
        (document) => fail('Expected failure'),
      );
    });
  });

  // ============================================================
  // hasDocument tests
  // ============================================================
  group('hasDocument', () {
    test('should return true when document is in cache', () async {
      // ARRANGE - Load document first to cache it
      const testFileId = 'dn-1';
      when(mockDataSource.loadDocument(testFileId))
          .thenAnswer((_) async => TestData.sampleDocument);

      await repository.loadDocument(testFileId);

      // ACT
      final result = await repository.hasDocument(testFileId);

      // ASSERT
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (hasDoc) => expect(hasDoc, true),
      );

      // Should not call datasource again - used cache
      verify(mockDataSource.loadDocument(testFileId)).called(1);
    });

    test('should return true when document can be loaded', () async {
      // ARRANGE
      const testFileId = 'dn-1';
      when(mockDataSource.loadDocument(testFileId))
          .thenAnswer((_) async => TestData.sampleDocument);

      // ACT - No prior cache
      final result = await repository.hasDocument(testFileId);

      // ASSERT
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (hasDoc) => expect(hasDoc, true),
      );
    });

    test('should return false when document cannot be loaded', () async {
      // ARRANGE
      const testFileId = 'non-existent';
      when(mockDataSource.loadDocument(testFileId))
          .thenThrow(Exception('File not found'));

      // ACT
      final result = await repository.hasDocument(testFileId);

      // ASSERT
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (hasDoc) => expect(hasDoc, false),
      );
    });
  });

  // ============================================================
  // preloadDocuments tests
  // ============================================================
  group('preloadDocuments', () {
    test('should return count of successfully loaded documents', () async {
      // ARRANGE
      when(mockDataSource.loadDocument('dn-1'))
          .thenAnswer((_) async => TestData.sampleDocument);
      when(mockDataSource.loadDocument('dn-2'))
          .thenAnswer((_) async => TestData.singlePageDocument);

      // ACT
      final result = await repository.preloadDocuments(['dn-1', 'dn-2']);

      // ASSERT
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (count) => expect(count, equals(2)),
      );
    });

    test('should count partial success correctly', () async {
      // ARRANGE - One succeeds, one fails
      when(mockDataSource.loadDocument('dn-1'))
          .thenAnswer((_) async => TestData.sampleDocument);
      when(mockDataSource.loadDocument('dn-fail'))
          .thenThrow(Exception('Not found'));

      // ACT
      final result = await repository.preloadDocuments(['dn-1', 'dn-fail']);

      // ASSERT
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (count) => expect(count, equals(1)), // Only 1 succeeded
      );
    });

    test('should return 0 when all fail', () async {
      // ARRANGE
      when(mockDataSource.loadDocument(any))
          .thenThrow(Exception('Not found'));

      // ACT
      final result = await repository.preloadDocuments(['fail-1', 'fail-2']);

      // ASSERT
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (count) => expect(count, equals(0)),
      );
    });

    test('should cache all successfully loaded documents', () async {
      // ARRANGE
      when(mockDataSource.loadDocument('dn-1'))
          .thenAnswer((_) async => TestData.sampleDocument);
      when(mockDataSource.loadDocument('dn-2'))
          .thenAnswer((_) async => TestData.singlePageDocument);

      // ACT - Preload
      await repository.preloadDocuments(['dn-1', 'dn-2']);

      // Access them again
      await repository.loadDocument('dn-1');
      await repository.loadDocument('dn-2');

      // ASSERT - Each loaded only once (during preload)
      verify(mockDataSource.loadDocument('dn-1')).called(1);
      verify(mockDataSource.loadDocument('dn-2')).called(1);
    });
  });
}
