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
/// sharing none of that file's other machinery — no slices, no pager, no
/// reading layout. The trail is not an exception to that: `/` carries one like
/// every other page, the emblem with no segments after it, which is this
/// function's own defaults rather than a second bar shape. Two copies of a bar
/// whose flex contract lives in the stylesheet is how one of them quietly stops
/// matching.
library;

import 'package:wisdom_shared/wisdom_shared.dart';

import '../domain/site_page.dart';
import 'node_labels.dart';
import 'reading_layouts.dart';
import 'search_dialog.dart';
import 'site_assets.dart';

/// Accessible name for the home link. The app's `navHome` (`app_si.arb:198`),
/// not new wording — two names for one thing is how surfaces drift.
const String homeLabel = 'මුල් පිටුව';

/// Accessible name for the trail itself.
///
/// Site-only furniture: the app's breadcrumb is an `AppBar` title and carries no
/// label of its own, because there it is the only thing in the bar. Here it is
/// one `<nav>` among three landmarks a screen-reader user tabs past, so it says
/// which one it is.
const String breadcrumbLabel = 'ස්ථානය';

/// The direction word on the up button.
///
/// Invented, and the only string on this surface that is. The app has no such
/// control — it has the navigator tree instead — and neither the ARB nor
/// tipitaka.lk has a label for one. Built on the pager's pattern (`පෙර`, `ඊළඟ`):
/// a direction word, then the node it leads to. Deliberately **not** the ARB's
/// `expand` ("ඉහළ​ට"), which is a disclosure toggle and means something else.
const String upLabel = 'ඉහළ';

/// The site's only route back to `/` — and, since the trail moved into the bar,
/// the first segment of it.
///
/// Load-bearing in a way it was not before P3.5: until the rail went, `href="/"`
/// appeared exactly once per page and only inside it. A leaf page's other links
/// are the breadcrumb, the pager and the aṭṭhakathā twin, none of which climb
/// past the node's own root, so without this the front door is unreachable from
/// anywhere in the corpus.
///
/// Rendered on `/` too, where it points at the page you are already on. A logo
/// that stops being a link on one page is the odder behaviour, and the
/// alternative costs a branch through every caller to save one anchor.
///
/// The emblem's URL arrives from [SiteAssets] rather than being written here:
/// it carries a hash of the image, which only the build that read the bytes can
/// know.
String homeLink(SiteAssets assets) => '<a class="home" href="/" '
    'title="$homeLabel">'
    '<img src="${assets.emblem}" width="28" height="28" alt="$homeLabel"></a>';

/// The trail: home, the ancestors, and the page itself.
///
/// ## Why it is in the bar
///
/// It used to sit inside `<main>`, above the `<h1>`. The bar is now window-sized
/// chrome modelled on the app's `AppBar`, and the slot this fills is the one the
/// app puts a breadcrumb in — `title: const BreadcrumbWidget()`
/// (`reader_screen.dart`). Same separator, same one line, same ellipsis, same
/// rule about which segments link.
///
/// ## The leaf is included, and is not a link
///
/// The site's trail used to stop at the parent, on the grounds that the `<h1>`
/// directly beneath it named the node. A sticky bar has no "directly beneath":
/// the heading scrolls away and the bar does not, so a trail ending at the
/// parent leaves a reader who has scrolled with no name for the page they are
/// on. The app includes it for the same reason and this now matches.
///
/// A `<span>`, not an anchor — a link from a page to itself does nothing, and
/// the 14,752 of them would be self-referential edges in the crawl graph.
/// `aria-current="page"` is what carries "this segment is where you are".
///
/// ## The emblem is segment zero
///
/// Not a control standing beside the trail: `/` really is the parent of `vp`,
/// `sp` and the other five roots, so the merge states a fact about the
/// hierarchy rather than saving a few pixels. It also puts the route home at
/// the one end of the line nothing is ever taken from.
///
/// ## Every segment is its own box
///
/// Each name is one flex item that clips itself, rather than all of them
/// sharing a single line that clips at the right. A shared line always eats the
/// *end* — the near ancestors and the page's own name, the segments a reader
/// most needs — so the trail got shorter by losing exactly the wrong half.
/// Per-segment, the ancestors surrender their characters first and the leaf is
/// last to give. `.breadcrumb`'s rules in `stylesheet.dart` carry the ordering;
/// what this function owes them is a flat child list with the leaf last.
///
/// No separator element: `›` is drawn by CSS on each segment, so a segment
/// collapsed at a narrow width takes its own separator with it and cannot leave
/// an orphan `›` behind. It also drops ~110 bytes from every page in the build.
///
/// ## `title` on every segment
///
/// The name a segment would show if it had the room. Ellipsis is honest about
/// *that* there is more and silent about *what*, and hover is the one channel
/// that can answer without a script or a taller bar. Not a second accessible
/// name: for an anchor, the name comes from its text content, which beats
/// `title` — so this arrives as a description, and it is the same string either
/// way.
String breadcrumb({
  required SiteAssets assets,
  List<TipitakaNode> trail = const <TipitakaNode>[],
  TipitakaNode? current,
}) {
  final buffer =
      StringBuffer('<nav class="breadcrumb" aria-label="$breadcrumbLabel">');
  buffer.write(homeLink(assets));
  for (final ancestor in trail) {
    // `nodeLabelHtml` escapes `"`, which is what lets one string be both the
    // text and the attribute.
    final label = nodeLabelHtml(ancestor);
    buffer.write('<a href="${tipitakaUrl(ancestor.nodeKey)}" '
        'title="$label">$label</a>');
  }
  if (current != null) {
    final label = nodeLabelHtml(current);
    buffer.write('<span class="leaf" aria-current="page" '
        'title="$label">$label</span>');
  }
  buffer.write('</nav>');
  return buffer.toString();
}

