/// Remove zero-width Unicode characters that appear in Sinhala/Pali text.
/// These invisible characters break text matching operations.
///
/// Characters removed:
/// - U+200D: Zero-Width Joiner (ZWJ)
/// - U+200C: Zero-Width Non-Joiner (ZWNJ)
/// - U+200B: Zero-Width Space (ZWSP)
/// - U+FEFF: Byte Order Mark (BOM)
String normalizeQueryText(String query) => query
    .replaceAll('\u200D', '') // Zero-Width Joiner
    .replaceAll('\u200C', '') // Zero-Width Non-Joiner
    .replaceAll('\u200B', '') // Zero-Width Space
    .replaceAll('\uFEFF', ''); // Byte Order Mark
