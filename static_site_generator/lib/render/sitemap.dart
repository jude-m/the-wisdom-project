import 'package:wisdom_shared/wisdom_shared.dart';
import 'entry_renderer.dart';
import 'landing_page.dart';

/// Path under the output directory. Flat at the root, which is where a crawler
/// looks and where `robots.txt` points.
const String sitemapOutputPath = 'sitemap.xml';

/// `sitemap.xml` — every page in the build, named once.
///
/// ## Why it is worth the file
///
/// Until this existed, discovery depended entirely on Google walking the TOC
/// chain down from `/`. That works, eventually, and it means the depth of a
/// sutta in the tree decides how long it waits to be found — which has nothing
/// to do with how much anyone wants to read it. A sitemap makes every page in
/// the corpus one hop from the crawler's queue.
///
/// ## One entry per file, from the plan
///
/// `SitePlan.pages` is exactly the right list and needs no filtering: one entry
/// per file the build writes under `/tipitaka/`, with the folded leaves
/// (`FIGURES.foldedLeaves`) already absent, because they are `#fragment`s
/// inside a chapter and not URLs of their own. Naming them would be naming
/// addresses that answer `404`.
///
/// Iterated as the `List` it is, never through a `Map`, for the reason
/// `search_index.dart` gives: two builds of one corpus have to produce
/// identical bytes or Cloudflare re-uploads the site (§11.8).
///
/// `/` is added by hand because it is not in the plan — it has no node. Total
/// is `FIGURES.realPages`, well under the protocol's 50,000-URL and 50 MB
/// ceilings, so this stays one file with no index above it.
///
/// **`404.html` is not in it**, and cannot be: it has no entry in the plan, no
/// URL of its own that means anything, and a `noindex` on the file itself.
///
/// ## No `<lastmod>`, and that is a decision
///
/// The build plan asked for one "from manifest hashes". That does not survive
/// contact with the manifest: it holds FNV-1a *content hashes* and, by §11.8,
/// carries no date anywhere — deliberately, since a timestamp would rewrite
/// every file on every build. A hash answers "did this change", never "when",
/// and `<lastmod>` is a W3C datetime.
///
/// The one date on hand is `bjt-provenance.json`'s single `synced_on`, which
/// would stamp all `FIGURES.realPages` URLs with the same day — the
/// uninformative signal Google discounts, and being discounted for lying is
/// worse than being believed for saying nothing. Omitted until a second corpus
/// sync gives per-file dates worth publishing.
///
/// Nothing else optional is here either. `<changefreq>` and `<priority>` are
/// ignored by every major crawler and have been for years.
String buildSitemap({required String origin, required SitePlan plan}) {
  final out = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');

  // The front door first, then the corpus in reading order — the same order
  // `/`'s own list and every prev/next chain already use. A sitemap's order
  // carries no meaning to a crawler; it carries a lot to whoever reads the diff
  // of one.
  _url(out, origin, LandingPage.url);
  for (final page in plan.pages) {
    _url(out, origin, page.url);
  }

  out.writeln('</urlset>');
  return out.toString();
}

/// The protocol requires entity-escaping in `<loc>`, and [escapeHtml] is that
/// escaping.
///
/// The same five characters, and the one difference is spelling: it writes `'`
/// as `&#39;` where XML documents usually show `&apos;`. Both are correct —
/// a numeric character reference is valid in every XML parser, and `&apos;` is
/// the one of the five predefined entities HTML got late. Writing a second
/// five-line escaper to change that would be two functions answering one
/// question, and this one already carries a compiled fast path that skips the
/// four `replaceAll`s on the URLs — which is all of them — containing none of
/// the characters.
///
/// It escapes nothing today: a nodeKey is `[a-z0-9.-]` and the origin is
/// validated in `bin/generate.dart`. It is called because the alternative is an
/// invisible dependency on that staying true through the next upstream re-sync,
/// and an unescaped `&` does not make a malformed sitemap loud — it makes it
/// unparseable, all at once, for every URL after the first bad one.
void _url(StringBuffer out, String origin, String path) {
  out.writeln('<url><loc>${escapeHtml('$origin$path')}</loc></url>');
}
