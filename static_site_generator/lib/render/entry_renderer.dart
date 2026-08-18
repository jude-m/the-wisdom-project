import 'package:wisdom_shared/wisdom_shared.dart';

import '../domain/content_file.dart';

/// Turns one source entry into one HTML element.
///
/// Mirrors: lib/presentation/widgets/reader/reader_entry_builder.dart
/// The switch below is that file's `switch (entry.entryType)`, and the classes
/// it emits are styled by `stylesheet.dart` from the same theme tokens the
/// widget reads. Two renderers, one decision tree.
class EntryRenderer {
  /// Conjunct switches baked into the HTML (build plan D1).
  ///
  /// A static page has no settings screen, so it ships the app's defaults —
  /// standard ligatures + touching, special conjuncts off. Same object the app
  /// starts from, same code applying it, so a cluster joins identically on both
  /// surfaces.
  static const PaliLetterOptions bakedOptions = PaliLetterOptions.defaults;

  const EntryRenderer();

  /// Renders [entry] as a block element.
  ///
  /// [isPali] gates the conjunct transform. Sinhala translation text must never
  /// go through it — it would bind consonants that Sinhala orthography keeps
  /// apart, which is the same seam `content_text_formatter.dart` enforces in
  /// the app.
  ///
  /// [headingDepths] maps a source heading `level` onto an HTML heading depth
  /// for the page being rendered; see `PageTemplate._headingDepths`, which owns
  /// the reasoning. Absent an entry for this level — a direct call in a test —
  /// the heading lands at `<h2>`, immediately under the page title.
  String render(
    ContentEntry entry, {
    required bool isPali,
    Map<int, int> headingDepths = const {},
  }) {
    final level = entry.level;
    final inner = renderText(entry.text, isPali: isPali);

    switch (entry.type) {
      case 'heading':
        // `l$clamped` still carries the *source* level, because that is what
        // the stylesheet sizes on — the tag says where the heading sits in the
        // outline, the class says how big the book printed it.
        final clamped = (level ?? 1).clamp(1, 5);
        final tag = 'h${headingDepths[clamped] ?? 2}';
        return '<$tag class="e-heading l$clamped">$inner</$tag>';
      case 'centered':
        // Deliberately not a heading. The type is a *typographic* one and its
        // level-1 members are bare numbering ("8. 6. 1."), which would litter
        // the outline with headings that say nothing.
        final clamped = (level ?? 1).clamp(1, 5);
        return '<p class="e-centered l$clamped">$inner</p>';
      case 'gatha':
        final second = (level ?? 1) >= 2 ? ' l2' : '';
        return '<p class="e-gatha$second">$inner</p>';
      case 'unindented':
        return '<p class="e-unindented">$inner</p>';
      default:
        return '<p class="e-paragraph">$inner</p>';
    }
  }

  /// Marker-bearing source text → inline HTML.
  ///
  /// `**bold**` becomes `<strong>`. Two other markers are deliberately *not*
  /// rendered, each for its own reason:
  ///
  /// - **`__underline__` is dropped to match the app** (decided 2026-07-30).
  ///   `text_entry_widget.dart` styles `markedRanges` with nothing but
  ///   `FontWeight.bold`, and `markedRanges` is fed from `boldRanges` — so the
  ///   app strips `__` and shows the text unstyled. Emitting `<u>` here would
  ///   underline spans that the app leaves plain, which is the drift the
  ///   shared-surface rule exists to prevent. No text is lost either way; only
  ///   the styling differs. Revisit **together with the app**, not on this side
  ///   alone.
  /// - **Footnote references are dropped in this phase** (D3): the app renders
  ///   zero footnotes today, they need per-printed-page numbering, and
  ///   half-rendering them now would put an orphan superscript on every
  ///   reference in the corpus.
  String renderText(String raw, {required bool isPali}) {
    final buffer = StringBuffer();
    var openBold = false;

    for (final segment in parseContentMarkers(raw)) {
      if (segment.isFootnote) continue; // D3
      if (segment.text.isEmpty) continue;

      // Re-open only on a change, so `**a b**` is one <strong>, not two.
      if (segment.bold != openBold) {
        buffer.write(segment.bold ? '<strong>' : '</strong>');
        openBold = segment.bold;
      }
      buffer.write(escapeHtml(bakeConjuncts(segment.text, isPali: isPali)));
    }
    if (openBold) buffer.write('</strong>');
    return buffer.toString();
  }

  /// Applies the baked conjunct switches to Pali text; passes Sinhala through.
  static String bakeConjuncts(String text, {required bool isPali}) =>
      isPali ? beautifyPaliText(text, bakedOptions) : text;
}

/// Escapes the five characters that can break out of HTML text or an attribute.
///
/// Deliberately not a "sanitizer": the corpus is trusted, vendored data, and
/// the job here is only to keep a literal `&` or `<` in the source from being
/// read as markup.
String escapeHtml(String text) {
  if (!text.contains(_needsEscaping)) return text;
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

/// Hoisted, not inline in [escapeHtml]: `RegExp(...)` builds and compiles a new
/// pattern on every evaluation, and this one is tested once per rendered
/// segment — millions of times across a full build, to answer the same question
/// each time.
final RegExp _needsEscaping = RegExp('[&<>"\']');

/// A node title as the **reader** sees it — conjuncts baked exactly as body
/// text is (D1), and exactly as the app renders the same string.
///
/// Use for every *visible* label: `<h1>`, breadcrumb, TOC entries, pager cards.
/// The app puts tree names through `beautifyPaliText` too — see
/// `breadcrumb_provider.dart` and `tree_navigator_widget.dart`, both of which
/// watch `paliLetterOptionsProvider` — so anything less here would print a
/// sutta's name one way in the breadcrumb and another way in the body two
/// lines below it.
String weldTitle(String title) =>
    beautifyPaliText(title, EntryRenderer.bakedOptions);

/// Strips the *touching* ZWJ from a title (build plan D2).
///
/// `consonant + ZWJ + hal + consonant` → `consonant + hal + consonant`, which
/// is character-for-character what tipitaka.lk does in `views/Home.vue:118`
/// before setting its document title.
///
/// Only the touching form goes. The **ligature** ZWJ that follows a hal —
/// `සූත්‍ර`, rakaransaya and yansaya — is ordinary Sinhala spelling and appears
/// in `FIGURES.namesWithLigatureZwj` of the tree's `FIGURES.nodeNames`;
/// removing it would misspell them.
///
/// **Machine-read strings only** — `<title>`, and OG / JSON-LD when P5 adds
/// them. A reader searching for a sutta types plain Sinhala, so baked ZWJ in an
/// indexed string means the form a search engine holds is not the form they
/// typed. That argument covers strings a *crawler* reads and nothing else;
/// applying it to visible chrome as well (as this first did) diverges from both
/// the app and tipitaka.lk, which un-welds `document.title` alone.
String unweldTitle(String title) => title.replaceAllMapped(
      _touchingInTitle,
      (match) => '${match[1]}්${match[2]}',
    );

final RegExp _touchingInTitle = RegExp('([ක-ෆ])‍්([ක-ෆ])');
