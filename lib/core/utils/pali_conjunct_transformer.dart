/// Conjunct consonant transformation for Pali text in Sinhala script.
///
/// Turns Pali consonant clusters into their bound (conjunct) forms using the
/// Zero-Width Joiner (ZWJ, U+200D). There are **two structurally different**
/// joining mechanisms — see `docs/pali-letter-settings-bandi-special-toggles.md`:
///
/// - **Ligated** = hal (U+0DCA) **then** ZWJ → a fused glyph from a fixed
///   inventory the font must contain. Used by Switch 3 (standard) and Switch 2
///   (special).
/// - **Touching** = ZWJ **then** hal → hides the hal and pushes the letters
///   together; a general/productive rule that works on any cluster. Used by
///   Switch 1 (touching).
library;

import 'pali_letter_options.dart';

/// Zero-Width Joiner (U+200D) — used to form conjunct consonants.
const _zwj = '\u200D';

/// Zero-Width Non-Joiner (U+200C) — stripped from source text.
const _zwnj = '\u200C';

/// Sinhala virama / hal kirīma (U+0DCA, ්).
const _hal = '්';

/// ය = U+0DBA (yayanna), ර = U+0DBB (rayanna).
const _yayanna = 'ය';
const _rayanna = 'ර';

/// **Switch 3** — common ligated pairs (8). Everyday conjuncts that join with
/// `hal + ZWJ`. Fuller than tipitaka.lk's 6 (adds ක්ෂ and න්ව), per pitaka.lk.
/// Format: [firstConsonant, secondConsonant].
const _commonConjunctPairs = [
  ['ක', 'ව'], // ක + ව  → ක්ව
  ['ක', 'ෂ'], // ක + ෂ  → ක්ෂ
  ['ත', 'ථ'], // ත + ථ  → ත්ථ
  ['ත', 'ව'], // ත + ව  → ත්ව
  ['න', 'ව'], // න + ව  → න්ව
  ['න', 'ථ'], // න + ථ  → න්ථ
  ['න', 'ද'], // න + ද  → න්ද
  ['න', 'ධ'], // න + ධ  → න්ධ
];

/// **Switch 2** — special / rare old-Pali ligatures (7). Ornate forms found in
/// old Pali books that need UN-type fonts; join with `hal + ZWJ`. This list is
/// **exactly** tipitaka.lk's `paliConjuncts`.
///
/// Two characters are DELIBERATELY excluded from this list — do not "helpfully"
/// re-add them (see the plan doc, §3):
///   • ම්බ — rare; tipitaka.lk excludes it and there is already a dedicated
///     prenasalized letter ඹ for "mb". (Switch 1 still binds it via touching.)
///   • ඞ්ග → ඟ — NOT a joiner but a single-codepoint *prenasalized* substitution
///     that can change meaning (cf. කන්ද "hill" vs කඳ "trunk"). Out of scope.
const _specialConjunctPairs = [
  ['ඤ', 'ච'], // ඤ + ච  → ඤ්ච
  ['ඤ', 'ජ'], // ඤ + ජ  → ඤ්ජ
  ['ඤ', 'ඡ'], // ඤ + ඡ  → ඤ්ඡ
  ['ට', 'ඨ'], // ට + ඨ  → ට්ඨ
  ['ණ', 'ඩ'], // ණ + ඩ  → ණ්ඩ
  ['ද', 'ධ'], // ද + ධ  → ද්ධ
  ['ද', 'ව'], // ද + ව  → ද්ව
];

/// **Switch 1** — touching pattern: consonant + hal + consonant, over the full
/// Sinhala consonant range U+0D9A–U+0DC6 (ක–ෆ). ZWJ is inserted BEFORE the hal.
/// The ligated tiers (Switch 3/2) run first and insert ZWJ *after* the hal,
/// which shields those pairs from this regex (the hal is no longer immediately
/// followed by a consonant), so each ligated tier wins over this catch-all.
final _touchingPattern = RegExp(r'([ක-ෆ])්([ක-ෆ])');

