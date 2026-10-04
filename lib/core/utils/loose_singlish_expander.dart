/// Loose Singlish: the Sinhala spellings that *sound like* what was typed.
///
/// Strict Singlish ([SinglishTransliterator]) maps one spelling to exactly one
/// Sinhala word. This finds the sound-alikes for a lower tier of results, and
/// keeps only spellings a word list really holds (see [PrefixOracle]). The
/// rules and the measurements behind them: docs/todo/loose-singlish-search.md.
library;

import 'dart:math' as math;

/// Answers which [candidates] begin at least one word of a word list — or,
/// with [wholeWords], which are words of it.
typedef PrefixOracle = Future<Set<String>> Function(
  Set<String> candidates, {
  required bool wholeWords,
});

class LooseSinglishExpander {
  const LooseSinglishExpander();

  /// Shorter input is broad enough already; loose would only add noise.
  static const int minLetters = 3;

  /// Safety caps. The measured corpus never needed more than 10 spellings.
  static const int maxSpellingsPerWord = 16;
  static const int maxStatesPerStep = 512;

  /// In [rank], a spelling used less than this share of the most-used one
  /// is dropped, and the strict one loses first place.
  static const double minUsageShare = 0.1;

  static final _singlishPattern = RegExp(r'^[a-z\s]+$');
  static final _letterPattern = RegExp('[a-z]');
  static final _spaces = RegExp(r'\s+');
  static final _iastLetters = RegExp('[${_iast.keys.join()}]');

  /// Whether [text] gets a loose tier: Roman letters only (IAST included),
  /// [minLetters] or more. Anything else (Sinhala, digits, the strict `~`
  /// codes) stays strict.
  static bool appliesTo(String text) {
    final letters = _plainLetters(text);
    return _singlishPattern.hasMatch(letters) &&
        _letterPattern.allMatches(letters).length >= minLetters;
  }

  /// [text] lowercased, with IAST letters (text copied from SuttaCentral,
  /// say) as typed Singlish spells them: `nibbāna` → `nibbaana`.
  static String _plainLetters(String text) => text
      .toLowerCase()
      .replaceAllMapped(_iastLetters, (letter) => _iast[letter[0]]!);

  /// Puts one typed word's [spellings] in search order: by [usage] (how many
  /// rows of the text use each), most used first, without those under
  /// [minUsageShare] of the top one — rare spellings are mostly misreadings.
  /// The [strict] spelling is always kept: first while it holds that share
  /// (or always, with [strictFirst]), else last.
  static List<String> rank(
    List<String> spellings, {
    required String strict,
    required Map<String, int> usage,
    bool strictFirst = false,
  }) {
    int usageOf(String spelling) => usage[spelling] ?? 0;
    final top = [strict, ...spellings].map(usageOf).reduce(math.max);
    bool common(String spelling) => usageOf(spelling) >= top * minUsageShare;

    final others = byUsage([
      for (final spelling in spellings)
        if (spelling != strict && common(spelling)) spelling,
    ], usage);
    return strictFirst || common(strict)
        ? [strict, ...others]
        : [...others, strict];
  }

  /// [spellings] by [usage], most used first. Ties keep the walk's order,
  /// which reads the strict letters first.
  static List<String> byUsage(List<String> spellings, Map<String, int> usage) {
    final walkOrder = {
      for (final (i, spelling) in spellings.indexed) spelling: i
    };
    return [...spellings]..sort((a, b) {
        final byCount = (usage[b] ?? 0).compareTo(usage[a] ?? 0);
        return byCount != 0 ? byCount : walkOrder[a]!.compareTo(walkOrder[b]!);
      });
  }

  /// The Sinhala spellings of each typed word of [singlish], in typed order:
  /// prefixes for prefix search, or whole words when [exact].
  ///
  /// Empty when [singlish] doesn't qualify, or when a word has no spelling the
  /// list holds — the loose tier then has nothing honest to show.
  Future<List<List<String>>> expand(
    String singlish,
    PrefixOracle oracle, {
    bool exact = false,
  }) async {
    if (!appliesTo(singlish)) return const [];
    final words = _plainLetters(singlish)
        .split(_spaces)
        .where((word) => word.isNotEmpty)
        .toList();
    final spellings = await Future.wait([
      for (final word in words) _expandWord(word, oracle, exact: exact),
    ]);
    if (spellings.any((forWord) => forWord.isEmpty)) return const [];
    return spellings;
  }

