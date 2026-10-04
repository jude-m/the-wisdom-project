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

/// Builds the FTS5 query for the loose-Singlish tier. [spellings] holds the
/// Sinhala spellings of each typed word, in typed order.
///
/// Each mode means what it does in [buildFtsQuery]. FTS5 allows no OR inside a
/// phrase or a NEAR group, so those modes list the combinations instead.
String buildLooseFtsQuery(
  List<List<String>> spellings, {
  bool isExactMatch = false,
  bool isPhraseSearch = true,
  bool isAnywhereInText = false,
  int proximityDistance = 10,
}) {
  if (spellings.isEmpty) return '""';

  String anyOf(List<String> forWord) =>
      '(${forWord.map((s) => isExactMatch ? s : '$s*').join(' OR ')})';

  if (spellings.length == 1) return anyOf(spellings.single);
  if (!isPhraseSearch && isAnywhereInText) {
    return spellings.map(anyOf).join(' AND ');
  }
  return spellingCombinations(spellings)
      .map((words) => buildFtsQuery(
            words.join(' '),
            isExactMatch: isExactMatch,
            isPhraseSearch: isPhraseSearch,
            isAnywhereInText: isAnywhereInText,
            proximityDistance: proximityDistance,
          ))
      .join(' OR ');
}

/// Every way to pick one spelling per word, in order, at most [max] of them.
///
/// When there are more, each word keeps its first few spellings, the room
/// shared evenly (two words: 8 × 8), so no word loses all but one.
List<List<String>> spellingCombinations(
  List<List<String>> spellings, {
  int max = 64,
}) {
  // Grow each word's share by one in turn while the product still fits.
  final keep = [for (final forWord in spellings) forWord.isEmpty ? 0 : 1];
  var product = keep.fold(1, (a, b) => a * b);
  for (var grew = product > 0; grew;) {
    grew = false;
    for (var i = 0; i < spellings.length; i++) {
      if (keep[i] >= spellings[i].length) continue;
      final next = product ~/ keep[i] * (keep[i] + 1);
      if (next > max) continue;
      product = next;
      keep[i]++;
      grew = true;
    }
  }

  var combinations = [<String>[]];
  for (var i = 0; i < spellings.length; i++) {
    combinations = [
      for (final head in combinations)
        for (final spelling in spellings[i].take(keep[i])) [...head, spelling],
    ];
  }
  return combinations;
}
