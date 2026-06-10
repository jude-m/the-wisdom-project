// Verbatim copy of lib/core/utils/singlish_transliterator.dart (pure Dart, Flutter-free).
// Prototype-only duplication — the real build extracts these into a shared package.
/// Singlish (romanized Sinhala) to Sinhala Unicode transliterator.
///
/// Converts romanized Sinhala (Singlish) input to Sinhala Unicode.
/// Uses case-sensitive mappings for disambiguation:
/// - `th` → ත (dental)
/// - `Th` → ථ (dental aspirated)
/// - `t` → ට (retroflex)
/// - `T` → ඨ (retroflex aspirated)
///
/// Based on: https://github.com/Open-SL/sinhala-unicode-converter
library;

/// Singlish transliterator for search functionality.
///
/// Converts romanized Sinhala (Singlish) to Sinhala Unicode string.
/// Case-sensitive: uppercase letters indicate aspirated/special consonants.
class SinglishTransliterator {
  // Singleton
  static final SinglishTransliterator instance = SinglishTransliterator._();
  SinglishTransliterator._();

  // ============== Mappings ==============
  // From sinhala-unicode-converter, reordered for correct matching

  /// Vowels with modifiers: [singlish, independent vowel, vowel modifier (pili)]
  /// Order: longer patterns first
  static const List<List<String>> _vowels = [
    ['oo', 'ඌ', 'ූ'],
    ['aa', 'ආ', 'ා'],
    ['Aa', 'ඈ', 'ෑ'],
    ['ae', 'ඈ', 'ෑ'],
    ['ii', 'ඊ', 'ී'],
    ['ie', 'ඊ', 'ී'],
    ['ee', 'ඊ', 'ී'],
    ['ea', 'ඒ', 'ේ'],
    ['ei', 'ඒ', 'ේ'],
    ['uu', 'ඌ', 'ූ'],
    ['au', 'ඖ', 'ෞ'],
    ['oe', 'ඕ', 'ෝ'],
    ['a', 'අ', ''], // inherent vowel - empty modifier
    ['A', 'ඇ', 'ැ'],
    ['i', 'ඉ', 'ි'],
    ['e', 'එ', 'ෙ'],
    ['u', 'උ', 'ු'],
    ['o', 'ඔ', 'ො'],
    ['I', 'ඓ', 'ෛ'],
  ];

  /// Consonants: [singlish, sinhala unicode]
  /// Order: CRITICAL - longer patterns MUST come first (e.g., 'nndh' before 'nnd')
  static const List<List<String>> _consonants = [
    // 4+ character combinations
    ['nndh', 'ඳ'],
    // 3 character combinations
    ['nnd', 'ඬ'],
    ['nng', 'ඟ'],
    // 2 character combinations (case-sensitive)
    ['Th', 'ථ'], // dental aspirated
    ['Dh', 'ධ'], // dental aspirated
    ['gh', 'ඝ'],
    ['Ch', 'ඡ'],
    ['ph', 'ඵ'],
    ['bh', 'භ'],
    ['sh', 'ශ'],
    ['Sh', 'ෂ'],
    ['GN', 'ඥ'],
    ['KN', 'ඤ'],
    ['Lu', 'ළු'],
    ['dh', 'ද'], // dental
    ['ch', 'ච'],
    ['kh', 'ඛ'],
    ['th', 'ත'], // dental
    // Single character (case-sensitive)
    ['t', 'ට'], // retroflex
    ['k', 'ක'],
    ['d', 'ඩ'], // retroflex
    ['n', 'න'],
    ['p', 'ප'],
    ['b', 'බ'],
    ['m', 'ම'],
    ['Y', '‍ය'], // yansaya
    ['y', 'ය'],
    ['j', 'ජ'],
    ['l', 'ල'],
    ['v', 'ව'],
    ['w', 'ව'],
    ['s', 'ස'],
    ['h', 'හ'],
    ['N', 'ණ'],
    ['L', 'ළ'],
    ['K', 'ඛ'],
    ['G', 'ඝ'],
    ['T', 'ඨ'], // retroflex aspirated
    ['D', 'ඪ'],
    ['P', 'ඵ'],
    ['B', 'ඹ'],
    ['f', 'ෆ'],
    ['q', 'ඣ'],
    ['g', 'ග'],
    ['r', 'ර'],
  ];

