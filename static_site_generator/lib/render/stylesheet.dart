import '../domain/theme_tokens.dart';
import 'reading_layouts.dart';
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
  _writeLayouts(css, tokens);
  _writeHomeLink(css);
  _writeLandingPage(css);
  _writeGroupedChapter(css);

  return css.toString();
}

/// Below this width, two columns of text stop being readable and side-by-side
/// folds to one — see [_writeLayouts].
///
/// ⚠️ **This is 768px, not 691px.** Inside a media query `rem` resolves against
/// the *initial* root font size (16px) and ignores `html { font-size: 90% }`,
/// which is the rule the rest of the sheet is measured in. So the same `48rem`
/// written here and in an ordinary rule names two different widths. Verified in
/// Chrome: two columns at 800px, one at 720px. Kept in `rem` anyway — it still
/// scales with a reader's own browser font-size setting, which px would not.
const String _twoColumnMinWidth = '48rem';

/// The reading column. Shared by `.content` and the toolbar's inner wrapper so
/// the two stay aligned; a bar whose control drifts away from the text it acts
/// on reads as belonging to something else.
const String _readingColumnWidth = '44rem';

/// Height of the sticky reader toolbar.
///
/// Emitted as `--toolbar-height` and consumed by two rules that must never
/// disagree: the bar's own height, and the `scroll-padding-top` that keeps an
/// anchor from landing behind it.
const String _toolbarHeight = '56px';

/// The reading column when side-by-side splits it in two.
///
/// [_readingColumnWidth] is a measure for *one* column of text; halving it
/// would give each language about 21rem, which is too narrow for the corpus's
/// long compounds. Widening only under side-by-side keeps single-column
/// reading at its proper measure instead of stretching every layout to suit
/// the one that needs the room.
const String _wideColumnWidth = '64rem';

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
  // The stacked layout's two-part rhythm, from the same constants
  // `stacked_pane.dart` lays out with.
  css.writeln('  --pair-gap: ${_px(tokens.spacing('stackedPairGapPx'))};');
  css.writeln(
      '  --pair-bottom-gap: ${_px(tokens.spacing('stackedPairBottomGapPx'))};');
  css.writeln('  --toolbar-height: $_toolbarHeight;');
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
  // Every `#fragment` landing clears the sticky toolbar, plus a line of air.
  // On the scroll container rather than on the targets, so it covers anchors
  // that do not exist yet — P7's footnote references above all, which are the
  // ones a reader will actually jump to. `#<nodeKey>` is the locked deep-link
  // form (grouped-leaf URLs resolve to exactly that), so this is load-bearing
  // as soon as anything links in.
  css.writeln('  scroll-padding-top: calc(var(--toolbar-height) + 1rem);');
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
  css.writeln('  max-width: $_readingColumnWidth;');
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
  // One row, both languages. The base state is a single column carrying the
  // stacked rhythm — a translation sits `--pair-gap` under the line it
  // translates, and the next pair starts `--pair-bottom-gap` below. Which is
  // also, deliberately, what a page with no layout radios at all renders as.
  //
  // `column-gap` is declared here but only ever has an effect once
  // side-by-side gives the grid a second column.
  css.writeln('.row {');
  css.writeln('  display: grid;');
  css.writeln('  row-gap: var(--pair-gap);');
  css.writeln('  column-gap: 1.75rem;');
  css.writeln('  margin-bottom: var(--pair-bottom-gap);');
  css.writeln('}');
  css.writeln();
}

