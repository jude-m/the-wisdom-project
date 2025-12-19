/// Represents the category of a search result
/// Used for grouping and filtering search results
enum SearchCategory {
  /// All categories combined - shows grouped results from each category
  all,

  /// Matches in sutta/document/commentary titles/names
  title,

  /// Matches in content text (paragraphs, verses)
  content,

  /// Dictionary word definitions (future feature)
  definition,
}

/// Extension methods for SearchCategory
extension SearchCategoryExtension on SearchCategory {
  /// Get display name for UI
  String get displayName {
    switch (this) {
      case SearchCategory.all:
        return 'Top Results';
      case SearchCategory.title:
        return 'Titles';
      case SearchCategory.content:
        return 'Content';
      case SearchCategory.definition:
        return 'Definitions';
    }
  }

  /// Get icon name for UI (Material icon names)
  String get iconName {
    switch (this) {
      case SearchCategory.all:
        return 'search';
      case SearchCategory.title:
        return 'title';
      case SearchCategory.content:
        return 'article';
      case SearchCategory.definition:
        return 'menu_book';
    }
  }
}