  /// Special Pali characters: [singlish, sinhala unicode]
  /// Used for anusvara, visarga, etc. important in Pali texts
  /// Uses ~ as escape prefix (similar to \ in TypeScript but Dart-friendly)
  static const List<List<String>> _specialChars = [
    ['~n', 'ං'], // Anusvara - used in: sanghang, dhammang
    ['~h', 'ඃ'], // Visarga - used in: duhkha
    ['~N', 'ඞ්'], // Velar nasal (ṅ) – always conjunct in Pali Sinhala
    ['~R', 'ඍ'], // Vocalic R (Pali/Sanskrit)
  ];

  /// Special modifiers for ru/ruu sounds
  static const List<List<String>> _specialModifiers = [
    ['ruu', 'ෲ'],
    ['ru', 'ෘ'],
  ];

  // ============== Public API ==============

  /// Converts Singlish text to Sinhala Unicode.
  ///
  /// Returns a single deterministic result based on case-sensitive mappings.
  /// If input contains no ASCII letters, returns as-is.
  ///
  /// Example:
  /// ```dart
  /// convert('sathi')  // → 'සති'
  /// convert('saThi')  // → 'සථි' (different - capital T = ථ)
  /// convert('dharma') // → 'දර්ම'
  /// ```
  String convert(String input) {
    if (input.isEmpty) return '';
    if (!isSinglishQuery(input)) return input;

    var text = input;

    // Step 0: Replace special Pali characters (anusvara, visarga, etc.)
    for (final special in _specialChars) {
      text = text.replaceAll(special[0], special[1]);
    }

    // Step 1: Replace consonant + special modifiers (ruu, ru)
    for (final cons in _consonants) {
      for (final mod in _specialModifiers) {
        text = text.replaceAll('${cons[0]}${mod[0]}', '${cons[1]}${mod[1]}');
      }
    }

    // Step 2: Replace consonant + rakaransha + vowel (e.g., "kra" → "ක්‍ර")
    for (final cons in _consonants) {
      for (final vowel in _vowels) {
        text = text.replaceAll(
          '${cons[0]}r${vowel[0]}',
          '${cons[1]}්‍ර${vowel[2]}',
        );
      }
      // Consonant + rakaransha without trailing vowel
      text = text.replaceAll('${cons[0]}r', '${cons[1]}්‍ර');
    }

    // Step 3: Replace consonant + vowel (CRITICAL: uses simple string replace)
    for (final cons in _consonants) {
      for (final vowel in _vowels) {
        text =
            text.replaceAll('${cons[0]}${vowel[0]}', '${cons[1]}${vowel[2]}');
      }
    }

    // Step 4: Replace standalone consonants (add hal ්)
    for (final cons in _consonants) {
      text = text.replaceAll(cons[0], '${cons[1]}්');
    }

    // Step 5: Replace standalone vowels
    for (final vowel in _vowels) {
      text = text.replaceAll(vowel[0], vowel[1]);
    }

    return text;
  }

  /// Checks if the query contains ASCII letters (needs transliteration).
  bool isSinglishQuery(String query) {
    return RegExp(r'[A-Za-z]').hasMatch(query);
  }

  // ============== Legacy API (for compatibility) ==============

  /// Returns list with single converted result.
  /// Kept for backward compatibility with existing code.
  List<String> getPossibleMatches(String input) {
    final result = convert(input);
    return result.isEmpty ? [] : [result];
  }
}
