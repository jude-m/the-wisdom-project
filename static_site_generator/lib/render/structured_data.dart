import 'dart:convert';

import 'package:wisdom_shared/wisdom_shared.dart';

import 'entry_renderer.dart';
import 'landing_page.dart';
import 'node_labels.dart';
import 'site_build.dart';
import 'site_chrome.dart';

/// `application/ld+json` — the machine-readable half of what the toolbar
/// already shows a reader.
///
/// **`BreadcrumbList` and nothing else.** It is the one type here with a
/// visible payoff: Google replaces the URL line in a result with the readable
/// trail, which is worth more to someone browsing scripture than
/// `sammaditthi.pages.dev › tipitaka › an-1-1` ever was. `Book` and `Chapter`
/// would describe the canon more fully and have no rich-result treatment at
/// all, so they would be markup nothing reads.
///
/// ## It restates the breadcrumb, and must not restate it differently
///
/// Same trail, same order, same nodes as [breadcrumb] — this is that `<nav>`
/// in the format a crawler parses, and a structured trail that disagrees with
/// the visible one is the shape Google penalises rather than ignores. What it
/// does *not* share is the string treatment, in three ways that would each be
/// silent if got wrong:
///
/// - **Un-welded** (D2). [nodeLabelHtml] welds, because it feeds an element a
///   reader looks at; this feeds a parser, like `<title>` and `og:title`.
/// - **JSON-escaped, never HTML-escaped.** [nodeLabelHtml] also escapes `"` so
///   one string can be both text and attribute. Inside a `<script>` element
///   there is no entity parsing, so an HTML-escaped name would reach Google as
///   the literal characters `&quot;`.
/// - **`<` escaped to `\u003c`**, on the way out. The one sequence that can
///   end a raw-text element is `</script`, and a node named with a `<` would
///   close this block early and spill JSON into the page. Nothing in
///   `tree.json` contains one today; the whole defence costs one `replaceAll`.
///
/// ## The names follow the site's two-way rule
///
/// The ancestors are steps on the way to a page, so they take the bare Pali
/// name [nodeLabelHtml] shows. The last item *is* the page, so it takes
/// [nodeTitle] — commentary marker included — and matches the `<h1>`, the
/// `<title>`, `og:title` and the row search draws for it. This is the
/// distinction the search index lost once, shipping commentary rows
/// indistinguishable from their canon twins; there is no third way to name a
/// node, and this is not it.
///
/// ## The last item carries no `item`
///
/// Google's own guidance, and it mirrors the markup: the visible trail ends on
/// a `<span aria-current="page">`, not a link, because a page does not link to
/// itself.
///
/// ## Not on `/`
///
/// A one-item breadcrumb says only "you are at the front door", which the URL
/// already says. `LandingPage` emits none.
String breadcrumbJsonLd({
  required SiteBuild build,
  required List<TipitakaNode> trail,
  required TipitakaNode current,
}) {
  final items = <Map<String, Object>>[
    // `/` is segment zero — the real parent of the seven roots, and the same
    // thing the emblem is at the left of every trail.
    _item(1, homeLabel, build.absolute(LandingPage.url)),
    for (final (index, ancestor) in trail.indexed)
      _item(
        index + 2,
        unweldTitle(ancestor.paliName),
        // Through the resolver, never `tipitakaUrl`: an ancestor is a
        // container and so always owns its page, but the day that stops being
        // true this should move with the TOC rather than 404 quietly.
        build.absolute(build.urlFor(ancestor.nodeKey)),
      ),
    _item(trail.length + 2, nodeTitle(current), null),
  ];

  // Map literals, encoded in source order. Dart's map literals are insertion-
  // ordered and this one is written out, not accumulated, so §11.8's
  // byte-determinism holds without sorting anything — there is no Map here
  // whose order was decided at runtime.
  final json = jsonEncode({
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    'itemListElement': items,
  });

  return '<script type="application/ld+json">${_forRawText(json)}</script>\n';
}

/// One `ListItem`. [url] is null on the last, which carries a name alone.
Map<String, Object> _item(int position, String name, String? url) => {
      '@type': 'ListItem',
      'position': position,
      'name': name,
      if (url != null) 'item': url,
    };

/// Makes encoded JSON safe inside a `<script>` element.
///
/// `<` is the character that matters — it opens the `</script` that would close
/// the block — and `\u003c` is how JSON spells it, which every parser reads
/// back as `<`. `>` goes too, for the `]]>` that would end a CDATA section if
/// these bytes are ever read as XML.
String _forRawText(String json) =>
    json.replaceAll('<', '\\u003c').replaceAll('>', '\\u003e');
