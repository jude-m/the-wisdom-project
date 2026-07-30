import 'package:wisdom_shared/wisdom_shared.dart';

import '../domain/document.dart';
import '../domain/site_page.dart';
import 'entry_renderer.dart';

/// Renders a complete HTML document for one [SitePage].
///
/// Pure: models in, string out, no filesystem. Everything the page needs is
/// passed in, which is what lets the whole template be unit-tested without a
/// 340 MB corpus on disk.
class PageTemplate {
  final TipitakaTree tree;
  final EntryRenderer entries;

  /// Version stamped into `<meta name="generator">`. **Not** a build id — the
  /// output has to be byte-identical between runs on unchanged input, or
  /// Cloudflare's content-hash dedup re-uploads all 16,356 files (§11.8).
  final String generatorVersion;

  const PageTemplate({
    required this.tree,
    required this.generatorVersion,
    this.entries = const EntryRenderer(),
  });

  /// [slices] holds the rendered rows for each sutta on the page, keyed by
  /// nodeKey; [preamble] is the container's own slice, rendered above a chapter
  /// or a TOC (the pitaka heading, `namo tassa`, the vagga title).
  String render(
    SitePage page, {
    required Map<String, NodeSlice> slices,
    NodeSlice? preamble,
    SitePage? previous,
    SitePage? next,
    required String sourceFile,
  }) {
    final body = StringBuffer();
    final depths = _headingDepths(page, slices, preamble);

    body.writeln('<div class="content">');
    body.writeln(_breadcrumb(page.node));
    body.writeln('<h1 class="page-title">${_headingHtml(page.node)}</h1>');
    final commentary = _commentaryLink(page.node);
    if (commentary != null) body.writeln(commentary);

    switch (page.kind) {
      case PageKind.sutta:
        body.writeln(_rows(slices[page.nodeKey], depths));
      case PageKind.chapter:
        body.writeln(_chapter(page, slices, preamble, depths));
      case PageKind.toc:
        if (preamble != null && preamble.rows.isNotEmpty) {
          body.writeln(
              '<div class="preamble">${_rows(preamble, depths)}</div>');
        }
        body.writeln(_toc(page));
    }

    if (page.isReadable) body.writeln(_pager(previous, next));
    body.writeln('</div>');

    return _document(
      page,
      head: _provenance(page, slices, preamble, sourceFile),
      body: body.toString(),
    );
  }

  // ── head ──────────────────────────────────────────────────────────────────

  /// `rel="canonical"` is left **root-relative** on purpose. The absolute form
  /// is the usual recommendation, but the apex domain is not settled yet and a
  /// wrong absolute canonical points every page at a host that does not serve
  /// it. Relative is legal and resolved against the document URL; revisit when
  /// the domain is fixed at the P5 hosting gate.
  String _document(SitePage page,
      {required String head, required String body}) {
    final title = escapeHtml(_titleText(page.node));
    return '''
<!DOCTYPE html>
<html lang="si">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title</title>
<link rel="canonical" href="${page.url}">
<link rel="stylesheet" href="/assets/site.css">
<meta name="generator" content="wisdom-ssg $generatorVersion">
$head</head>
<body>
$body</body>
</html>
''';
  }

  /// Where this page's text came from, in the direction debugging runs.
  ///
  /// The `.manifest.json` maps source → outputs so the build knows what to
  /// regenerate; this maps output → source, because the first question about a
  /// wrong-looking page is always "which entries did the slicer grab?".
  /// Dublin Core `dc.source` (ISO 15836) means exactly "the resource this was
  /// derived from".
  ///
  /// Emitted into `<head>`. `<meta>` is head-only content — a parser that meets
  /// one in `<body>` is in error recovery, and every page here would have
  /// tripped it. The comment rides along so the two stay together.
  String _provenance(
    SitePage page,
    Map<String, NodeSlice> slices,
    NodeSlice? preamble,
    String sourceFile,
  ) {
    final lines = <String>[
      '<meta name="dc.source" content="assets/text/$sourceFile.json">',
      '<!--',
      '  node: ${page.nodeKey} (${page.kind.name})',
      if (preamble != null && preamble.rows.isNotEmpty)
        '  preamble: ${preamble.coordinateRange}',
      for (final sutta in page.suttas)
        '  ${sutta.nodeKey}: ${slices[sutta.nodeKey]?.coordinateRange ?? 'missing'}',
      '-->',
    ];
    return '${lines.join('\n')}\n';
  }

