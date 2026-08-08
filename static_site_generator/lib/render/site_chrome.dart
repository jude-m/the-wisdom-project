/// The chrome and shared furniture every page wears — reading page, container
/// TOC and `/` alike.
///
/// Mirrors: lib/presentation/widgets/navigation/ (the app's navigation surface).
///
/// ## What used to be here
///
/// P3 put a collapsing navigator rail on all 14,752 pages: a checkbox, a
/// hamburger, a scrim and a pruned `<details>` tree. It was measured on the full
/// build and withdrawn (P3.5) — see the build plan's P3 revision note. What is
/// left is the part that was doing real work: a way home.
///
/// Kept out of `page_template.dart` because `/` needs the identical bar while
/// sharing none of that file's other machinery — no slices, no breadcrumb, no
/// pager. Two copies of a bar whose flex contract lives in the stylesheet is how
/// one of them quietly stops matching.
library;

import 'package:wisdom_shared/wisdom_shared.dart';

import '../domain/site_page.dart';
import 'node_labels.dart';
import 'reading_layouts.dart';

/// Accessible name for the home link. The app's `navHome` (`app_si.arb:198`),
/// not new wording — two names for one thing is how surfaces drift.
const String homeLabel = 'මුල් පිටුව';

/// A committed 200×200 derivative of `assets/icons/app_logo.png`, produced by
/// `static_site_generator/assets/make_emblem.sh` — see that script for why the
/// 634 KB source is never shipped.
const String emblemFileName = 'emblem.png';

/// The mark in the toolbar, on every page including `/`.
///
/// One constant, so the `<img src>` and the file the build copies cannot name
/// two different things.
const String emblemUrl = '/assets/$emblemFileName';

/// The toolbar's home link — the site's only route back to `/`.
///
/// Load-bearing in a way it was not before P3.5: until the rail went, `href="/"`
/// appeared exactly once per page and only inside it. A leaf page's other links
/// are the breadcrumb, the pager and the aṭṭhakathā twin, none of which climb
/// past the node's own root, so without this the front door is unreachable from
/// anywhere in the corpus.
///
/// `margin-right: auto` in the stylesheet is what keeps the layout group at the
/// other end of the bar; the anchor is the flex item that absorbs the space.
///
/// Rendered on `/` too, where it points at the page you are already on. A logo
/// that stops being a link on one page is the odder behaviour, and the
/// alternative costs a branch through every caller to save one anchor.
String homeLink() => '<a class="home" href="/" title="$homeLabel">'
    '<img src="$emblemUrl" width="28" height="28" alt="$homeLabel"></a>';

/// A list of child links — a container's table of contents, and `/`'s list of
/// the seven roots.
///
/// Takes the nodes rather than a parent key, because `/` has no parent node: its
/// children are `tree.roots`, which no `childrenOf` call returns. One function
/// either way, so the front page and a container TOC cannot drift into two list
/// markups the stylesheet has to style twice.
String tocList(Iterable<TipitakaNode> nodes) {
  final buffer = StringBuffer('<ul class="toc">');
  for (final node in nodes) {
    buffer.write('<li><a href="${tipitakaUrl(node.nodeKey)}">'
        '${nodeLabelHtml(node)}</a></li>');
  }
  buffer.write('</ul>');
  return buffer.toString();
}

/// The sticky bar: home on the left, layout switcher on the right.
///
/// One element, edge to edge — background and contents both. The bar is chrome:
/// sized by the window, never by the text under it, which is what keeps the
/// controls still when a reader switches layout. Reasoning in `.toolbar`.
///
/// **Every page gets the bar, including a TOC and `/`.** P2 emitted it only on
/// readable pages, because the layout group was the only thing in it; P3 changed
/// that for its hamburger, and the reason outlived the hamburger — a page with
/// no bar is a page with no way home. [withLayouts] is what stays gated: frame
/// 03 gives container TOCs no layout group, and neither they nor `/` have a
/// reading layout to choose.
///
/// A plain `<div>`, not a `<nav>`: choosing a layout is not navigation, and
/// marking it up as one adds another unnamed landmark beside the breadcrumb and
/// the pager for a screen-reader user to wade through. `role="radiogroup"` would
/// be no better — the radios are outside this element, not in it. The grouping
/// is already carried where it belongs, by the shared `name="layout"`, which is
/// what makes a reader announce "2 of 4".
String toolbar({required bool withLayouts}) {
  final buffer = StringBuffer('<div class="toolbar">');
  buffer.write(homeLink());
  if (withLayouts) {
    buffer.write('<div class="layouts">');
    for (final layout in readingLayouts) {
      // `title` is a hover tooltip for sighted mouse users, who otherwise get
      // only "P" or an icon. It is not a duplicate announcement: the input's
      // accessible name comes from its own `aria-label`, and a `<label>` is not
      // focusable, so this string never reaches the a11y tree twice.
      buffer.write('<label for="${layout.id}" title="${layout.label}">'
          '${layout.glyph}</label>');
    }
    buffer.write('</div>');
  }
  buffer.write('</div>');
  return buffer.toString();
}
