import 'package:wisdom_shared/wisdom_shared.dart';

import 'singlish_transliterator.dart';
import 'text_utils.dart';

/// Computes the effective search query from raw user input.
///
/// Shared pipeline for FTS search, in-page search, and dictionary lookup:
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
String computeEffectiveQuery(String rawQuery) =>
    normalizeText(_convertQuery(rawQuery));

/// The Sinhala to show for a Singlish [rawQuery], or null when there is none:
/// Sinhala input, a sutta reference like "SN 15.3", or nothing left after
/// cleaning.
///
/// Checks for Latin letters rather than comparing raw and converted text:
/// trimming or ZWJ removal also changes Sinhala input, which is no conversion.
/// Unlike [computeEffectiveQuery] it keeps ZWJ, so ්‍ර and ‍ය render joined
/// instead of with a visible hal. Display only — search never uses it.
String? singlishPreviewText(String rawQuery) {
  if (!SinglishTransliterator.instance.isSinglishQuery(rawQuery)) return null;
  if (SuttaCentralRefResolver.parseRef(rawQuery) != null) return null;
  final display = _convertQuery(rawQuery);
  return display.isEmpty ? null : display;
}

/// Steps 1–3 of [computeEffectiveQuery].
String _convertQuery(String rawQuery) {
  final sanitized = sanitizeSearchQuery(rawQuery);
  if (sanitized == null || sanitized.isEmpty) return '';

  final transliterator = SinglishTransliterator.instance;
  final converted = transliterator.isSinglishQuery(sanitized)
      ? transliterator.convert(sanitized)
      : sanitized;

  // Remove leftover ~ that didn't match special patterns (e.g., "aaka~")
  return converted.replaceAll('~', '');
}