/// One rule per entry type, in the order `reader_entry_builder.dart` switches
/// on them, so the two can be read side by side.
void _writeEntryStyles(StringBuffer css, ThemeTokens tokens) {
  /// [bodyType] marks the three types a *pane* is allowed to re-weight —
  /// paragraph, unindented and gatha. Their weight is emitted as
  /// `var(--body-weight, N)` so the stacked layout can lift the Pali side
  /// without a second copy of every rule; `N` is the theme's own value, so a
  /// page that never sets the variable is byte-for-byte what P1 shipped.
  /// Headings and centered entries keep a literal weight, exactly as
  /// `ReaderEntryBuilder.buildEntry` refuses to override them.
  void writeStyle(String selector, EntryStyle style,
      {String? extra, bool bodyType = false}) {
    css.writeln('$selector {');
    // Every entry style in the token file names the reader family, so the
    // variable says the same thing and keeps the fallback stack with it.
    css.writeln('  font-family: var(--font-reader);');
    css.writeln('  font-size: ${_num(style.fontSizeEm)}em;');
    css.writeln(bodyType
        ? '  font-weight: var(--body-weight, ${style.fontWeight});'
        : '  font-weight: ${style.fontWeight};');
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
    bodyType: true,
  );
  writeStyle(
    '.e-unindented',
    tokens.entryStyle('unindented'),
    extra: '  text-align: justify;\n',
    bodyType: true,
  );
  writeStyle(
    '.e-gatha',
    tokens.entryStyle('gatha'),
    extra: '  text-align: left;\n'
        '  padding-left: var(--gatha-indent);\n'
        // `gatha` is the one type whose source text carries newlines — the app
        // gets line breaks free from Flutter's Text; CSS needs telling.
        '  white-space: pre-line;\n',
    bodyType: true,
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

/// The four reading layouts, and the segmented control that picks one.
///
/// Mirrors: lib/presentation/widgets/reader/multi_pane_reader_widget.dart
/// and its panes. Four radios, four rules, **no JavaScript** (C5) — both
/// languages are always in the DOM, so hiding one is a display choice and
/// never an indexing one (Google indexes hidden tab content; the Sinhala side
/// stays findable on a Pali-default page).
///
/// The selectors reach `.content` as a *sibling* of the radios, not `.sutta`.
/// The plan's §7 sketch used `~ .sutta .si`, which silently matches nothing on
/// a grouped chapter page, where `.sutta` is nested inside `.chapter`.
void _writeLayouts(StringBuffer css, ThemeTokens tokens) {
  css.writeln('/* Reading layout — pure CSS, four radios. */');
  // Visually hidden, NOT `display: none`: a hidden-that-way radio leaves the
  // tab order, and the control becomes unusable from a keyboard. (The one
  // place `display: none` *is* correct is a control that has no rendering at
  // the current width — see the side-by-side radio below.)
  //
  // `position: absolute` also keeps the radios out of flow, which is what lets
  // `body` take a layout of its own without them becoming boxes in it.
  css.writeln('.layout-input {');
  css.writeln('  position: absolute;');
  css.writeln('  width: 1px;');
  css.writeln('  height: 1px;');
  css.writeln('  margin: -1px;');
  css.writeln('  padding: 0;');
  css.writeln('  border: 0;');
  css.writeln('  overflow: hidden;');
  css.writeln('  clip-path: inset(50%);');
  css.writeln('  white-space: nowrap;');
  css.writeln('}');
  css.writeln();
  css.writeln('.toolbar {');
  css.writeln('  position: sticky;');
  css.writeln('  top: 0;');
  css.writeln('  z-index: 2;');
  css.writeln('  height: var(--toolbar-height);');
  css.writeln('  background: var(--c-surface-container-high);');
  css.writeln('  border-bottom: 1px solid var(--c-outline);');
  css.writeln('}');
  // Same width and padding as `.content`, so the control sits over the right
  // edge of the text column instead of the window's.
  css.writeln('.toolbar-inner {');
  css.writeln('  display: flex;');
  css.writeln('  justify-content: flex-end;');
  css.writeln('  align-items: center;');
  css.writeln('  gap: 0.75rem;');
  css.writeln('  height: 100%;');
  css.writeln('  max-width: $_readingColumnWidth;');
  css.writeln('  margin: 0 auto;');
  css.writeln('  padding: 0 1.25rem;');
  css.writeln('}');
  css.writeln();
  css.writeln('.layouts {');
  css.writeln('  display: inline-flex;');
  css.writeln('  border: 1px solid var(--c-outline);');
  css.writeln('  border-radius: 8px;');
  css.writeln('  overflow: hidden;');
  css.writeln('  background: var(--c-background);');
  css.writeln('}');
  css.writeln('.layouts label {');
  css.writeln('  display: flex;');
  css.writeln('  align-items: center;');
  css.writeln('  justify-content: center;');
  css.writeln('  width: 40px;');
  css.writeln('  height: 34px;');
  css.writeln('  font-family: var(--font-ui);');
  css.writeln('  font-size: 0.875em;');
  css.writeln('  font-weight: 600;');
  css.writeln('  color: var(--c-on-surface-variant);');
  css.writeln('  cursor: pointer;');
  css.writeln('}');
  css.writeln('.layouts label + label '
      '{ border-left: 1px solid var(--c-outline); }');
  css.writeln('.layout-icon { width: 18px; height: 18px; }');
  css.writeln();

  // Which button is lit. Every layout lights its own button — except the
  // default, which below the breakpoint does not render as itself.
  //
  // Side-by-side folds to a single column there, i.e. to stacked, and it is
  // also the layout baked `checked`. Left alone, a phone opened the site with
  // the side-by-side button lit over a stacked page, two of the four buttons
  // rendering identically, and a tap on "stacked" changing nothing but which
  // button glowed. So on a narrow screen side-by-side is not offered at all
  // and the stacked button lights for both; above the breakpoint the media
  // query below hands the highlight back.
  final selfLit = [
    for (final layout in readingLayouts)
      if (layout.id != defaultLayoutId)
        '#${layout.id}:checked ~ .toolbar label[for="${layout.id}"]',
    '#$defaultLayoutId:checked ~ .toolbar label[for="$narrowFallbackLayoutId"]',
  ];
  css.writeln('${selfLit.join(',\n')} {');
  css.writeln('  background: var(--c-primary-container);');
  css.writeln('  color: var(--c-on-primary-container);');
  css.writeln('}');
  // The radio goes with its button, not just the button.
  //
  // `.layout-input` hides the radios the accessible way — off-screen but still
  // focusable — which is what lets the group be arrowed through at all. Hiding
  // only the *label* therefore left a radio with no button: arrowing onto it
  // selected side-by-side, moved the highlight to stacked (right), and painted
  // the focus ring onto a `display: none` label, so focus disappeared for one
  // keypress. `display: none` takes it out of the tab order and the arrow
  // cycle instead.
  //
  // Safe for the layout engine: `:checked` reads DOM state and `~` walks DOM
  // structure, so both keep matching a `display: none` input. The baked default
  // stays checked and still drives the single-column rendering below the
  // breakpoint — it just cannot be focused while it has nothing to point at.
  //
  // Written as base-state-plus-override rather than a `max-width` query on
  // purpose: a second breakpoint would have to be spelled `47.99rem`, giving
  // the sheet two expressions of one number and a seam between them — a bad
  // trade anywhere, and a worse one here, where `48rem` already means two
  // different pixel widths (see [_twoColumnMinWidth]).
  css.writeln('#$defaultLayoutId { display: none; }');
  css.writeln('.layouts label[for="$defaultLayoutId"] { display: none; }');
  css.writeln();

  // `:focus-visible` on the hidden input paints the label, which is the only
  // thing on screen — without it a keyboard reader tabbing through the group
  // has no idea where they are.
  for (final layout in readingLayouts) {
    css.writeln('#${layout.id}:focus-visible ~ .toolbar '
        'label[for="${layout.id}"] '
        '{ outline: 2px solid var(--c-primary); outline-offset: -2px; }');
  }
  css.writeln();

  // Single-language layouts. Hiding the cell is not enough: a row that has
  // *only* the other language would otherwise survive as an empty grid item
  // and print a gap where nothing is. `.no-pali` / `.no-si` say which rows
  // those are, decided at build time rather than with a `:has()` test.
  css.writeln('#$paliOnlyLayoutId:checked ~ .content .si { display: none; }');
  css.writeln(
      '#$paliOnlyLayoutId:checked ~ .content .row.no-pali { display: none; }');
  css.writeln(
      '#$sinhalaOnlyLayoutId:checked ~ .content .pali { display: none; }');
  css.writeln(
      '#$sinhalaOnlyLayoutId:checked ~ .content .row.no-si { display: none; }');
  // Nothing is paired when one language is showing, so rows fall back to the
  // app's plain single-column entry gap.
  css.writeln('#$paliOnlyLayoutId:checked ~ .content .row,');
  css.writeln('#$sinhalaOnlyLayoutId:checked ~ .content .row '
      '{ margin-bottom: var(--entry-gap); }');
  css.writeln();

  // Stacked is the base `.row` state; stated anyway so the declaration exists
  // to read, and so a future change to the base cannot silently redefine what
  // "stacked" means.
  css.writeln('#$stackedLayoutId:checked ~ .content .row '
      '{ grid-template-columns: 1fr; }');
  css.writeln();

  // Side by side, but only where two columns of text still read. Below the
  // breakpoint it falls back to the base single column — which is the stacked
  // layout, and so matches the app, whose seed in portrait is stacked and in
  // landscape side-by-side (`resolveSeedLayout`).
  // `.row.col-heads`, not `.col-heads`: the base `.row { display: grid }` has
  // the same specificity, so a bare class would be beating it on source order
  // alone — and reordering the writers in `buildStylesheet` would then reveal
  // the captions in every layout, with nothing to say why.
  css.writeln('.row.col-heads { display: none; }');
  css.writeln('@media (min-width: $_twoColumnMinWidth) {');
  // Side-by-side is a real choice again at this width: put its radio back in
  // the keyboard cycle, offer the button, light it, and stop lighting stacked
  // on its behalf. `block`, because that is what `display` computes to for the
  // absolutely positioned box `.layout-input` makes of it either way.
  css.writeln('  #$defaultLayoutId { display: block; }');
  css.writeln('  .layouts label[for="$defaultLayoutId"] { display: flex; }');
  css.writeln('  #$defaultLayoutId:checked ~ .toolbar '
      'label[for="$narrowFallbackLayoutId"] '
      '{ background: none; color: var(--c-on-surface-variant); }');
  css.writeln('  #$defaultLayoutId:checked ~ .toolbar '
      'label[for="$defaultLayoutId"] '
      '{ background: var(--c-primary-container); '
      'color: var(--c-on-primary-container); }');
  // The column widens with the layout, and the toolbar with it, or the control
  // would no longer sit over the text it governs.
  css.writeln('  #$sideBySideLayoutId:checked ~ .content,');
  css.writeln('  #$sideBySideLayoutId:checked ~ .toolbar .toolbar-inner '
      '{ max-width: $_wideColumnWidth; }');
  css.writeln('  #$sideBySideLayoutId:checked ~ .content .row {');
  css.writeln('    grid-template-columns: 1fr 1fr;');
  // Top-align: 18.9% of paired entries are a Pali gatha against a Sinhala
  // paragraph, so the two cells of a row are routinely different heights and
  // any other alignment would drift the two languages apart down the page.
  css.writeln('    align-items: start;');
  css.writeln('    margin-bottom: var(--entry-gap);');
  css.writeln('  }');
  // Explicit columns so a row missing one language still puts the language it
  // has under the right heading, instead of sliding into column 1.
  css.writeln(
      '  #$sideBySideLayoutId:checked ~ .content .pali { grid-column: 1; }');
  css.writeln(
      '  #$sideBySideLayoutId:checked ~ .content .si { grid-column: 2; }');
  css.writeln(
      '  #$sideBySideLayoutId:checked ~ .content .row.col-heads { display: grid; }');
  css.writeln('}');
  css.writeln('.col-heads div {');
  css.writeln('  font-family: var(--font-ui);');
  css.writeln('  font-size: 0.7em;');
  css.writeln('  font-weight: 600;');
  css.writeln('  letter-spacing: 0.1em;');
  css.writeln('  color: var(--c-on-surface-variant);');
  css.writeln('  padding-bottom: 0.4rem;');
  css.writeln('  border-bottom: 1px solid var(--c-outline-variant);');
  css.writeln('}');
  css.writeln();

  // Pali runs heavier wherever both languages share one column, which is what
  // `stacked_pane.dart` does with `AppFonts.paliWeight` — "two weight steps
  // heavier than body so Pali stays visually distinct from its translation".
  // It matters more on this corpus than the phrase suggests: the Pali is set
  // in Sinhala script, so weight is the only thing telling a stacked pair
  // apart. Body types only — `buildEntry` leaves headings and centered
  // entries at their theme weight, and so does this.
  //
  // Set on the cell as a custom property; the entry rules read it through
  // `var(--body-weight, …)`. One declaration instead of one per entry type.
  final paliWeight = tokens.paneWeight('paliStacked');
  final bodyWeight = tokens.paneWeight('body');
  css.writeln('/* Pali heavier than its translation wherever they share a '
      'column. */');
  css.writeln('.pali { --body-weight: $paliWeight; }');
  // ...except when only one language is on the page, where there is nothing to
  // distinguish it from and the bump would just be heavy type.
  css.writeln('#$paliOnlyLayoutId:checked ~ .content .pali,');
  css.writeln('#$sinhalaOnlyLayoutId:checked ~ .content .pali '
      '{ --body-weight: $bodyWeight; }');
  css.writeln('@media (min-width: $_twoColumnMinWidth) {');
  css.writeln('  #$sideBySideLayoutId:checked ~ .content .pali '
      '{ --body-weight: $bodyWeight; }');
  css.writeln('}');
  css.writeln();
}

/// The toolbar's home link — the emblem at the left of the bar.
///
/// `margin-right: auto` is what puts it there and keeps the layout group at the
/// other end: `.toolbar-inner` is `justify-content: flex-end`, so the auto
/// margin absorbs all the free space between the two. The same trick P3's
/// hamburger used, on the one control that outlived it.
void _writeHomeLink(StringBuffer css) {
  css.writeln('/* Toolbar home link. */');
  css.writeln('.home {');
  css.writeln('  display: flex;');
  css.writeln('  align-items: center;');
  css.writeln('  margin-right: auto;');
  css.writeln('  border-radius: 8px;');
  css.writeln('}');
  // A focus ring the anchor can actually show — unlike the layout labels, this
  // is a real link, so `:focus-visible` lands on the element itself.
  css.writeln('.home:focus-visible '
      '{ outline: 2px solid var(--c-primary); outline-offset: 2px; }');
  css.writeln('.home img { display: block; width: 28px; height: 28px; }');
  css.writeln();
}

/// The landing page (`/`).
///
/// Almost nothing, and that is the point: `/` is a container TOC like any other
/// (see `landing_page.dart`), so it inherits `.content`, `.page-title` and
/// `.toc` and needs a rule only for the one element the rest of the site has no
/// use for — the hint under the heading.
void _writeLandingPage(StringBuffer css) {
  css.writeln('/* Landing page. */');
  // Sits between the site title and the list it is an instruction for. Centred
  // to match `.page-title` directly above it — that rule is `text-align: center`
  // on every page, and a left-aligned line under it would read as a mistake.
  //
  // The negative top margin *collapses* against the title's 2rem bottom rather
  // than adding to it: adjacent siblings collapse to
  // `max(positive) + min(negative)`, so 2rem and -1rem leave a 1rem gap. The
  // pair belongs together more closely than the title belongs to body text.
  css.writeln('.landing-hint {');
  css.writeln('  font-family: var(--font-ui);');
  css.writeln('  color: var(--c-on-surface-variant);');
  css.writeln('  text-align: center;');
  css.writeln('  margin: -1rem 0 2rem;');
  css.writeln('  line-height: 1.6;');
  css.writeln('}');
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
  // No `scroll-margin-top` here. P1 gave `.sutta:target` 1rem back when the
  // page had no fixed chrome; the sticky toolbar made that 14.4px against a
  // 56px bar, landing every targeted sutta ~42px behind it. `html`'s
  // `scroll-padding-top` now covers the bar and the breathing room together,
  // for every anchor rather than this one — keeping a per-target margin as
  // well would only stack a second offset on top of it.
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
