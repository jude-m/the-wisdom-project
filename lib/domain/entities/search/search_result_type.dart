import '../../../core/localization/l10n/app_localizations.dart';

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
  /// Localized display label for UI (the search tabs and their matching
  /// section sub-headers share this single token, so both follow the locale).
  ///
  /// Resolves against [AppLocalizations]. Same pattern as
  /// [SearchScopeChip.label]. The canonical English strings live in
  /// `app_en.arb` (e.g. `searchTabTitles`).
  String displayLabel(AppLocalizations l10n) {
    switch (this) {
      case SearchResultType.topResults:
        return l10n.searchTabTopResults;
      case SearchResultType.title:
        return l10n.searchTabTitles;
      case SearchResultType.fullText:
        return l10n.searchTabFullText;
      case SearchResultType.definition:
        return l10n.searchTabDefinitions;
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
