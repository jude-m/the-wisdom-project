import 'package:wisdom_shared/wisdom_shared.dart';

import 'document_shell.dart';
import 'site_chrome.dart';

/// The site's front door — `/`, the one page outside the `/tipitaka/<nodeKey>`
/// grammar.
///
/// ## Why it exists at all
///
/// The first dev deploy (2026-08-03) shipped 14,752 pages and had no front door:
/// `/` returned 404, and so did the first thing anyone tries next, `/<nodeKey>`.
/// The URL wrangler prints is the origin, so the deploy could not be clicked
/// through at all — `deploy.sh` printed a hand-picked `entry` URL as a stopgap,
/// gated on this file not existing yet. That stopgap is gone: the origin is now
/// the URL to smoke-test on every build shape, which is what [roots] is for.
///
/// ## It is a container TOC, not a page shape of its own
///
/// P3 built this as the app's empty reader state: an emblem hero on one side, a
/// pruned `<details>` tree on the other. That tree was withdrawn with the rest of
/// the rail (P3.5), and rebuilding a second, tree-shaped front page for its own
/// sake would have been the wrong lesson to draw. So `/` is now exactly what
/// every container in the corpus already is — a heading and a list of children —
/// with the build's roots as the children. One page shape for the whole site,
/// one list markup for the stylesheet to style.
///
/// It keeps its own `<h1>` and its own canonical rather than pointing at
/// `/tipitaka/sp`: `/` is the highest-value page on the site for search, and a
/// canonical aimed elsewhere is a page that never ranks. P5 hangs OG and JSON-LD
/// here first.
class LandingPage {
  /// The subtrees this build wrote, in walk order — every one of them a page
  /// that is in the upload.
  ///
  /// Not `tree.roots`. On a whole-corpus build the two are the same seven, but
  /// `--root anya` writes one subtree and the unfiltered list would put six
  /// dead links on the front page of the dev preview it was built for.
  final List<TipitakaNode> roots;

  final String generatorVersion;

  const LandingPage({required this.roots, required this.generatorVersion});

  /// Written flat at the site root, so its URL is `/`.
  static const String outputPath = 'index.html';

  static const String url = '/';

  String render() {
    final body = StringBuffer();
    // No layout radios — nothing here is readable text, and per P2's mechanism
    // that absence needs no CSS: with no radio checked, none of the
    // `#L-x:checked ~` rules match.
    body.writeln(toolbar(withLayouts: false));
    // `nav`, for the same reason a container TOC gets it: a heading, a hint and
    // a list of links, with no running text to set a measure for.
    body.writeln('<main class="content nav">');
    // The site's only page with no node to name it, so its heading has to be
    // written rather than derived. Without one, `/` is the highest-value page on
    // the site for search and the only one with no heading at all.
    body.writeln('<h1 class="page-title">$_title</h1>');
    body.writeln('<p class="landing-hint">$_hint</p>');
    // Roots, not `childrenOf` — `/` has no node above it. On a whole-corpus
    // build these are `vp` `sp` `ap` `atta-vp` `atta-sp` `atta-ap` `anya`, in
    // the order `tree.json` declares them, which is pinned by document order
    // (§11.8).
    body.writeln(tocList(roots));
    body.writeln('</main>');

    return htmlDocument(
      title: _title,
      canonical: url,
      generatorVersion: generatorVersion,
      body: body.toString(),
    );
  }
}

/// The app's `statusSelectSuttaToRead` (`app_si.arb:186`).
///
/// **Not** the near-identical `selectNodeToRead` (`app_si.arb:28`), which says
/// සංචාලකයෙන් where this says ව්‍යූහයෙන් and belongs to a different empty state.
/// Two strings one word apart is exactly the trap the "strings come from the
/// app" rule exists to catch, so the wrong one would have looked right.
const String _hint = 'කියවීම ආරම්භ කිරීමට ව්‍යූහයෙන් සූත්‍රයක් තෝරන්න';

/// The app's `appTitle` (`app_si.arb:4`).
///
/// Bare for now. `/` is the highest-value page on the site for SEO — its
/// `<title>`, description and OG matter more than any single sutta's — and P5 is
/// where that gets decided properly, together with the `<title>` grammar the
/// rest of the site already follows.
const String _title = 'ප්‍රඥා ව්‍යාපෘතිය';
