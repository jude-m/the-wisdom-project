import 'package:freezed_annotation/freezed_annotation.dart';
import 'citation.dart';

part 'research_answer.freezed.dart';
part 'research_answer.g.dart';

/// The grounded answer returned by the `/research` backend (design doc §7).
@freezed
class ResearchAnswer with _$ResearchAnswer {
  const factory ResearchAnswer({
    /// The answer prose, in the same language as the question. Carries inline
    /// `[[cite:uid]]` markers at each grounded span — the answer renderer
    /// (`research_answer_view.dart`) parses these into tappable citation chips.
    /// Also uses the small Markdown subset `**bold**` / `*italic*` / `- ` bullets.
    required String answer,

    /// "si" | "en".
    required String lang,

    /// Sources the answer is grounded on (may be empty).
    @Default([]) List<Citation> citations,
  }) = _ResearchAnswer;

  factory ResearchAnswer.fromJson(Map<String, dynamic> json) =>
      _$ResearchAnswerFromJson(json);
}
