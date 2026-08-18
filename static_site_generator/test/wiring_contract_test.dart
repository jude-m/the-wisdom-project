/// The build plan's §8.3 — the guard for the one class of bug that every other
/// signal in this package is blind to.
///
/// ## Why this file exists
///
/// `render/page_template.dart` emits ids and class names. `render/stylesheet.dart`
/// writes selectors against them. **Nothing connects the two.** When they
/// disagree, the site breaks and every check currently run stays green:
///
/// | signal                        | verdict on a dead layout engine |
/// |-------------------------------|----------------------------------|
/// | `dart analyze`                | clean — neither file is wrong alone |
/// | `dart format`                 | clean |
/// | build-twice hash (§11.8)      | identical — a broken site is deterministically broken |
/// | entry conservation            | passes — every element is present |
/// | HTML validator (P6)           | passes — class names have no schema |
/// | link checker (P6)             | passes — no URL changed |
///
/// The reason underneath all six: **a CSS rule that matches nothing is not an
/// error.** That is by design in CSS — it is how forward-compatibility works —
/// and the cost is that "matches zero elements" is indistinguishable from
/// "correctly matches zero elements right now".
///
/// The post-P2 review caught exactly this by reading, which does not scale.
/// Centralising the four layout ids in `render/reading_layouts.dart` narrowed the
/// window; it did not close it, because the *class* names are still bare string
/// literals typed once on each side (`'no-pali'` at `page_template.dart` and
/// again inside a selector string in `stylesheet.dart`).
///
/// Part 2 covers the template's own decisions — every one of them a branch that
/// has already been wrong once and was fixed by hand.
///
/// ## Deliberately not here
///
/// Whether the CSS *renders* correctly: that a 600 weight reads as distinct,
/// that the sticky bar clears an anchor, that a phone shows three buttons. A
/// string test cannot see a browser; that stays `tool/serve.dart` and the
/// ui-auditor. Nor golden HTML files, which fail on every legitimate change and
/// teach the reflex of regenerating without reading the diff.
///
/// Needs no corpus — both sides are pure functions returning Strings, which is
/// what makes this cheap. Run with `dart test` from the package root.
library;

import 'dart:convert';
import 'dart:io';

import 'package:static_site_generator/domain/content_file.dart';
import 'package:static_site_generator/domain/document.dart';
import 'package:static_site_generator/domain/site_page.dart';
import 'package:static_site_generator/domain/theme_tokens.dart';
import 'package:static_site_generator/render/entry_renderer.dart';
import 'package:static_site_generator/render/landing_page.dart';
import 'package:static_site_generator/render/page_template.dart';
import 'package:static_site_generator/render/reading_layouts.dart';
import 'package:static_site_generator/render/site_assets.dart';
import 'package:static_site_generator/render/stylesheet.dart';
import 'package:test/test.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

