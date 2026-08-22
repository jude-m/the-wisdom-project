import 'entry_renderer.dart';
import 'search_dialog.dart';
import 'site_assets.dart';

/// The `<head>` every page on the site shares, and the `<html>`/`<body>`
/// around it.
///
/// Extracted when the landing page arrived (P3). The five things in this head
/// are a contract — charset, viewport, canonical, the one stylesheet, the
/// generator stamp — and P5 adds OG and JSON-LD to all of them at once. A
/// second copy for `/` would be a second place to forget.
///
/// [origin] is the scheme and host this build is being uploaded to, without a
/// trailing slash — `bin/generate.dart` validates it and strips one, so every
/// caller may concatenate a root-relative path onto it without checking first.
///
/// [canonical] is the page's **root-relative path**; the URL the tag carries is
/// [origin] + that. Relative was the shipping form through P4, because the apex
/// domain is not settled and a wrong absolute canonical points every page at a
/// host that does not serve it. The origin is now an *input* rather than a
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
/// [assets] is passed in rather than written here because every URL in it
/// carries a hash of the bytes behind it ([SiteAssets]) — the head cannot know
/// those, and the one caller that builds them can. Threaded like
/// [generatorVersion]: one value, decided once per build, handed to both
/// templates.
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
  required String origin,
  required String? canonical,
  required String generatorVersion,
  required SiteAssets assets,
  required String body,
  String head = '',
}) {
  return '''
<!DOCTYPE html>
<html lang="si">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(title)}</title>${canonical == null ? '' : '\n<link rel="canonical" href="$origin$canonical">'}
<link rel="stylesheet" href="${assets.stylesheet}">
<meta name="generator" content="wisdom-ssg $generatorVersion">
$head</head>
<body>
$body${searchDialog(assets.searchIndex)}
${siteScript(assets.script)}
</body>
</html>
''';
}

/// `defer` rather than `async`: the script touches the layout radios, and the
/// two behave identically for a script this size except that `defer` guarantees
/// the DOM is parsed, which saves a `DOMContentLoaded` listener.
String siteScript(String url) => '<script src="$url" defer></script>';
