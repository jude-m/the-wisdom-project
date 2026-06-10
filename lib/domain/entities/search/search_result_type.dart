/// Represents the category of a search result
/// Used for grouping and filtering search results.
///
/// Pure domain enum: the localized display label is a UI concern, resolved in
/// the presentation layer — see `searchResultTypeLabel` in
/// `presentation/utils/search_result_labels.dart`.
enum SearchResultType {
  /// All categories combined - shows grouped results from each category
  topResults,

  /// Matches in sutta/document/commentary titles/names
  title,

  /// Matches in content text (paragraphs, verses)
  fullText,

  /// Dictionary word definitions (future feature)
  definition,
}
