import 'entry_renderer.dart';
import 'page_description.dart';
import 'search_dialog.dart';
import 'site_build.dart';

/// The `<head>` every page on the site shares, and the `<html>`/`<body>`
/// around it.
///
/// Extracted when the landing page arrived (P3), because `/` needs the same
/// head as every sutta and a second copy of it is a second place to forget.
/// What that head holds is a contract — charset, viewport, title, description,
/// canonical, the one stylesheet, the generator stamp — and P5 grew it from
/// five to this by hanging the whole SEO surface off the same parameters,
/// which is the alternative to two templates each remembering a meta tag.
///
/// [description] is raw text in both its forms; the shell escapes it, as it
/// does [title]. Null emits no tag at all — `pageDescription` in
/// `page_description.dart` is what decides that, and it is deliberately not
/// defaulted to the empty string here: an empty `content` attribute is a worse
/// signal to a crawler than an absent element.
///
/// [build] carries the values that are the same on every page — see
/// [SiteBuild], and why they arrive as one field rather than separately.
///
/// [canonical] is the page's **root-relative path**; the URL the tag carries is
/// the origin + that. Relative was the shipping form through P4, because the
/// apex domain is not settled and a wrong absolute canonical points every page
/// at a host that does not serve it. The origin is now an *input* rather than a
/// constant — `--origin`, passed by `deploy.sh` from the target it is actually
/// uploading to — which lets the tag do the one job a canonical exists for:
/// naming which of several hosts serving identical bytes is the real one.
/// Relative can never do that, however legal it is.
///
/// It also settles `?e=`, the entry-level coordinate the app's deep links carry
/// (`deep-linking-and-shareable-urls.md`). Nothing in this generator reads that
/// query and no page emits per-entry ids, so `…/an-1-1?e=12.4` is the same
/// bytes answering at a second address. A self-canonical folds it onto the
/// clean one. There was never any code to write for it — only this.
///
/// It is **nullable for exactly one page**, and the reason is the shape of the
/// only page that is not a page. Cloudflare serves `404.html`'s bytes back at
/// whatever address was asked for, so a canonical in them is a claim made on
/// behalf of every URL the site does not have: pointing it at `/` is the soft
/// 404 that file exists to end, and pointing it at `/404.html` aims every one
/// of them at a `noindex` page, which is two signals contradicting each other.
/// The HTTP status is the whole answer there, so that page sends no canonical
/// at all. Every page that *is* a page passes one, and the parameter stays
/// required-by-convention: it has no default.
///
/// The omission is written as an escaped `\n` inside a single-quoted string
/// rather than the triple-quoted form it reads more naturally in. Dart drops
/// the newline that immediately follows `'''`, so the natural spelling silently
/// welds the canonical onto the `<title>` line — on every page in the corpus,
/// which is a full re-upload of a site that is deployed hash-incrementally, for
/// a line break.
///
/// [head] carries whatever the page adds to the contract above, already
/// newline-terminated.
///
/// ## The search dialog and `site.js` close every body
///
/// Both are byte-identical on every page (`FIGURES.realPages`), so they belong
/// to the shell for the same reason the five head lines do: the alternative is
/// `page_template` and `landing_page` each remembering to append them, which is
/// two places to forget and one of them is the front page.
///
/// The script is **not** a search script — it resolves `?layout=` too — which
/// is why it is named and owned here rather than in `search_dialog.dart`.
///
/// **Last in the body, after `</main>`.** A `<dialog>` renders in the top layer
/// once `showModal()` runs, so its position in the DOM decides nothing visual —
/// but it decides two other things. It must not come between the layout radios
/// and `.toolbar`/`.content`: every layout rule is a sibling combinator off
/// those radios, and only their *order* keeps it matching. And it must not
/// precede `<main>` in the tab order, where an empty dialog's field would be
/// the first thing a keyboard reader meets on a page of scripture.
///
/// There is deliberately no `bodyClass` hook. P3 had one, for the single rule
/// that widened `/`'s reading column to hold its two-column hero; P3.5 made `/`
/// an ordinary container TOC and that rule went with the hero, leaving a class
/// on `<body>` that no selector matched. Every page shape the site emits is now
/// distinguished by what is *in* it — layout radios or not, a `.toc` list or
/// rows of text — which is what the stylesheet already keys off. The toolbar is
/// not one of those signals and cannot become one: every page carries it, `/`
/// included, trail and all.
String htmlDocument({
  required String title,
  required SiteBuild build,
  required String? canonical,
  required PageDescription? description,
  required String body,
  bool isFrontDoor = false,
  String head = '',
}) {
  final assets = build.assets;
  // Built above the template rather than interpolated into it. Three optional
  // head lines were already at the edge of readable as inline conditionals on
  // the `<title>` line, and Open Graph is six more; a page whose `<head>` is
  // wrong is debugged by reading this file.
  final meta = StringBuffer('<title>${escapeHtml(title)}</title>');
  if (description != null) {
    meta.write('\n<meta name="description" '
        'content="${escapeHtml(description.snippet)}">');
  }
  if (canonical != null) {
    final url = build.absolute(canonical);
    meta.write('\n<link rel="canonical" href="$url">');
    meta.write(_openGraph(
      title: title,
      // The card's form, not the snippet's: `og:title` is written one line
      // above and a subtitle repeating it verbatim is the failure the two
      // forms exist to avoid. See [PageDescription].
      subtitle: description?.subtitle,
      url: url,
      imageUrl: build.absolute(assets.ogCard),
      isFrontDoor: isFrontDoor,
    ));
  }

  return '''
<!DOCTYPE html>
<html lang="si">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
$meta
<link rel="stylesheet" href="${assets.stylesheet}">
<meta name="generator" content="wisdom-ssg ${build.generatorVersion}">
$head</head>
<body>
$body${searchDialog(assets.searchIndex)}
${siteScript(assets.script)}
</body>
</html>
''';
}

