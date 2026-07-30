import '../domain/theme_tokens.dart';
import 'web_fonts.dart';

/// Builds `assets/site.css` from the app's exported theme tokens.
///
/// Mirrors: lib/presentation/widgets/reader/reader_entry_builder.dart
/// That file decides how each entry type is laid out in the app — centred
/// headings, indented verse, justified prose. This is the same decision tree
/// expressed as CSS, and the *values* come from `theme_tokens.json` rather than
/// from anyone's memory of them.
///
/// ## Two things this file deliberately does not do
///
/// It does not apply `paragraphIndent`. The token exists — the app's
/// `TextEntryTheme` computes it — but **nothing in the app consumes it**, so
/// honouring it here would make the site the odd one out.
///
/// It emits no dark palette yet. The colours are custom properties on `:root`
/// precisely so a `prefers-color-scheme` block drops in later without touching
/// a single rule below.
String buildStylesheet(ThemeTokens tokens) {
  final css = StringBuffer();

  css.writeln(
      '/* GENERATED from static_site_generator/assets/theme_tokens.json');
  css.writeln('   Mirrors the app\'s TextEntryTheme. Do not hand-edit: run');
  css.writeln(
      '   `flutter test tools/dump_theme_tokens.dart`, then rebuild. */');
  css.writeln();

  _writeFontFaces(css, tokens);
  _writeRootVariables(css, tokens);
  _writePageChrome(css, tokens);
  _writeEntryStyles(css, tokens);
  _writeGroupedChapter(css);

  return css.toString();
}

/// Self-hosted WOFF2 (D7) — not polish, correctness.
///
/// Browsers ship no fonts of their own; they use the OS. Only Android carries
/// Noto Sans Sinhala, so on Windows, macOS, iOS and most Linux the page would
/// render in a *different face than the app* — and the baked conjuncts (D1) are
/// glyph-coverage-specific to Noto. Nirmala UI receiving our ZWJ is unverified
/// behaviour, so the font is shipped, not hoped for.
void _writeFontFaces(StringBuffer css, ThemeTokens tokens) {
  for (final face in webFontFaces(tokens)) {
    css.writeln('@font-face {');
    css.writeln('  font-family: "${face.family}";');
    css.writeln('  src: url("../fonts/${face.relativePath}") format("woff2");');
    css.writeln('  font-weight: ${face.weight};');
    css.writeln('  font-style: normal;');
    // Text first, webfont when it lands. A blank page is worse than a
    // moment of the fallback face on a slow connection — which is the
    // connection this whole surface exists for.
    css.writeln('  font-display: swap;');
    css.writeln('}');
  }
  css.writeln();
}

void _writeRootVariables(StringBuffer css, ThemeTokens tokens) {
  css.writeln(':root {');
  for (final color in tokens.lightColors.entries) {
    css.writeln('  --c-${_kebab(color.key)}: ${color.value};');
  }
  css.writeln('  --font-reader: "${tokens.readerFont}", '
      '${_fallbackStack(tokens.readerFallback)};');
  css.writeln('  --font-ui: "${tokens.uiFont}", '
      '${_fallbackStack(tokens.uiFallback)};');
  // `paragraphIndentEm` is in the token file and not read here — it has no
  // consumer in the app either (see above).
  css.writeln('  --entry-gap: ${_px(tokens.spacing('entryGapPx'))};');
  css.writeln('  --page-gap: ${_px(tokens.spacing('pageGapPx'))};');
  css.writeln('  --gatha-indent: ${_num(tokens.spacing('gathaIndentEm'))}em;');
  css.writeln(
      '  --gatha-indent-2: ${_num(tokens.spacing('gathaLevel2IndentEm'))}em;');
  css.writeln('}');
  css.writeln();
}

/// The fallback half of a `font-family` stack, minus families no browser can
/// resolve — see [appOnlyFallbackFamilies].
String _fallbackStack(List<String> fallback) => fallback
    .where((family) => !appOnlyFallbackFamilies.contains(family))
    .map(_quoteFamily)
    .join(', ');

