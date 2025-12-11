import '../entities/search/recent_search.dart';

/// Repository interface for recent searches functionality
/// Stores and retrieves user's search history for quick access
///
/// Current implementation uses SharedPreferences for local storage.
/// Future: Will sync with Supabase for cross-device history.
abstract class RecentSearchesRepository {
  /// Get the most recent searches, ordered by timestamp (newest first)
  Future<List<RecentSearch>> getRecentSearches({int limit = 5});

  /// Add a search query to recent searches
  /// If the query already exists, it will be moved to the top
  Future<void> addRecentSearch(String query);

  /// Remove a specific search from history
  Future<void> removeRecentSearch(String query);

  /// Clear all recent searches
  Future<void> clearRecentSearches();
}