void main() {
  // The real committed tokens, not a synthetic map: a hand-written stand-in
  // would drift from the schema `dump_theme_tokens.dart` actually emits, and
  // then this file would be testing a fiction. It is 5.6 KB — a build input,
  // not the corpus.
  final tokens = _readThemeTokens();
  // A literal font token, like `_assets` below and for the same reason: these
  // tests assert what reaches the page, and hashing the real WOFF2 faces here
  // would make an expected string change whenever a face is re-subset.
  final css = buildStylesheet(tokens, fontVersion: 'test');

  group('the wiring contract — markup ⇄ stylesheet', () {
    test('every #L- selector in the stylesheet names a real layout', () {
      final declared = {for (final layout in readingLayouts) layout.id};
      final selected = RegExp(r'#(L-[\w-]+)')
          .allMatches(css)
          .map((match) => match.group(1)!)
          .toSet();

      // Without this the test passes vacuously on a stylesheet that emits no
      // layout rules at all — which is itself the failure being guarded.
      expect(selected, isNotEmpty,
          reason: 'The layout CSS emitted no #L- selectors. The engine cannot '
              'be wired if nothing selects on it.');
      expect(selected.difference(declared), isEmpty,
          reason:
              'The stylesheet selects on a layout id that does not exist in '
              'readingLayouts. Those rules match nothing and the layout they '
              'belong to is dead — silently, because an unmatched CSS rule is '
              'not an error anywhere in the toolchain.');
    });

    test('every layout has both an <input id> and a <label for>', () {
      final html = _render(_suttaPage, slices: {'sp-toc-1': _bothLanguages()});

      for (final layout in readingLayouts) {
        expect(html, contains('id="${layout.id}"'),
            reason: '${layout.id} is in readingLayouts but no radio carries it '
                '— the layout is unreachable.');
        expect(html, contains('for="${layout.id}"'),
            reason: '${layout.id} has a radio but no button bound to it — the '
                'layout exists and cannot be chosen.');
      }
    });

    test('exactly one radio is checked, and it is the default', () {
      final html = _render(_suttaPage, slices: {'sp-toc-1': _bothLanguages()});
      final checked =
          RegExp(r'<input[^>]*\bchecked\b[^>]*>').allMatches(html).toList();

      expect(checked, hasLength(1),
          reason: 'Two defaults or none. With none, the page opens in the base '
              'single-column state no button is lit for.');
      expect(checked.single.group(0), contains('id="$defaultLayoutId"'));
    });

    test('the default and narrow-fallback ids are themselves real layouts', () {
      // Both are consumed by the stylesheet as bare interpolations, so a typo
      // in either writes a selector that compiles and matches nothing.
      final declared = {for (final layout in readingLayouts) layout.id};
      expect(declared, contains(defaultLayoutId));
      expect(declared, contains(narrowFallbackLayoutId));
    });

    test('layout ids and tokens are each unique', () {
      // Ids: duplicates are invalid HTML and every label binds to the first.
      // Tokens: P4 resolves `?layout=` by matching on `token`, so a repeat
      // would make one layout unreachable from a shared link.
      expect(readingLayouts.map((layout) => layout.id).toSet(),
          hasLength(readingLayouts.length));
      expect(readingLayouts.map((layout) => layout.token).toSet(),
          hasLength(readingLayouts.length));
    });

    test('every class the layout CSS acts on is emitted by the template', () {
      // Derived from the sheet rather than hand-listed, for two reasons. A
      // hand-kept array only covers the classes someone remembered to add to
      // it — P4's search dialog will bring more. And checking a name against
      // the *whole* stylesheet proves less than it looks: `.content` renamed
      // inside a layout rule alone would still find `.content { … }` in the
      // page chrome and pass, with paliOnly quietly no longer hiding anything.
      // Scoping to the rules that mention a radio is what makes this check mean
      // what its name says.
      final selectors = _rulesSelectingOn(css, '#L-');
      expect(selectors, isNotEmpty,
          reason: 'No CSS rule selects on a layout radio at all. The engine is '
              'unwired and the assertions below would pass vacuously.');

      // A layout can have a radio, a label and no rule that acts on the text —
      // reachable, lit, and inert. Every one of the four must reach `.content`.
      for (final layout in readingLayouts) {
        expect(
            selectors.any((selector) =>
                selector.contains('#${layout.id}:checked') &&
                selector.contains('.content')),
            isTrue,
            reason: '${layout.id} has a radio and a button but no rule that '
                'acts on the text. Choosing it would change nothing.');
      }

      final acted = <String>{
        for (final selector in selectors)
          ...RegExp(r'\.([\w-]+)')
              .allMatches(selector)
              .map((match) => match.group(1)!),
      };

      // A chapter page carrying a mixed slice emits nearly the whole set at
      // once — both languages (col-heads), a Pali-only row (no-si) and a
      // Sinhala-only row (no-pali). The one class it cannot show is `.nav`,
      // which only a container page carries and which the side-by-side width
      // override names in a `:not()`; the TOC page joins it for that. Worth
      // keeping in scope rather than exempting `:not()`, since a `.nav` the
      // template stopped emitting would make that guard silently inert.
      final emitted = _classNamesIn(_render(
        _chapterPage,
        slices: {
          'sp-grp-1': _slice('sp-grp-1', [
            _row(pali: _entry('ධම්මං'), sinhala: _entry('ධර්මය')),
            _row(pali: _entry('පාළි පමණයි'), at: 1),
          ]),
          'sp-grp-2': _slice('sp-grp-2', [
            _row(sinhala: _entry('සිංහල පමණයි'), at: 2),
          ]),
        },
      ))
        ..addAll(_classNamesIn(_render(_tocPage)));

      expect(emitted, containsAll(acted),
          reason: 'The layout CSS acts on ${acted.difference(emitted)}, which '
              'the template does not emit. Those rules match nothing — a dead '
              'rule, not an error, anywhere in the toolchain.');
    });

    test('the grouped-chapter filter selects on classes the template emits',
        () {
      // The zero-JS single-sutta view: `.chapter:has(.sutta:target)` hides
      // every sibling `.sutta`, and `.chapter-bar` is the way back to the whole
      // run. No radio appears in those rules, so the derivation above cannot
      // reach them — and this is the seam P4 leans on hardest. Rename either
      // side and every grouped-leaf deep link (`FIGURES.foldedLeaves`) lands on
      // a chapter showing its whole run: HTTP 200, valid markup, no URL
      // changed, nothing red.
      final selectors = _rulesSelectingOn(css, ':target');
      expect(selectors, isNotEmpty,
          reason: 'Nothing in the stylesheet reacts to a URL fragment. The '
              'single-sutta view is gone.');

      final acted = <String>{
        for (final selector in selectors)
          ...RegExp(r'\.([\w-]+)')
              .allMatches(selector)
              .map((match) => match.group(1)!),
      };
      expect(acted, containsAll(['chapter', 'chapter-bar', 'sutta']),
          reason: 'The filter no longer names all three of .chapter, '
              '.chapter-bar and .sutta: $acted.');

      final emitted = _classNamesIn(_render(_chapterPage, slices: {
        'sp-grp-1': _bothLanguages('sp-grp-1'),
        'sp-grp-2': _bothLanguages('sp-grp-2'),
      }));
      expect(emitted, containsAll(acted),
          reason: 'The filter acts on ${acted.difference(emitted)}, which a '
              'chapter page does not emit.');
    });

    test('chapter sections are anchored by nodeKey', () {
      // Load-bearing for P4: the grouped leaves (`FIGURES.foldedLeaves`) have
      // no page of their own, so a search result must link
      // `/tipitaka/<chapter>#<leafKey>`. If the id here stops being the bare
      // nodeKey, every one of those deep links lands on the chapter head
      // instead of the sutta — and still returns 200, so no link checker sees
      // it.
      final html = _render(_chapterPage, slices: {
        'sp-grp-1': _bothLanguages('sp-grp-1'),
        'sp-grp-2': _bothLanguages('sp-grp-2'),
      });

      expect(html, contains('<section class="sutta" id="sp-grp-1">'));
      expect(html, contains('<section class="sutta" id="sp-grp-2">'));
    });
  });

  group("the template's own decisions", () {
    test('a repeated preamble title clears the Pali cell, not the row', () {
      // The P1 regression: `_withoutRepeatedTitle` dropped the whole row when
      // its heading repeated the <h1>. But the <h1> carries the Pali name only,
      // so the Sinhala name went with it and a sinhalaOnly reader met a page
      // titled in a language they had switched off.
      final vagga = _tree['sp-grp']!;
      final html = _render(
        _chapterPage,
        slices: {'sp-grp-1': _bothLanguages('sp-grp-1')},
        preamble: _slice('sp-grp', [
          _row(
            pali: _entry(vagga.paliName, type: 'heading', level: 5),
            sinhala: _entry(vagga.sinhalaName, type: 'heading', level: 5),
          ),
        ]),
      );

      // The welded name is what a reader sees. It belongs in the <h1> and
      // nowhere else in the text — twice means the preamble printed it again
      // two lines below the title.
      //
      // Counted inside `<main>`, not across the document: the breadcrumb ends
      // on the current node and so names it too, deliberately. That segment is
      // chrome in a different landmark, and letting it into the count would
      // make this guard fail on a change it has no opinion about.
      expect(_countOf(_mainOf(html), weldTitle(vagga.paliName)), 1,
          reason: 'The vagga name renders twice: once as the <h1> and once as '
              'the preamble heading the <h1> was meant to replace.');
      expect(html, contains(vagga.sinhalaName),
          reason: 'The Sinhala name went with the Pali one — the exact P1 '
              'regression this guards.');
      expect(_classNamesIn(html), contains('no-pali'),
          reason: 'The surviving row must be marked no-pali so paliOnly can '
              'skip it rather than print an empty gap.');
      // D8: the suppressed row is named in the provenance comment, because the
      // coordinate range above it still counts the row.
      expect(html, contains('title-repeat suppressed'));
    });

    test('a preamble heading that differs is left alone', () {
      // The control. Without it the test above passes just as well against a
      // renderer that drops every preamble heading unconditionally.
      final html = _render(
        _chapterPage,
        slices: {'sp-grp-1': _bothLanguages('sp-grp-1')},
        preamble: _slice('sp-grp', [
          _row(
            pali: _entry('නමො තස්ස', type: 'heading', level: 5),
            sinhala: _entry('නමෝ තස්ස', type: 'heading', level: 5),
          ),
        ]),
      );

      expect(html, contains(weldTitle('නමො තස්ස')));
      expect(html, isNot(contains('title-repeat suppressed')));
    });

    test('row classes track the cells actually emitted', () {
      final html = _render(_suttaPage, slices: {
        'sp-toc-1': _slice('sp-toc-1', [
          _row(pali: _entry('දෙකම'), sinhala: _entry('දෙපැත්ත')),
          _row(pali: _entry('පාළි පමණයි'), at: 1),
          _row(sinhala: _entry('සිංහල පමණයි'), at: 2),
          // DocRow.isEmpty — the only shape dropped outright. One row in the
          // whole corpus looks like this.
          _row(pali: _entry(''), sinhala: _entry(''), at: 3),
        ]),
      });

      final contentRows = _rowClassesIn(html)
          .where((classes) => classes != 'col-heads')
          .toList();

      expect(contentRows, ['', 'no-si', 'no-pali'],
          reason: 'A row with one side missing must render with the class that '
              'lets a single-language layout skip it; only a both-sides-empty '
              'row is dropped.');
    });

    test('column captions are withheld when a language is wholly absent', () {
      // `FIGURES.readablePagesWithoutSinhala` readable pages — every one in
      // the ap-pat* files — carry no Sinhala at all. Under the baked
      // side-by-side default they widened to two columns and printed "සිංහල"
      // over blank space.
      final paliOnly = _render(_suttaPage, slices: {
        'sp-toc-1': _slice('sp-toc-1', [_row(pali: _entry('පාළි'))]),
      });
      expect(_classNamesIn(paliOnly), isNot(contains('col-heads')));

      // Symmetric even though no readable page in the corpus lacks Pali —
      // nothing guarantees that after a re-sync from upstream tipitaka.lk.
      final sinhalaOnly = _render(_suttaPage, slices: {
        'sp-toc-1': _slice('sp-toc-1', [_row(sinhala: _entry('සිංහල'))]),
      });
      expect(_classNamesIn(sinhalaOnly), isNot(contains('col-heads')));

      final both = _render(_suttaPage, slices: {'sp-toc-1': _bothLanguages()});
      expect(_classNamesIn(both), contains('col-heads'));
    });

    test('heading depths are contiguous from h2 and rank both languages', () {
      // Source `level` is a typographic *size*, not an outline depth. Mapping
      // it arithmetically gave every page an h1 → h4 → h6 outline with h2, h3
      // and h5 missing. Fixed twice already.
      final html = _render(_suttaPage, slices: {
        'sp-toc-1': _slice('sp-toc-1', [
          _row(
            pali: _entry('විශාල', type: 'heading', level: 5),
            sinhala: _entry('විශාල', type: 'heading', level: 5),
          ),
          _row(
            pali: _entry('මධ්‍යම', type: 'heading', level: 3),
            sinhala: _entry('මධ්‍යම', type: 'heading', level: 3),
            at: 1,
          ),
          // Sinhala-only. The load-bearing row: if _headingDepths scanned the
          // Pali side alone, level 1 would never enter the ranking, this
          // heading would fall through to the <h2> default, and the skipped
          // level would reopen.
          _row(sinhala: _entry('කුඩා', type: 'heading', level: 1), at: 2),
          _row(pali: _entry('පෙළ'), sinhala: _entry('පෙළ'), at: 3),
        ]),
      });

      // Largest source size first: 5 → h2, 3 → h3, 1 → h4. The l<n> class still
      // carries the source level, which is what the stylesheet sizes on.
      expect(html, contains('<h2 class="e-heading l5">'));
      expect(html, contains('<h3 class="e-heading l3">'));
      expect(html, contains('<h4 class="e-heading l1">'));

      final depths = RegExp(r'<h([1-6])[ >]')
          .allMatches(html)
          .map((match) => int.parse(match.group(1)!))
          .toSet();
      expect(depths, {1, 2, 3, 4},
          reason: 'The outline skips a level: $depths. A crawler reads that as '
              'nesting the page does not have.');
    });

    test('the Sinhala cell never carries a touching ZWJ', () {
      // D1 bakes the app's conjunct defaults into Pali. Sinhala translation
      // text must never go through the transform — it would bind consonants
      // that Sinhala orthography keeps apart.
      const text = 'ධම්මං';
      final html = _render(_suttaPage, slices: {
        'sp-toc-1': _slice('sp-toc-1', [
          _row(pali: _entry(text), sinhala: _entry(text)),
        ]),
      });

      // Touching is ZWJ *before* the hal. The ligature form (hal + ZWJ) is
      // ordinary Sinhala spelling — රකාරාංශය and යංශය, in
      // `FIGURES.namesWithLigatureZwj` of the tree's names — and must survive
      // untouched, so this is not a blanket ZWJ test.
      const touching = '‍්';

      // Asserted in both directions: without the first expectation the second
      // would pass against a build where the transform is off everywhere.
      expect(_cell(html, 'pali').contains(touching), isTrue,
          reason: 'The Pali cell is not welding at all, so the Sinhala check '
              'below proves nothing.');
      expect(_cell(html, 'si').contains(touching), isFalse,
          reason: 'The conjunct transform leaked into the translation.');
    });

    test('the toolbar is on every page; the radios only on readable ones', () {
      // Every page carries the bar: a page without one has no way home, and no
      // route to search once P4 lands. What stays gated is the *layout group*,
      // which is what frame 03 specifies and `site_chrome.dart` documents.
      final pages = {
        'sutta': _render(_suttaPage, slices: {'sp-toc-1': _bothLanguages()}),
        'chapter': _render(_chapterPage,
            slices: {'sp-grp-1': _bothLanguages('sp-grp-1')}),
        'toc': _render(_tocPage),
        'landing': LandingPage(
          roots: _tree.roots,
          generatorVersion: 'test',
          assets: _assets,
          urlFor: tipitakaUrl,
        ).render(),
      };

      pages.forEach((kind, html) {
        expect(_countOf(html, 'class="toolbar"'), 1,
            reason: 'The $kind page must carry exactly one toolbar — zero is a '
                'page with no way home, two is a duplicate id.');
      });

      // Readable pages get the four radios; a TOC and `/` have no reading
      // layout to choose, and the absence needs no CSS: with nothing checked,
      // no `#L-x:checked ~` rule matches and a .row keeps its single column.
      expect(_countOf(pages['sutta']!, 'class="layout-input"'),
          readingLayouts.length);
      expect(_countOf(pages['chapter']!, 'class="layout-input"'),
          readingLayouts.length);
      expect(_countOf(pages['toc']!, 'class="layout-input"'), 0);
      expect(_countOf(pages['landing']!, 'class="layout-input"'), 0);
    });
  });
}

