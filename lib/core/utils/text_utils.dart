/// Remove zero-width Unicode characters that appear in Sinhala/Pali text.
/// These invisible characters break text matching operations.
///
/// Characters removed:
/// - U+200D: Zero-Width Joiner (ZWJ)
/// - U+200C: Zero-Width Non-Joiner (ZWNJ)
/// - U+200B: Zero-Width Space (ZWSP)
/// - U+FEFF: Byte Order Mark (BOM)
///
/// Set [toLowerCase] to true for case-insensitive search matching.
String normalizeText(String text, {bool toLowerCase = false}) {
  var normalized = text
      .replaceAll('\u200D', '') // Zero-Width Joiner
      .replaceAll('\u200C', '') // Zero-Width Non-Joiner
      .replaceAll('\u200B', '') // Zero-Width Space
      .replaceAll('\uFEFF', ''); // Byte Order Mark

  return toLowerCase ? normalized.toLowerCase() : normalized;
}

/// Alias for [normalizeText] without lowercasing.
/// Used for query sanitization before FTS search.
String normalizeQueryText(String query) => normalizeText(query);
