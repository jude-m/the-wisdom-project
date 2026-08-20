import 'package:wisdom_shared/wisdom_shared.dart';

import '../domain/document.dart';
import '../domain/site_page.dart';
import 'document_shell.dart';
import 'entry_renderer.dart';
import 'node_labels.dart';
import 'reading_layouts.dart';
import 'site_assets.dart';
import 'site_chrome.dart';

/// Renders a complete HTML document for one [SitePage].
///
/// Pure: models in, string out, no filesystem. Everything the page needs is
/// passed in, which is what lets the whole template be unit-tested without the
/// corpus on disk.
class PageTemplate {
  final TipitakaTree tree;
  final EntryRenderer entries;

  /// Version stamped into `<meta name="generator">`. **Not** a build id — the
  /// output has to be byte-identical between runs on unchanged input, or
  /// Cloudflare's content-hash dedup re-uploads every file (§11.8).
  final String generatorVersion;

  /// The stylesheet, script, index and emblem URLs, each carrying a hash of its
  /// own bytes — see [SiteAssets]. Threaded in for the same reason
  /// [generatorVersion] is: one value per build, and the template is not the
  /// thing that knows it.
  final SiteAssets assets;

  /// Where a link to a nodeKey must point — [SitePlan.urlFor].
  ///
  /// Every outgoing link the template writes to a key it did not get from a
  /// [SitePage] has to go through this: a TOC child and an අට්ඨකථා twin are
  /// both just keys, and a folded key's bare URL is served by no file.
  final UrlResolver urlFor;