// ── fixtures ─────────────────────────────────────────────────────────────────

/// Seven nodes — the smallest tree that produces all three page kinds.
///
/// Rows are `tree.json`'s wire format:
/// `[pali, sinhala, hierarchyLevel, [pageIndex, entryIndex], parent, fileId]`.
///
/// `sp-grp`'s name is deliberately one that *welds* (චිත්ත → චිත‍්ත), so the
/// repeated-title test exercises the welded comparison rather than passing on a
/// string the transform happens to leave alone.
final TipitakaTree _tree = TipitakaTree.fromJson({
  'sp': [
    'සුත්තපිටක',
    'සූත්‍ර පිටකය',
    7,
    [0, 0],
    'root',
    'an-1'
  ],
  // A container that stays exploded: its children get their own pages.
  'sp-toc': [
    'එකකනිපාතො',
    'එකක නිපාතය',
    6,
    [0, 1],
    'sp',
    'an-1'
  ],
  'sp-toc-1': [
    'පඨමසුත්තං',
    'පළමු සූත්‍රය',
    1,
    [0, 2],
    'sp-toc',
    'an-1'
  ],
  'sp-toc-2': [
    'දුතියසුත්තං',
    'දෙවන සූත්‍රය',
    1,
    [0, 5],
    'sp-toc',
    'an-1'
  ],
  // A container that groups: its children live inside one chapter file.
  'sp-grp': [
    'චිත්තපරියාදානවග්ගො',
    'චිත්ත වර්ගය',
    5,
    [0, 8],
    'sp',
    'an-1'
  ],
  'sp-grp-1': [
    'පඨමං',
    'පළමුවැන්න',
    1,
    [0, 9],
    'sp-grp',
    'an-1'
  ],
  'sp-grp-2': [
    'දුතියං',
    'දෙවැන්න',
    1,
    [0, 11],
    'sp-grp',
    'an-1'
  ],
});

