/// Data model for FTS search results from the database
/// Includes edition information for multi-edition search support
class FTSMatch {
  final String editionId;
  final int id;
  final String filename;
  final String eind;
  final String language;
  final String type;
  final int level;

  /// The tree node key for this entry (e.g., 'dn-1-1' for Brahmajala Sutta).
  /// Enables direct O(1) lookup of the containing sutta/section.
  final String nodeKey;

  /// BM25 relevance score from FTS5.
  /// Lower values (more negative) indicate better matches.
  /// null if ranking not available.
  final double? relevanceScore;

  FTSMatch({
    required this.editionId,
    required this.id,
    required this.filename,
    required this.eind,
    required this.language,
    required this.type,
    required this.level,
    required this.nodeKey,
    this.relevanceScore,
  });

  factory FTSMatch.fromMap(Map<String, dynamic> map, String editionId) {
    return FTSMatch(
      editionId: editionId,
      id: map['id'] as int,
      filename: map['filename'] as String,
      eind: map['eind'] as String,
      language: map['language'] as String,
      type: map['type'] as String,
      level: map['level'] as int,
      nodeKey: map['nodeKey'] as String,
      relevanceScore: map['score'] as double?,
    );
  }
}

/// Abstract interface for FTS (Full-Text Search) data source
/// Supports multiple Tipitaka editions with separate databases
abstract class FTSDataSource {
  /// Initialize FTS databases for the specified editions
  /// Each edition has its own database file: {editionId}.db
  Future<void> initializeEditions(Set<String> editionIds);

  /// Search for content across one or more editions
  /// Returns results tagged with their source edition
  ///
  /// [scope] - Tree node keys (e.g., 'sp', 'dn', 'dn-1') for filtering.
  /// Empty set = search all content.
  ///
  /// [isPhraseSearch] - true for phrase matching (consecutive/adjacent words),
  /// false for separate-word search (words within proximity).
  ///
  /// [isAnywhereInText] - When true and isPhraseSearch is false, ignores
  /// proximity distance and searches anywhere in the text.
  ///
  /// [proximityDistance] - Distance for NEAR/n proximity (1-100).
  /// Only used when isPhraseSearch is false and isAnywhereInText is false.
  ///
  /// [language] - When non-null ('pali' or 'sinh'), restricts matches to that
  /// language's text only. Null (default) searches both languages. Driven by
  /// the පාළි / සිංහල search toggles in the refine dialog.
  Future<List<FTSMatch>> searchFullText(
    String query, {
    required Set<String> editionIds,
    Set<String> scope = const {},
    bool isExactMatch = false,
    bool isPhraseSearch = true,
    bool isAnywhereInText = false,
    int proximityDistance = 10,
    String? language,
    int limit = 50,
    int offset = 0,
  });

  /// Count full-text matches without loading results (efficient for tab badges)
  ///
  /// [scope] - Tree node keys (e.g., 'sp', 'dn', 'dn-1') for filtering.
  /// Empty set = count all content.
  ///
  /// [isPhraseSearch] - true for phrase matching (consecutive/adjacent words),
  /// false for separate-word search (words within proximity).
  ///
  /// [isAnywhereInText] - When true and isPhraseSearch is false, ignores
  /// proximity distance and searches anywhere in the text.
  ///
  /// [proximityDistance] - Distance for NEAR/n proximity (1-100).
  /// Only used when isPhraseSearch is false and isAnywhereInText is false.
  ///
  /// [language] - When non-null ('pali' or 'sinh'), counts only that language's
  /// matches. Null (default) counts both. Must mirror the filter used by
  /// [searchFullText] so the tab badge matches the visible rows.
  Future<int> countFullTextMatches(
    String query, {
    required String editionId,
    Set<String> scope = const {},
    bool isExactMatch = false,
    bool isPhraseSearch = true,
    bool isAnywhereInText = false,
    int proximityDistance = 10,
    String? language,
  });

  /// Close all database connections
  Future<void> close();
}
