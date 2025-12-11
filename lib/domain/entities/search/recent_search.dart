import 'package:freezed_annotation/freezed_annotation.dart';

part 'recent_search.freezed.dart';
part 'recent_search.g.dart';

/// Represents a recent search query saved for quick access
@freezed
class RecentSearch with _$RecentSearch {
  const factory RecentSearch({
    /// The search query text
    required String queryText,

    /// When this search was performed
    required DateTime timestamp,
  }) = _RecentSearch;

  /// Create from JSON for SharedPreferences storage
  factory RecentSearch.fromJson(Map<String, dynamic> json) =>
      _$RecentSearchFromJson(json);
}
