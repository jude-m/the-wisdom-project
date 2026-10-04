import 'package:dartz/dartz.dart';

import '../entities/failure.dart';
import '../entities/search/loose_spellings.dart';

/// Finds the Sinhala spellings that sound like a Singlish query, for the
/// "similar spellings" tier shown after the strict results.
abstract class LooseSpellingRepository {
  /// The spellings of [singlishText], checked against the words of
  /// [editionIds]' text (and ranked by how often it uses them) and against
  /// dictionary headwords: prefixes for prefix search, or whole words when
  /// [isExactMatch]. Empty for text that doesn't qualify (see
  /// `LooseSinglishExpander.appliesTo`).
  Future<Either<Failure, LooseSpellings>> spellingsFor(
    String singlishText, {
    required Set<String> editionIds,
    bool isExactMatch = false,
  });
}
