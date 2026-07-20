/// Resolves a canonical SuttaCentral reference to our BJT tree node key.
///
/// Two pure steps, both cheap and I/O-free:
///   1. [parseRef]        — "SN 15.3" / "sn15.3"  ->  canonical uid "sn15.3"
///   2. [resolveToNodeKey] — "sn15.3"             ->  BJT node "sn-2-3-1-3"
///
/// The concordance [Map] is *injected* (the app/server loads it from the
/// committed `assets/data/sc-to-bjt.json`), so this class stays pure Dart — no
/// Flutter, trivially table-testable.
///
/// Why a map and not a formula? BJT nests and *bundles* saṁyuttas differently
/// from SuttaCentral's flat numbering (e.g. SN 12+13 share one node), so both
/// saṁyutta titles and positions diverge — only leaf sutta titles align the two
/// editions. The mapping is therefore authored data. Full reasoning + evidence:
/// `docs/todo/suttacentral-bjt-concordance-findings.md`.
class SuttaCentralRefResolver {
  /// SuttaCentral uid (e.g. `sn15.3`) -> BJT node key (e.g. `sn-2-3-1-3`).
  final Map<String, String> _scToNode;

  const SuttaCentralRefResolver(this._scToNode);

  /// Book / nikāya abbreviations we accept as a *reference* (lowercased).
  ///
  /// This only gates what *looks* like a canonical reference so that ordinary
  /// search words ("metta123") don't parse as one; whether it actually resolves
  /// still depends on the concordance. Matches the linkifier's set in the RAG
  /// design doc.
  static const Set<String> knownBooks = {
    'sn', 'mn', 'dn', 'an', // four main nikāyas
    'dhp', 'ud', 'iti', 'snp', // Khuddaka — common verse/prose books
    'thag', 'thig', 'vv', 'pv', 'cp', 'bv', // Khuddaka — more verse books
  };

  /// `<letters><digits>(.<digits>)*` with an optional space after the letters:
  /// "SN 15.3", "sn15.3", "AN 3.65", "Dhp 1". Anchored — the whole string must
  /// be a reference, so it never fires on a sentence that merely contains one.
  static final RegExp _refPattern =
      RegExp(r'^([A-Za-z]+)\s*([0-9]+(?:\.[0-9]+)*)$');

  /// Step 1 — parse a human/uid string into a canonical SuttaCentral uid, or
  /// `null` if it isn't a canonical reference at all.
  ///
  /// "SN 15.3" | "sn 15.3" | "SN15.3" | "sn15.3"  ->  "sn15.3"
  static String? parseRef(String input) {
    final match = _refPattern.firstMatch(input.trim());
    if (match == null) return null;

    final book = match.group(1)!.toLowerCase();
    if (!knownBooks.contains(book)) return null;

    return '$book${match.group(2)!}'; // "sn" + "15.3" -> "sn15.3"
  }

  /// Canonical display abbreviations; anything else falls back to UPPERCASE.
  static const Map<String, String> _displayBook = {
    'sn': 'SN',
    'mn': 'MN',
    'dn': 'DN',
    'an': 'AN',
    'dhp': 'Dhp',
    'ud': 'Ud',
    'iti': 'Iti',
    'snp': 'Snp',
    'thag': 'Thag',
    'thig': 'Thig',
    'vv': 'Vv',
    'pv': 'Pv',
    'cp': 'Cp',
    'bv': 'Bv',
  };

  /// Format a canonical uid as a human display reference:
  /// "sn15.3" -> "SN 15.3", "dhp1" -> "Dhp 1". Returns [uid] unchanged if it
  /// doesn't split into letters + digits.
  static String displayRef(String uid) {
    final match = RegExp(r'^([A-Za-z]+)([0-9].*)$').firstMatch(uid.trim());
    if (match == null) return uid;
    final book = _displayBook[match.group(1)!.toLowerCase()] ??
        match.group(1)!.toUpperCase();
    return '$book ${match.group(2)!}';
  }

  /// Step 2 (combined) — resolve any reference string straight to a BJT node
  /// key, or `null` if it isn't a reference or the concordance doesn't cover it.
  String? resolveToNodeKey(String input) {
    final uid = parseRef(input);
    if (uid == null) return null;
    return _scToNode[uid];
  }

  /// Direct uid -> node key, for callers that already hold a canonical uid
  /// (e.g. RAG citations). `null` if not in the concordance.
  String? nodeKeyForUid(String uid) => _scToNode[uid];

  /// True once the concordance is non-empty. Lets a caller skip the reference
  /// check entirely before the asset has finished loading.
  bool get isReady => _scToNode.isNotEmpty;
}