/// Repaya: ර as the *first* consonant of a cluster (ර + hal + consonant). ZWJ
/// goes after the hal: `ර ්` → `ර ් ‍`. Run AFTER yansaya/rakaransaya so an
/// already-reduced pair (which now has a ZWJ between hal and the consonant)
/// can't re-match here.
final _repayaPattern = RegExp(r'ර්([ක-ෆ])');

// ===========================================================================
// SINGLE-PURPOSE UNITS (each pure, one job — String → String)
// ===========================================================================

/// Strips existing ZWJ/ZWNJ so transformation is idempotent regardless of what
/// the source JSON already contains.
String _stripZeroWidth(String t) =>
    t.replaceAll(_zwnj, '').replaceAll(_zwj, '');

/// Switch 3 · yansaya — `් ය` → `් ‍ ය` (ligated, ZWJ after hal).
String addYansaya(String t) =>
    t.replaceAll('$_hal$_yayanna', '$_hal$_zwj$_yayanna');

/// Switch 3 · rakaransaya — `් ර` → `් ‍ ර` (ligated, ZWJ after hal).
String addRakaransaya(String t) =>
    t.replaceAll('$_hal$_rayanna', '$_hal$_zwj$_rayanna');

/// Switch 3 · repaya — `ර ්` (ර first) → `ර ් ‍` (ligated, ZWJ after hal).
String addRepaya(String t) => t.replaceAllMapped(
      _repayaPattern,
      (m) => '$_rayanna$_hal$_zwj${m.group(1)}',
    );

/// Ligates each `[first, second]` pair: `X ් Y` → `X ් ‍ Y` (ZWJ after the
/// hal). Shared by the common (Switch 3) and special (Switch 2) tiers, which
/// differ only in their pair list.
String _ligatePairs(String t, List<List<String>> pairs) {
  var result = t;
  for (final pair in pairs) {
    result = result.replaceAll(
      '${pair[0]}$_hal${pair[1]}',
      '${pair[0]}$_hal$_zwj${pair[1]}',
    );
  }
  return result;
}

/// Switch 3 · the 8 common ligated pairs — `X ් Y` → `X ් ‍ Y`.
String addCommonConjuncts(String t) => _ligatePairs(t, _commonConjunctPairs);

/// Switch 2 · the 7 special ligated pairs — `X ් Y` → `X ් ‍ Y`.
String addSpecialConjuncts(String t) => _ligatePairs(t, _specialConjunctPairs);

/// Switch 1 · touching — `X ් Y` → `X ‍ ් Y` for every remaining cluster.
/// Applied twice to catch consecutive clusters (e.g. ගන්ත්වා has two hals where
/// a consonant is shared between two overlapping matches).
String addTouchingConjuncts(String t) {
  String join(String s) => s.replaceAllMapped(
        _touchingPattern,
        (m) => '${m.group(1)}$_zwj$_hal${m.group(2)}',
      );
  return join(join(t));
}

/// Switch 1 · long→short vowel (traditional Pali orthography):
/// ේ (U+0DDA) → ෙ (U+0DD9), ෝ (U+0DDD) → ො (U+0DDC).
String shortenVowels(String t) =>
    t.replaceAll('ේ', 'ෙ').replaceAll('ෝ', 'ො');

// ===========================================================================
// ORCHESTRATOR (composition only)
// ===========================================================================

/// Applies the enabled Pali-letter transformations in the correct order:
/// ligated tiers (Switch 3, then Switch 2) before touching (Switch 1) so the
/// after-hal ZWJ shields ligated pairs from the touching catch-all.
///
/// Always leads with [_stripZeroWidth] so re-application is idempotent.
///
/// Only meaningful for Pali text. Sinhala translations must NOT be transformed
/// — that would incorrectly bind consonants (the seam in
/// `content_text_formatter.dart` enforces this).
String beautifyPaliText(String text, PaliLetterOptions options) {
  var t = _stripZeroWidth(text);

  if (options.standardLigatures) {
    // Switch 3 (ligated). Reduced forms first, then common pairs.
    t = addYansaya(t);
    t = addRakaransaya(t);
    t = addRepaya(t);
    t = addCommonConjuncts(t);
  }

  if (options.specialConjuncts) {
    // Switch 2 (ligated).
    t = addSpecialConjuncts(t);
  }

  if (options.touching) {
    // Switch 1 (touching) — catch-all for whatever the ligated tiers left.
    t = addTouchingConjuncts(t);
    t = shortenVowels(t);
  }

  return t;
}

