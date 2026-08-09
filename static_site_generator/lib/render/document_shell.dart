import 'entry_renderer.dart';

/// The `<head>` every page on the site shares, and the `<html>`/`<body>`
/// around it.
///
/// Extracted when the landing page arrived (P3). The five things in this head
/// are a contract — charset, viewport, canonical, the one stylesheet, the
/// generator stamp — and P5 adds OG and JSON-LD to all of them at once. A
/// second copy for `/` would be a second place to forget.
///
/// [canonical] is left **root-relative** on purpose. The absolute form is the
/// usual recommendation, but the apex domain is not settled yet and a wrong
/// absolute canonical points every page at a host that does not serve it.
/// Relative is legal and resolved against the document URL; revisit when the
/// domain is fixed at the P5 hosting gate.
///
/// [head] carries whatever the page adds to the contract above, already
/// newline-terminated.
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
  required String canonical,
  required String generatorVersion,
  required String body,
  String head = '',
}) {
  return '''
<!DOCTYPE html>
<html lang="si">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(title)}</title>
<link rel="canonical" href="$canonical">
<link rel="stylesheet" href="/assets/site.css">
<meta name="generator" content="wisdom-ssg $generatorVersion">
$head</head>
<body>
$body</body>
</html>
''';
}
