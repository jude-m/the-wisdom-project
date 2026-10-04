import 'package:dartz/dartz.dart';

import '../../core/utils/loose_singlish.dart';
import '../../domain/entities/failure.dart';
import '../../domain/entities/search/loose_spellings.dart';
import '../../domain/repositories/loose_spelling_repository.dart';
import '../cache/lru_cache.dart';
import '../datasources/dictionary_datasource.dart';
import '../datasources/fts_datasource.dart';

class LooseSpellingRepositoryImpl implements LooseSpellingRepository {
  final FTSDataSource _ftsDataSource;
  final DictionaryDataSource _dictionaryDataSource;

  /// Results, counts and highlights all ask about one query at the same
  /// moment, so the pending answer is cached too and one walk serves them all.
  final LRUCache<String, Future<LooseSpellings>> _cache = LRUCache(32);

  static const LooseSinglishExpander _expander = LooseSinglishExpander();

  /// The word list behind [corpusSpellings]: the one edition there is.
  static const String _corpusEditionId = 'bjt';

  static final _space = RegExp(r'\s');

  LooseSpellingRepositoryImpl(this._ftsDataSource, this._dictionaryDataSource);

  @override
  Future<Either<Failure, LooseSpellings>> corpusSpellings(
    String singlishText, {
    bool isExactMatch = false,
  }) =>
      _spellings(
        'corpus',
        singlishText,
        isExactMatch,
        (candidates, {required wholeWords}) => _ftsDataSource.existingTerms(
          _corpusEditionId,
          candidates,
          wholeWords: wholeWords,
        ),
      );

  @override
  Future<Either<Failure, LooseSpellings>> dictionarySpellings(
    String singlishText, {
    bool isExactMatch = false,
  }) async {
    if (_space.hasMatch(singlishText.trim())) {
      return const Right(LooseSpellings());
    }
    return _spellings(
      'dictionary',
      singlishText,
      isExactMatch,
      _dictionaryDataSource.existingHeadwords,
    );
  }

  Future<Either<Failure, LooseSpellings>> _spellings(
    String source,
    String singlishText,
    bool isExactMatch,
    PrefixOracle oracle,
  ) async {
    if (!LooseSinglishExpander.appliesTo(singlishText)) {
      return const Right(LooseSpellings());
    }

    // Case never changes the spellings, so it stays out of the key.
    final key = '$source|${isExactMatch ? 1 : 0}|${singlishText.toLowerCase()}';
    var pending = _cache.get(key);
    if (pending == null) {
      pending = _expander
          .expand(singlishText, oracle, exact: isExactMatch)
          .then((words) => LooseSpellings(words: words));
      _cache.put(key, pending);
    }

    try {
      return Right(await pending);
    } catch (e) {
      _cache.remove(key); // a failure must not stick
      return Left(
        Failure.dataLoadFailure(
          message: 'Failed to find similar spellings',
          error: e,
        ),
      );
    }
  }
}
