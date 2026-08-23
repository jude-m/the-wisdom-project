/// `_headers` — the response headers Pages applies to paths the defaults get
/// wrong.
///
/// Cloudflare Pages reads this file from the root of the upload, applies it to
/// matching responses, and does not serve the file itself.
///
/// Almost all of it is caching, which is why it was `cache_headers.dart` until
/// `.manifest.json` needed an `X-Robots-Tag` (backlog C3). The subject was
/// always this one file rather than one header in it.
///
/// ## What the caching rules are for
///
/// Pages' default on every response is `public, max-age=0, must-revalidate`
/// (measured on the dev deployment, 2026-08-15). The bytes land in the
/// browser's cache, but the browser must ask the edge "still valid?" before
/// reusing them — a conditional request, a `304`, and a full round trip. Every
/// link on this site is a whole new document, so **each page view pays that
/// round trip for the stylesheet, the script, the emblem and every WOFF2 face
/// it uses** (8 faces, 328 KB, 2–4 per page), none of which changed between one
/// sutta and the next. On the slow connections this surface exists for, that is
/// the difference between a page that renders and a page that waits.
///
/// The HTML keeps the default and must: a page's URL is stable while its
/// content is not, so a reader who returns to a sutta has to get the current
/// one.
///
/// ## One tier, because every URL here carries a hash
///
/// A year of `immutable` is only safe when a new file arrives under a new URL,
/// and [SiteAssets] makes that true of all five — the stylesheet, the script,
/// the search index, the emblem, and the font faces through the `@font-face`
/// rules in the stylesheet. None of them can go stale: a changed file is a
/// changed URL, and an unchanged one is not worth revalidating.
///
/// This used to be two tiers. The emblem and the fonts had no version, so they
/// got a week of `max-age` — long enough to skip revalidating across one
/// sitting, short enough to bound the wait for a corrected font face. Hashing
/// them retired the compromise and, with it, the second tier and the three
/// exact-path rules that kept the two apart.
///
/// ## The two rules that are not about caching
///
/// Both say the same thing about a root-level file written for a machine: it
/// belongs in the upload, and it does not belong in a result page.
///
/// `.manifest.json` is the source → output map with a content hash per source.
/// It is nothing secret and nothing links to it, but it has to stay in the
/// upload — `_clearOutputDir` reads it as the marker that says a directory is a
/// previous build of this site — and it answers `200` to anyone who asks
/// (measured on the dev deployment, 2026-08-15, 595 KB). `X-Robots-Tag` keeps
/// it out of search results without taking it out of the build, which a
/// deletion would.
///
/// `sitemap.xml` is the same shape and gets the same header. It is *linked*,
/// by `robots.txt`, which is the whole reason it exists — and the header does
/// not touch that: `noindex` governs whether a URL may appear in results, not
/// whether a crawler may fetch and act on the file, and a sitemap is consumed
/// rather than indexed. What it prevents is the file itself surfacing as a
/// result for a site: query, which is a page of raw XML offered to a reader
/// who wanted the canon.
///
/// ## Rules must not overlap
///
/// > An incoming request which matches multiple rules' URL patterns will
/// > inherit all rules' headers.
///
/// — and where two matched rules set the *same* header, Pages joins the values
/// with a comma. A `/assets/*` blanket beside a `/assets/emblem.png` exception
/// would therefore not override anything; it would emit
/// `Cache-Control: public, max-age=31536000, immutable, public, max-age=604800`
/// and leave the real policy to whatever the browser makes of that. The two
/// patterns below are disjoint, which is the only reason the file is this
/// short. A future rule setting a *different* header (`Content-Security-Policy`
/// on `/*`, say) can safely span both.
library;

import '../manifest/build_manifest.dart';
import 'site_assets.dart';
import 'sitemap.dart';
import 'web_fonts.dart';

/// Path under the output directory. Root of the upload, not `assets/`.
const String siteHeadersOutputPath = '_headers';

/// A year, the conventional ceiling. Safe for every path below because each one
/// is versioned by content.
const String _immutable = 'public, max-age=31536000, immutable';

/// Built from the same constants the rest of the build writes and links, so a
/// renamed asset cannot leave a rule pointing at a path nothing is served from.
///
/// Two wildcards rather than five exact paths. Exact paths were the safer shape
/// while `assets/` held a mix of versioned and unversioned files and a wildcard
/// could not tell them apart; now that everything under both directories is
/// versioned, naming them one by one would only be five chances to forget the
/// sixth.
String buildSiteHeaders() {
  // Whole header lines rather than values, because the rules no longer set one
  // header between them. A map keyed by path is still the right shape: it is
  // the key Pages matches on, and two entries for one path would be the
  // overlap the section above warns about — here the compiler refuses it.
  const rules = <String, List<String>>{
    '/$assetsOutputDir/*': ['Cache-Control: $_immutable'],
    '/$fontsOutputDir/*': ['Cache-Control: $_immutable'],
    '/$manifestOutputPath': ['X-Robots-Tag: noindex'],
    '/$sitemapOutputPath': ['X-Robots-Tag: noindex'],
  };

  final out = StringBuffer();
  out.writeln('# GENERATED by wisdom-ssg — see lib/render/site_headers.dart.');
  out.writeln('# Pages consumes this file; it is never served.');
  out.writeln('# Every cached path below carries a ?v=<hash of its bytes>,');
  out.writeln('# so a changed file is a changed URL — see site_assets.dart.');
  out.writeln('# HTML is deliberately absent: it keeps Pages\' default');
  out.writeln(
      '# `max-age=0, must-revalidate`, because a page\'s URL is stable');
  out.writeln('# while its content is not.');
  for (final rule in rules.entries) {
    out.writeln();
    out.writeln(rule.key);
    for (final header in rule.value) {
      out.writeln('  $header');
    }
  }
  return out.toString();
}
