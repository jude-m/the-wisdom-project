import 'package:freezed_annotation/freezed_annotation.dart';

part 'dictionary_entry.freezed.dart';

/// Represents a single dictionary entry with word and meaning
@freezed
class DictionaryEntry with _$DictionaryEntry {
  const factory DictionaryEntry({
    /// Database row ID
    required int id,

    /// The Pali word (in Sinhala script)
    required String word,

    /// Dictionary identifier (e.g., 'DPD', 'PTS', 'BUS')
    required String dictionaryId,

    /// The meaning/definition (HTML content)
    required String meaning,

    /// Target language of the definition ('en' or 'si')
    required String targetLanguage,

    /// Source language of the word ('pali' or 'sinhala')
    required String sourceLanguage,

    /// Priority ranking for ordering (higher = more important)
    @Default(0) int rank,

    /// Optional relevance score from FTS search
    double? relevanceScore,
  }) = _DictionaryEntry;
}