void _writePageChrome(StringBuffer css, ThemeTokens tokens) {
  // The app renders web at 0.9 scale (AppFonts.webDefaultScale); matching it on
  // the root keeps every em below identical to the app's web build, while a
  // reader who has raised their browser font size still gets it.
  css.writeln('html {');
  css.writeln('  font-size: ${_num(tokens.webDefaultScale * 100)}%;');
  css.writeln('  -webkit-text-size-adjust: 100%;');
  css.writeln('}');
  css.writeln();
  css.writeln('body {');
  css.writeln('  margin: 0;');
  css.writeln('  background: var(--c-background);');
  css.writeln('  color: var(--c-on-surface);');
  css.writeln('  font-family: var(--font-ui);');
  css.writeln('}');
  css.writeln();
  css.writeln('.content {');
  css.writeln('  max-width: 44rem;');
  css.writeln('  margin: 0 auto;');
  css.writeln('  padding: 1.5rem 1.25rem 4rem;');
  css.writeln('}');
  css.writeln();
  css.writeln('.breadcrumb {');
  css.writeln('  font-family: var(--font-ui);');
  css.writeln('  font-size: 0.85em;');
  css.writeln('  color: var(--c-on-surface-variant);');
  css.writeln('  margin-bottom: 1.5rem;');
  css.writeln('  line-height: 1.6;');
  css.writeln('}');
  css.writeln('.breadcrumb a { color: inherit; text-decoration: none; }');
  css.writeln('.breadcrumb a:hover { text-decoration: underline; }');
  css.writeln('.breadcrumb .sep { opacity: 0.5; margin: 0 0.4em; }');
  css.writeln();
  css.writeln('.page-title {');
  css.writeln('  font-family: var(--font-reader);');
  css.writeln('  color: var(--c-heading);');
  css.writeln('  text-align: center;');
  css.writeln('  font-size: 1.6em;');
  css.writeln('  line-height: 1.3;');
  css.writeln('  margin: 0 0 2rem;');
  css.writeln('}');
  css.writeln();
  // Prev/next sit in the flow, not fixed — nothing should cover the text on a
  // small screen, and a static page has no scroll listener to hide them.
  css.writeln('.pager {');
  css.writeln('  display: grid;');
  css.writeln('  grid-template-columns: 1fr 1fr;');
  css.writeln('  gap: 0.75rem;');
  css.writeln('  margin-top: var(--page-gap);');
  css.writeln('}');
  css.writeln('.pager a {');
  css.writeln('  display: block;');
  css.writeln('  padding: 0.75rem 1rem;');
  css.writeln('  border: 1px solid var(--c-outline);');
  css.writeln('  border-radius: 0.5rem;');
  css.writeln('  background: var(--c-surface-container-lowest);');
  css.writeln('  color: inherit;');
  css.writeln('  text-decoration: none;');
  css.writeln('  font-family: var(--font-ui);');
  css.writeln('  font-size: 0.9em;');
  css.writeln('  line-height: 1.4;');
  css.writeln('}');
  css.writeln('.pager a:hover { background: var(--c-surface-container-low); }');
  css.writeln('.pager .next { text-align: right; }');
  css.writeln('.pager .label { display: block; '
      'color: var(--c-on-surface-variant); font-size: 0.85em; }');
  // `.spacer` needs no rule of its own — it is an empty grid item holding the
  // first or last column open when a page has no prev/next.
  css.writeln();
  css.writeln('.commentary-link {');
  css.writeln('  font-family: var(--font-ui);');
  css.writeln('  font-size: 0.9em;');
  css.writeln('  text-align: center;');
  css.writeln('  margin-bottom: 1.5rem;');
  css.writeln('}');
  css.writeln('.commentary-link a { color: var(--c-primary); }');
  css.writeln();
  css.writeln('.toc { list-style: none; padding: 0; margin: 0; }');
  css.writeln('.toc li { margin: 0 0 0.5rem; }');
  css.writeln('.toc a {');
  css.writeln('  display: block;');
  css.writeln('  padding: 0.6rem 0.9rem;');
  css.writeln('  border-radius: 0.4rem;');
  css.writeln('  background: var(--c-surface-container-lowest);');
  css.writeln('  border: 1px solid var(--c-outline-variant);');
  css.writeln('  color: inherit;');
  css.writeln('  text-decoration: none;');
  css.writeln('  font-family: var(--font-reader);');
  css.writeln('}');
  css.writeln('.toc a:hover { background: var(--c-surface-container-low); }');
  css.writeln();
  // The Pali column. P2 adds a `.si` sibling inside `.row`; the grid is already
  // here so that lands as a column count, not a restructure.
  css.writeln(
      '.row { display: grid; gap: 1rem; margin-bottom: var(--entry-gap); }');
  css.writeln();
}

