import 'package:characters/characters.dart';

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

/// Pre-compiled whitespace pattern for search normalization.
final _whitespacePattern = RegExp(r'\s');

/// Normalizes text for search and builds a position map in a single pass.
///
/// Strips zero-width chars and sentence punctuation ([_invalidTextCharsPattern]),
/// collapses whitespace, trims, and lowercases.
/// Only strips punctuation that appears between tokens (`.` `;` `!`).
/// Formatting markers (`**`, `{}`, etc.) are left intact.
///
/// Returns the normalized string and a position map where
/// `positionMap[i]` = original index for normalized char `i`.
({String normalized, List<int> positionMap}) normalizeSearchText(
  String originalText,
) {
  final buffer = StringBuffer();
  final map = <int>[];
  bool lastWasSpace = true; // Start true to skip leading whitespace (trim)

  for (int i = 0; i < originalText.length; i++) {
    final char = originalText[i];
    // Skip zero-width characters
    if (_zeroWidthChars.contains(char)) continue;
    // Skip search-invalid characters (punctuation, but keep - and ,)
    if (_invalidTextCharsPattern.hasMatch(char)) continue;

    // Collapse consecutive whitespace
    if (_whitespacePattern.hasMatch(char)) {
      if (lastWasSpace) continue;
      lastWasSpace = true;
    } else {
      lastWasSpace = false;
    }

    buffer.write(char);
    map.add(i);
  }

  // Trim trailing whitespace from both buffer and map
  var normalizedStr = buffer.toString();
  if (map.isNotEmpty && lastWasSpace) {
    normalizedStr = normalizedStr.substring(0, normalizedStr.length - 1);
    map.removeLast();
  }

  // Add end position for substring extraction
  map.add(originalText.length);

  return (normalized: normalizedStr.toLowerCase(), positionMap: map);
}

/// Chars stripped from queries.
/// Periods/commas/hyphens are also removed to avoid FTS complexity although they appear in titles.
const _invalidSearchChars = r'"()*{}\[\]@#$%&=+<>\\`|/;\^!.,-';
final _invalidCharsPattern = RegExp('[$_invalidSearchChars]');

/// Sentence punctuation stripped from text during search normalization.
/// Only includes chars that appear between matched tokens in Pali/Sinhala
/// content (e.g., "16. ස") and would prevent indexOf from finding the query.
/// Formatting markers (**, {}, etc.) are NOT stripped — they wrap words
/// rather than separate them, so indexOf still finds matches through them.
const _invalidTextChars = r'.;!';
final _invalidTextCharsPattern = RegExp('[$_invalidTextChars]');

/// Matches valid content: Sinhala, English, or digits.
final _validContentPattern = RegExp(r'[\u0D80-\u0DFFa-zA-Z0-9]');

/// Sinhala dependent vowel signs (pillam) - must attach to base chars.
final _sinhalaPillamPattern = RegExp(r'[\u0DCA\u0DCF-\u0DDF\u0DF2\u0DF3]');

/// Sinhala base characters (independent vowels + consonants).
final _sinhalaBaseCharPattern = RegExp(r'[\u0D85-\u0D96\u0D9A-\u0DC6]');

// =============================================================================
// GRAPHEME-SAFE TEXT UTILITIES
// =============================================================================

/// Truncates [text] to at most [maxGraphemes] grapheme clusters, appending
/// '...' if truncation occurred.
///
/// Sinhala script uses combining characters (virama, vowel signs) that form
/// multi-code-unit grapheme clusters. Plain [String.substring] can split these
/// and produce garbled text. This function uses [Characters] to cut safely.
///
/// Returns the original string unchanged if it fits within [maxGraphemes].
String truncateGraphemes(String text, int maxGraphemes) {
  final graphemes = text.characters;
  if (graphemes.length <= maxGraphemes) return text;
  return '${graphemes.take(maxGraphemes)}...';
}

/// Snaps a code-unit [index] in [text] to the nearest grapheme cluster
/// boundary.
///
/// When [forward] is false (default), snaps backward to the start of the
/// grapheme cluster containing [index]. When [forward] is true, snaps forward
/// to the end of that cluster. Use backward-snap for snippet starts and
/// forward-snap for snippet ends to avoid splitting combining characters.
///
/// Returns 0 if [index] <= 0, or [text.length] if [index] >= text.length.
int snapToGraphemeBoundary(String text, int index, {bool forward = false}) {
  if (index <= 0) return 0;
  if (index >= text.length) return text.length;

  // Walk through grapheme clusters, tracking code-unit positions.
  int pos = 0;
  for (final grapheme in text.characters) {
    final nextPos = pos + grapheme.length;
    if (nextPos > index) {
      // index falls inside this grapheme cluster
      return forward ? nextPos : pos;
    }
    pos = nextPos;
  }
  return text.length;
}

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
