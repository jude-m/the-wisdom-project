/// `<meta name="description">` — the sentence Google prints under the title.
///
/// ## Why it is generated rather than written
///
/// There are `FIGURES.realPages` of them. With no description Google writes the
/// snippet from scraped page text, which on a canon page is the opening line of
/// Pali: accurate, and it tells a searcher nothing about what they found. This
/// is the click-through lever, and the only way to pull it at this scale is a
/// grammar.
///
/// ## The words are borrowed, never invented
///
/// The same rule the layout labels learned in P2: two names for one thing is
/// how surfaces drift. Every term below is one this corpus's own people already
/// use.
///
/// - `පාළි පෙළ` and `සිංහල පරිවර්තනය` are tipitaka.lk's own pairing, from the
///   Welcome page that describes exactly this material: *"තිපිටක පෙළ සහ සිංහල
///   පරිවර්තනය බුද්ධ ජයන්ති තිපිටක ග්‍රන්ථ මාලාවෙනි"* (`src/views/Welcome.vue`).
/// - `කොටස්` is the app's word for a passage (`researchMatchedPassage`,
///   `app_si.arb`).
/// - `{n}ක්` is the counting form already on this site, in the search dialog's
///   status line, itself taken from tipitaka.lk's `TSearch.vue`.
///
/// Upstream sets **no** per-page description of its own — `metaInfo` there
/// carries a title and an `og:title` and nothing else — so there was no
/// sentence to copy, only vocabulary.
///
/// ## Two claims it must never make
///
/// **That a page has a translation when it does not.** `bothLanguages` is
/// already asked once per page and already decides the column captions, the
/// layout group and the `solo` class; this is the fourth thing hanging off that
/// one answer, and the reason it is a parameter rather than a second scan. On
/// the `FIGURES.readablePagesWithoutSinhala` pages the sentence stops at
/// `පාළි පෙළ`.
///
/// **That a page is reading text when it is a list of links.** A nav-only
/// container's preamble is its title and `namo tassa`; promising a translation
/// of that would be describing furniture. Those pages describe their subdivisions
/// instead, which is what a reader arriving there actually gets.
///
/// ## Two readers, two forms of the same sentence
///
/// The snippet opens on the title because Google prints it *under* a title the
/// searcher has already skimmed past, and a location repeated there is a
/// location confirmed. A link-preview card is the other shape: it draws the
/// title in bold and the description directly beneath it, so the same string
/// renders as a subtitle that repeats its own heading word for word before
/// adding six words of its own — on exactly the surface Open Graph was added
/// for. [PageDescription] carries both forms so neither caller has to take the
/// other's.
library;

/// tipitaka.lk's `Welcome.vue`, and the pairing this whole corpus is.
const String _paliText = 'පාළි පෙළ';
const String _sinhalaTranslation = 'සිංහල පරිවර්තනය';

/// The app's `researchMatchedPassage`.
const String _sections = 'කොටස්';

/// The counting suffix in `{n}ක්` — tipitaka.lk's `TSearch.vue`, by way of this
/// site's own search dialog.
///
/// A constant rather than trailing letters welded to the interpolation. Dart
/// identifiers are ASCII, so `'$sections' + 'ක්'` written as one literal does
/// in fact stop at the `s` — but that is the language spec holding the two
/// apart, and a reader of a Sinhala template should be able to see the seam
/// instead of knowing the rule. Naming it also puts it beside the three other
/// borrowed strings, which is where a borrowed string belongs.
const String _countSuffix = 'ක්';

const String _and = 'සහ';

/// Google truncates the SERP snippet somewhere near 155–160 characters and the
/// exact width depends on the glyphs, so this is a budget rather than a limit.
/// Sinhala is wide; cutting short of the boundary is cheaper than being cut at
/// one.
const int _descriptionMaxChars = 155;

/// One page's description, in the two forms the `<head>` needs.
///
/// Built together and from one grammar, so the tag a searcher reads and the
/// tag a WhatsApp card draws cannot describe the page differently — which is
/// the whole reason this is a class rather than two functions.
class PageDescription {
  /// `<meta name="description">` — opens on the `<title>` string, because a
  /// SERP snippet is printed under a title and confirms it rather than
  /// competing with it.
  final String snippet;