/// One rule per entry type, in the order `reader_entry_builder.dart` switches
/// on them, so the two can be read side by side.
void _writeEntryStyles(StringBuffer css, ThemeTokens tokens) {
  void writeStyle(String selector, EntryStyle style, {String? extra}) {
    css.writeln('$selector {');
    // Every entry style in the token file names the reader family, so the
    // variable says the same thing and keeps the fallback stack with it.
    css.writeln('  font-family: var(--font-reader);');
    css.writeln('  font-size: ${_num(style.fontSizeEm)}em;');
    css.writeln('  font-weight: ${style.fontWeight};');
    if (style.fontStyle != 'normal') {
      // NotoSerifSinhala ships no italic face, so this is a synthesised
      // oblique in the browser. Left faithful to the token rather than
      // suppressed with `font-synthesis: none`, because the app requests the
      // same italic from the same family — whatever it does, the site matches
      // the token it was given. Revisit if the app turns out to render upright.
      css.writeln('  font-style: ${style.fontStyle};');
    }
    css.writeln('  line-height: ${_num(style.lineHeight)};');
    css.writeln('  color: var(--c-${_kebab(style.colorRole)});');
    if (extra != null) css.write(extra);
    css.writeln('  margin: 0;');
    css.writeln('}');
  }

  writeStyle(
    '.e-paragraph',
    tokens.entryStyle('paragraph'),
    extra: '  text-align: justify;\n',
  );
  writeStyle(
    '.e-unindented',
    tokens.entryStyle('unindented'),
    extra: '  text-align: justify;\n',
  );
  writeStyle(
    '.e-gatha',
    tokens.entryStyle('gatha'),
    extra: '  text-align: left;\n'
        '  padding-left: var(--gatha-indent);\n'
        // `gatha` is the one type whose source text carries newlines — the app
        // gets line breaks free from Flutter's Text; CSS needs telling.
        '  white-space: pre-line;\n',
  );
  css.writeln('.e-gatha.l2 { padding-left: var(--gatha-indent-2); }');
  css.writeln();

  for (var level = 1; level <= 5; level++) {
    writeStyle(
      '.e-heading.l$level',
      tokens.levelledEntryStyle('heading', level),
      extra: '  text-align: center;\n',
    );
  }
  css.writeln();
  for (var level = 1; level <= 5; level++) {
    writeStyle(
      '.e-centered.l$level',
      tokens.levelledEntryStyle('centered', level),
      extra: '  text-align: center;\n',
    );
  }
  css.writeln();
  // `strong` only. There is deliberately no `u` rule: `__underline__` markers
  // render as plain text here because that is what the app does — its
  // `markedRanges` carry `FontWeight.bold` and nothing else. Styling underline
  // on this surface alone would make the two disagree, and the decision (build
  // plan, `__underline__`, 2026-07-30) is to revisit it on both at once.
  css.writeln('strong { font-weight: 700; }');
  css.writeln();
}

/// The zero-JS single-sutta view on a grouped chapter page.
void _writeGroupedChapter(StringBuffer css) {
  css.writeln('/* Grouped chapter: no #fragment shows the whole run;');
  css.writeln('   #<nodeKey> filters to that one sutta. */');
  // Written as `:not(:target):not(:has(:target))` from the start, not the
  // shorter `.chapter:has(.sutta:target) .sutta:not(:target)`. When P7 adds
  // footnotes, targeting a footnote *inside* a sutta makes the short form stop
  // matching and every hidden sutta reappears. This form keeps a sutta visible
  // whenever the target is anywhere within it.
  css.writeln(
      '.chapter:has(.sutta:target) .sutta:not(:target):not(:has(:target)) {');
  css.writeln('  display: none;');
  css.writeln('}');
  css.writeln();
  css.writeln('.sutta { margin-bottom: var(--page-gap); }');
  css.writeln('.sutta:target { scroll-margin-top: 1rem; }');
  css.writeln();
  // Only meaningful in the filtered view, so it is hidden until a sutta is
  // targeted — no JS, same :has() test as the filter itself.
  css.writeln('.chapter-bar { display: none; }');
  css.writeln('.chapter:has(.sutta:target) .chapter-bar {');
  css.writeln('  display: block;');
  css.writeln('  font-family: var(--font-ui);');
  css.writeln('  font-size: 0.9em;');
  css.writeln('  margin-bottom: 1.5rem;');
  css.writeln('  padding: 0.6rem 0.9rem;');
  css.writeln('  border-radius: 0.4rem;');
  css.writeln('  background: var(--c-surface-container-low);');
  css.writeln('}');
  css.writeln('.chapter-bar a { color: var(--c-primary); }');
}

String _kebab(String camel) => camel.replaceAllMapped(
      RegExp('[A-Z]'),
      (match) => '-${match[0]!.toLowerCase()}',
    );

/// Quotes a font family name only when CSS requires it.
String _quoteFamily(String family) =>
    family.contains(' ') ? '"$family"' : family;

/// `12.0` → `12px`, `12.5` → `12.5px`.
String _px(double value) => '${_num(value)}px';

/// Drops a trailing `.0` so the CSS reads like CSS, and keeps the output
/// byte-stable across builds (§11.8).
String _num(double value) {
  final asInt = value.round();
  return (value - asInt).abs() < 1e-9 ? '$asInt' : '$value';
}
