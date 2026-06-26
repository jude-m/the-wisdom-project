import 'package:freezed_annotation/freezed_annotation.dart';

part 'ask_filters.freezed.dart';
part 'ask_filters.g.dart';

/// Optional metadata scope for `/ask` (design doc §7) — e.g. restrict retrieval
/// to the Vinaya. All fields optional; an all-null filter means "no scope".
@freezed
class AskFilters with _$AskFilters {
  const factory AskFilters({
    /// "vinaya" | "sutta" — the uid-derived basket (design §5.2).
    String? basket,
  }) = _AskFilters;

  factory AskFilters.fromJson(Map<String, dynamic> json) =>
      _$AskFiltersFromJson(json);
}