  // ── page furniture ────────────────────────────────────────────────────────

  /// Ancestors, outermost first. Doubles as the internal-link graph that lets a
  /// crawler reach every node from any page.
  String _breadcrumb(TipitakaNode node) {
    final trail = tree.ancestorsOf(node.nodeKey).reversed.toList();
    if (trail.isEmpty) return '';
    final parts = <String>[
      for (final ancestor in trail)
        '<a href="${tipitakaUrl(ancestor.nodeKey)}">${_titleHtml(ancestor)}</a>',
    ];
    return '<nav class="breadcrumb" aria-label="ස්ථානය">'
        '${parts.join('<span class="sep">›</span>')}</nav>';
  }

  /// Canon ↔ commentary cross-link, emitted only when the twin key really
  /// exists in the tree — a pure key test, so it can never 404. 4,627 of 8,355
  /// canon leaves have one.
  String? _commentaryLink(TipitakaNode node) {
    const prefix = TipitakaNodeKeys.commentary;
    final isCommentary = node.nodeKey.startsWith(prefix);
    final twinKey = isCommentary
        ? node.nodeKey.substring(prefix.length)
        : '$prefix${node.nodeKey}';
    if (tree[twinKey] == null) return null;
    final label = isCommentary ? 'මූල පාඨය' : commentaryMarker;
    // Same-site navigation, so no `target="_blank"`: the app opens the twin in
    // place, and forcing a new tab here would make the same link behave
    // differently on the two surfaces.
    return '<p class="commentary-link">'
        '<a href="${tipitakaUrl(twinKey)}">$label</a></p>';
  }

  String _pager(SitePage? previous, SitePage? next) {
    final buffer = StringBuffer('<nav class="pager" aria-label="ගමන්">');
    if (previous != null) {
      buffer.write('<a class="prev" rel="prev" href="${previous.url}">'
          '<span class="label">පෙර</span>${_titleHtml(previous.node)}</a>');
    } else {
      buffer.write('<span class="spacer"></span>');
    }
    if (next != null) {
      buffer.write('<a class="next" rel="next" href="${next.url}">'
          '<span class="label">ඊළඟ</span>${_titleHtml(next.node)}</a>');
    } else {
      buffer.write('<span class="spacer"></span>');
    }
    buffer.write('</nav>');
    return buffer.toString();
  }

  String _toc(SitePage page) {
    final buffer = StringBuffer('<ul class="toc">');
    for (final child in tree.childrenOf(page.nodeKey)) {
      buffer.write('<li><a href="${tipitakaUrl(child.nodeKey)}">'
          '${_titleHtml(child)}</a></li>');
    }
    buffer.write('</ul>');
    return buffer.toString();
  }

  // ── body ──────────────────────────────────────────────────────────────────

