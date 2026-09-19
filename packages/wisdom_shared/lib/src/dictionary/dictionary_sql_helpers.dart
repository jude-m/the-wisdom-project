/// Appends the WHERE condition for headwords starting with [word], or equal
/// to it when [exactMatch] is true.
///
/// A range rather than `LIKE`, so SQLite searches `idx_word` instead of reading
/// the whole table. U+10FFFF sorts after any character that can follow [word].
void appendDictionaryWordMatch(
  StringBuffer buffer,
  List<Object> args,
  String word, {
  bool exactMatch = false,
}) {
  if (exactMatch) {
    buffer.write('word = ?');
    args.add(word);
  } else {
    buffer.write('word >= ? AND word < ?');
    args.addAll([word, '$word\u{10FFFF}']);
  }
}

/// Dictionary result order: exact match, then the higher-ranked dictionary,
/// then alphabetical. `rank` is the same for a whole dictionary, so without
/// the last two the order inside one would depend on the query plan; `id`
/// breaks the last ties. Needs `is_exact` in the SELECT.
const String dictionaryOrderBy = 'ORDER BY is_exact ASC, rank DESC, word, id';

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
