import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:the_wisdom_project/domain/entities/failure.dart';
import 'package:the_wisdom_project/domain/usecases/load_navigation_tree_usecase.dart';

import '../../helpers/mocks.mocks.dart';
import '../../helpers/test_data.dart';

void main() {
  // Declare the objects we need for testing
  late LoadNavigationTreeUseCase useCase;
  late MockNavigationTreeRepository mockRepository;

  // setUp runs before EACH test
  setUp(() {
    // Create a fresh mock for each test
    mockRepository = MockNavigationTreeRepository();
    // Create the use case with the mock repository
    useCase = LoadNavigationTreeUseCase(mockRepository);
  });

  group('LoadNavigationTreeUseCase', () {
    test('should return tree when repository call is successful', () async {
      // ARRANGE: Tell the mock what to return
      // when() sets up the mock behavior
      // thenAnswer() is for async methods (returns Future)
      when(mockRepository.loadNavigationTree())
          .thenAnswer((_) async => Right(TestData.sampleTree));

      // ACT: Call the method we're testing
      final result = await useCase.execute();

      // ASSERT: Check the result
      // 1. Verify we got a Right (success) value
      expect(result.isRight(), true);

      // 2. Extract the value and check it
      result.fold(
        (failure) =>
            fail('Expected success but got failure: ${failure.userMessage}'),
        (tree) {
          expect(tree.length, equals(2)); // sampleTree has 2 root nodes
          expect(tree[0].nodeKey, equals('sp')); // Sutta Pitaka
          expect(tree[1].nodeKey, equals('vp')); // Vinaya Pitaka
        },
      );

      // 3. Verify the repository was called exactly once
      verify(mockRepository.loadNavigationTree()).called(1);
    });

    test('should return failure when repository call fails', () async {
      // ARRANGE: Make the mock return a failure
      when(mockRepository.loadNavigationTree())
          .thenAnswer((_) async => Left(TestData.dataLoadFailure));

      // ACT
      final result = await useCase.execute();

      // ASSERT
      expect(result.isLeft(), true);

      result.fold(
        (failure) {
          expect(failure, isA<DataLoadFailure>());
          expect(failure.userMessage, contains('Failed to load'));
        },
        (tree) => fail('Expected failure but got success'),
      );

      verify(mockRepository.loadNavigationTree()).called(1);
    });

    test('should return empty list when tree is empty', () async {
      // ARRANGE: Return empty list (valid but empty)
      when(mockRepository.loadNavigationTree())
          .thenAnswer((_) async => const Right([]));

      // ACT
      final result = await useCase.execute();

      // ASSERT
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success but got failure'),
        (tree) => expect(tree, isEmpty),
      );
    });
  });
}
