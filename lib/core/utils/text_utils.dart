/// Removes zero-width Unicode chars (ZWJ, ZWNJ, ZWSP, BOM), collapses
/// whitespace, and optionally lowercases for case-insensitive matching.
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

/// Alias for [normalizeText] without lowercasing.
/// Used for query sanitization before FTS search.
String normalizeQueryText(String query) => normalizeText(query);

/// Chars stripped from queries. Escaped for regex: \[ \] \\ \^
/// Note: Periods/commas NOT stripped - needed for title search (e.g., "1. 1. 1.").
/// FTS handles them via unicode61 tokenizer.
const _invalidSearchChars = r'"()*{}\[\]@#$%&=<>~\\`|/;\^!';
final _invalidCharsPattern = RegExp('[$_invalidSearchChars]');

/// Regex pattern to check for valid content.
/// Matches Sinhala (U+0D80-U+0DFF), English (a-zA-Z), or digits (0-9).
final _validContentPattern = RegExp(r'[\u0D80-\u0DFFa-zA-Z0-9]');

/// Sinhala dependent vowel signs (pillam) - must attach to base characters.
/// Includes: virama (U+0DCA), vowel signs (U+0DCF-U+0DDF, U+0DF2-U+0DF3)
final _sinhalaPillamPattern = RegExp(r'[\u0DCA\u0DCF-\u0DDF\u0DF2\u0DF3]');

/// Sinhala base characters that can stand alone:
/// - Independent vowels: U+0D85-U+0D96 (අ ආ ඇ ඈ ඉ...)
/// - Consonants: U+0D9A-U+0DC6 (ක ඛ ග ඝ...)
final _sinhalaBaseCharPattern = RegExp(r'[\u0D85-\u0D96\u0D9A-\u0DC6]');

/// Sanitizes search query by stripping invalid chars (see [_invalidSearchChars]).
/// Returns `null` if no valid content (Sinhala/English/digits) remains,
/// or if query contains Sinhala vowel signs (pillam) without base characters.
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