/// One level up, named after where it goes.
///
/// The trail alone does not cover this. A phone has no room for it: measured on
/// the corpus as the boxes render, a full trail is 684px at the median, against
/// 172px of room on a 390px screen — the window less 218px of pinned controls,
/// which is three layout buttons and not four, side-by-side being
/// `display: none` below 48rem. What fits in 172px is the emblem and the page's
/// own name and nothing else. So below 30rem the stylesheet collapses every
/// ancestor and the parent link goes with them. This anchor is pinned and never
/// shrinks, which is what keeps the one step a reader always wants on screen.
///
/// The app ships no equivalent because it has the navigator tree; P3.5 withdrew
/// this site's, and nothing took over the job of climbing one level.
///
/// Omitted on the seven roots, whose parent is `/` — the emblem at the other end
/// of the trail already goes there, and two controls to one destination is the
/// kind of thing a reader has to test to understand.
///
/// `title` alone, not `title` plus `aria-label`. The glyph is `aria-hidden`, so
/// the anchor has no name from its content and `title` becomes the name — the
/// one attribute doing both jobs. Carrying both instead makes the string a name
/// *and* a description, which a screen reader may well read out twice, and
/// dropping `title` for `aria-label` would take the hover tooltip off the one
/// control in the bar whose destination is not written on it.
String upLink(TipitakaNode parent) {
  // Welded and escaped, like every other label a reader sees (D1). `escapeHtml`
  // covers `"`, which is what makes the same string safe in an attribute.
  final name = '$upLabel ${nodeLabelHtml(parent)}';
  return '<a class="up" href="${tipitakaUrl(parent.nodeKey)}" '
      'title="$name">$_upGlyph</a>';
}

/// Inline SVG on the same terms as the layout icons: `currentColor`, no second
/// request, ~140 bytes, and drawn to their stroke weight so the two controls in
/// the bar read as one set.
const String _upGlyph = '<svg class="up-icon" viewBox="0 0 24 24" fill="none" '
    'stroke="currentColor" stroke-width="1.6" stroke-linecap="round" '
    'stroke-linejoin="round" aria-hidden="true">'
    '<path d="M12 19V5"/><path d="M5 12l7-7 7 7"/></svg>';

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

/// The sticky bar: the trail on the left, up and the layout switcher on the
/// right.
///
/// One element, edge to edge — background and contents both. The bar is chrome:
/// sized by the window, never by the text under it, which is what keeps the
/// controls still when a reader switches layout. Reasoning in `.toolbar`.
///
/// Three flex items in one contract: [breadcrumb] is the elastic one and the
/// only one that may shrink, [upLink] and the layout group are pinned. Nothing
/// here is centred, so a long trail costs the controls nothing — it costs
/// itself, by ellipsis.
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
///
/// **The search trigger is on every page too, and is not gated.** It is the
/// site's only way to reach a node that is not an ancestor, a child or a
/// neighbour of the one you are on — the job P3.5's navigator used to do — so a
/// page without it is a page a reader can only leave by climbing. It sits
/// between [upLink] and the layout group because the two before it navigate and
/// the group after it does not.
String toolbar({
  required bool withLayouts,
  required SiteAssets assets,
  List<TipitakaNode> trail = const <TipitakaNode>[],
  TipitakaNode? current,
  TipitakaNode? parent,
}) {
  final buffer = StringBuffer('<div class="toolbar">');
  // Defaults render `/`'s bar: the emblem alone in a trail with nowhere to
  // climb. That is the same markup every other page carries, minus segments —
  // not a second bar shape with a branch guarding it.
  buffer.write(breadcrumb(assets: assets, trail: trail, current: current));
  if (parent != null) buffer.write(upLink(parent));
  buffer.write(searchTrigger());
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
