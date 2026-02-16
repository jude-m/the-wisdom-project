import 'singlish_transliterator.dart';
import 'text_utils.dart';

/// Computes the effective search query from raw user input.
///
/// Shared pipeline for both FTS search and in-page search:
/// 1. [sanitizeSearchQuery] - strip invalid chars, normalize ZWJ
/// 2. [SinglishTransliterator.convert] - Singlish → Sinhala (if ASCII input)
/// 3. Strip leftover `~` (incomplete special char escapes)
/// 4. [normalizeText] - strip ZWJ/ZWNJ re-introduced by transliteration
///
/// Step 4 is critical: the transliterator adds ZWJ for rakaransha (්‍ර) and
/// yansaya (‍ය), but FTS index and [SearchMatchFinder] store/match text
/// without ZWJ. Without this step, Singlish "prahaa" → ප්‍රහා (with ZWJ)
/// won't match the indexed ප්රහා (without ZWJ).
///
/// Returns empty string if query is invalid.
String computeEffectiveQuery(String rawQuery) {
  final sanitized = sanitizeSearchQuery(rawQuery);
  if (sanitized == null || sanitized.isEmpty) return '';

  final transliterator = SinglishTransliterator.instance;
  final converted = transliterator.isSinglishQuery(sanitized)
      ? transliterator.convert(sanitized)
      : sanitized;

  // Remove leftover ~ that didn't match special patterns (e.g., "aaka~")
  var result = converted.replaceAll('~', '');

  // Normalize ZWJ/ZWNJ that the transliterator adds for rakaransha/yansaya.
  // Both FTS index and SearchMatchFinder match text without these characters.
  result = normalizeText(result);

  return result;
}

/// Whether the effective query differs from raw input due to Singlish conversion.
///
/// Used by both FTS and in-page search state classes to expose a
/// consistent `isSinglishConverted` getter.
bool querySinglishConverted(String rawQuery, String effectiveQuery) =>
    rawQuery.isNotEmpty &&
    effectiveQuery.isNotEmpty &&
    rawQuery != effectiveQuery;