  /// Builds every spelling letter by letter, asking [oracle] once per round
  /// which of them still begin a real word, and dropping the rest.
  Future<List<String>> _expandWord(
    String word,
    PrefixOracle oracle, {
    required bool exact,
  }) async {
    var states = const [_Spelling('', '', 0)];
    final finished = <String>{}; // insertion order = discovery order

    while (states.isNotEmpty) {
      final next = <String, _Spelling>{};
      for (final state in states) {
        if (state.position == word.length) {
          finished.add(exact ? state.asWord : state.written);
          continue;
        }
        for (final step in _stepsFrom(state, word)) {
          next.putIfAbsent(step.key, () => step);
        }
      }
      if (next.isEmpty) break;

      final live = await oracle(
        {for (final step in next.values) step.written},
        wholeWords: false,
      );
      states = [
        for (final step in next.values)
          if (live.contains(step.written)) step,
      ].take(maxStatesPerStep).toList();
    }

    if (finished.isEmpty) return const [];
    if (exact) {
      final words = await oracle(finished, wholeWords: true);
      return [
        for (final spelling in finished)
          if (words.contains(spelling)) spelling,
      ].take(maxSpellingsPerWord).toList();
    }

    // ධම්ම already covers ධම්මා in a prefix search; keep the shortest only.
    final all = finished.toList();
    return [
      for (final spelling in all)
        if (!all.any((other) =>
            other.length < spelling.length && spelling.startsWith(other)))
          spelling,
    ].take(maxSpellingsPerWord).toList();
  }

  /// Every way to read the next one to three typed letters after [state].
  Iterable<_Spelling> _stepsFrom(_Spelling state, String word) sync* {
    final at = state.position;
    final rest = word.substring(at);
    final waiting = state.pending.isNotEmpty;

    // A vowel: a sign on the waiting consonant, or a letter of its own.
    for (final entry in _vowels.entries) {
      if (!rest.startsWith(entry.key)) continue;
      final (signs, letters) = entry.value;
      for (final form in waiting ? signs : letters) {
        yield _Spelling('${state.written}$form', '', at + entry.key.length);
      }
    }
    // Vocalic r (කෘ) is also typed "kru".
    if (waiting && rest.startsWith('ru')) {
      final long = rest.startsWith('ruu');
      yield _Spelling(
          '${state.written}${long ? 'ෲ' : 'ෘ'}', '', at + (long ? 3 : 2));
    }

    // A consonant. A waiting one takes the hal first: two in a row are a cluster.
    final settled = waiting ? '${state.written}$_hal' : state.text;
    for (final entry in _consonants.entries) {
      if (!rest.startsWith(entry.key)) continue;
      for (final letter in entry.value) {
        yield _Spelling(settled, letter, at + entry.key.length);
      }
    }
    // ඞ only ever comes before a k or g sound (සඞ්ඝ, මඞ්ගල).
    if (rest.length > 1 && rest[0] == 'n' && 'kg'.contains(rest[1])) {
      yield _Spelling(settled, 'ඞ', at + 1);
    }
    // ං is typed n, m or ng, and never comes before a vowel.
    final nasal = rest.startsWith('n') || rest.startsWith('m');
    if (nasal && (rest.length == 1 || _consonantLetters.contains(rest[1]))) {
      yield _Spelling('$settledං', '', at + 1);
    }
    if (rest == 'ng') yield _Spelling('$settledං', '', at + 2);
  }
}

/// A spelling being built. [text] is settled; [pending] is a last consonant
/// still waiting to learn whether a vowel or a hal follows it.
class _Spelling {
  final String text;
  final String pending;

  /// How many typed letters this spelling has used.
  final int position;

  const _Spelling(this.text, this.pending, this.position);

  /// What is written so far. Every word that continues it starts with this.
  String get written => '$text$pending';

  /// As a finished word: a last consonant takes the hal.
  String get asWord => pending.isEmpty ? text : '$text$pending$_hal';

  String get key => '$text|$pending|$position';
}

const String _hal = '්';

