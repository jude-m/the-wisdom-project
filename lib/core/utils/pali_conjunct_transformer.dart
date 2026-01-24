/// Conjunct consonant transformation for Pali text in Sinhala script.
///
/// This utility transforms Pali text to display consonant clusters as
/// bound letters (conjuncts) using Zero-Width Joiner (ZWJ).
///
/// Example: ධම්ම → ධම්‍ම (the 'm' letters visually join)
library;

/// Zero-Width Joiner - used to form conjunct consonants
const _zwj = '\u200D';

/// Zero-Width Non-Joiner - removed from source text
const _zwnj = '\u200C';

/// Pattern for Rakaranshaya/Yansaya: hal (්) + ර or ය
/// ZWJ is inserted AFTER the hal to form the special curved sign
/// ර = U+0DBB (rayanna), ය = U+0DBA (yayanna)
final _rakarYansaPattern = RegExp(r'\u0DCA([\u0DBA\u0DBB])');

/// Special Pali conjunct pairs that form unique ligatures
/// These need ZWJ AFTER the hal (same as rakaranshaya)
/// Format: [firstConsonant, secondConsonant]
const _paliConjunctPairs = [
  ['\u0DA4', '\u0DA0'], // ඤ + ච
  ['\u0DA4', '\u0DA2'], // ඤ + ජ
  ['\u0DA4', '\u0DA1'], // ඤ + ඡ
  ['\u0DA7', '\u0DA8'], // ට + ඨ
  ['\u0DAB', '\u0DA9'], // ණ + ඩ
  ['\u0DAF', '\u0DB0'], // ද + ධ
  ['\u0DAF', '\u0DC0'], // ද + ව
];

/// Pattern for Bandi Akuru: consonant + hal + consonant (excluding ර and ය)
/// Captures: (1) first consonant, (2) second consonant (but NOT ර or ය)
/// ZWJ is inserted BEFORE the hal to form stacked/joined letters
/// Range [\u0D9A-\u0DB9\u0DBC-\u0DC6] = all consonants except ය(U+0DBA) and ර(U+0DBB)
final _bandiPattern = RegExp(r'([\u0D9A-\u0DC6])\u0DCA([\u0D9A-\u0DB9\u0DBC-\u0DC6])');

/// Transforms text to use conjunct consonants (bound letters).
///
/// - Removes ZWNJ (U+200C) that appears in some source text
/// - Applies Rakaranshaya/Yansaya for ර/ය (ZWJ after hal)
/// - Applies special Pali ligatures: ද්ධ, ඤ්ච, ඤ්ජ, ඤ්ඡ, ට්ඨ, ණ්ඩ, ද්ව (ZWJ after hal)
/// - Applies Bandi Akuru for other consonants (ZWJ before hal)
/// - Converts long vowels to short (ේ→ෙ, ෝ→ො)
///
/// [text] - The input text to transform
/// [enabled] - When false, returns text unchanged (for future settings toggle)
///
/// Note: Only meaningful for Pali text. Sinhala translations should not use this
/// as it would incorrectly join consonants that should remain separate.
///
/// Example:
/// ```dart
/// final pali = 'ධම්මපදට්ඨකථා';
/// final transformed = applyConjunctConsonants(pali);
/// // Consonant clusters now display as bound letters
/// ```
String applyConjunctConsonants(String text) {
  var result = text;

  // Step 1: Remove any existing ZWNJ and ZWJ for uniform re-application
  // Source data may already contain ZWJ for some conjuncts (e.g., rakaranshaya),
  // which would break the conjunct pattern matching. Removing both ensures
  // we can apply ZWJ uniformly to all consonant clusters.
  result = result.replaceAll(_zwnj, ''); // ZWNJ (U+200C)
  result = result.replaceAll(_zwj, ''); // ZWJ (U+200D) - existing conjuncts

  const hal = '\u0DCA'; // Sinhala virama (hal kirīma)

  // Step 2: Apply Rakaranshaya/Yansaya FIRST
  // For ර and ය, ZWJ goes AFTER the hal: hal + ZWJ + ර/ය
  // This creates the special curved signs (rakaranshaya/yansaya)
  result = result.replaceAllMapped(
    _rakarYansaPattern,
    (match) => '$hal$_zwj${match.group(1)}',
  );

  // Step 3: Apply special Pali conjunct pairs (ද්ධ, ඤ්ච, etc.)
  // These form unique ligatures and need ZWJ AFTER the hal
  // Pattern: consonant1 + hal + consonant2 → consonant1 + hal + ZWJ + consonant2
  for (final pair in _paliConjunctPairs) {
    final pattern = '${pair[0]}$hal${pair[1]}';
    final replacement = '${pair[0]}$hal$_zwj${pair[1]}';
    result = result.replaceAll(pattern, replacement);
  }

  // Step 4: Apply Bandi Akuru for other consonants
  // ZWJ goes BEFORE the hal: consonant + ZWJ + hal + consonant
  // This creates stacked/joined letters
  // Apply twice to handle consecutive conjuncts (e.g., ගන්ත්වා has two hal marks)
  result = result.replaceAllMapped(
    _bandiPattern,
    (match) => '${match.group(1)}$_zwj$hal${match.group(2)}',
  );
  result = result.replaceAllMapped(
    _bandiPattern,
    (match) => '${match.group(1)}$_zwj$hal${match.group(2)}',
  );

  // Step 5: Convert long vowels to short vowels (traditional Pali orthography)
  // ේ (kombuva deka + hal) → ෙ (kombuva deka)
  result = result.replaceAll('\u0DDA', '\u0DD9');
  // ෝ (kombuva + hal) → ො (kombuva)
  result = result.replaceAll('\u0DDD', '\u0DDC');

  return result;
}
