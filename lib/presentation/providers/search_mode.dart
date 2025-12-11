/// Represents the current mode/state of the search UI
/// Used to determine what to display in the search overlay and results
enum SearchMode {
  /// Initial state - no overlay, search bar not focused
  idle,

  /// Search bar focused, showing recent searches dropdown
  recentSearches,

  /// User is typing, showing categorized preview results
  previewResults,

  /// User pressed Enter, showing full search results page with tabs
  fullResults,
}
