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
///
/// [fontVersion] is the cache token for the WOFF2 faces — see
/// [_writeFontFaces]. It is the one input here that is not a theme value,
/// because the stylesheet is the only file that names a font.
String buildStylesheet(ThemeTokens tokens, {required String fontVersion}) {
  final css = StringBuffer();

  css.writeln(
      '/* GENERATED from static_site_generator/assets/theme_tokens.json');
  css.writeln('   Mirrors the app\'s TextEntryTheme. Do not hand-edit: run');
  css.writeln(
      '   `flutter test tools/dump_theme_tokens.dart`, then rebuild. */');
  css.writeln();

  _writeFontFaces(css, tokens, fontVersion);
  _writeRootVariables(css, tokens);
  _writePageChrome(css, tokens);
  _writeEntryStyles(css, tokens);
  _writeLayouts(css, tokens);
  _writeToolbarNav(css);
  _writeSearch(css);
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

/// The reading column in `rem` — `.content`. Every layout below
/// [_twoColumnMinWidth], and every layout but side-by-side above it.
/// `.content`'s number alone: the toolbar is sized by the window and takes
/// nothing from here.
///
/// ## What sets it
///
/// Words per line, and Pali governs: shaped over the corpus a Pali word runs
/// ~4.3em of glyphs against English prose's ~2em. The app's
/// `PaneWidthConstants.readingColumnMeasureEm` — 54.5em today — carries 11 Pali
/// words a line; the old 44rem carried 8. It is the same number on all three
/// surfaces, which is what makes them read the same line at three different
/// pixel sizes: this sheet and Flutter web at 15.84px
/// (`AppFonts.webDefaultScale` takes 16 to 14.4 on both), the native app at
/// 17.6px — a wider column with the same words in it.
///
/// ## Nothing here is written down
///
/// Both halves arrive as generated tokens, so a change on the app side reaches
/// this sheet without anyone remembering to bring it. The measure is stated
/// against the *paragraph* and `rem` against the *root*, and the paragraph's own
/// `fontSizeEm` is the only thing that converts one to the other — today 1.1, so
/// 54.5em is 59.95rem, 863.28px. Baking either number in would leave the site
/// reading a different line than the app the moment the other moved, with
/// nothing failing to say so.
double _readingColumnRem(ThemeTokens tokens) =>
    tokens.spacing('readingColumnMeasureEm') *
    tokens.entryStyle('paragraph').fontSizeEm;

/// The trail's three collapse steps: keep the 3 nearest ancestors, then 1, then
/// none. Widest first, because each one drops what the one above it kept.
///
/// ⚠️ **Same `rem` trap as [_twoColumnMinWidth].** Inside a media query `rem` is
/// the initial 16px and ignores `html { font-size: 90% }`, so these are 816px,
/// 624px and 528px.
///
/// Derived, not chosen. Beside the trail the bar pins width it never gives
/// back, and how much depends on which side of 48rem you are on: 305px above
/// it (`padding` 36 + three `gap`s 32 + the up button 36 + the search button 36
/// + the four layout buttons 165), and 264px below, where the side-by-side
/// button is `display: none` and three buttons measure 124. The first step is
/// set against 305, the other two against 264. Measured across every built page
/// at the real 12.24px: a leaf name is 126px at the median and 162px at
/// p75, and a page carries 5 ancestors at the median, 6 at most. An ancestor
/// squeezed under about 45px is three Sinhala clusters and an ellipsis —
/// present, unreadable, and standing where the page's own name should be. Each
/// step is where the ancestors still showing stop clearing that floor. Below
/// the last one the emblem and the leaf are the whole of what fits, and the up
/// button is what replaces the parent link that went with them.
///
/// ## P4 moved all three, by exactly one control's width
///
/// The search button added a 36px control and the `gap` before it: **+46.8px**
/// of pinned chrome at every width. Nothing on the trail's side changed — same
/// names, same 45px floor, same 126px leaf — so these are the P3 steps plus
/// that delta, rounded up to the next whole rem: 768 → 814.8 → **51rem**,
/// 576 → 622.8 → **39rem**, 480 → 526.8 → **33rem**. Re-deriving from the
/// corpus instead would have re-litigated judgment already settled — 480px was
/// itself rounded up from a computed 445 to a conventional breakpoint — where
/// adding the delta pays only for the thing that changed.
///
/// Rounded **up** each time, so a step fires just before the floor is breached
/// rather than just after. P3's first step rounded the other way (781 down to
/// 768) and bought a 13px band where six ancestors sat under 45px. Up costs at
/// most 16px of a step arriving early, which nobody can see.
///
/// ## What it costs on a phone, stated plainly
///
/// At 390px the trail gets 125px where it used to get 172. Emblem 28 and the
/// leaf's own 14px of padding leave **83px for the page's own name against a
/// 126px median**, so the median leaf name now ellipsizes on a phone where it
/// used to just fit. Accepted, not designed around: the `<h1>` one line below
/// carries the name in full and `title` carries it on hover, and the only way
/// to buy the room back was to drop the up button or a layout button. Search
/// reaches the whole corpus; those two reach one node and one rendering.
///
/// [_trailKeepThree] no longer coincides with [_twoColumnMinWidth], as it did
/// at 48rem through P3. That was arithmetic, not sharing — the two answer
/// different questions, and this is the first of them to move.
const String _trailKeepThree = '51rem';
const String _trailKeepOne = '39rem';
const String _trailKeepNone = '33rem';

/// Height of the sticky reader toolbar.
///
/// Emitted as `--toolbar-height` and consumed by two rules that must never
/// disagree: the bar's own height, and the `scroll-padding-top` that keeps an
/// anchor from landing behind it.
const String _toolbarHeight = '56px';

/// The width of a list of link rows — `.toc` wherever it appears, and
/// `.content.nav` on the pages that hold nothing but one.
///
/// Nothing in either is running text: a heading, `namo tassa`, and link labels,
/// the widest 229px in the corpus. [_readingColumnRem] would buy them nothing
/// and stretch each button to 863px around a 103px label.
///
/// **One size, on every kind of page.** `.toc` carries the cap itself rather
/// than inheriting a column, so a link row measures the same on a nav-only
/// container, on one of the `FIGURES.readableContainerTocs` containers that
/// read at the full measure, and on `/`. It narrows with the window, like any
/// `max-width`, and with nothing else — which is the whole of what should
/// decide the size of a button. Two consequences worth stating: a reader meets
/// one button across the site instead of one per page type, and on a page wider
/// than this the list ends inside the text above it rather than reaching past
/// it.
///
/// Sizing the *page* was how this used to be done, and it broke the moment a
/// container page stopped being pure navigation: `.content.nav` follows
/// `SitePage.isReadable`, so a container whose preamble is the book's
/// introduction (`textBearingContainerKeys`) drops the class — and took its
/// buttons out to 863px with it.
///
/// That 863 is [_readingColumnRem] itself, not a width derived from it: the
/// sheet sets no `box-sizing`, so `max-width` caps `.content`'s *content* box
/// and its 36px of padding sits outside — the same arithmetic [_wideColumnRem]
/// does in the other direction when it adds that 36 back.
///
/// `.content.nav` is safe from the side-by-side override because the override
/// says so: it is written `~ .content:not(.nav)`. It *does* reach a readable
/// container page, deliberately — that page's preamble splits into two columns
/// like any other text. The guard belongs in the rule, not in the markup —
/// `#sbs:checked ~ .content` is (1,0,1,0) against this rule's (0,0,2,0) and
/// would win outright, and whether a container page emits layout radios is
/// decided in two other files (`page_template.dart`'s `navOnly`,
/// `landing_page.dart`'s `toolbar(withLayouts: false)`). Excluding `.nav` holds
/// the width whatever those two emit.
const double _navColumnRem = 44;

/// The gap between the two columns of side-by-side. Named because
/// [_wideColumnRem] has to account for it.
const double _columnGapRem = 1.75;

/// The site's keyboard focus ring, written once for the seven rules that draw
/// it. Always inset: every element taking it either sits in a clipping box
/// (`.breadcrumb` has `overflow: hidden`) or is a bordered control whose ring
/// should trace the border. [offset] varies only for the 1px-bordered field.
String _focusRing({int offset = -2}) =>
    'outline: 2px solid var(--c-primary); outline-offset: ${offset}px;';

/// The reading column when side-by-side splits it in two: both columns at
/// [_readingColumnRem] plus the gap between them, so each side reads at the
/// same measure as every other layout — and as the app's side-by-side, which
/// derives its cap the same way.
///
/// 121.65rem today. Engages past a 1,788px window (1,751.76 + `.content`'s 36px
/// of padding); below that the two columns simply take what the window gives.
double _wideColumnRem(ThemeTokens tokens) =>
    _readingColumnRem(tokens) * 2 + _columnGapRem;

/// Self-hosted WOFF2 (D7) — not polish, correctness.
///
/// Browsers ship no fonts of their own; they use the OS. Only Android carries
/// Noto Sans Sinhala, so on Windows, macOS, iOS and most Linux the page would
/// render in a *different face than the app* — and the baked conjuncts (D1) are
/// glyph-coverage-specific to Noto. Nirmala UI receiving our ZWJ is unverified
/// behaviour, so the font is shipped, not hoped for.
///
/// [fontVersion] is a hash of the faces themselves, so a re-subset reaches a
/// reader who already has the old one — see `fontsVersion`. It rides in the
/// stylesheet because this is the only place a font file is named; the pages
/// pick the change up through the CSS hash they link.
void _writeFontFaces(StringBuffer css, ThemeTokens tokens, String fontVersion) {
  for (final face in webFontFaces(tokens)) {
    css.writeln('@font-face {');
    css.writeln('  font-family: "${face.family}";');
    // Relative, so it resolves against `/assets/site.css` to `/fonts/…`.
    css.writeln('  src: url("../$fontsOutputDir/${face.relativePath}'
        '?v=$fontVersion") format("woff2");');
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
  css.writeln('  max-width: ${_num(_readingColumnRem(tokens))}rem;');
  css.writeln('  margin: 0 auto;');
  css.writeln('  padding: 1.5rem 1.25rem 4rem;');
  css.writeln('}');
  css.writeln('.content.nav { max-width: ${_num(_navColumnRem)}rem; }');
  css.writeln();
  // No `.breadcrumb` here any more — it is toolbar furniture now, styled with
  // the rest of the bar in [_writeToolbarNav]. `.page-title` is what `.content`
  // opens with, and `.content`'s own `padding-top` is the air above it.
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
  // Several suttas can share one vaṇṇanā, so its `මූල පාඨය` has several right
  // answers and the URL says which. Each `.origin` is an empty span carrying
  // one sutta's id, and its return link is the very next element — `+` does the
  // pairing, which is why no rule here names a sutta and this stylesheet stays
  // constant while the corpus does not.
  css.writeln('.origin-link { display: none; }');
  css.writeln('.origin:target + .origin-link { display: block; }');
  // The default is the run's first sutta, where this link pointed before any of
  // the above existed. Visible unless a marker claims the page, so search
  // arrivals, shared URLs and browsers without `:has()` keep the old behaviour.
  css.writeln('body:has(.origin:target) .back-default { display: none; }');
  css.writeln();
  // `max-width` here and not on the page: see [_navColumnRem]. Left-aligned
  // (`margin: 0`), so on a page wider than the list the buttons start on the
  // text's own left edge and stop short of its right one. On a page exactly
  // this wide — every nav-only container, and `/` — the two edges coincide,
  // which is what they have always done.
  css.writeln('.toc {');
  css.writeln('  list-style: none;');
  css.writeln('  padding: 0;');
  css.writeln('  margin: 0;');
  css.writeln('  max-width: ${_num(_navColumnRem)}rem;');
  css.writeln('}');
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
  css.writeln('  column-gap: ${_num(_columnGapRem)}rem;');
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
  // Chrome: sized by the window, never by the text under it — which is what
  // keeps the controls still when the layout changes. Same shape as the app's
  // `AppBar` (`reader_screen.dart:120`), which pins `leading`/`actions` to the
  // window while the text is centred behind them.
  //
  // One element. A centred `.toolbar-inner` used to carry the width, and that
  // width was the only thing positioning the emblem and the layout group — so
  // capping it at the reading column slid both 144px on every layout switch.
  // With no cap left it had nothing to hold. Both failed caps are measured in
  // the build plan.
  //
  // `padding` matches `.content`'s: on a phone the emblem and the first
  // character of the text share one left edge.
  //
  // Full bleed needs this to stay a normal-flow block child of `<body>`, which
  // keeps `margin: 0`. `.layout-input` keeps the radios out of flow so `body`
  // *can* take a layout later; a row flex would make this and `<main>` columns
  // of it.
  css.writeln('.toolbar {');
  css.writeln('  position: sticky;');
  css.writeln('  top: 0;');
  css.writeln('  z-index: 2;');
  // Fixed, not `min-height`: `scroll-padding-top` is
  // `calc(var(--toolbar-height) + 1rem)`, so a bar free to grow under-clears
  // every `#fragment` landing.
  css.writeln('  height: var(--toolbar-height);');
  css.writeln('  display: flex;');
  css.writeln('  justify-content: flex-end;');
  css.writeln('  align-items: center;');
  css.writeln('  gap: 0.75rem;');
  css.writeln('  padding: 0 1.25rem;');
  css.writeln('  background: var(--c-surface-container-high);');
  css.writeln('  border-bottom: 1px solid var(--c-outline);');
  css.writeln('}');
  css.writeln();
  css.writeln('.layouts {');
  css.writeln('  display: inline-flex;');
  // Pinned, like `.up`. The trail's breakpoints are derived from a fixed
  // layout group — 165px at four buttons, 124px at three; leave this at the
  // default `flex-shrink: 1` and the group gives width back under pressure,
  // which both moves the number the breakpoints were measured against and
  // squeezes four 40px targets.
  css.writeln('  flex: none;');
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
        '{ ${_focusRing()} }');
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
  //
  // `.content.solo` joins the list rather than declaring the gap again: a page
  // holding one language is emitted with no radios at all (`page_template.dart`
  // — there is nothing for a switcher to switch), so no `:checked` selector can
  // reach it, and it is in the same state these two describe for exactly the
  // same reason. The base `.row` keeps `--pair-bottom-gap`, which is the
  // *stacked pair* rhythm and wrong where there is no pair.
  css.writeln('#$paliOnlyLayoutId:checked ~ .content .row,');
  css.writeln('#$sinhalaOnlyLayoutId:checked ~ .content .row,');
  css.writeln('.content.solo .row { margin-bottom: var(--entry-gap); }');
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
  // The text column widens — and only the text column. Adding `~ .toolbar` here
  // so the chrome keeps up is what this rule used to say, and what slid the
  // emblem and the layout group 144px apart on every layout switch.
  // `:not(.nav)` so a nav-only page keeps [_navColumnRem] whatever the markup
  // does. This rule is (1,0,1,0) and `.content.nav` is (0,0,2,0), so without
  // the exclusion an id selector wins and a heading and `namo tassa` are laid
  // out across 1,788px — held off today only by a pairing decided in
  // `page_template.dart` and `landing_page.dart`, neither of which this sheet
  // can see. The link buttons are no longer among the casualties: `.toc` caps
  // itself. The sibling rules below need no such guard, and it is `.row`,
  // `.pali`, `.si` and `.col-heads` that would want one — a readable container
  // page has all four, and splitting its preamble into two columns is what
  // side-by-side is for.
  css.writeln('  #$sideBySideLayoutId:checked ~ .content:not(.nav) '
      '{ max-width: ${_num(_wideColumnRem(tokens))}rem; }');
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
  // distinguish it from and the bump would just be heavy type. `.content.solo`
  // is that same state reached from the other end — a page the corpus gave one
  // language, rather than a reader asking for one — and it carries no radios to
  // hang a `:checked` selector on.
  css.writeln('#$paliOnlyLayoutId:checked ~ .content .pali,');
  css.writeln('#$sinhalaOnlyLayoutId:checked ~ .content .pali,');
  css.writeln('.content.solo .pali { --body-weight: $bodyWeight; }');
  css.writeln('@media (min-width: $_twoColumnMinWidth) {');
  css.writeln('  #$sideBySideLayoutId:checked ~ .content .pali '
      '{ --body-weight: $bodyWeight; }');
  css.writeln('}');
  css.writeln();
}

/// The bar's navigation half: the trail, the emblem that opens it, and the up
/// button pinned beyond its right edge.
///
/// `.toolbar` is `justify-content: flex-end`, and the trail's `flex: 1` is what
/// absorbs the free space — so the trail starts at the window's left edge and
/// everything else stays at the right. `.home` used to do that job with
/// `margin-right: auto`; it is inside the trail now and needs no margin of its
/// own.
void _writeToolbarNav(StringBuffer css) {
  css.writeln('/* Toolbar: the trail, its emblem, and the up button. */');
  // The only flex item in the bar allowed to shrink, and the whole reason the
  // controls beside it never move. `min-width: 0` is what permits that: a flex
  // item's floor is `min-content` until it is said otherwise, and here that is
  // the whole trail — 1,154px at the corpus's worst. Every segment is
  // `white-space: nowrap`, so no segment's min-content is less than its entire
  // name, and a flex row's is the sum of theirs. Without it the trail pushes
  // the layout buttons off a phone instead of clipping itself.
  //
  // A flex row, so every segment is its own box and clips itself. As one block
  // sharing one line it clipped once, at the right, which is the near end of
  // the hierarchy: the page's own name went first and what survived on a phone
  // were the outermost containers, the segments a reader least needs. Per
  // segment the order can be stated instead, and it is — see the `flex` values
  // below.
  //
  // Ellipsis and not a scroll box: it is the app's behaviour
  // (`TextOverflow.ellipsis`, one line), and a horizontal scroller inside a
  // 56px sticky bar has no affordance a mouse can see.
  //
  // `overflow: hidden` here is a backstop, not the mechanism. Each segment has
  // a floor it cannot shrink past, and enough segments at their floor can still
  // out-measure the box; this is what stops the overflow landing on the up
  // button rather than being clipped.
  css.writeln('.breadcrumb {');
  css.writeln('  display: flex;');
  css.writeln('  align-items: center;');
  css.writeln('  flex: 1;');
  css.writeln('  min-width: 0;');
  css.writeln('  overflow: hidden;');
  css.writeln('  font-family: var(--font-ui);');
  css.writeln('  font-size: 0.85em;');
  css.writeln('  line-height: 1;');
  css.writeln('  color: var(--c-on-surface-variant);');
  css.writeln('}');
  css.writeln();
  // Every segment but the emblem: one line, its own ellipsis, its own `›`.
  //
  // `min-width: 0` for the same reason the bar gives it to `.breadcrumb` — a
  // flex item will not shrink below `min-content` unless told to, and a node
  // name's `min-content` is the whole name.
  //
  // The vertical padding is slack for `overflow: hidden`. `line-height: 1` sets
  // the box to the em, and Sinhala ink runs taller than its em, so without this
  // each segment would shave the marks off its own text. 6px keeps the box at
  // ~24px, still under the 28px emblem, so the bar's height is untouched.
  css.writeln('.breadcrumb > :not(.home) {');
  css.writeln('  position: relative;');
  css.writeln('  min-width: 0;');
  css.writeln('  padding: 6px 0 6px 1.15em;');
  css.writeln('  white-space: nowrap;');
  css.writeln('  overflow: hidden;');
  css.writeln('  text-overflow: ellipsis;');
  css.writeln('}');
  // Drawn, not marked up. As an element between segments it was a flex item of
  // its own, so a segment squeezed to nothing left its `›` standing there —
  // `⌂ › › › name` at the widths where that matters most. Inside the segment
  // and absolutely positioned, it is clipped by the same `overflow` and leaves
  // with it. Out of flow, so it neither takes part in the ellipsis nor picks up
  // the hover underline; `padding-left` is the room it sits in.
  //
  // A screen reader may still announce it, as generated content sometimes is.
  // No worse than the `<span>` it replaces, which was announced for certain.
  css.writeln('.breadcrumb > :not(.home)::before {');
  css.writeln("  content: '›';");
  css.writeln('  position: absolute;');
  css.writeln('  left: 0.3em;');
  css.writeln('  opacity: 0.5;');
  css.writeln('}');
  css.writeln('.breadcrumb a { color: inherit; text-decoration: none; }');
  css.writeln('.breadcrumb a:hover { text-decoration: underline; }');
  css.writeln();
  // Who gives first. Flex shares a shortfall in proportion to
  // `flex-shrink × flex-basis`, so a median page's five ancestors at 200 absorb
  // 99.9% of it and the leaf is untouched until every one of them has hit its
  // floor. That is the whole point: the ancestors compress, and the name of the
  // page you are on is the last thing to go.
  //
  // Neither may grow — `.breadcrumb` is wider than its contents whenever the
  // trail is short, and a stretched trail would put the emblem and the page
  // name at opposite ends of the bar.
  css.writeln('.breadcrumb a:not(.home) { flex: 0 200 auto; }');
  // The page you are on, brighter than the links above it — the app draws the
  // same distinction, leaf in `resultMatchedText` and parents dimmed to
  // `onSurfaceVariant`.
  css.writeln('.breadcrumb .leaf { flex: 0 1 auto; '
      'color: var(--c-on-surface); }');
  css.writeln();
  css.writeln('.home { display: flex; flex: none; align-items: center; }');
  // A focus ring the anchor can actually show — unlike the layout labels, this
  // is a real link, so `:focus-visible` lands on the element itself. Inset,
  // because an outset ring on the first segment would be drawn outside
  // `.breadcrumb`'s padding box and clipped by its `overflow: hidden`.
  css.writeln('.home:focus-visible '
      '{ ${_focusRing()} border-radius: 8px; }');
  css.writeln('.home img { display: block; width: 28px; height: 28px; }');
  css.writeln();
  // Where compressing stops paying and dropping starts. Derivation and the
  // measurements behind each width are on [_trailKeepThree] and its two
  // siblings.
  //
  // `:nth-last-of-type` counts anchors from the end, so the rules are written
  // in terms of how many of the *nearest* ancestors survive — which is the
  // question — and hold for a trail of two segments or of six without knowing
  // which it is. `:not(.home)` spares the emblem, which is an anchor too.
  //
  // `width: 0`, never `display: none`. A collapsed segment is still a rendered
  // link in the DOM and in the accessibility tree; the breadcrumb *is* this
  // site's internal link graph, and Google indexes it at a phone's viewport
  // width, which is precisely where these rules apply. Zeroing the box is the
  // one way to take a link off the screen without taking it out of the crawl.
  for (final step in const [
    (_trailKeepThree, 'n+4'),
    (_trailKeepOne, 'n+2'),
    (_trailKeepNone, null),
  ]) {
    final position = step.$2 == null ? '' : ':nth-last-of-type(${step.$2})';
    css.writeln('@media (max-width: ${step.$1}) {');
    css.writeln('  .breadcrumb a:not(.home)$position '
        '{ width: 0; padding-left: 0; }');
    css.writeln('}');
  }
  css.writeln();
  // Last of the trail's rules on purpose. It ties the media queries above at
  // specificity, so source order is what lets focus win — a keyboard user who
  // tabs into a collapsed segment gets it back, rather than watching focus
  // vanish into a zero-width box. `:not(.home)` keeps the emblem's own 8px
  // ring, which this would otherwise outrank.
  css.writeln('.breadcrumb a:not(.home):focus-visible {');
  css.writeln('  width: auto;');
  // `width: auto` alone gives the segment nothing back. `flex-basis: auto`
  // resolves to that width, and at `flex-shrink: 200` the bar takes it straight
  // off again — the segment would return a few pixels wide. The floor is what
  // makes the rule mean what it says; `.breadcrumb`'s `overflow: hidden` is
  // still the backstop if the trail now out-measures the box.
  css.writeln('  flex-shrink: 0;');
  css.writeln('  padding-left: 1.15em;');
  css.writeln('  ${_focusRing()}');
  css.writeln('  border-radius: 4px;');
  css.writeln('}');
  css.writeln();
  // The bar's two icon controls — `.up` (an anchor) and `.search-trigger` (a
  // button). **One rule, not two identical ones**: the trail's breakpoints are
  // derived from each holding exactly 36px, so their being the same box is an
  // invariant the arithmetic depends on, not something two blocks must
  // remember. Sized to one layout button — 34px inside a 1px border — so all
  // three read as one set. `flex: none` on the same terms as `.layouts`: the
  // trail is the bar's only elastic item, and these are the affordances that
  // exist *for* the widths where it collapses.
  //
  // Three declarations serve one of the two and are harmless on the other:
  // `text-decoration` for the anchor, which sits outside `.breadcrumb` and so
  // keeps the UA underline; `padding` and `cursor` for the button's UA
  // defaults. Neither needs a font reset — both hold an SVG and no text.
  css.writeln('.up, .search-trigger {');
  css.writeln('  display: flex;');
  css.writeln('  flex: none;');
  css.writeln('  align-items: center;');
  css.writeln('  justify-content: center;');
  css.writeln('  width: 34px;');
  css.writeln('  height: 34px;');
  css.writeln('  padding: 0;');
  css.writeln('  border: 1px solid var(--c-outline);');
  css.writeln('  border-radius: 8px;');
  css.writeln('  background: var(--c-background);');
  css.writeln('  color: var(--c-on-surface-variant);');
  css.writeln('  text-decoration: none;');
  css.writeln('  cursor: pointer;');
  css.writeln('}');
  css.writeln('.up:hover, .search-trigger:hover '
      '{ background: var(--c-surface-container-low); }');
  css.writeln('.up:focus-visible, .search-trigger:focus-visible '
      '{ ${_focusRing()} }');
  // `[hidden]` needs saying, and saying *after* the shared rule: its UA
  // `display: none` loses to the `display: flex` above on specificity, and
  // without this the search button shows for every reader with JS off — the
  // dead control C8 forbids.
  css.writeln('.search-trigger[hidden] { display: none; }');
  css.writeln('.up-icon, .search-icon { width: 18px; height: 18px; }');
  css.writeln();
}

/// The search dialog. Its trigger is not here — `.search-trigger` shares one
/// rule with `.up` up in [_writeToolbarNav], because the two are the same box
/// and the bar's arithmetic depends on their staying it.
///
/// The only rules on this sheet whose markup is not on the page until a script
/// says so — but they are written for markup the generator emits statically, so
/// nothing here is injected and every selector below has something to match
/// from the first byte.
void _writeSearch(StringBuffer css) {
  css.writeln('/* Search: the dialog. */');

  // The panel.
  //
  // Pinned near the top rather than centred: results grow downwards, and a
  // vertically centred panel jumps up the screen as they arrive.
  //
  // ⚠️ **`display` is on `[open]`, and must stay there.** The closed state is
  // the UA's `dialog:not([open]) { display: none }` — a *user-agent* rule,
  // which any author declaration outranks no matter how weak its selector,
  // because cascade origin is settled before specificity is consulted. So a
  // bare `.search { display: flex }` does not merely style the panel: it
  // overrides that rule and leaves the dialog rendered, open, in the normal
  // flow of every page. Guarding on `[open]` hands the closed state back
  // to the UA.
  css.writeln('.search {');
  css.writeln('  width: min(34rem, calc(100vw - 2rem));');
  // Bounded, so a 50-row result list scrolls inside the panel instead of
  // running the page off the bottom of the phone.
  //
  // Twice, `vh` then `dvh`. On mobile Safari `100vh` is the *large* viewport,
  // so with the URL bar showing, the panel's bottom edge sits under browser
  // chrome — on the surface this dialog was built for. The `vh` line stays as
  // the fallback for browsers that drop the `dvh` one (Safari 15.3 and down).
  css.writeln('  max-height: min(32rem, calc(100vh - 6rem));');
  css.writeln('  max-height: min(32rem, calc(100dvh - 6rem));');
  css.writeln('  margin: 3rem auto;');
  css.writeln('  padding: 0;');
  css.writeln('  overflow: hidden;');
  css.writeln('  border: 1px solid var(--c-outline);');
  css.writeln('  border-radius: 12px;');
  css.writeln('  background: var(--c-surface-container-high);');
  css.writeln('  color: var(--c-on-surface);');
  css.writeln('  font-family: var(--font-ui);');
  css.writeln('}');
  // The open state, and the only place this element gets a `display` — see the
  // warning above.
  css.writeln('.search[open] { display: flex; flex-direction: column; }');
  // Dimmed, not blurred: a backdrop filter costs a compositor pass on every
  // frame of the open animation, and this site's budget is a phone on a slow
  // connection.
  css.writeln('.search::backdrop { background: rgba(0, 0, 0, 0.45); }');
  css.writeln();

  css.writeln('.search-head {');
  css.writeln('  display: flex;');
  css.writeln('  align-items: center;');
  css.writeln('  gap: 0.5rem;');
  css.writeln('  padding: 0.75rem;');
  css.writeln('  border-bottom: 1px solid var(--c-outline-variant);');
  css.writeln('}');
  css.writeln('.search-field {');
  css.writeln('  flex: 1;');
  // `min-width: 0` for the same reason `.breadcrumb` needs it: an `<input>`
  // carries a default intrinsic size that a flex item will not shrink below,
  // and on a narrow phone that pushes the close button off the panel.
  css.writeln('  min-width: 0;');
  css.writeln('  padding: 0.5rem 0.6rem;');
  css.writeln('  border: 1px solid var(--c-outline);');
  css.writeln('  border-radius: 8px;');
  css.writeln('  background: var(--c-background);');
  css.writeln('  color: var(--c-on-surface);');
  // The field holds Sinhala the reader types and the corpus answers in. Left
  // to the UA it would render in a Latin system face, so the one string on the
  // page composed *by* the reader would be the one not in the site's font.
  css.writeln('  font-family: var(--font-ui);');
  // 16px at the root's 90% — below this iOS Safari zooms the viewport on
  // focus, which on a fixed-position modal leaves the panel off-centre and the
  // reader pinch-zooming back out.
  css.writeln('  font-size: 1.12rem;');
  css.writeln('}');
  css.writeln('.search-field:focus-visible { ${_focusRing(offset: -1)} }');
  css.writeln();

  css.writeln('.search-close {');
  css.writeln('  display: flex;');
  css.writeln('  flex: none;');
  css.writeln('  align-items: center;');
  css.writeln('  justify-content: center;');
  // 40px, not the bar's 34: this one is inside a modal with room to spare, and
  // 24×24 is the WCAG 2.2 SC 2.5.8 floor that P3.5's disclosure toggle failed.
  css.writeln('  width: 40px;');
  css.writeln('  height: 40px;');
  css.writeln('  padding: 0;');
  css.writeln('  border: 0;');
  css.writeln('  border-radius: 8px;');
  css.writeln('  background: none;');
  css.writeln('  color: var(--c-on-surface-variant);');
  css.writeln('  cursor: pointer;');
  css.writeln('}');
  css.writeln('.search-close:hover '
      '{ background: var(--c-surface-container-low); }');
  css.writeln('.search-close:focus-visible { ${_focusRing()} }');
  css.writeln('.search-close-icon { width: 20px; height: 20px; }');
  css.writeln();

  // `:empty` keeps the line from reserving space before there is anything to
  // say — the resting state of the dialog is a field and nothing else.
  css.writeln('.search-status {');
  css.writeln('  margin: 0;');
  css.writeln('  padding: 0.5rem 0.9rem;');
  css.writeln('  font-size: 0.85em;');
  css.writeln('  color: var(--c-on-surface-variant);');
  css.writeln('}');
  css.writeln('.search-status:empty { display: none; }');
  css.writeln();

  css.writeln('.search-results {');
  css.writeln('  flex: 1;');
  css.writeln('  margin: 0;');
  css.writeln('  padding: 0;');
  css.writeln('  list-style: none;');
  css.writeln('  overflow-y: auto;');
  // Momentum scrolling inside the panel rather than the page behind it.
  css.writeln('  overscroll-behavior: contain;');
  css.writeln('}');
  css.writeln('.search-results a {');
  css.writeln('  display: block;');
  css.writeln('  padding: 0.6rem 0.9rem;');
  css.writeln('  color: inherit;');
  css.writeln('  text-decoration: none;');
  css.writeln('}');
  css.writeln('.search-results a:hover, .search-results a:focus-visible {');
  css.writeln('  background: var(--c-primary-container);');
  css.writeln('  color: var(--c-on-primary-container);');
  css.writeln('}');
  // The arrow keys move focus down this list, and the tint alone cannot say
  // where it landed: `--c-primary-container` on `--c-surface-container-high`
  // measures **1.44:1**, under the 3:1 SC 2.4.13 asks of a focus indicator.
  css.writeln('.search-results a:focus-visible { ${_focusRing()} }');
  css.writeln();

  // The name in the reader's font, the path under it in the UI font — the same
  // split the breadcrumb makes, and for the same reason: one is scripture, the
  // other is furniture.
  css.writeln('.search-name {');
  css.writeln('  display: block;');
  css.writeln('  font-family: var(--font-reader);');
  css.writeln('  line-height: 1.5;');
  css.writeln('}');
  css.writeln('.search-path {');
  css.writeln('  display: block;');
  css.writeln('  font-size: 0.8em;');
  css.writeln('  color: var(--c-on-surface-variant);');
  css.writeln('  white-space: nowrap;');
  css.writeln('  overflow: hidden;');
  css.writeln('  text-overflow: ellipsis;');
  css.writeln('}');
  // Inherited on the hovered row, where `--c-on-surface-variant` against
  // `--c-primary-container` is the one pairing on this sheet that is not a
  // theme pair at all — the token is defined against `surface`.
  css.writeln('.search-results a:hover .search-path, '
      '.search-results a:focus-visible .search-path '
      '{ color: inherit; opacity: 0.75; }');
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
  // One gate, every rule below. `.sutta:target` answers only when a *section*
  // is named in the address bar; `.sutta :target` — note the space — also when
  // the target sits *inside* one, which is how an origin marker addresses a
  // merged vaṇṇanā today and how a footnote will under P7. Scoped to `.sutta`
  // on purpose: a bare `:has(:target)` would fire on a preamble id and hide
  // every section, since none of them contains it.
  const filtered = '.chapter:has(.sutta:target, .sutta :target)';
  // `:not(:has(:target))` keeps the *containing* section visible when the
  // target is nested inside it — written from the start, inert until the gate
  // learned to admit a nested target, load-bearing from now on.
  css.writeln('$filtered .sutta:not(:target):not(:has(:target)) {');
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
  css.writeln('$filtered .chapter-bar {');
  css.writeln('  display: block;');
  css.writeln('  font-family: var(--font-ui);');
  css.writeln('  font-size: 0.9em;');
  css.writeln('  margin-bottom: 1.5rem;');
  css.writeln('  padding: 0.6rem 0.9rem;');
  css.writeln('  border-radius: 0.4rem;');
  css.writeln('  background: var(--c-surface-container-low);');
  css.writeln('}');
  css.writeln('.chapter-bar a { color: var(--c-primary); }');
  css.writeln();
  // Two pagers per chapter page, one view each. Unfiltered, the page's own
  // pager walks files and the per-section ones stay hidden; filtered, they
  // swap — the filter above has already hidden every section but the targeted
  // one, so only its pager can show.
  //
  // `display: grid` restates `.pager`'s own value from `_writePageChrome`;
  // there is no way to say "back to the earlier author rule". Hiding by default
  // rather than showing the page's pager conditionally is what the no-`:has()`
  // fallback rides on: neither rule below applies there, so those browsers keep
  // the file-walking pager they have today.
  css.writeln('.sutta .pager { display: none; }');
  css.writeln('$filtered .sutta .pager { display: grid; }');
  css.writeln('$filtered ~ .pager { display: none; }');
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
