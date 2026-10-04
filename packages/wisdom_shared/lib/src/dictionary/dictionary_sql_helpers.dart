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
const String dictionaryOrderBy = 'ORDER BY $_dictionaryRowOrder';

/// [dictionaryOrderBy] after the strict rows (`tier` 0) come the similar
/// spellings of a Singlish query (`tier` 1 and up, one per spelling). In
/// each, the spelling as a whole word (`is_reading` 0) comes before longer
/// words, and the headword with the most entries first: the word every
/// dictionary has (පඤ්ඤා) before a stem (පඤ්ඤ), each word's entries
/// together. Needs `tier` and `is_reading` in the SELECT too.
const String dictionaryTieredOrderBy = 'ORDER BY tier ASC, '
    'CASE WHEN tier > 0 THEN is_reading END, '
    'CASE WHEN tier > 0 THEN (SELECT count(*) FROM dictionary e '
    'WHERE e.word = dictionary.word) END DESC, '
    'CASE WHEN tier > 0 THEN word END, '
    '$_dictionaryRowOrder';

const String _dictionaryRowOrder = 'is_exact ASC, rank DESC, word, id';

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

/// Appends one condition matching any of [words], each as in
/// [appendDictionaryWordMatch].
void appendDictionaryAnyWordMatch(
  StringBuffer buffer,
  List<Object> args,
  List<String> words, {
  bool exactMatch = false,
}) {
  buffer.write('(');
  for (var i = 0; i < words.length; i++) {
    if (i > 0) buffer.write(' OR ');
    buffer.write('(');
    appendDictionaryWordMatch(buffer, args, words[i], exactMatch: exactMatch);
    buffer.write(')');
  }
  buffer.write(')');
}
