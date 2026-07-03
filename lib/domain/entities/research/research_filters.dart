import 'package:freezed_annotation/freezed_annotation.dart';

part 'research_filters.freezed.dart';
part 'research_filters.g.dart';

/// Optional metadata scope for `/research` (design doc §7) — e.g. restrict retrieval
/// to the Vinaya. All fields optional; an all-null filter means "no scope".
@freezed
class ResearchFilters with _$ResearchFilters {
  const factory ResearchFilters({
    /// "vinaya" | "sutta" — the uid-derived basket (design §5.2).
    String? basket,
  }) = _ResearchFilters;

  factory ResearchFilters.fromJson(Map<String, dynamic> json) =>
      _$ResearchFiltersFromJson(json);
}