  /// Source heading `level` → HTML heading depth, contiguous from `<h2>`.
  ///
  /// A source `level` is a *typographic size* (1 smallest … 5 largest), not an
  /// outline depth, and a page carries whichever sizes its printed book
  /// happens to use. Mapping it arithmetically — the old `h${7 - level}` —
  /// gave every `an-1` page an `<h1> → <h4> → <h6>` outline with h2, h3 and h5
  /// missing: a skipped-heading-level failure that tells a crawler the page
  /// nests three levels deeper than it does.
  ///
  /// So the sizes actually present on *this* page are ranked largest-first and
  /// handed `<h2>`, `<h3>`, … in order. A page printing two heading sizes gets
  /// `<h2>` and `<h3>` under its `<h1>`, whatever the source called them.
  /// Nothing below `<h6>` is expressible, so the tail clamps there — no page in
  /// the corpus prints more than five sizes, so the clamp never fires today.
  ///
  /// Computed per page rather than corpus-wide on purpose: a global mapping
  /// would reserve depths for sizes the page never prints, reintroducing the
  /// gaps this exists to close.
  Map<int, int> _headingDepths(
    SitePage page,
    Map<String, NodeSlice> slices,
    NodeSlice? preamble,
  ) {
    final levels = <int>{};
    void scan(NodeSlice? slice) {
      for (final row in slice?.rows ?? const <DocRow>[]) {
        final pali = row.pali;
        if (pali?.type == 'heading') {
          levels.add((pali!.level ?? 1).clamp(1, 5));
        }
      }
    }

    scan(preamble);
    for (final sutta in page.suttas) {
      scan(slices[sutta.nodeKey]);
    }

    final ranked = levels.toList()..sort((a, b) => b.compareTo(a));
    return {
      for (var i = 0; i < ranked.length; i++) ranked[i]: (i + 2).clamp(2, 6),
    };
  }

  /// A grouped run: every sutta in its own `<section>`, filtered to one by the
  /// URL fragment through CSS alone.
  String _chapter(
    SitePage page,
    Map<String, NodeSlice> slices,
    NodeSlice? preamble,
    Map<int, int> depths,
  ) {
    final buffer = StringBuffer('<div class="chapter">');
    // Shown only when a sutta is targeted — the way back to the whole run.
    buffer.write('<p class="chapter-bar">'
        '<a href="${page.url}">සම්පූර්ණ පරිච්ඡේදය</a></p>');
    if (preamble != null && preamble.rows.isNotEmpty) {
      buffer.write('<div class="preamble">${_rows(preamble, depths)}</div>');
    }
    for (final sutta in page.suttas) {
      buffer.write('<section class="sutta" id="${sutta.nodeKey}">');
      buffer.write(_rows(slices[sutta.nodeKey], depths));
      buffer.write('</section>');
    }
    buffer.write('</div>');
    return buffer.toString();
  }

  /// One `.row` per source entry.
  ///
  /// The row wrapper exists from day one even though only the Pali side is
  /// rendered in this phase: P2 adds a `.si` cell beside `.pali` and the grid
  /// picks it up as a column count, not a restructure.
  ///
  /// ## Rows this phase cannot show
  ///
  /// 5,571 rows across the corpus carry Sinhala text against an *empty* Pali
  /// entry — translator's matter the printed book has on one side only. A
  /// Pali-only phase has nothing to render for them, but dropping them without
  /// trace leaves no way to tell "the source had nothing here" from "the slicer
  /// lost it". Each one leaves a comment naming its coordinate instead, so
  /// `grep -c untranslated` over the build is a real conservation check and the
  /// count has to fall to zero when P2 lands.
  ///
  /// Genuinely empty rows — [DocRow.isEmpty], one in the whole corpus — are the
  /// only ones dropped outright.
  String _rows(NodeSlice? slice, Map<int, int> depths) {
    if (slice == null) return '';
    final buffer = StringBuffer();
    for (final row in slice.rows) {
      if (row.isEmpty) continue;
      final pali = row.pali;
      if (pali == null || pali.text.isEmpty) {
        buffer.write('<!-- untranslated: '
            'pages[${row.pageIndex}].[${row.entryIndex}] -->');
        continue;
      }
      buffer.write('<div class="row">');
      buffer.write('<div class="pali" lang="pi-Sinh">');
      buffer.write(entries.render(pali, isPali: true, headingDepths: depths));
      buffer.write('</div></div>');
    }
    return buffer.toString();
  }

  // ── titles ────────────────────────────────────────────────────────────────

