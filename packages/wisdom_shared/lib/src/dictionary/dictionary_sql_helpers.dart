/// Builds a SQL LIKE pattern for dictionary word lookup.
///
/// Escapes special LIKE characters (% and _).
/// Returns prefix match pattern by default, exact match when [exactMatch] is true.
String buildDictionaryLikePattern(String word, {bool exactMatch = false}) {
  if (word.isEmpty) return '%';
  final escaped = word.replaceAll('%', '\\%').replaceAll('_', '\\_');
  return exactMatch ? escaped : '$escaped%';
}

/// Appends SQL WHERE clause fragment for dictionary ID filtering.
///
/// If [dictionaryIds] is empty, nothing is appended (all dictionaries).
void appendDictionaryFilter(
  StringBuffer buffer,
  List<Object> args,
  Set<String> dictionaryIds,
) {
  if (dictionaryIds.isNotEmpty) {
    final placeholders = List.filled(dictionaryIds.length, '?').join(', ');
    buffer.write(' AND dict_id IN ($placeholders)');
    args.addAll(dictionaryIds);
  }
}
