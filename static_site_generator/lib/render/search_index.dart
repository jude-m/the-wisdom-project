/// `assets/search-index.json` — every node in the corpus, in one array the
/// search dialog fetches once and keeps for the whole site.
///
/// Mirrors: nothing in the app. The app searches SQLite FTS over the *text*;
/// this searches **names only**, which is the question a static site can answer
/// without shipping a database.
///
/// Its output path and its cache token are in `site_assets.dart`, not here:
/// `site.js` reads a row by field *position*, so the script and this file are
/// one contract and are busted by one hash of both. That replaced a hand-bumped
/// `searchContractVersion` whose trigger — bump when a field moves — missed
/// every other way this file changes, an upstream re-sync first among them.
///
/// ## Why it is built here and not from `tree.json`
///
/// 1,603 of the 16,355 nodes have no page of their own — they are leaves
/// swallowed into 146 grouped chapter files — so their result row has to link
/// `/tipitaka/<chapter>#<key>`, never `/tipitaka/<key>`, which 404s. Only
/// [SitePlan] knows which those are. An index built from the tree alone would
/// look right and send 1,603 of its rows to a missing page.
///
/// ## Row shape
///
/// `[key, pali, sinhala, parentIdx, chapterIdx, marked]` — positional, not a
/// map with six key strings repeated 16,355 times. `parentIdx` and
/// `chapterIdx` are indices into this same array rather than repeated key
/// strings, which is worth ~15% gzipped and makes the parent-path walk a
/// pointer chase instead of a lookup.
///
/// Measured on the full corpus: **2,248 KB raw / 254 KB gzip / 180 KB
/// brotli**. Fetched on first dialog open, never on page load, then cached for
/// every page after it.
library;

import 'dart:convert';

import 'package:wisdom_shared/wisdom_shared.dart';

import '../domain/site_page.dart';
import 'entry_renderer.dart';
import 'node_labels.dart';

/// Builds the index for a planned site.
///
/// ## Order is the plan's, not a map's
///
/// Iterating [SitePlan.pages] — a `List` — is what keeps the output
/// byte-identical between builds (§11.8). A `Map` keyed by nodeKey would give
/// the same *rows* in an order nobody declared, and Cloudflare's hash-
/// incremental deploy would re-upload the file on every build.
///
/// It also lands each grouped leaf directly after the chapter that holds it,
/// which is tree-walk order — so the array reads as the corpus reads, and
/// nearby rows share prefixes, which is most of why it gzips as well as it
/// does.
///
/// ## The Pali column is welded, the Sinhala column is raw
///
/// This is the detail that would otherwise ship a search that silently misses.
/// Names go through [weldTitle] before a reader ever sees them (D1), which
/// inserts touching ZWJ; raw `tree.json` names carry none. An index in one form
/// alone fails against a query typed in the other, so the index ships the form
/// the reader *sees* on the page they land on, and `site.js` strips
/// zero-width characters from both the row and the query before comparing.
/// Costs +17 KB gzipped over the raw form, and saves porting
/// `beautifyPaliText`'s conjunct tables to JavaScript.
///
/// Sinhala names ship raw because they are not Pali: `beautifyPaliText` must
/// never touch a translation (it would bind consonants that should stay
/// apart). The 8,536 that carry ligature ZWJ — rakaransaya, yansaya — are
/// ordinary spelling, and the same zero-width strip removes it from query and
/// row alike.
///
/// ## The commentary marker is a flag, not a second name
///
/// A row is drawn two ways: as a result, where its page's own name applies
/// ([nodeTitle], marked "X අට්ඨකථා"), and as one of the two ancestors under
/// another result, where the trail's form applies ([nodeLabelHtml], bare). So
/// the Pali column ships the bare name and column 6 ships the marker's
/// verdict — 6,674 rows — for `site.js` to apply to a row's own name only.
///
/// Without it, 127 commentary results were byte-identical to a canon result,
/// same name and same trail, one of them landing on a page whose `<h1>` said
/// something else. Shipping the marked name as a sixth *string* instead costs
/// 525 KB raw for what a bit says (the flag costs 33 KB raw, 748 bytes
/// gzipped); deriving it in JavaScript puts the rule in a third place, which is
/// what caused the bug.
String buildSearchIndex({required SitePlan plan}) {
  final nodes = <TipitakaNode>[];
  for (final page in plan.pages) {
    nodes.add(page.node);
    // Only a chapter's leaves are extra: a sutta page's `suttas` is the page's
    // own node, and adding it here would index all 8,355 of them twice.
    if (page.kind == PageKind.chapter) nodes.addAll(page.suttas);
  }

  final position = {
    for (var i = 0; i < nodes.length; i++) nodes[i].nodeKey: i,
  };

  // Which chapter file each node's text is inside, for the nodes that have no
  // file of their own. Built from the same walk rather than by re-deriving an
  // ancestor, so the answer can only be the page the generator actually wrote.
  final chapterOf = <String, int>{};
  for (final page in plan.pages) {
    if (page.kind != PageKind.chapter) continue;
    final chapterIndex = position[page.nodeKey]!;
    for (final sutta in page.suttas) {
      chapterOf[sutta.nodeKey] = chapterIndex;
    }
  }

  final rows = <List<Object>>[
    for (final node in nodes)
      [
        node.nodeKey,
        weldTitle(node.paliName),
        node.sinhalaName,
        // -1, not null: a homogeneous integer column costs less than a mixed
        // one and the JS reads `< 0` either way.
        position[node.parentNodeKey] ?? -1,
        chapterOf[node.nodeKey] ?? -1,
        // 1/0 rather than true/false: three bytes a row saved across 16,355 of
        // them, and JavaScript reads either the same way.
        carriesCommentaryMarker(node) ? 1 : 0,
      ],
  ];

  // No trailing newline and no indent. `jsonEncode` is already compact; this is
  // 2.3 MB of machine-read data, not a file anyone opens.
  return jsonEncode(rows);
}
