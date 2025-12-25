/// Represents a high-level content scope for search filtering.
///
/// Scopes are parallel content domains (not narrowing filters).
/// Selecting multiple scopes expands the search to include all selected areas.
///
/// Example:
/// - Empty set = search all content
/// - {sutta} = search only Sutta Pitaka
/// - {sutta, vinaya} = search Sutta and Vinaya Pitaka
enum SearchScope {
  sutta, // Sutta Pitaka (Discourses)
  vinaya, // Vinaya Pitaka (Monastic Law)
  abhidhamma, // Abhidhamma Pitaka
  commentaries, // All Atthakatha combined
  treatises, // Visuddhimagga, Saddharmalankaraya, etc.
}

extension SearchScopeX on SearchScope {
  /// Display name in English
  String get displayName {
    switch (this) {
      case SearchScope.sutta:
        return 'Sutta';
      case SearchScope.vinaya:
        return 'Vinaya';
      case SearchScope.abhidhamma:
        return 'Abhidhamma';
      case SearchScope.commentaries:
        return 'Commentaries';
      case SearchScope.treatises:
        return 'Treatises';
    }
  }

  /// Display name in Sinhala
  String get displayNameSi {
    switch (this) {
      case SearchScope.sutta:
        return 'සුත්ත';
      case SearchScope.vinaya:
        return 'විනය';
      case SearchScope.abhidhamma:
        return 'අභිධම්ම';
      case SearchScope.commentaries:
        return 'අට්ඨකථා';
      case SearchScope.treatises:
        return 'ග්‍රන්ථ';
    }
  }
}
