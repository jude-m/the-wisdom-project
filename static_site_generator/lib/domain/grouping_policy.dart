import 'package:wisdom_shared/wisdom_shared.dart';

/// Which line a leaf is measured against — or whether it is measured at all.
///
/// The two lines are named for their *size*, not for canon and commentary.
/// Canon and commentary are only the defaults: four commentary books sit on the
/// short line by decision, and naming the values after the corpus made those
/// four read as contradictions at the one place they most need to read clearly.
enum LeafPolicy {
  /// Never folds against its siblings, whatever its size. For books where the
  /// leaf *is* a complete named work rather than a section of a longer text.
  ownPage,

  /// [GroupingPolicy.shortLineChars] — the default for canon.
  shortLine,

  /// [GroupingPolicy.longLineChars] — the default for commentary.
  longLine,
}

/// The per-book exceptions to the split rule, and the lines they select.
///
/// **One table, not two lists.** The promoted books and the commentary
/// carve-out are the same kind of statement — *this book is treated
/// differently* — and splitting them across two constants means two places to
/// look and two places to forget.
///
/// The table is closed. It grows only by a decision recorded in
/// `docs/todo/web-strategy/reading-units-and-grouping.md`, never by
/// measurement, and every entry is argued there. Editing it is a URL change:
/// re-run `--write-snapshot` and review the diff of `grouping_snapshot.dart`.
class GroupingPolicy {
  GroupingPolicy._();

  /// A leaf this long or longer gets its own page. The canon default.
  ///
  /// **Strictly less-than, and the margin is one character** — `kn-thig-6`'s
  /// longest leaf measures exactly 1,500. Combined Pali + Sinhala, raw text
  /// with markers left in: the convention the locked figure was measured under
  /// (`NodeSlice.rawCharCount`), never Pali alone.
  ///
  /// Under the split rule this asks *"does this one sutta deserve its own
  /// URL"*, not *"is this vagga worth grouping"* — so a substantial sutta keeps
  /// its page whatever its siblings do, and the exact value matters far less
  /// than it did.
  static const int shortLineChars = 1500;

  /// The same question ten times higher. The commentary default.
  ///
  /// The short line is an SEO guard: one substantial sutta in a vagga must keep
  /// its own rankable page. A commentary does not need that guard — nobody
  /// searches for ජරාසුත්තවණ්ණනා, they search the sutta, whose page already
  /// exists and already carries the අට්ඨකථා cross-link. What the high line buys
  /// instead is assembly of works BJT fragmented: the dozen pages holding
  /// chunks of the Bhayabherava commentary become one page that *is* it.
  ///
  /// 15,000 is the last value before the biggest chapter roughly doubles and
  /// the count over 100k characters quintuples (the measured table is in the
  /// plan doc).
  static const int longLineChars = 15000;

  /// Shortest run of short leaves worth one page. A run of one is just a sutta.
  static const int minRunLength = 2;

  /// **THE table.** Longest matching key prefix wins; anything unlisted takes
  /// the default for its corpus — [LeafPolicy.shortLine] for canon,
  /// [LeafPolicy.longLine] for commentary.
  ///
  /// The six promoted books are those where a leaf is a complete named work — a
  /// chanted text, a named udāna, a named elder's poem — which is a structural
  /// property a size threshold cannot see. The four carved-out commentaries are
  /// the mirror case: their children are distinct named people and named
  /// stories, so the long line would fold them wholesale.
  ///
  /// Adding or removing a book is one line plus `--write-snapshot`. Exploding
  /// Buddhavaṃsa, for instance, is `'kn-bv': LeafPolicy.ownPage` and costs 0
  /// pages today; the measured costs of the other candidates are recorded in
  /// the plan doc.
  static const Map<String, LeafPolicy> bookPolicies = {
    // Promoted: the leaf IS the work.
    'kn-khp': LeafPolicy.ownPage,
    'kn-snp': LeafPolicy.ownPage,
    'kn-ud': LeafPolicy.ownPage,
    'kn-iti': LeafPolicy.ownPage,
    'kn-thag': LeafPolicy.ownPage,
    'kn-thig': LeafPolicy.ownPage,
    // Carved back down to the short line: named people, named stories.
    'atta-kn-jat': LeafPolicy.shortLine,
    'atta-kn-thag': LeafPolicy.shortLine,
    'atta-kn-thig': LeafPolicy.shortLine,
    'atta-kn-dhp': LeafPolicy.shortLine,
  };

  /// The policy for one leaf.
  ///
  /// **Prefix matching is on key segments, not characters.** `'kn-ud'` claims
  /// `kn-ud-1-3` and `kn-ud` itself, and must never claim a future `kn-udx`;
  /// a bare `startsWith` would, silently and only once upstream adds the book.
  static LeafPolicy policyFor(TipitakaNode node) {
    LeafPolicy? best;
    var bestLength = -1;
    for (final entry in bookPolicies.entries) {
      final prefix = entry.key;
      final matches = node.nodeKey == prefix ||
          node.nodeKey.startsWith('$prefix-') ||
          // Dotted commentary keys (`atta-ap-dhs-2-1-1.1`) still hang off a
          // hyphenated book prefix, so this only has to allow the dot as a
          // segment separator in the same position.
          node.nodeKey.startsWith('$prefix.');
      if (matches && prefix.length > bestLength) {
        best = entry.value;
        bestLength = prefix.length;
      }
    }
    if (best != null) return best;
    return node.isCommentary ? LeafPolicy.longLine : LeafPolicy.shortLine;
  }

  /// The character line [policyFor] selects, or null when the leaf is promoted
  /// and therefore never measured.
  static int? lineFor(TipitakaNode node) => switch (policyFor(node)) {
        LeafPolicy.ownPage => null,
        LeafPolicy.shortLine => shortLineChars,
        LeafPolicy.longLine => longLineChars,
      };
}
