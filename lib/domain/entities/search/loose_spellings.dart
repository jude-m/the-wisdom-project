import 'package:freezed_annotation/freezed_annotation.dart';

part 'loose_spellings.freezed.dart';

/// Sinhala spellings that sound like a Singlish query — the loose tier.
///
/// One list per typed word, in typed order. Empty means no loose tier.
@freezed
class LooseSpellings with _$LooseSpellings {
  const LooseSpellings._();

  const factory LooseSpellings({
    @Default([]) List<List<String>> words,
  }) = _LooseSpellings;

  bool get isEmpty => words.isEmpty;

  /// The spellings of a one-word query; empty otherwise.
  List<String> get singleWord => words.length == 1 ? words.single : const [];
}
