/// Represents the category of a search result
/// Used for grouping and filtering search results
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

/// Extension methods for SearchCategory
extension SearchResultTypeExtension on SearchResultType {
  /// Get display name for UI
  String get displayName {
    switch (this) {
      case SearchResultType.topResults:
        return 'Top Results';
      case SearchResultType.title:
        return 'Titles';
      case SearchResultType.fullText:
        return 'Full text';
      case SearchResultType.definition:
        return 'Definitions';
    }
  }

  /// Get icon name for UI (Material icon names)
  String get iconName {
    switch (this) {
      case SearchResultType.topResults:
        return 'search';
      case SearchResultType.title:
        return 'title';
      case SearchResultType.fullText:
        return 'article';
      case SearchResultType.definition:
        return 'menu_book';
    }
  }
}
