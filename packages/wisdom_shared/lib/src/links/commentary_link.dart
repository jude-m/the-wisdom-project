/// Which node the canon ↔ aṭṭhakathā cross-link points at.
///
/// Both surfaces offer one link on a text: `අට්ඨකථා` from the canon,
/// `මූල පාඨය` from the commentary. Answering "point at what" used to be a
/// `startsWith`/`substring` pair written out at three call sites, each linking
/// only when the flipped key happened to name a node.
///
/// **The two directions are not the same question.** The canon is complete: a
/// gap in canon sibling keys means the book *merged* suttas — `sn-2-5-4-8` is
/// පිතුසුත්තාදිඡක්කං, six suttas under one key — never that text is missing.
/// So walking to find a commentary's root text cannot lie.
///
/// The commentary is not complete, and a gap there is ambiguous. Either the
/// vaṇṇanā merged (`atta-sn-2-5-4-2` is "2-4. කුසලමූලසමුච්ඡෙදසුත්තාදිවණ්ණනා",
/// which does treat suttas 3 and 4), or it simply has nothing to say —
/// `atta-an-5-5-5-1` is followed by 9, because suttas 2–8 are mechanical
/// කාය/වචී/මනො variants the commentary never glosses. Walking would treat
/// those alike and open a commentary on a different sutta, so this direction
/// does not walk: it reads the vaṇṇanā's own declaration. **Where none claims
/// the sutta there is no link, and that is the answer rather than a gap.**
library;

import '../constants/tipitaka_node_keys.dart';
import '../tree/tipitaka_tree.dart';

/// The mechanical key flip: `sn-2-5-4-1` ↔ `atta-sn-2-5-4-1`.
///
/// Names no node on its own — [crossLinkTargetKey] decides whether the flipped
/// key is the right answer. Public because the figures report counts twins,
/// which is a question about the corpus rather than about a link.
String twinKeyOf(String nodeKey) =>
    nodeKey.startsWith(TipitakaNodeKeys.commentary)
        ? nodeKey.substring(TipitakaNodeKeys.commentary.length)
        : '${TipitakaNodeKeys.commentary}$nodeKey';

/// `2-4. කුසලමූලසමුච්ඡෙදසුත්තාදිවණ්ණනා` → 3, the count of suttas it treats.
///
/// **The width, never the endpoints.** Many commentary nodes declare a number
/// that disagrees with their own key index — `ap-dhk-2` is its container's
/// second child but the book prints it "1.", because the first child is the
/// introduction. Reading "1." as canon sutta 1 would walk the link a whole node
/// backwards. A width has no origin to be wrong about: a node at key `n`
/// declaring `a-b` treats `n … n + (b - a)`, whatever `a` counts from.
///
/// Anchored at the head of the title, so the dotted placeholder titles
/// (`atta-kn-mn-1-1` is literally "1 - 1") do not read as ranges — they carry
/// no `.` after the second number. Pali first, Sinhala only where the Pali side
/// is silent, the same authority `nodeLabelHtml` picks.
final RegExp _declaredRange = RegExp(r'^\s*(\d+)\s*[-–]\s*(\d+)\s*\.');

/// How many consecutive suttas [node] declares it treats, or null when its
/// title declares no range at all.
///
/// **A silent title is width 1, not unknown.** Most commentary titles carry no
/// number, and defaulting them to "treats only itself" is what keeps an
/// unlabelled vaṇṇanā from being read as covering everything after it.
int? _declaredWidth(TipitakaNode node) {
  for (final title in [node.paliName, node.sinhalaName]) {
    final match = _declaredRange.firstMatch(title);
    if (match == null) continue;
    final from = int.parse(match.group(1)!);
    final to = int.parse(match.group(2)!);
    if (to < from) continue; // "13-7." — a typo, not a range
    return to - from + 1;
  }
  return null;
}

/// The nearest preceding sibling of [nodeKey] whose own twin exists, or null.
///
/// **Nearest, and then stop.** A farther sibling's coverage would have to reach
/// *through* the nearer one's node to touch [nodeKey], which is the same as
/// saying the nearer node is not where its key puts it.
TipitakaNode? _nearestPrecedingTwin(TipitakaTree tree, String nodeKey) {
  final parent = tree.parentOf(nodeKey);
  if (parent == null) return null;
  final siblings = parent.childKeys;
  final index = siblings.indexOf(nodeKey);
  for (var i = index - 1; i >= 0; i--) {
    final twin = tree[twinKeyOf(siblings[i])];
    if (twin != null) return twin;
  }
  return null;
}