  /// `og:description` — the same sentences with that leading title clause
  /// removed, because a card draws `og:title` immediately above this line and
  /// a subtitle that restates its own heading is the one thing a preview has
  /// no room for.
  ///
  /// **Null when nothing survives the removal**, and the caller then emits no
  /// `og:description` at all, because a card carrying a title above an empty
  /// subtitle is worse than one carrying the title alone.
  ///
  /// No page in the corpus reaches it, and the reason is worth writing down
  /// because the obvious candidate is not it: a Pali-only sutta page still
  /// claims `පාළි පෙළ`, so the clause list is not empty there. It would take a
  /// page that is neither readable nor names a subdivision, which nothing in
  /// `SitePlan` emits. The guard stays because that is a property of the plan
  /// rather than of this grammar, and the plan is free to change.
  final String? subtitle;

  const PageDescription({required this.snippet, required this.subtitle});

  /// A description that is prose in its own right rather than a composed
  /// location — `/`'s hand-written sentence.
  ///
  /// The same string in both slots, and correctly so: it never opened on the
  /// title, so there is nothing to strip and nothing for a card to repeat.
  ///
  /// Not passed through [_fit], which a `const` constructor cannot call. The
  /// assert takes its place and is the better half of the trade: a written
  /// sentence over budget fails to compile at the `const` that writes it,
  /// rather than shipping with an ellipsis nobody chose.
  const PageDescription.written(String text)
      : assert(
          text.length <= _descriptionMaxChars,
          'A written description must fit the snippet budget — shorten the '
          'sentence rather than leaving it to be cut.',
        ),
        snippet = text,
        subtitle = text;
}

/// Builds the description for one page.
///
/// [title] is the composed `<title>` text — `<leaf> — <vagga> — <collection>`,
/// un-welded and de-duplicated. Reused deliberately rather than re-derived: it
/// is already this site's one answer to "where does this page sit", and a
/// second answer would be free to disagree with the first.
///
/// [sections] is how many subdivisions the page names — the leaves a chapter
/// carries, or the children a container lists. Null on a page that names none,
/// which is every single-sutta page.
///
/// Returns null when there is nothing true to say, so the caller emits no tag
/// at all. **No description beats a blank description**, and an empty `content`
/// attribute is a worse signal than an absent element.
PageDescription? pageDescription({
  required String title,
  required bool readable,
  required bool bothLanguages,
  int? sections,
}) {
  final trimmed = title.trim();
  // Cannot fire on the vendored corpus — every node has a name, even if
  // `FIGURES.numericOnlyLeafTitles` of them are only a number, and a number is
  // still something to print. Guarded because the alternative to a description
  // is no tag, not a tag saying nothing.
  if (trimmed.isEmpty) return null;

  // What the page says about itself *beyond* naming where it sits. The snippet
  // puts the title in front of these; the card, which draws the title itself
  // one line above, gets them alone.
  final claims = <String>[];

  if (sections != null && sections > 0) {
    claims.add('$_sections $sections$_countSuffix');
  }

  if (readable) {
    claims.add(
      bothLanguages ? '$_paliText $_and $_sinhalaTranslation' : _paliText,
    );
  }

  return PageDescription(
    snippet: _fit('${[trimmed, ...claims].join('. ')}.'),
    // Fitted too, though nothing it can hold comes close to the budget: the
    // clauses are two fixed phrases and a count. Cheap, and it stops being a
    // fact about today's grammar that only one of the two forms is bounded.
    subtitle: claims.isEmpty ? null : _fit('${claims.join('. ')}.'),
  );
}

/// Cuts to [_descriptionMaxChars] on a word boundary.
///
/// Whole words, because a Sinhala word cut mid-syllable can strand a vowel sign
/// or a hal on its own, which renders as a mark attached to nothing. The
/// ellipsis is the single U+2026 character, not three dots — one glyph against
/// three of a budget this tight.
String _fit(String text) {
  if (text.length <= _descriptionMaxChars) return text;

  final cut = text.lastIndexOf(' ', _descriptionMaxChars - 1);
  // No space in the budget at all: one very long compound, which this corpus
  // does produce. Better a hard cut than a description of nothing.
  if (cut <= 0) return '${text.substring(0, _descriptionMaxChars - 1)}…';
  return '${text.substring(0, cut)}…';
}
