import 'package:freezed_annotation/freezed_annotation.dart';

part 'loose_spellings.freezed.dart';

/// Sinhala spellings that sound like a Singlish query — the loose tier.
///
/// Empty lists mean no loose tier.
@freezed
class LooseSpellings with _$LooseSpellings {
  const factory LooseSpellings({
    /// Per typed word, in typed order: the spellings the Tipitaka text holds,
    /// in search order. The strict search's own spelling leads unless a far
    /// more common one outranks it; the rest follow by how often the text
    /// uses them, the rarest dropped. Titles, full text and highlights search
    /// with these (see SearchQuery.leadText).
    @Default([]) List<List<String>> words,

    /// The spellings dictionary headwords hold, for definitions, the ones the
    /// text uses most first. A headword is one word, so only a one-word query
    /// has any.
    @Default([]) List<String> headwords,
  }) = _LooseSpellings;
}
