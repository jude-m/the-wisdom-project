import 'package:dartz/dartz.dart';

import '../entities/failure.dart';
import '../entities/search/loose_spellings.dart';

/// Finds the Sinhala spellings that sound like a Singlish query, for the
/// "similar spellings" tier shown after the strict results.
///
/// Prefixes for prefix search, or whole words when [isExactMatch]. Empty for
/// text that doesn't qualify (see `LooseSinglishExpander.appliesTo`).
abstract class LooseSpellingRepository {
  /// Spellings checked against the words of the Tipitaka text.
  Future<Either<Failure, LooseSpellings>> corpusSpellings(
    String singlishText, {
    bool isExactMatch = false,
  });

  /// Spellings checked against dictionary headwords, which are a different
  /// list: many never begin a word of the text. A headword is one word, so
  /// longer queries get none.
  Future<Either<Failure, LooseSpellings>> dictionarySpellings(
    String singlishText, {
    bool isExactMatch = false,
  });
}