  const PageTemplate({
    required this.tree,
    required this.generatorVersion,
    required this.assets,
    required this.urlFor,
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
    // Filtered before the depths are computed, not after: dropping a heading
    // changes which sizes the page prints, and _headingDepths ranks the sizes
    // it is given. Ranking the unfiltered set would reserve `<h2>` for a
    // heading that never reaches the page and start the suttas at `<h3>` —
    // the skipped level that ranking-by-size exists to prevent.
    final shown = _withoutRepeatedTitle(preamble, page.node);
    final depths = _headingDepths(page, slices, shown.preamble);

    // Every slice the page renders, in one list: the preamble a chapter or a
    // readable TOC prints above the text, and the leaves themselves.
    // [SitePage.suttas] is `[node]` for a sutta page, the whole run for a
    // chapter and empty for a TOC, so the three kinds need no branch here — and
    // asking the question once is what stops the caption and the switcher below
    // from being two scans able to disagree.
    final bothLanguages = _hasBothLanguages([
      shown.preamble,
      for (final sutta in page.suttas) slices[sutta.nodeKey],
    ]);

    // Order is the contract. Every rule that switches a layout is a sibling
    // combinator off the radios, so they have to *precede* `.toolbar` and
    // `.content` and all three have to stay siblings. Nothing here may be
    // wrapped in a container without rewriting the stylesheet with it.
    //
    // **Not emitted where there is nothing to switch.** On a page holding one
    // language three of the four layouts differ only in how much blank column
    // they reserve, and the fourth — whichever hides the language the page
    // *has* — renders nothing at all: the sinhalaOnly rule hides every
    // `.row.no-si`, which on a `FIGURES.readablePagesWithoutSinhala` page is
    // every row it has. `site.js` remembers the choice, so picking it once
    // anywhere blanked every Paṭṭhāna page a reader opened afterwards.
    // Withholding the control is what makes that state unreachable — with
    // JavaScript on or off, which a runtime guard could not manage.
    final withLayouts = page.isReadable && bothLanguages;
    if (withLayouts) body.writeln(_layoutRadios());
    body.writeln(toolbar(
      withLayouts: withLayouts,
      assets: assets,
      // Outermost first — `ancestorsOf` walks upwards, a trail reads downwards.
      trail: tree.ancestorsOf(page.nodeKey).reversed.toList(),
      current: page.node,
      parent: tree.parentOf(page.nodeKey),
    ));

    // `<main>`, not a div: a landmark is what lets a screen reader skip the bar
    // and start at the text.
    //
    // `nav` on a TOC page whose preamble is a title and `namo tassa`: nothing
    // there wants a measure, so the column is sized for link rows. The
    // `FIGURES.readableContainerTocs` containers whose preamble is the book's
    // introduction are excluded by the same predicate that gates the radios
    // above, and read at the full measure like any other page. The link rows
    // keep their own width either way — `.toc` caps itself.
    //
    // `solo` on a readable page holding one language. It carries no layout of
    // its own — the base `.row` state is already what a page with no radios
    // renders as — but two declarations live only on the single-language
    // layouts, and with no radio checked the sheet has nothing else to hang
    // them on: the entry gap, and the Pali weight bump that exists to
    // distinguish Pali from a translation this page does not have.
    final navOnly = !page.isReadable;
    final solo = page.isReadable && !bothLanguages;
    body.writeln('<main class="content'
        '${navOnly ? ' nav' : ''}${solo ? ' solo' : ''}">');
    body.writeln('<h1 class="page-title">${_headingHtml(page.node)}</h1>');
    final commentary = _commentaryLink(page.node);
    if (commentary != null) body.writeln(commentary);

    switch (page.kind) {
      case PageKind.sutta:
        body.writeln(_columnHeads(bothLanguages));
        body.writeln(_rows(slices[page.nodeKey], depths));
      case PageKind.chapter:
        body.writeln(_chapter(page, slices, shown.preamble, depths,
            bothLanguages: bothLanguages));
      case PageKind.toc:
        if (shown.preamble != null && shown.preamble!.rows.isNotEmpty) {
          // Captions only where there is a measure to caption. On a nav-only
          // container the preamble is the title and `namo tassa`, laid out in
          // one column with no layout switcher to split it — a පාළි/සිංහල
          // header there would label a pair of columns the reader cannot
          // produce.
          if (page.isReadable) {
            body.writeln(_columnHeads(bothLanguages));
          }
          body.writeln(
              '<div class="preamble">${_rows(shown.preamble, depths)}</div>');
        }
        body.writeln(tocList(tree.childrenOf(page.nodeKey), urlFor: urlFor));
    }

    if (page.isReadable) body.writeln(_pager(previous, next));
    body.writeln('</main>');

    return _document(
      page,
      // The *unfiltered* slice: provenance answers "what did the slicer grab",
      // which stays true whether or not the renderer showed all of it. The
      // suppressed row is named separately so the two never have to be guessed
      // apart.
      head: _provenance(page, slices, preamble, shown.dropped, sourceFile),
      body: body.toString(),
    );
  }

  /// The preamble minus a heading that merely repeats the page's own `<h1>`.
  ///
  /// Both are correct on their own. The template writes an `<h1>` from the tree
  /// node because every page needs exactly one — the breadcrumb, the `<title>`
  /// and every crawler key off it. The printed book *also* opens the container
  /// with its name, and that is a normal heading entry in the JSON, which the
  /// preamble renders faithfully. On many container pages the two are the same
  /// string, so the reader would get the vagga name twice in a row.
  ///
  /// The `<h1>` wins and the source heading goes. Dropping the `<h1>` instead
  /// would leave the pages that *don't* repeat with no heading at all.
  ///
  /// Only the **first heading** in the preamble is a candidate, and only when it
  /// matches: measured across the corpus subtree, every repeat is the preamble's
  /// first heading and its only one — sometimes row 0 (`an-1-1`), sometimes row
  /// 3 behind three `centered` lines (`an-1`). Anything later is the book
  /// genuinely printing a second heading, and is left alone.
  ///
  /// **Only the Pali cell is cleared, not the row.** The `<h1>` carries the
  /// node's Pali name and nothing else, so removing the whole row would take
  /// the Sinhala name of the container with it — and a reader in
  /// sinhalaOnly would then meet a page whose title exists only in a language
  /// they have switched off. The row survives as `no-pali`: hidden in
  /// paliOnly, where the `<h1>` already says it, and showing the translation
  /// in the three layouts that want it.
  ({NodeSlice? preamble, DocRow? dropped}) _withoutRepeatedTitle(
    NodeSlice? preamble,
    TipitakaNode node,
  ) {
    if (preamble == null) return (preamble: null, dropped: null);

    for (var i = 0; i < preamble.rows.length; i++) {
      final row = preamble.rows[i];
      final pali = row.pali;
      if (pali == null || pali.text.isEmpty) continue;
      if (pali.type != 'heading') continue;

      // Compared *welded*, the form both sides are displayed in, so the test is
      // literally "would the reader see the same string twice" rather than a
      // guess about how the two spellings normalise.
      if (weldTitle(pali.text).trim() != weldTitle(node.paliName).trim()) {
        return (preamble: preamble, dropped: null);
      }
      final rows = [...preamble.rows];
      rows[i] = DocRow(
        pageIndex: row.pageIndex,
        pageNum: row.pageNum,
        entryIndex: row.entryIndex,
        pali: null,
        sinhala: row.sinhala,
      );
      return (
        preamble: NodeSlice(
          nodeKey: preamble.nodeKey,
          rows: rows,
          startIndex: preamble.startIndex,
        ),
        dropped: row,
      );
    }
    return (preamble: preamble, dropped: null);
  }

  // ── head ──────────────────────────────────────────────────────────────────

  /// Canonical is always **self**, including on the commentary pages
  /// (`FIGURES.commentaryPages`): a commentary and its canon twin are different
  /// texts, not duplicates, so neither ever points at the other (§10).
  String _document(SitePage page,
          {required String head, required String body}) =>
      htmlDocument(
        title: _titleText(page.node),
        canonical: page.url,
        generatorVersion: generatorVersion,
        assets: assets,
        head: head,
        body: body,
      );

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
    DocRow? droppedTitle,
    String sourceFile,
  ) {
    final lines = <String>[
      '<meta name="dc.source" content="assets/text/$sourceFile.json">',
      '<!--',
      '  node: ${page.nodeKey} (${page.kind.name})',
      if (preamble != null && preamble.rows.isNotEmpty)
        '  preamble: ${preamble.coordinateRange}',
      // Named, not silently swallowed: the coordinate range above still counts
      // this row, so without the note a reader of the comment would count one
      // more entry than the page shows and go looking for a slicer bug.
      if (droppedTitle != null)
        '  title-repeat suppressed (pali side only): '
            'pages[${droppedTitle.pageIndex}].[${droppedTitle.entryIndex}]',
      for (final sutta in page.suttas)
        '  ${sutta.nodeKey}: ${slices[sutta.nodeKey]?.coordinateRange ?? 'missing'}',
      '-->',
    ];
    return '${lines.join('\n')}\n';
  }

