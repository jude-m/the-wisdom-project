import 'package:wisdom_shared/wisdom_shared.dart';

import 'document_shell.dart';
import 'page_description.dart';
import 'site_build.dart';
import 'site_chrome.dart';

/// The site's front door — `/`, the one page outside the `/tipitaka/<nodeKey>`
/// grammar.
///
/// ## Why it exists at all
///
/// The first dev deploy (2026-08-03) shipped the whole corpus and had no front
/// door: `/` returned 404, and so did the first thing anyone tries next,
/// `/<nodeKey>`.
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
///
/// ## `404.html` is this same page
///
/// [LandingPage.notFound] renders the not-found page, because a wrong address
/// wants exactly what the front door offers: the roots, and a way in. Building
/// it as a second class would have been a second copy of a heading, a hint, a
/// list and a toolbar, kept in step by hand.
///
/// Three things differ, and all three follow from Cloudflare serving this
/// file's bytes back at whatever address was asked for:
///
/// - **a different `<h1>`**, because the reader needs to know the address was
///   wrong before they are offered somewhere else to go;
/// - **no canonical**, since one here would speak for every URL the site does
///   not have (see [htmlDocument]);
/// - **`noindex`**, which is not about the 404 responses — a `404` is already
///   uncrawlable — but about `/404.html` itself, which is a real file in the
///   upload and answers `200` to anyone who asks for it by name.
class LandingPage {
  /// The subtrees this build wrote, in walk order — every one of them a page
  /// that is in the upload.
  ///
  /// Not `tree.roots`. On a whole-corpus build the two are the same seven, but
  /// `--root anya` writes one subtree and the unfiltered list would put six
  /// dead links on the front page of the dev preview it was built for.
  final List<TipitakaNode> roots;

  /// The values that are the same on every page — see [SiteBuild].
  ///
  /// Its resolver is the identity here: a root is always a container and so
  /// always owns its own page. Used anyway rather than reaching for
  /// [tipitakaUrl], because [tocList] takes one resolver for both callers and a
  /// second answer to "what is a link" is how the two lists drift apart.
  final SiteBuild build;

  /// Whether this is the not-found page rather than the front door. See the
  /// class comment for the three things it changes and why each one follows
  /// from how Cloudflare serves `404.html`.
  final bool isNotFound;

  const LandingPage({
    required this.roots,
    required this.build,
  }) : isNotFound = false;

  /// `404.html` — the same page under a heading that says the address was
  /// wrong.
  const LandingPage.notFound({
    required this.roots,
    required this.build,
  }) : isNotFound = true;

  /// Written flat at the site root, so its URL is `/`.
  static const String outputPath = 'index.html';

  /// Cloudflare Pages serves this file for any path the upload has no file
  /// for, with a real `404` status. **Without it Pages falls back to
  /// `index.html` and answers `200`** — every typo'd and stale inbound link
  /// then returns the landing page as though it were the page asked for, which
  /// Google reads as a soft 404 across the whole address space
  /// (`FIGURES.pagesWithStubs` of them). Measured on the dev deployment
  /// 2026-08-03; backlog A1.
  ///
  /// Flat at the root and named exactly this: Pages looks for `/404.html` and
  /// nothing else.
  static const String notFoundOutputPath = '404.html';

  static const String url = '/';

  String render() {
    final body = StringBuffer();
    // No layout radios — nothing here is readable text, and per P2's mechanism
    // that absence needs no CSS: with no radio checked, none of the
    // `#L-x:checked ~` rules match.
    body.writeln(toolbar(withLayouts: false, assets: build.assets));
    // `nav`, for the same reason a container TOC gets it: a heading, a hint and
    // a list of links, with no running text to set a measure for.
    body.writeln('<main class="content nav">');
    // The site's only page with no node to name it, so its heading has to be
    // written rather than derived. Without one, `/` is the highest-value page on
    // the site for search and the only one with no heading at all.
    //
    // [siteName] and not a name of its own. The rest of the site titles itself
    // `<leaf> — <vagga> — <collection>` because a bare name would repeat across
    // `FIGURES.realPages` pages; `/` has no ancestors to disambiguate it
    // against, and is the one page whose name *is* the whole site's name — the
    // same string `og:site_name` carries everywhere else.
    final title = isNotFound ? _notFoundTitle : siteName;
    body.writeln('<h1 class="page-title">$title</h1>');
    // The same hint under both headings, and it is the right sentence twice:
    // what follows is the list of roots either way, and the reader's next move
    // is the same one.
    body.writeln('<p class="landing-hint">$_hint</p>');
    // Roots, not `childrenOf` — `/` has no node above it. On a whole-corpus
    // build these are `vp` `sp` `ap` `atta-vp` `atta-sp` `atta-ap` `anya`, in
    // the order `tree.json` declares them, which is pinned by document order
    // (§11.8).
    body.writeln(tocList(roots, urlFor: build.urlFor));
    body.writeln('</main>');

    return htmlDocument(
      title: title,
      build: build,
      canonical: isNotFound ? null : url,
      // None on the not-found page, for the same reason it sends no canonical:
      // Cloudflare serves these bytes at every address the site has no file
      // for, so a description here is a sentence written on behalf of URLs
      // nobody has seen. The `noindex` below is the whole answer.
      description:
          isNotFound ? null : const PageDescription.written(_description),
      // The one page on the site that is the site rather than a document in it,
      // which is the whole of `og:type`'s question. `404.html` never reaches
      // the branch — it has no canonical, so it emits no Open Graph at all.
      isFrontDoor: true,
      head: isNotFound ? '<meta name="robots" content="noindex">\n' : '',
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

/// The one description on the site that is written rather than generated.
///
/// `/` is the highest-value page here for search — it is what `sitemap.xml`
/// names as the entry and what an unqualified query for the site should land
/// on — so it gets a sentence about the whole corpus instead of the
/// per-page grammar in `page_description.dart`, which has a node to describe
/// and this page does not.
///
/// Assembled from what tipitaka.lk's Welcome page says about this exact
/// material — *"ශ්‍රී ලංකා තිපිටක පෙළ, අටුවා සහ සිංහල පරිවර්තනය"*
/// (`src/views/Welcome.vue`) — because the two sites are describing the same
/// books and should not invent separate vocabulary for them. `අට්ඨකථා` rather
/// than upstream's `අටුවා`, per the site-wide rule that every node is named by
/// the tree's Pali field.
const String _description = 'බුද්ධ ජයන්ති තිපිටකයේ පාළි පෙළ, අට්ඨකථා සහ '
    'සිංහල පරිවර්තනය. සම්පූර්ණ ත්‍රිපිටකය සහ අට්ඨකථා නොමිලේ කියවන්න.';

/// The app's `statusNoTreeContent` (`app_si.arb:190`) — "no content available",
/// which is what a missing address has.
///
/// Taken from the app rather than composed, under the same rule as [_hint]: a
/// string this site shows a reader is one the app already says somewhere, so
/// the two surfaces cannot end up phrasing the same idea two ways. Nothing in
/// the app or in the tipitaka.lk source says "page not found" — neither has an
/// address bar to get wrong — so this is the nearest thing either of them
/// asserts, and it is true of a wrong URL.
const String _notFoundTitle = 'අන්තර්ගතයක් නොමැත';
