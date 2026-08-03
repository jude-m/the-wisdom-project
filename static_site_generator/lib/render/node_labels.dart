import 'package:wisdom_shared/wisdom_shared.dart';

import 'entry_renderer.dart';

/// A node's name as it appears in a *link* — breadcrumb, pager, TOC entry, nav
/// tree.
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
/// because `tree.json` carries no Latin text for any of its 16,355 nodes. When
/// it lands, this function and `PageTemplate`'s title helpers are the places to
/// change.
///
/// **Always the Pali field, never the Sinhala one** (locked 2026-08-03). The
/// two differ for most containers — `sp` is `සුත්තපිටක` in Pali and
/// `සූත්‍ර පිටකය` in Sinhala — and the site names every node exactly one way, on
/// every surface. The build plan's §5.2 sketched the landing page with the
/// Sinhala names because the frame was drawn from the app, whose Content
/// Language defaults to Sinhala (`content_language_provider.dart`); the static
/// site has no such setting, and letting the nav tree disagree with the
/// breadcrumb directly below it is the drift P2 learned to avoid.
String nodeLabelHtml(TipitakaNode node) => escapeHtml(weldTitle(node.paliName));