/// Where a `අට්ඨකථා` / `මූල පාඨය` link on [nodeKey] must point, or null when
/// the link must not be offered at all.
///
/// The key alone, not a URL: a folded leaf owns no file, so the site resolves
/// it through `SitePlan.urlFor` and the app opens it as a node.
///
/// **Canon → commentary:** the exact twin; else the nearest preceding sibling's
/// vaṇṇanā, but only if its [_declaredWidth] reaches this sutta; else null.
///
/// **Commentary → canon:** the exact twin; else the nearest preceding sibling's
/// canon node, since a canon key gap is a merge; else the nearest ancestor's,
/// for the commentary that subdivides where the canon does not.
///
/// That last step has no counterpart on the canon side on purpose. A
/// container's commentary is not "the commentary on this sutta", and offering
/// it as one is exactly the claim the reader cannot check.
String? crossLinkTargetKey(TipitakaTree tree, String nodeKey) {
  final node = tree[nodeKey];
  if (node == null) return null;

  final exact = twinKeyOf(nodeKey);
  if (tree[exact] != null) return exact;

  if (node.isCommentary) {
    final sibling = _nearestPrecedingTwin(tree, nodeKey);
    if (sibling != null) return sibling.nodeKey;
    for (final ancestor in tree.ancestorsOf(nodeKey)) {
      final twin = twinKeyOf(ancestor.nodeKey);
      if (tree[twin] != null) return twin;
    }
    return null;
  }

  // A key whose index cannot be read — `vp`, `kn-khp`, the dotted commentary
  // keys — is one no declared range can name.
  final index = trailingIndexOf(nodeKey);
  if (index == null) return null;
  final vannana = _nearestPrecedingTwin(tree, nodeKey);
  if (vannana == null) return null;
  final start = trailingIndexOf(vannana.nodeKey);
  if (start == null || start > index) return null;
  final width = _declaredWidth(vannana) ?? 1;
  return index <= start + width - 1 ? vannana.nodeKey : null;
}

/// What an origin marker's `id` starts with. Underscore, and no nodeKey
/// contains one — see [originId].
const String originIdPrefix = 'via_';

/// The `id` of the marker standing for [canonKey] inside the vaṇṇanā that
/// answers for it: `sn-2-5-4-3` → `via_sn-2-5-4-3`.
///
/// **The underscore is load-bearing.** A nodeKey-shaped fragment is the node
/// the reader asked for, and `via-sn-2-5-4-3` matches that shape — the app
/// would open a node that does not exist. The underscore is what keeps the two
/// grammars apart, so `TipitakaLink` can read this fragment as
/// `TipitakaLink.originKey` and hand it back to [crossLinkTargetKey], which
/// answers with the vaṇṇanā the marker sits in.
///
/// **The path cannot answer instead.** Most vaṇṇanā that merge are folded
/// leaves, so the path names the *chapter* carrying them, not the vaṇṇanā —
/// a reader dropped there gets a run of commentaries rather than the one they
/// clicked. The fragment is the only part of the URL that can name it, which
/// is why it is read rather than skipped.
String originId(String canonKey) => '$originIdPrefix$canonKey';

/// The canon key inside an origin marker's `id`, or null when [fragment] is
/// not one: `via_sn-2-5-4-3` → `sn-2-5-4-3`.
///
/// The inverse of [originId], and the whole of what a URL consumer needs —
/// [crossLinkTargetKey] turns the answer back into the vaṇṇanā, so nothing has
/// to carry the commentary key through the fragment as well.
///
/// Reads the prefix and nothing else. Whether the payload is *shaped* like a
/// node key is the caller's question, because the shape belongs to the URL
/// grammar rather than to this file: `TipitakaLink.parse` holds it to the same
/// pattern it holds the path key to.
String? canonKeyFromOriginId(String fragment) =>
    fragment.length > originIdPrefix.length &&
            fragment.startsWith(originIdPrefix)
        ? fragment.substring(originIdPrefix.length)
        : null;

/// Every canon key whose `අට්ඨකථා` link resolves to [commentaryKey], in reading
/// order — the inverse of [crossLinkTargetKey] on the canon side.
///
/// Usually one key, its own twin. Several when the vaṇṇanā declares a range:
/// `atta-sn-2-5-4-2` is "2-4. කුසලමූලසමුච්ඡෙදසුත්තාදිවණ්ණනා" and answers for
/// suttas 2, 3 and 4 — which is what makes the return trip answerable. Going in,
/// several suttas collapse onto one commentary; coming back its key names only
/// the first, so a caller that knows where the reader came from can offer that
/// sutta instead. One key means there is nothing to disambiguate.
///
/// Empty for a canon node, and for a vaṇṇanā no canon sutta points at.
List<String> canonKeysCoveredBy(TipitakaTree tree, String commentaryKey) {
  final node = tree[commentaryKey];
  if (node == null || !node.isCommentary) return const [];
  // Coverage never leaves one container: the rule only ever consults preceding
  // *siblings*, so the canon twin's parent bounds the whole search.
  final parent = tree.parentOf(twinKeyOf(commentaryKey));
  if (parent == null) return const [];
  return [
    for (final key in parent.childKeys)
      if (crossLinkTargetKey(tree, key) == commentaryKey) key,
  ];
}
