import 'dart:async';
import 'dart:developer' as developer;

import 'package:dartz/dartz.dart';

import '../../core/utils/loose_singlish_expander.dart';
import '../../core/utils/search_query_utils.dart' show computeEffectiveQuery;
import '../../domain/entities/failure.dart';
import '../../domain/entities/search/loose_spellings.dart';
import '../../domain/repositories/loose_spelling_repository.dart';
import '../cache/lru_cache.dart';
import '../datasources/dictionary_datasource.dart';
import '../datasources/fts_datasource.dart';

class LooseSpellingRepositoryImpl implements LooseSpellingRepository {
  final FTSDataSource _ftsDataSource;
  final DictionaryDataSource _dictionaryDataSource;

  /// Whether a far more common spelling may lead instead of the strict one
  /// (see [LooseSinglishExpander.rank]). False keeps the strict one first.
  final bool _mostUsedLeads;

  /// Tab switches and filter changes search the same text again. The pending
  /// answer is cached too, so callers that overlap share one walk.
  final LRUCache<String, Future<LooseSpellings>> _cache = LRUCache(32);

  static const LooseSinglishExpander _expander = LooseSinglishExpander();

  static final _space = RegExp(r'\s');

  LooseSpellingRepositoryImpl(
    this._ftsDataSource,
    this._dictionaryDataSource, {
    bool mostUsedLeads = true,
  }) : _mostUsedLeads = mostUsedLeads;

  @override
  Future<Either<Failure, LooseSpellings>> spellingsFor(
    String singlishText, {
    required Set<String> editionIds,
    bool isExactMatch = false,
  }) async {
    final editions = editionIds.toList()..sort();
    // Case never changes the spellings, so it stays out of the key.
    final key = '${isExactMatch ? 1 : 0}|${editions.join(',')}|'
        '${singlishText.toLowerCase()}';
    var pending = _cache.get(key);
    if (pending == null) {
      pending = _find(singlishText, editions, exact: isExactMatch);
      _cache.put(key, pending);
    }

    try {
      return Right(await pending);
    } catch (e) {
      _cache.remove(key); // a failure must not stick
      developer.log(
        'Similar spellings failed: $e',
        name: 'LooseSpellingRepository',
      );
      return Left(
        Failure.dataLoadFailure(
          message: 'Failed to find similar spellings',
          error: e,
        ),
      );
    }
  }

  /// Both walks at once, one against the text and one against the headwords;
  /// then both put in search order by how often the text uses each spelling.
  Future<LooseSpellings> _find(
    String singlishText,
    List<String> editionIds, {
    required bool exact,
  }) async {
    final isOneWord = !_space.hasMatch(singlishText.trim());
    var (words, headwords) = await (
      _expander.expand(
        singlishText,
        (candidates, {required wholeWords}) => _existingTerms(
          editionIds,
          candidates,
          wholeWords: wholeWords,
        ),
        exact: exact,
      ),
      isOneWord
          ? _expander.expand(
              singlishText,
              _dictionaryDataSource.existingHeadwords,
              exact: exact,
            )
          : Future.value(const <List<String>>[]),
    ).wait;

    // Ranked against the strict search's own spelling of each word. A typed
    // word that doesn't line up with one can't be: no tier rather than a guess.
    final strict = computeEffectiveQuery(singlishText).split(' ');
    if (strict.length != words.length) words = const [];
    if (words.isEmpty && headwords.isEmpty) return const LooseSpellings();

    final usage = await _usage(
      editionIds,
      {
        if (words.isNotEmpty) ...strict,
        for (final spellings in [...words, ...headwords]) ...spellings,
      },
      wholeWords: exact,
    );
    return LooseSpellings(
      words: [
        for (final (i, spellings) in words.indexed)
          LooseSinglishExpander.rank(
            spellings,
            strict: strict[i],
            usage: usage,
            strictFirst: !_mostUsedLeads,
          ),
      ],
      // All kept, rare or not: many headwords begin no word of the text.
      headwords: headwords.isEmpty
          ? const []
          : LooseSinglishExpander.byUsage(headwords.single, usage),
    );
  }

  /// How many rows of [editionIds]' text use each of [spellings], added up
  /// over the editions.
  Future<Map<String, int>> _usage(
    List<String> editionIds,
    Set<String> spellings, {
    required bool wholeWords,
  }) async {
    final found = await Future.wait([
      for (final editionId in editionIds)
        _ftsDataSource.termUsage(
          editionId,
          spellings,
          wholeWords: wholeWords,
        ),
    ]);
    return {
      for (final spelling in spellings)
        spelling: found.fold(0, (sum, usage) => sum + (usage[spelling] ?? 0)),
    };
  }

  /// Which [candidates] begin a word of any of [editionIds]' text — or, with
  /// [wholeWords], are one.
  Future<Set<String>> _existingTerms(
    List<String> editionIds,
    Set<String> candidates, {
    required bool wholeWords,
  }) async {
    final found = await Future.wait([
      for (final editionId in editionIds)
        _ftsDataSource.existingTerms(
          editionId,
          candidates,
          wholeWords: wholeWords,
        ),
    ]);
    return {for (final terms in found) ...terms};
  }
}