/// The site's own name, for `og:site_name` and for `/`'s `<title>`.
///
/// The app's `appTitle` (`app_si.arb`), under the rule every string on this
/// surface follows: a name the app already says is not re-invented here.
const String siteName = 'ප්‍රඥා ව්‍යාපෘතිය';

/// Open Graph — what a pasted link looks like in a message.
///
/// **Not a ranking signal.** Google reads none of this. It matters because this
/// audience shares in WhatsApp and Facebook, where a link with no OG tags
/// renders as a bare URL and one with them renders as a card carrying the
/// sutta's name.
///
/// Gated on [canonical] rather than on a flag of its own, which is what keeps
/// `404.html` out: that file's bytes are served at every address the site has
/// no page for, so an `og:url` in them would be a claim made on behalf of URLs
/// nobody has seen — the same reason it sends no canonical. One condition, two
/// tags that must agree, no way to set one without the other.
///
/// `og:title` is the un-welded `<title>` string (D2). Every reference here
/// agrees with the tag beside it because all three are the *same variables*,
/// not three lookups of the same idea.
///
/// [subtitle] is **not** the `<meta name="description">` string. That one opens
/// on the title, which is right under a search result and wrong here: a card
/// draws `og:title` in bold and this directly beneath it, so the snippet's form
/// renders as a subtitle repeating its own heading word for word before adding
/// anything. Null when the page has nothing to add past its own name, and then
/// the tag is omitted rather than emitted empty.
///
/// Deliberately absent:
///
/// - **`og:image:width` / `:height`.** They let a scraper lay the card out
///   before it has fetched the image, which is worth something on a first
///   share — and it costs the card's dimensions being written in Dart as well
///   as in `make_emblem.sh`, where they are already decided. Two places to
///   disagree about one picture, on every page in the build, to save one
///   fetch that happens once per URL ever shared.
/// - **Twitter Card tags.** X falls back to Open Graph.
String _openGraph({
  required String title,
  required String? subtitle,
  required String url,
  required String imageUrl,
  required bool isFrontDoor,
}) {
  final tags = StringBuffer();
  tags.write('\n<meta property="og:type" content="'
      // `website` is the whole site; `article` is a document within it. `/`
      // is the only page here that is the former.
      '${isFrontDoor ? 'website' : 'article'}">');
  tags.write('\n<meta property="og:title" content="${escapeHtml(title)}">');
  if (subtitle != null) {
    tags.write('\n<meta property="og:description" '
        'content="${escapeHtml(subtitle)}">');
  }
  tags.write('\n<meta property="og:url" content="$url">');
  tags.write('\n<meta property="og:image" content="$imageUrl">');
  tags.write(
      '\n<meta property="og:site_name" content="${escapeHtml(siteName)}">');
  // Sinhala as written in Sri Lanka. The `<html lang>` above says `si`, which
  // is the language; Open Graph's locale is a language *and* a territory, and
  // there is only one that prints this canon.
  tags.write('\n<meta property="og:locale" content="si_LK">');
  return tags.toString();
}

/// `defer` rather than `async`: the script touches the layout radios, and the
/// two behave identically for a script this size except that `defer` guarantees
/// the DOM is parsed, which saves a `DOMContentLoaded` listener.
String siteScript(String url) => '<script src="$url" defer></script>';
