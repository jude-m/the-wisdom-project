import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:the_wisdom_project/domain/entities/failure.dart';
import 'package:the_wisdom_project/domain/usecases/load_bjt_document_usecase.dart';

import '../../helpers/mocks.mocks.dart';
import '../../helpers/test_data.dart';

void main() {
  late LoadBJTDocumentUseCase useCase;
  late MockBJTDocumentRepository mockRepository;

  setUp(() {
    mockRepository = MockBJTDocumentRepository();
    useCase = LoadBJTDocumentUseCase(mockRepository);
  });

  group('LoadBJTDocumentUseCase', () {
    const testFileId = 'dn-1';

    test('should return document when repository call is successful', () async {
      // ARRANGE
      when(mockRepository.loadDocument(testFileId))
          .thenAnswer((_) async => Right(TestData.sampleDocument));

      // ACT
      final result = await useCase.execute(testFileId);

      // ASSERT
      expect(result.isRight(), true);

      result.fold(
        (failure) => fail('Expected success but got failure'),
        (document) {
          expect(document.fileId, equals('dn-1'));
          expect(document.pageCount, equals(2));
          expect(document.editionId, equals('bjt'));
        },
      );

      // Verify the repository was called with the correct fileId
      verify(mockRepository.loadDocument(testFileId)).called(1);
    });

    test('should return failure when document is not found', () async {
      // ARRANGE
      const invalidFileId = 'non-existent';
      when(mockRepository.loadDocument(invalidFileId))
          .thenAnswer((_) async => Left(TestData.notFoundFailure));

      // ACT
      final result = await useCase.execute(invalidFileId);

      // ASSERT
      expect(result.isLeft(), true);

      result.fold(
        (failure) {
          expect(failure, isA<NotFoundFailure>());
          expect(failure.userMessage, contains('Not found'));
        },
        (document) => fail('Expected failure but got success'),
      );
    });

    test('should return failure when loading fails', () async {
      // ARRANGE
      when(mockRepository.loadDocument(testFileId))
          .thenAnswer((_) async => Left(TestData.dataLoadFailure));

      // ACT
      final result = await useCase.execute(testFileId);

      // ASSERT
      expect(result.isLeft(), true);

      result.fold(
        (failure) => expect(failure, isA<DataLoadFailure>()),
        (document) => fail('Expected failure but got success'),
      );
    });

    test('should pass fileId correctly to repository', () async {
      // ARRANGE
      const customFileId = 'mn-42';
      when(mockRepository.loadDocument(customFileId))
          .thenAnswer((_) async => Right(TestData.sampleDocument));

      // ACT
      await useCase.execute(customFileId);

      // ASSERT: Verify the exact fileId was passed
      verify(mockRepository.loadDocument(customFileId)).called(1);
      // Verify no other calls were made
      verifyNoMoreInteractions(mockRepository);
    });
  });
}
