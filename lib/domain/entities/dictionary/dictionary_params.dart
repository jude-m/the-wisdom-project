import 'package:freezed_annotation/freezed_annotation.dart';

part 'dictionary_params.freezed.dart';

/// Parameters for dictionary word lookup (tap-on-word feature)
/// Used with dictionaryLookupProvider
@freezed
class DictionaryLookupParams with _$DictionaryLookupParams {
  const factory DictionaryLookupParams({
    /// The word to look up
    required String word,

    /// Whether to require exact match (no prefix matching)
    /// Default false = prefix matching enabled
    @Default(false) bool exactMatch,

    /// Filter by target language ('en'/'si')
    /// Default null = all languages
    String? targetLanguage,

    /// Maximum number of results to return
    @Default(50) int limit,
  }) = _DictionaryLookupParams;
}

/// Parameters for dictionary definition search (search tab integration)
/// Used with dictionarySearchProvider and dictionaryCountProvider
@freezed
class DictionarySearchParams with _$DictionarySearchParams {
  const factory DictionarySearchParams({
    /// The search query text
    required String query,

    /// Whether to require exact word match (no prefix matching)
    @Default(false) bool isExactMatch,

    /// Filter by target language ('en'/'si')
    /// Default null = all languages
    String? targetLanguage,

    /// Maximum number of results to return
    @Default(50) int limit,
  }) = _DictionarySearchParams;
}