  // ── page furniture ────────────────────────────────────────────────────────

  /// The four reading-layout radios, with **no JavaScript** behind them (C5).
  ///
  /// One radio set per page, never one per section — duplicated `id`s are
  /// invalid HTML and every label would bind to the first set only.
  ///
  /// The inputs are visually hidden rather than `display:none`, which would
  /// take them out of the tab order and leave the control unreachable from a
  /// keyboard. Their accessible name comes from `aria-label`, because the
  /// visible label is a letter or an icon: the app's own Sinhala strings from
  /// `app_si.arb` are what a screen reader should say, not "P".
  ///
  /// Emitted on readable pages only. A container TOC has no reading layout to
  /// choose, and the absence costs nothing: with no radio checked, none of the
  /// `#L-x:checked ~` rules match, so a `.row` keeps its default single column
  /// and both languages show stacked — which is the right thing for a
  /// preamble, reached without a single special case in the CSS.
  String _layoutRadios() {
    final buffer = StringBuffer();
    for (final layout in readingLayouts) {
      buffer.write('<input class="layout-input" type="radio" name="layout"'
          ' id="${layout.id}" value="${layout.token}"');
      if (layout.id == defaultLayoutId) buffer.write(' checked');
      buffer.write(' aria-label="${layout.label}">');
    }
    return buffer.toString();
  }

