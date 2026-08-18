import 'package:wisdom_shared/wisdom_shared.dart';

import 'entry_renderer.dart';

/// A node's name as it appears in a *link* — breadcrumb, pager, TOC entry.
/// Those are the site's only three link surfaces, and all three are here.
///
/// Welded, because these are labels a person looks at and D1 governs everything
/// a reader sees; the app welds the very same strings in its own tree and
/// breadcrumb. Only the `<title>` takes the un-welded D2 treatment.
///
/// Bare, with no commentary marker: inside a commentary subtree every ancestor
/// and sibling is `atta-*` too, so marking each one would print අට්ඨකථා at
/// every step of the trail to say something the reader already knows from the
/// page they are on.
///
/// No romanized (IAST) variant is offered: D4 ships Sinhala-script titles
/// because `tree.json` carries no Latin text for any of its nodes. When it
/// lands, this function and `PageTemplate`'s title helpers are the places to
/// change.
///
/// **Always the Pali field, never the Sinhala one** (locked 2026-08-03). The
/// two differ for most containers — `sp` is `සුත්තපිටක` in Pali and
/// `සූත්‍ර පිටකය` in Sinhala — and the site names every node exactly one way, on
/// every surface. The build plan's §5.2 sketched the landing page with the
/// Sinhala names because the frame was drawn from the app, whose Content
/// Language defaults to Sinhala (`content_language_provider.dart`); the static
/// site has no such setting, and letting `/` name a root one way while the
/// breadcrumb on the page it links to names it another is the drift P2 learned
/// to avoid.
String nodeLabelHtml(TipitakaNode node) => escapeHtml(weldTitle(node.paliName));

/// The Sinhala word for the commentary layer.
const String commentaryMarker = 'අට්ඨකථා';

/// Whether [node]'s own name needs the marker appended.
///
/// `endsWith`, not `contains`: some nodes are named with the marker upstream
/// (`atta-dn` "දීඝනිකාය අට්ඨකථා") and would read "… අට්ඨකථා අට්ඨකථා" — the gap
/// between `FIGURES.commentaryNodes` and
/// `FIGURES.nodesCarryingCommentaryMarker` — while `atta-ap-dhs-5`
/// "අට්ඨකථාකණ්ඩො" is a section *about* the commentary and does need marking.
/// Public because the search index ships the answer as a column.
bool carriesCommentaryMarker(TipitakaNode node) =>
    node.isCommentary &&
    !unweldTitle(node.paliName).trimRight().endsWith(commentaryMarker);

/// A node's name as its **own page** names it — `<title>`, `<h1>`, and the row
/// a search result draws.
///
/// The counterpart to [nodeLabelHtml], and next to it because those are the
/// only two ways the site names anything: the page you are on, and a step on
/// the way to one. Splitting them across files is how the search index came to
/// ship a third form, unmarked, that no page ever showed.
///
/// The `atta-*` pages carry their canon twins' names, so without the marker the
/// two compete for the same searches (§10).
///
/// Raw text and un-welded, unlike [nodeLabelHtml]: `<title>` takes it as it is
/// (D2), visible uses weld it first (D1).
String nodeTitle(TipitakaNode node) {
  final name = unweldTitle(node.paliName);
  return carriesCommentaryMarker(node) ? '$name $commentaryMarker' : name;
}
