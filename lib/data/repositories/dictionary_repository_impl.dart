import 'package:dartz/dartz.dart';

import '../../domain/entities/dictionary/dictionary_entry.dart';
import '../../domain/entities/failure.dart';
import '../../domain/repositories/dictionary_repository.dart';
import '../datasources/dictionary_datasource.dart';

/// Implementation of DictionaryRepository
class DictionaryRepositoryImpl implements DictionaryRepository {
  final DictionaryDataSource _dataSource;

  DictionaryRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, List<DictionaryEntry>>> lookupWord(
    String word, {
    bool exactMatch = false,
    String? targetLanguage,
    int limit = 50,
  }) async {
    try {
      // Defensive guard - return empty list for empty/whitespace query
      if (word.trim().isEmpty) {
        return const Right([]);
      }

      final entries = await _dataSource.lookupWord(
        word.trim(),
        exactMatch: exactMatch,
        targetLanguage: targetLanguage,
        limit: limit,
      );

      return Right(entries);
    } catch (e) {
      return Left(
        Failure.dataLoadFailure(
          message: 'Failed to lookup word in dictionary',
          error: e,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<DictionaryEntry>>> searchDefinitions(
    String query, {
    bool isExactMatch = false,
    String? targetLanguage,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      // Defensive guard - return empty list for empty/whitespace query
      if (query.trim().isEmpty) {
        return const Right([]);
      }

      final entries = await _dataSource.searchDefinitions(
        query.trim(),
        isExactMatch: isExactMatch,
        targetLanguage: targetLanguage,
        limit: limit,
        offset: offset,
      );

      return Right(entries);
    } catch (e) {
      return Left(
        Failure.dataLoadFailure(
          message: 'Failed to search definitions',
          error: e,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, int>> countDefinitions(
    String query, {
    bool isExactMatch = false,
    String? targetLanguage,
  }) async {
    try {
      // Defensive guard - return 0 for empty/whitespace query
      if (query.trim().isEmpty) {
        return const Right(0);
      }

      final count = await _dataSource.countDefinitions(
        query.trim(),
        isExactMatch: isExactMatch,
        targetLanguage: targetLanguage,
      );

      return Right(count);
    } catch (e) {
      return Left(
        Failure.dataLoadFailure(
          message: 'Failed to count definitions',
          error: e,
        ),
      );
    }
  }
}
