/// Ported from lib/data/datasources/fts_datasource.dart (models only — the
/// datasource interface stays in the app).
/// Prototype-only duplication — the real build extracts these into a shared package.
library;

/// Data model for FTS search results from the server API.
class FTSMatch {
  const FTSMatch({
    required this.editionId,
    required this.id,
    required this.filename,
    required this.eind,
    required this.language,
    required this.type,
    required this.level,
    required this.nodeKey,
    this.relevanceScore,
    this.matchedText,
  });

  final String editionId;
  final int id;

  /// Content file id, e.g. 'dn-1'.
  final String filename;

  /// Match position, format: "pageIndex-entryIndex".
  final String eind;
  final String language;
  final String type;
  final int level;
  final String nodeKey;
  final double? relevanceScore;

  /// Pre-loaded matched text from the server (used as the result snippet).
  final String? matchedText;

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
      matchedText: map['matchedText'] as String?,
    );
  }

  /// Page index parsed from [eind] ("pageIndex-entryIndex").
  int get pageIndex => int.parse(eind.split('-')[0]);

  /// Entry index parsed from [eind] ("pageIndex-entryIndex").
  int get entryIndex => int.parse(eind.split('-')[1]);
}