ContentEntry _entry(String text, {String type = 'paragraph', int? level}) =>
    ContentEntry(type: type, text: text, level: level);

DocRow _row({ContentEntry? pali, ContentEntry? sinhala, int at = 0}) => DocRow(
      pageIndex: 0,
      pageNum: 1,
      entryIndex: at,
      pali: pali,
      sinhala: sinhala,
    );

NodeSlice _slice(String nodeKey, List<DocRow> rows) =>
    NodeSlice(nodeKey: nodeKey, rows: rows, startIndex: 0);

/// One row carrying both languages — the default shape most tests only need to
/// be non-empty.
NodeSlice _bothLanguages([String nodeKey = 'sp-toc-1']) => _slice(nodeKey, [
      _row(pali: _entry('ධම්මං'), sinhala: _entry('ධර්මය')),
    ]);

final PageTemplate _template = PageTemplate(
  tree: _tree,
  generatorVersion: 'test',
  assets: _assets,
  // These fixtures build `SitePage`s by hand, with no plan behind them and no
  // folded leaf in the tree, so the serving URL is the bare one.
  urlFor: tipitakaUrl,
);

/// Literal URLs, not `SiteAssets.forContent(...)`: these tests assert what
/// reaches the page, and hashing real bytes here would make every expected
/// string change whenever the stylesheet, the script or the corpus does.
const SiteAssets _assets = SiteAssets(
  stylesheet: '/assets/site.css?v=test',
  script: '/assets/site.js?v=test',
  searchIndex: '/assets/search-index.json?v=test',
  emblem: '/assets/emblem.png?v=test',
);

