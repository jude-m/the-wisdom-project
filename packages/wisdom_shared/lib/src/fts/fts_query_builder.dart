/// Builds FTS5 query syntax for single or multi-word queries.
///
/// ## Single word:
/// - `word*` (prefix matching) when [isExactMatch] is false
/// - `word` (exact token) when [isExactMatch] is true
///
/// ## Multi-word with [isPhraseSearch] = true (phrase search):
/// - [isExactMatch] = true: `"word1 word2"` (exact phrase, consecutive)
/// - [isExactMatch] = false: `NEAR(word1* word2*, 1)` (adjacent with prefix)
///   Note: FTS5 doesn't support wildcards inside phrase quotes, so we use
///   NEAR with distance 1 as a workaround for phrase+prefix matching.
///
/// ## Multi-word with [isPhraseSearch] = false (separate-word search):
/// - [isAnywhereInText] = true: Implicit AND (space-separated words)
/// - [isAnywhereInText] = false: Use NEAR(terms, n) for proximity
/// - [isExactMatch] affects whether wildcards are added to each word
///
/// ## Search Flows Summary (FTS5):
/// | isPhraseSearch | isAnywhereInText | isExactMatch | FTS5 Query |
/// |---------------|------------------|--------------|------------|
/// | true | - | true | `"word1 word2"` (exact phrase) |
/// | true | - | false | `NEAR(word1* word2*, 1)` (phrase with/adjacent prefix) |
/// | false | true | true | `word1 word2` (AND, exact tokens) |
/// | false | true | false | `word1* word2*` (AND, prefix match) |
/// | false | false | true | `NEAR(word1 word2, n)` (proximity, exact) |
/// | false | false | false | `NEAR(word1* word2*, n)` (proximity, prefix) |
String buildFtsQuery(
  String queryText, {
  bool isExactMatch = false,
  bool isPhraseSearch = true,
  bool isAnywhereInText = false,
  int proximityDistance = 10,
}) {
  if (queryText.isEmpty) {
    return '""';
  }

  // Split into words (handles multi-word queries)
  final words = queryText.split(' ').where((w) => w.isNotEmpty).toList();

  if (words.length == 1) {
    // Single word: simple token matching (no quotes)
    return isExactMatch ? words[0] : '${words[0]}*';
  }

  // Multi-word handling
  if (isPhraseSearch) {
    // Phrase search: words must be adjacent (consecutive)
    if (isExactMatch) {
      // Exact phrase: use double quotes for FTS phrase query
      return '"${words.join(' ')}"';
    } else {
      // FTS5 workaround: wildcards not supported inside phrase quotes
      // Use NEAR with distance 1 to approximate phrase+prefix behavior
      return 'NEAR(${words.map((w) => '$w*').join(' ')}, 1)';
    }
  } else {
    // Separate-word search
    if (isAnywhereInText) {
      // Anywhere in text: use implicit AND (no NEAR operator)
      if (isExactMatch) {
        return words.join(' ');
      } else {
        return words.map((w) => '$w*').join(' ');
      }
    } else {
      // Proximity search: words within specific distance
      if (isExactMatch) {
        return 'NEAR(${words.join(' ')}, $proximityDistance)';
      } else {
        return 'NEAR(${words.map((w) => '$w*').join(' ')}, $proximityDistance)';
      }
    }
  }
}
