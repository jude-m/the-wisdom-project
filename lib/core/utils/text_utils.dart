/// Removes zero-width chars, collapses whitespace, optionally lowercases.
String normalizeText(String text, {bool toLowerCase = false}) {
  var normalized = text
      .replaceAll('\u200D', '') // Zero-Width Joiner
      .replaceAll('\u200C', '') // Zero-Width Non-Joiner
      .replaceAll('\u200B', '') // Zero-Width Space
      .replaceAll('\uFEFF', ''); // Byte Order Mark

  // Collapse multiple spaces and trim
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

  return toLowerCase ? normalized.toLowerCase() : normalized;
}

/// Normalizes query text for FTS search (no lowercasing).
String normalizeQueryText(String query) => normalizeText(query);

/// Zero-width characters removed during normalization.
const _zeroWidthChars = {'\u200D', '\u200C', '\u200B', '\uFEFF'};

/// Sinhala Unicode block range (U+0D80-U+0DFF).
/// Includes signs, independent vowels, consonants, virama, and dependent vowel signs.
const sinhalaUnicodeRange = r'\u0D80-\u0DFF';

/// Pattern for matching Sinhala words.
/// Includes Zero-Width Joiner (U+200D) for conjunct consonants.
final sinhalaWordPattern = RegExp('[$sinhalaUnicodeRange\\u200D]+');

/// Maps normalized text positions back to original positions.
/// Returns list where `map[i]` = original position for normalized index `i`.
List<int> createNormalizedToOriginalPositionMap(String originalText) {
  final map = <int>[];

  for (int i = 0; i < originalText.length; i++) {
    final char = originalText[i];
    // Skip zero-width characters (they don't appear in normalized text)
    if (_zeroWidthChars.contains(char)) {
      continue;
    }
    map.add(i);
  }
  // Add end position for substring extraction
  map.add(originalText.length);

  return map;
}

/// Chars stripped from queries. 
/// Periods/commas/hyphens are also removed to avoid FTS complexity although they appear in titles.
const _invalidSearchChars = r'"()*{}\[\]@#$%&=+<>\\`|/;\^!.,-';
final _invalidCharsPattern = RegExp('[$_invalidSearchChars]');

/// Matches valid content: Sinhala, English, or digits.
final _validContentPattern = RegExp(r'[\u0D80-\u0DFFa-zA-Z0-9]');

/// Sinhala dependent vowel signs (pillam) - must attach to base chars.
final _sinhalaPillamPattern = RegExp(r'[\u0DCA\u0DCF-\u0DDF\u0DF2\u0DF3]');

/// Sinhala base characters (independent vowels + consonants).
final _sinhalaBaseCharPattern = RegExp(r'[\u0D85-\u0D96\u0D9A-\u0DC6]');

/// Strips invalid chars, returns `null` if no valid content remains.
String? sanitizeSearchQuery(String query) {
  var sanitized = normalizeText(query);
  sanitized = sanitized.replaceAll(_invalidCharsPattern, '');
  sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();

  if (!_validContentPattern.hasMatch(sanitized)) {
    return null;
  }

  // If query contains Sinhala vowel signs (pillam), it MUST also contain
  // Sinhala base characters (consonants or independent vowels).
  // Pillam + only digits/English = invalid (e.g., "123ි" or "testි")
  if (_sinhalaPillamPattern.hasMatch(sanitized) &&
      !_sinhalaBaseCharPattern.hasMatch(sanitized)) {
    return null;
  }

  return sanitized;
}