SitePage get _suttaPage => SitePage(
      kind: PageKind.sutta,
      node: _tree['sp-toc-1']!,
      suttas: [_tree['sp-toc-1']!],
    );

SitePage get _chapterPage => SitePage(
      kind: PageKind.chapter,
      node: _tree['sp-grp']!,
      suttas: [_tree['sp-grp-1']!, _tree['sp-grp-2']!],
    );

SitePage get _tocPage =>
    SitePage(kind: PageKind.toc, node: _tree['sp-toc']!, suttas: const []);

String _render(
  SitePage page, {
  Map<String, NodeSlice> slices = const {},
  NodeSlice? preamble,
}) =>
    _template.render(
      page,
      slices: slices,
      preamble: preamble,
      sourceFile: 'an-1',
    );

// ── helpers ──────────────────────────────────────────────────────────────────

ThemeTokens _readThemeTokens() {
  final file = File('assets/theme_tokens.json');
  if (!file.existsSync()) {
    fail('assets/theme_tokens.json not found. Run `dart test` from the '
        'static_site_generator/ package root — the path is relative to it.');
  }
  return ThemeTokens(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
}

/// Every individual class name the markup uses.
///
/// Split on whitespace rather than substring-matched: `contains('si')` is true
/// of `no-si`, and even `\bsi\b` matches inside it, so only exact membership
/// answers "did the template emit this class".
Set<String> _classNamesIn(String html) {
  final names = <String>{};
  for (final match in RegExp(r'class="([^"]*)"').allMatches(html)) {
    names.addAll(
        match.group(1)!.split(RegExp(r'\s+')).where((name) => name.isNotEmpty));
  }
  return names;
}

/// The selector of every CSS rule mentioning [marker] — the way a test names a
/// *mechanism* (`#L-` is the layout engine, `:target` the chapter filter)
/// rather than a line range or a hand-kept list of class names.
///
/// A selector is the text between one brace and the next `{`, which is exact
/// here because the only two things that can put a brace anywhere else are
/// accounted for: comments are stripped, and quoted strings are stepped over —
/// the sheet has them on both sides of the colon (`[for="L-pali"]` in a
/// selector, `content: '›'` in a value). Strings are left *in* the selector
/// rather than blanked, since an attribute selector's value is part of what a
/// caller matches on. Comma-separated selector lists arrive as one string,
/// spanning however many `writeln`s wrote them.
List<String> _rulesSelectingOn(String css, Pattern marker) {
  final clean = css.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  final selectors = <String>[];
  var start = 0;
  String? quote;
  for (var i = 0; i < clean.length; i++) {
    final char = clean[i];
    // The generated sheet never escapes a quote inside a string, so the next
    // matching delimiter always closes it.
    if (quote != null) {
      if (char == quote) quote = null;
      continue;
    }
    if (char == '"' || char == "'") {
      quote = char;
      continue;
    }
    if (char != '{' && char != '}') continue;
    if (char == '{') {
      final selector = clean.substring(start, i).trim();
      if (selector.contains(marker)) selectors.add(selector);
    }
    start = i + 1;
  }
  return selectors;
}

/// The class list of each `.row`, in document order, with the leading `row`
/// stripped — `['col-heads', '', 'no-si']`.
List<String> _rowClassesIn(String html) => RegExp(r'<div class="row([^"]*)"')
    .allMatches(html)
    .map((match) => match.group(1)!.trim())
    .toList();

/// The inner HTML of the first `.pali` or `.si` cell.
///
/// Non-greedy is safe here because a language cell's children are `<p>` and
/// `<h*>` elements — no nested `<div>` to close early.
String _cell(String html, String cssClass) {
  final match =
      RegExp('<div class="$cssClass" lang="[^"]*">(.*?)</div>', dotAll: true)
          .firstMatch(html);
  if (match == null) fail('No .$cssClass cell in the rendered page.');
  return match.group(1)!;
}

int _countOf(String haystack, String needle) =>
    needle.isEmpty ? 0 : haystack.split(needle).length - 1;

/// The page's text, without the chrome around it.
///
/// The toolbar carries a breadcrumb whose last segment is the current node, so
/// the node's name is on every page twice by design. Assertions about what the
/// *text* prints have to say so, or they answer a question about the bar.
///
/// Split on the prefix, not the whole tag: a container page opens
/// `<main class="content nav">`, and matching the full tag would hand back the
/// entire document instead of failing.
String _mainOf(String html) => html.split('<main class="content').last;
