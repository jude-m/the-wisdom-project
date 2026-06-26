import 'package:freezed_annotation/freezed_annotation.dart';
import 'citation.dart';

part 'ask_answer.freezed.dart';
part 'ask_answer.g.dart';

/// The grounded answer returned by the `/ask` backend (design doc §7).
@freezed
class AskAnswer with _$AskAnswer {
  const factory AskAnswer({
    /// The answer prose, in the same language as the question.
    required String answer,

    /// "si" | "en".
    required String lang,

    /// Sources the answer is grounded on (may be empty).
    @Default([]) List<Citation> citations,
  }) = _AskAnswer;

  factory AskAnswer.fromJson(Map<String, dynamic> json) =>
      _$AskAnswerFromJson(json);
}