  /// Canon ↔ commentary cross-link, emitted only when the twin key exists in
  /// the tree — `FIGURES.pagesWithCommentaryLink` pages carry one.
  ///
  /// **The key test is not enough on its own.** A key that exists may still be
  /// a folded leaf, which owns no file — `FIGURES.commentaryTwinsFolded` of
  /// these twins are — so the destination has to come from [urlFor] and not
  /// from [tipitakaUrl]. The remaining way to 404 is a subtree build, where the
  /// twin lives under a root that was not built at all: `an-1` sits under `sp`
  /// and `atta-an-1` under `atta-sp`.
  String? _commentaryLink(TipitakaNode node) {
    final twinKey = node.isCommentary
        ? node.nodeKey.substring(TipitakaNodeKeys.commentary.length)
        : '${TipitakaNodeKeys.commentary}${node.nodeKey}';
    if (tree[twinKey] == null) return null;
    final label = node.isCommentary ? 'මූල පාඨය' : commentaryMarker;
    // Same-site navigation, so no `target="_blank"`: the app opens the twin in
    // place, and forcing a new tab here would make the same link behave
    // differently on the two surfaces.
    return '<p class="commentary-link">'
        '<a href="${urlFor(twinKey)}">$label</a></p>';
  }

  String _pager(SitePage? previous, SitePage? next) {
    final buffer = StringBuffer('<nav class="pager" aria-label="ගමන්">');
    if (previous != null) {
      buffer.write('<a class="prev" rel="prev" href="${previous.url}">'
          '<span class="label">පෙර</span>${nodeLabelHtml(previous.node)}</a>');
    } else {
      buffer.write('<span class="spacer"></span>');
    }
    if (next != null) {
      buffer.write('<a class="next" rel="next" href="${next.url}">'
          '<span class="label">ඊළඟ</span>${nodeLabelHtml(next.node)}</a>');
    } else {
      buffer.write('<span class="spacer"></span>');
    }
    buffer.write('</nav>');
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
        // Both sides, because either can be the only one on a row and the two
        // do not always agree on type — a heading in Sinhala can pair with a
        // Pali entry the book set as something else. Ranking only the Pali
        // levels would leave a Sinhala-only heading with no depth at all,
        // defaulting it to `<h2>` and reopening the skipped-level gap this
        // whole mapping exists to close.
        for (final entry in [row.pali, row.sinhala]) {
          if (entry?.type == 'heading') {
            levels.add((entry!.level ?? 1).clamp(1, 5));
          }
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
    Map<int, int> depths, {
    required bool bothLanguages,
  }) {
    final buffer = StringBuffer('<div class="chapter">');
    // Shown only when a sutta is targeted — the way back to the whole run.
    //
    // A lone-child chapter (`FIGURES.loneChildChapters`: a container merged
    // with its only leaf) has no "rest" to go back to, so the bar would offer a
    // link from the page to itself. The `:has(:target)` filter still applies
    // and still does the right thing; there is simply nothing filtered away.
    if (page.suttas.length > 1) {
      buffer.write('<p class="chapter-bar">'
          '<a href="${page.url}">සම්පූර්ණ පරිච්ඡේදය</a></p>');
    }
    // After the bar, not before: in the filtered single-sutta view the bar is
    // the page's first line, and column captions above it would caption it.
    buffer.write(_columnHeads(bothLanguages));
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

  /// One `.row` per source entry, carrying both language cells.
  ///
  /// The row is the unit the four layouts act on: side-by-side gives it two
  /// grid columns, stacked one, and the single-language layouts hide a cell.
  /// All of that is CSS — the markup is the same on every page and both
  /// languages are always in the DOM, which is what keeps the Sinhala text
  /// indexable no matter which layout is baked in (C5).
  ///
  /// ## A missing side is a row class, not a missing row
  ///
  /// Thousands of rows corpus-wide carry Sinhala against an *empty* Pali entry
  /// (`FIGURES.rowsSinhalaWithEmptyPali`) — translator's matter the printed
  /// book has on one side only — and rows with the reverse shape are commoner
  /// still. Both are rendered, with the absent cell simply not emitted and the
  /// row marked `no-pali` / `no-si`.
  ///
  /// That class is what lets a single-language layout skip the row entirely
  /// rather than print an empty gap where the other language would have been.
  /// Emitting a placeholder cell instead would work for the grid but would put
  /// that blank into paliOnly and sinhalaOnly too, where nothing is there to
  /// fill it; side-by-side keeps its columns honest with explicit
  /// `grid-column`, which needs no placeholder.
  ///
  /// Genuinely empty rows — [DocRow.isEmpty], `FIGURES.rowsEmptyBothSides` in
  /// the whole corpus — are the only ones dropped outright.
  String _rows(NodeSlice? slice, Map<int, int> depths) {
    if (slice == null) return '';
    final buffer = StringBuffer();
    for (final row in slice.rows) {
      if (row.isEmpty) continue;
      final pali = row.pali;
      final sinhala = row.sinhala;
      final hasPali = pali != null && pali.text.isNotEmpty;
      final hasSinhala = sinhala != null && sinhala.text.isNotEmpty;

      buffer.write('<div class="row');
      if (!hasPali) buffer.write(' no-pali');
      if (!hasSinhala) buffer.write(' no-si');
      buffer.write('">');
      if (hasPali) {
        // `pi-Sinh` — Pali written in Sinhala script. Not `si`: the words are
        // Pali, and a screen reader or language detector told otherwise reads
        // them as Sinhala.
        buffer.write('<div class="pali" lang="pi-Sinh">');
        buffer.write(entries.render(pali, isPali: true, headingDepths: depths));
        buffer.write('</div>');
      }
      if (hasSinhala) {
        // `isPali: false` gates the conjunct transform off. Baking ZWJ into
        // the translation would bind consonants that Sinhala orthography keeps
        // apart — the same seam `content_text_formatter.dart` holds in the app.
        buffer.write('<div class="si" lang="si">');
        buffer.write(
            entries.render(sinhala, isPali: false, headingDepths: depths));
        buffer.write('</div>');
      }
      buffer.write('</div>');
    }
    return buffer.toString();
  }

  /// Column captions for the side-by-side layout, hidden in the other three.
  ///
  /// Not decoration on this corpus specifically: Pali here is *written in
  /// Sinhala script*, so two columns of it are the same alphabet and a reader
  /// landing mid-page cannot tell which side is the canon and which the
  /// translation. Every other layout either shows one language or alternates
  /// them, so the captions would be noise — CSS shows them only under
  /// side-by-side.
  ///
  /// A `.row` like any other, so it inherits the same grid and its cells line
  /// up with the text below. `aria-hidden` because the cells themselves carry
  /// `lang`, which is how a screen reader already announces the switch.
  ///
  /// **Emitted only when the page really has both languages** — see
  /// [_hasBothLanguages], which is the same fact that decides whether the page
  /// gets a layout switcher at all. Captioning a column that is empty from top
  /// to bottom labels the absence rather than explaining it.
  String _columnHeads(bool bothLanguages) {
    if (!bothLanguages) return '';
    return '<div class="row col-heads" aria-hidden="true">'
        '<div class="pali">පාළි</div>'
        '<div class="si">සිංහල</div>'
        '</div>';
  }

  /// Whether both languages actually reach the page.
  ///
  /// One question, asked once per page over every slice it renders, because
  /// three things turn on it and they must not be able to disagree: the column
  /// captions above, the layout switcher, and the `solo` class that carries
  /// what the missing radios would have set. It was the captions' private scan
  /// until it turned out the switcher needed the same answer — see [render],
  /// which has the incident.
  ///
  /// The `FIGURES.readablePagesWithoutSinhala` readable pages that answer *no*
  /// are all in the `ap-pat*` (Paṭṭhāna) files, which carry no Sinhala at all.
  /// No readable page in the corpus lacks Pali
  /// (`FIGURES.readablePagesWithoutPali`), so the reverse never fires — but the
  /// test is symmetric because nothing guarantees that stays true after a
  /// re-sync from upstream.
  ///
  /// Judged on the text a row actually holds, matching [_rows]: an entry
  /// present but empty is not a language on the page, and is exactly the row
  /// [_rows] marks `no-pali` / `no-si`.
  bool _hasBothLanguages(Iterable<NodeSlice?> slices) {
    var hasPali = false;
    var hasSinhala = false;
    for (final slice in slices) {
      for (final row in slice?.rows ?? const <DocRow>[]) {
        hasPali |= row.pali?.text.isNotEmpty ?? false;
        hasSinhala |= row.sinhala?.text.isNotEmpty ?? false;
        if (hasPali && hasSinhala) return true;
      }
    }
    return false;
  }

  // ── titles ────────────────────────────────────────────────────────────────

  /// `<leaf> — <vagga> — <collection>` for the `<title>` element, un-welded per
  /// D2. The only string on the page that gets that treatment — everything a
  /// reader looks at goes through [weldTitle] instead.
  ///
  /// The three parts are not decoration. `FIGURES.numericOnlyLeafTitles` leaves
  /// are titled with nothing but a number ("1. 16. 8. 9-24"), and
  /// `FIGURES.leavesSharingATitle` share a name with another leaf — a bare name
  /// would give thousands of pages an identical, meaningless `<title>`, which
  /// is the duplicate-content signal C2 exists to avoid.
  /// Parts that repeat are dropped, so a node directly under its collection
  /// does not say the collection twice.
  String _titleText(TipitakaNode node) {
    final parts = <String>[nodeTitle(node)];
    // Dedupe against the node's *bare* name, not the marked one in parts[0]:
    // "X අට්ඨකථා" can never equal a candidate, so a commentary node directly
    // under a same-named parent would have said the name twice.
    final seen = <String>{unweldTitle(node.paliName)};
    final parent = tree.parentOf(node.nodeKey);
    final collection = collectionOf(tree, node.nodeKey);
    for (final extra in [parent, collection]) {
      if (extra == null) continue;
      final name = unweldTitle(extra.paliName);
      if (name.isEmpty || !seen.add(name)) continue;
      parts.add(name);
    }
    return parts.join(' — ');
  }

  /// The visible page heading.
  ///
  /// Welded, not un-welded — it is text a person reads, so it follows D1 like
  /// the body does. Only the `<title>` above takes the D2 treatment.
  ///
  /// Carries the commentary marker like the `<title>` does, and for the same
  /// reason: without it a commentary page and its canon twin are two documents
  /// whose heading is the identical string. It does **not** repeat the vagga
  /// and collection the `<title>` appends — the breadcrumb in the toolbar
  /// already says them (§10).
  ///
  /// That trail now ends on this node too, so the name is on screen twice. Not
  /// a repeat worth suppressing, unlike the preamble's in [_withoutRepeatedTitle]:
  /// one is the page's heading and the other is a position in a hierarchy, they
  /// are in different landmarks, and the marker means the two are not even the
  /// same string on a commentary page.
  String _headingHtml(TipitakaNode node) =>
      escapeHtml(weldTitle(nodeTitle(node)));
}