const String _consonantLetters = 'bcdfghjklmnpqrstvwxyz';

/// Typed vowels → (signs after a consonant, letters on their own), longest
/// first. '' is the inherent a. A single a/i/u may also be long; a doubled one
/// must be. Pali writes e/o short, so their length never decides.
const Map<String, (List<String>, List<String>)> _vowels = {
  'aae': (['ෑ'], ['ඈ']),
  'aee': (['ෑ'], ['ඈ']),
  'aa': (['ා'], ['ආ']),
  'ae': (['ැ', 'ෑ'], ['ඇ', 'ඈ']),
  'ai': (['ෛ'], ['ඓ']),
  'au': (['ෞ'], ['ඖ']),
  'ou': (['ෞ'], ['ඖ']),
  'ii': (['ී'], ['ඊ']),
  'ie': (['ී'], ['ඊ']),
  'ee': (['ී', 'ේ', 'ෙ'], ['ඊ', 'ඒ', 'එ']),
  'ea': (['ේ', 'ෙ'], ['ඒ', 'එ']),
  'ei': (['ේ', 'ෙ', 'ෛ'], ['ඒ', 'එ', 'ඓ']),
  'uu': (['ූ'], ['ඌ']),
  'oo': (['ූ', 'ෝ', 'ො'], ['ඌ', 'ඕ', 'ඔ']),
  'oe': (['ෝ'], ['ඕ']),
  'a': (['', 'ා'], ['අ', 'ආ']),
  'i': (['ි', 'ී'], ['ඉ', 'ඊ']),
  'u': (['ු', 'ූ'], ['උ', 'ඌ']),
  'e': (['ෙ', 'ේ'], ['එ', 'ඒ']),
  'o': (['ො', 'ෝ'], ['ඔ', 'ඕ']),
};

/// IAST letters → the Roman letters typed for them: a long vowel doubled, the
/// dots and the tilde dropped.
const Map<String, String> _iast = {
  'ā': 'aa',
  'ī': 'ii',
  'ū': 'uu',
  'ṭ': 't',
  'ḍ': 'd',
  'ṇ': 'n',
  'ḷ': 'l',
  'ñ': 'n',
  'ṅ': 'n',
  'ṃ': 'm',
  'ṁ': 'm',
};

/// Typed consonants → the letters they may stand for, longest first, the
/// strict reading first. Sound-alikes share a list: aspirated or not, dental
/// or retroflex, and the three s letters. A typed `h` after k, g, j, p or b
/// means the aspirate only; `th`/`dh` stay open, as Singlish writes the
/// plain dental ත/ද with them.
const Map<String, List<String>> _consonants = {
  'ngh': ['ඟ'],
  'ndh': ['ඳ', 'ඬ'],
  'mbh': ['ඹ'],
  'kh': ['ඛ'],
  'gh': ['ඝ'],
  'ch': ['ච', 'ඡ'],
  'jh': ['ඣ'],
  'th': ['ත', 'ථ', 'ට', 'ඨ'],
  'dh': ['ද', 'ධ', 'ඩ', 'ඪ'],
  'ph': ['ඵ'],
  'bh': ['භ'],
  'sh': ['ශ', 'ෂ', 'ස'],
  'ng': ['ඟ'],
  'nd': ['ඬ', 'ඳ'],
  'mb': ['ඹ'],
  'gn': ['ඥ', 'ඤ'],
  'kn': ['ඤ'],
  'ny': ['ඤ'],
  'k': ['ක', 'ඛ'],
  'g': ['ග', 'ඝ'],
  'c': ['ච', 'ඡ'],
  'j': ['ජ', 'ඣ'],
  'q': ['ඣ', 'ජ'],
  't': ['ට', 'ඨ', 'ත', 'ථ'],
  'd': ['ඩ', 'ඪ', 'ද', 'ධ'],
  'n': ['න', 'ණ', 'ඤ'],
  'p': ['ප', 'ඵ'],
  'b': ['බ', 'භ'],
  'm': ['ම'],
  'y': ['ය'],
  'r': ['ර'],
  'l': ['ල', 'ළ'],
  'v': ['ව'],
  'w': ['ව'],
  's': ['ස', 'ශ', 'ෂ'],
  'h': ['හ'],
  'f': ['ෆ'],
};
