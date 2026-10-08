import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/search/recent_search.dart';
import '../../domain/repositories/recent_searches_repository.dart';

/// Implementation of RecentSearchesRepository using SharedPreferences
/// Stores search history locally with LIFO ordering and deduplication.
///
/// Future: Will sync with Supabase for cross-device history.
class RecentSearchesRepositoryImpl implements RecentSearchesRepository {
  static const _key = 'recent_searches';
  static const _maxItems = 10;

  final SharedPreferences _prefs;

  RecentSearchesRepositoryImpl(this._prefs);

  @override
  Future<List<RecentSearch>> getRecentSearches({int limit = 5}) async {
    final jsonString = _prefs.getString(_key);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final list = jsonDecode(jsonString) as List;
      final searches = list
          .map((e) => RecentSearch.fromJson(e as Map<String, dynamic>))
          .toList();

      // Return most recent first, limited
      return searches.take(limit).toList();
    } catch (e) {
      // If parsing fails, clear corrupted data and return empty
      await _prefs.remove(_key);
      return [];
    }
  }

  @override
  Future<void> addRecentSearch(String query) async {
    // Helakuru leaves a zero-width space (U+200B) inside words, so the same
    // word could be saved twice. Only U+200B: the joiner U+200D must stay.
    final trimmed = query.replaceAll('\u200B', '').trim();
    if (trimmed.isEmpty) return;

    final existing = await _getAllSearches();

    // Remove duplicate if exists (will be re-added at top). Case matters:
    // in Singlish "kana" (කන) and "kaNa" (කණ) are different words.
    existing.removeWhere((s) => s.queryText == trimmed);

    // Add new search at the beginning (LIFO)
    existing.insert(
      0,
      RecentSearch(
        queryText: trimmed,
        timestamp: DateTime.now(),
      ),
    );

    // Limit the list size
    final limited = existing.take(_maxItems).toList();

    await _saveSearches(limited);
  }

  @override
  Future<void> removeRecentSearch(String query) async {
    final existing = await _getAllSearches();
    existing.removeWhere((s) => s.queryText == query);
    await _saveSearches(existing);
  }

  @override
  Future<void> clearRecentSearches() async {
    await _prefs.remove(_key);
  }

  /// Get all stored searches (no limit)
  Future<List<RecentSearch>> _getAllSearches() async {
    final jsonString = _prefs.getString(_key);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final list = jsonDecode(jsonString) as List;
      return list
          .map((e) => RecentSearch.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Save searches to SharedPreferences
  Future<void> _saveSearches(List<RecentSearch> searches) async {
    final jsonList = searches.map((s) => s.toJson()).toList();
    await _prefs.setString(_key, jsonEncode(jsonList));
  }
}