  /// `<leaf> — <vagga> — <collection>` for the `<title>` element, un-welded per
  /// D2. The only string on the page that gets that treatment — everything a
  /// reader looks at goes through [weldTitle] instead.
  ///
  /// The three parts are not decoration. 1,165 leaves are titled with nothing
  /// but a number ("1. 16. 8. 9-24"), and 2,216 share a name with another leaf
  /// — a bare name would give thousands of pages an identical, meaningless
  /// `<title>`, which is the duplicate-content signal C2 exists to avoid.
  /// Parts that repeat are dropped, so a node directly under its collection
  /// does not say the collection twice.
  String _titleText(TipitakaNode node) {
    final parts = <String>[_leafTitle(node)];
    // Dedupe against the node's *bare* name, not the marked one in parts[0]:
    // "X අට්ඨකථා" can never equal a candidate, so a commentary node directly
    // under a same-named parent would have said the name twice.
    final seen = <String>{unweldTitle(node.paliName)};
    final parent =
        node.parentNodeKey == null ? null : tree[node.parentNodeKey!];
    final collection = collectionOf(tree, node.nodeKey);
    for (final extra in [parent, collection]) {
      if (extra == null) continue;
      final name = unweldTitle(extra.paliName);
      if (name.isEmpty || !seen.add(name)) continue;
      parts.add(name);
    }
    return parts.join(' — ');
  }

  /// The node's own name, with the commentary marker where §10 requires it.
  ///
  /// The 6,731 `atta-*` pages carry the *same* sutta names as their canon
  /// twins; untreated they compete for the same searches. The marker keeps the
  /// canon page the stronger hit for a bare sutta-name query while leaving the
  /// commentary indexable in its own right (it is 57 M of the corpus's ~103 M
  /// characters — unique scripture, not a duplicate, so never `noindex` and
  /// never canonical-ed at its twin).
  /// 57 nodes — the pitaka- and nikāya-level ones, `atta-vp` "විනය අට්ඨකථා",
  /// `atta-dn` "දීඝනිකාය අට්ඨකථා" — are named with the marker already, and
  /// appending blindly gave them "… අට්ඨකථා අට්ඨකථා". The test is `endsWith`,
  /// not `contains`: `atta-ap-dhs-5` is "අට්ඨකථාකණ්ඩො", a section *about* the
  /// commentary, and it does still need marking.
  String _leafTitle(TipitakaNode node) {
    final name = unweldTitle(node.paliName);
    if (!node.nodeKey.startsWith(TipitakaNodeKeys.commentary)) return name;
    return name.trimRight().endsWith(commentaryMarker)
        ? name
        : '$name $commentaryMarker';
  }

  /// The visible page heading.
  ///
  /// Welded, not un-welded — it is text a person reads, so it follows D1 like
  /// the body does. Only the `<title>` above takes the D2 treatment.
  ///
  /// Carries the commentary marker like the `<title>` does, and for the same
  /// reason: without it a commentary page and its canon twin are two documents
  /// whose heading is the identical string. It does **not** repeat the vagga
  /// and collection the `<title>` appends — the breadcrumb sits directly above
  /// and already says them (§10).
  String _headingHtml(TipitakaNode node) =>
      escapeHtml(weldTitle(_leafTitle(node)));

  /// A node's name as it appears in a *link* — breadcrumb, pager, TOC entry.
  ///
  /// Welded, for the same reason as [_headingHtml]: these are labels a reader
  /// looks at, and the app welds the very same strings in its tree and
  /// breadcrumb.
  ///
  /// Bare, with no commentary marker: inside a commentary subtree every
  /// ancestor and sibling is `atta-*` too, so marking each one would print
  /// අට්ඨකථා at every step of the trail to say something the reader already
  /// knows from the page they are on.
  ///
  /// No romanized (IAST) variant is offered anywhere in this file: D4 ships
  /// Sinhala-only titles because tree.json carries no Latin text for any of its
  /// 16,355 nodes.
  String _titleHtml(TipitakaNode node) => escapeHtml(weldTitle(node.paliName));
}

/// The Sinhala word for the commentary layer, appended to every `atta-*` title.
const String commentaryMarker = 'අට්ඨකථා';