/// Builds a position map from [source] (plainText) to [target] (displayText
/// after conjunct transformation).
///
/// Returns a `List<int>` of length `source.length + 1` where `map[i]` gives
/// the corresponding index in [target] for source index `i`. The extra entry
/// at `source.length` maps to the end of [target] (sentinel for range ends).
///
/// The conjunct transformation only inserts/removes ZWJ/ZWNJ and replaces
/// vowels 1:1, so every "real" character in source has exactly one counterpart
/// in target — just at a potentially different offset. (Agnostic to *which*
/// switches ran, since they all only add/remove zero-width chars or swap a
/// vowel 1:1.)
List<int> buildConjunctPositionMap(String source, String target) {
  final map = List<int>.filled(source.length + 1, 0);
  int si = 0;
  int ti = 0;

  while (si < source.length) {
    // Skip zero-width characters in source (removed by transformation)
    if (source[si] == _zwj || source[si] == _zwnj) {
      map[si] = ti;
      si++;
      continue;
    }

    // Skip zero-width characters in target (inserted by transformation)
    while (ti < target.length && (target[ti] == _zwj || target[ti] == _zwnj)) {
      ti++;
    }

    // Real characters correspond 1:1 (including vowel replacements)
    map[si] = ti;
    si++;
    if (ti < target.length) ti++;
  }

  // Sentinel: map end-of-source to current target position
  // (skip any trailing ZWJ in target)
  while (ti < target.length && (target[ti] == _zwj || target[ti] == _zwnj)) {
    ti++;
  }
  map[source.length] = ti;

  return map;
}

/// Removes ZWJ/ZWNJ formatting from text for dictionary lookup.
///
/// Display text contains ZWJ characters that create visual conjuncts, but
/// dictionary databases store text without these formatting characters. This
/// strips ZWJ (U+200D) and ZWNJ (U+200C) to enable proper lookups, regardless
/// of which switches produced the display text.
///
/// Note: This does NOT reverse vowel conversion (ෙ→ේ, ො→ෝ).
String removeConjunctFormatting(String text) {
  return text.replaceAll(_zwj, '').replaceAll(_zwnj, '');
}

/// Convenience extension for applying conjunct transformation inline.
///
/// Usage:
/// ```dart
/// Text(paliName.withPaliLetters(options))
/// ```
extension PaliConjunctExtension on String {
  /// Returns this string with the enabled Pali-letter transformations applied.
  String withPaliLetters(PaliLetterOptions options) =>
      beautifyPaliText(this, options);
}

/// Applies conjunct transformation and remaps highlight ranges.
///
/// Takes [rawText] and a list of character [ranges] found on the raw text,
/// transforms the text via [beautifyPaliText] using [options], then remaps the
/// ranges to the display text coordinates using [buildConjunctPositionMap].
///
/// Returns the display text and remapped ranges as a record.
///
/// Used by both the reading pane and FTS search results to avoid duplicating
/// the transform-then-remap pattern.
(String, List<({int start, int end})>) applyConjunctsWithRangeMapping(
  String rawText,
  List<({int start, int end})> ranges,
  PaliLetterOptions options,
) {
  final displayText = beautifyPaliText(rawText, options);
  if (ranges.isEmpty) return (displayText, const []);

  final posMap = buildConjunctPositionMap(rawText, displayText);
  final remappedRanges = [
    for (final r in ranges) (start: posMap[r.start], end: posMap[r.end]),
  ];
  return (displayText, remappedRanges);
}
