import 'dart:io';

/// Every link the built site writes, resolved against the files on disk: each
/// internal `href`, `src`, `url()`, URL-shaped `data-*` and `sitemap.xml`
/// `<loc>` against a real file, and each `#fragment` against the ids on the
/// page it names. Exits 1 on any failure, so it can gate a deploy.
///
/// The fragments are the load-bearing half. A folded leaf is served as
/// `<chapter>#<key>`, so a fragment naming nothing is a sutta with no way in —
/// and nothing else notices, because the chapter still renders, the HTML is
/// still valid and the page still hashes the same.
///
/// Why this is Dart rather than a Node crawler, and why it is not in
/// `dart test`, are in docs/todo/web-strategy/static-html-site-build-plan.md.
///
///     dart run static_site_generator/tool/check_links.dart
///     dart run static_site_generator/tool/check_links.dart --build <dir>
void main(List<String> args) {
  final options = _parseArgs(args, const {'--build', '--origin'});
  if (options == null) {
    exitCode = 1;
    return;
  }

  final rootPath = _normalize(options['--build'] ?? '$_packageRoot/build');
  if (!Directory(rootPath).existsSync()) {
    stderr.writeln('no build directory at $rootPath. Generate one first, or '
        'pass --build <dir>.');
    exitCode = 1;
    return;
  }
  stdout.writeln('build   $rootPath\n');

  // Fatal rather than assumed. With no origin every absolute URL on the site —
  // the canonical and og:url on every page, and every sitemap <loc> — is filed
  // as somebody else's and skipped, which is a quieter and much smaller check
  // than the one that was asked for.
  final String? origin;
  final originFlag = options['--origin'];
  if (originFlag != null) {
    origin = _normalizeOrigin(originFlag);
    if (origin == null) {
      stderr.writeln('--origin needs a scheme and a host, as in '
          'https://sammaditthi.net. Got: $originFlag');
      exitCode = 1;
      return;
    }
  } else {
    origin = _detectOrigin(rootPath);
  }
  if (origin == null) {
    stderr.writeln('no origin: $rootPath/index.html carries no canonical, so '
        'the site\'s own absolute URLs cannot be told from anyone else\'s. '
        'Pass --origin https://<host> to say it outright.');
    exitCode = 1;
    return;
  }
  stdout.writeln('origin  $origin');

  final tree = _Tree.scan(rootPath);
  final report = _Report();
  final demands = <String, Map<String, String>>{};

  // Pass 1: every source file, once. Targets are resolved as they are found;
  // fragments are only *recorded*, because the file that has to answer for one
  // is usually not the file that asks.
  for (final from in tree.sources) {
    final text = File('$rootPath/$from').readAsStringSync();

    if (from.endsWith('.html')) {
      _duplicateIds(text).forEach((id, count) {
        report.duplicateIds['$from#$id'] = 'declared $count times';
      });
    }

    for (final raw in _urlsIn(from, text)) {
      report.links++;
      final link = _Link.parse(raw, origin: origin);

      if (link == null) continue; // mailto:, tel:, data: — nothing to resolve.
      if (link.isExternal) {
        report.externalHosts.add(link.host!);
        continue;
      }

      // A bare `#frag` asks its own file; everything else names a path.
      final target =
          link.path == null ? from : _resolve(link.path!, tree, from: from);
      if (target == null) {
        report.brokenTargets.putIfAbsent(raw, () => from);
        continue;
      }

      if (link.fragment == null) continue;
      // First asker wins: enough to name the defect, and it bounds the map on a
      // corpus where one anchor is linked from a whole chapter's worth of rows.
      demands
          .putIfAbsent(target, () => {})
          .putIfAbsent(link.fragment!, () => from);
    }
  }

  // Pass 2: only the files someone points a fragment at, read once each.
  final targets = demands.keys.toList()..sort();
  for (final target in targets) {
    final ids = _idsIn(File('$rootPath/$target').readAsStringSync());
    for (final demand in demands[target]!.entries) {
      report.fragments++;
      if (ids.contains(demand.key)) continue;
      report.missingFragments['$target#${demand.key}'] = demand.value;
    }
  }

  report.print();
  if (!report.passed) exitCode = 1;
}

/// Read off `Platform.script` — the URI of *this file* — so the default build
/// directory is the package's own, not whatever `build/` the working directory
/// happens to hold. `bin/generate.dart` and `tool/serve.dart` do the same.
final String _packageRoot = File.fromUri(Platform.script).parent.parent.path;

/// Accepts `--flag value` and `--flag=value`, and refuses anything else.
///
/// Both forms, because the sibling tools take both and the habit carries over.
/// Refuses, because an unrecognised flag that parses as "nothing was passed"
/// runs the gate over the default build and reports PASS — a green answer to a
/// question nobody asked.
Map<String, String>? _parseArgs(List<String> args, Set<String> known) {
  final values = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    final equals = arg.indexOf('=');
    final name = equals == -1 ? arg : arg.substring(0, equals);

    if (!known.contains(name)) {
      stderr.writeln('unknown option: $arg');
      stderr.writeln('known options: ${(known.toList()..sort()).join(', ')}');
      return null;
    }
    if (equals != -1) {
      values[name] = arg.substring(equals + 1);
    } else if (i + 1 < args.length) {
      values[name] = args[++i];
    } else {
      stderr.writeln('$name needs a value.');
      return null;
    }
  }
  return values;
}

/// Absolute, and without the trailing slash a shell completion adds — every
/// root-relative path in the report is cut from a full path using this as the
/// prefix, and `build//` matches none of them.
String _normalize(String path) {
  var absolute = Directory(path).absolute.path;
  while (absolute.length > 1 && absolute.endsWith(Platform.pathSeparator)) {
    absolute = absolute.substring(0, absolute.length - 1);
  }
  return absolute;
}

// ---------------------------------------------------------------------------
// The build, as a set of names
// ---------------------------------------------------------------------------

/// Every path in the build, read once. Resolution then asks this rather than
/// the filesystem, which is what makes it **case-exact**: APFS is
/// case-insensitive and Cloudflare Pages is not, so `existsSync` would clear a
/// `/SUB/page` that 404s in production.
class _Tree {
  const _Tree({
    required this.files,
    required this.directories,
    required this.sources,
  });

  /// Root-relative, exact case.
  final Set<String> files;
  final Set<String> directories;

  /// The files worth reading, sorted. `listSync` order is unspecified, and the
  /// report names the *first* file that asks for each offender — so without a
  /// sort, two runs over one build can attribute the same defect differently.
  final List<String> sources;

  static _Tree scan(String rootPath) {
    final files = <String>{};
    final directories = <String>{};
    for (final entity in Directory(rootPath).listSync(recursive: true)) {
      final relative = _relative(entity.path, rootPath);
      if (entity is File) {
        files.add(relative);
      } else if (entity is Directory) {
        directories.add(relative);
      }
    }
    return _Tree(
      files: files,
      directories: directories,
      sources: files.where(_isSource).toList()..sort(),
    );
  }
}

/// HTML, CSS and the sitemap. The fonts, images and JSON are link *targets*;
/// nothing in them points anywhere, and `search-index.json` alone is 2 MB of
/// text a reference regex has no business walking.
bool _isSource(String relative) =>
    relative.endsWith('.html') ||
    relative.endsWith('.css') ||
    relative == 'sitemap.xml';

// ---------------------------------------------------------------------------
// What a link is
// ---------------------------------------------------------------------------

/// One parsed reference: where it points, and whether we own it.
class _Link {
  const _Link({this.path, this.fragment, this.host});

  /// Null for a same-page `#fragment`, which asks the file it was found in.
  final String? path;
  final String? fragment;

  /// Set only when the URL names an origin that is not ours.
  final String? host;

  bool get isExternal => host != null;

  /// Returns null for a scheme with nothing on disk behind it.
  ///
  /// `Uri.parse` rather than string surgery, because it is the same normaliser
  /// a browser applies — it is what makes `?v=` a query rather than part of the
  /// filename, and what decodes a percent-escape back to the byte the file is
  /// actually named with.
  static _Link? parse(String raw, {required String origin}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } on FormatException {
      // Unparseable is not "external" — it is a link nobody can follow.
      return const _Link(path: '/__unparseable__');
    }

    if (uri.hasScheme && uri.scheme != 'http' && uri.scheme != 'https') {
      return null; // mailto:, tel:, data:, javascript:
    }

    final fragment = uri.fragment.isEmpty ? null : uri.fragment;
    if (uri.hasAuthority) {
      if ('${uri.scheme}://${uri.authority}' != origin) {
        return _Link(host: uri.authority, fragment: fragment);
      }
      // Our own absolute URL — the canonical, og:url and every sitemap <loc>.
      // An empty path is the landing page, which is what `/` resolves to.
      return _Link(path: uri.path.isEmpty ? '/' : uri.path, fragment: fragment);
    }

    return _Link(path: uri.path.isEmpty ? null : uri.path, fragment: fragment);
  }
}

// ---------------------------------------------------------------------------
// Extraction
// ---------------------------------------------------------------------------

final RegExp _htmlRef = RegExp(r'(?:href|src)="([^"]*)"');

/// `og:image` carries an asset URL that appears nowhere else on the page, and
/// P5 named it the one asset whose absence is invisible on the site itself —
/// only a link scraper ever asks for it. `og:url` rides along for free.
final RegExp _metaRef =
    RegExp(r'<meta[^>]+property="og:(?:image|url)"[^>]+content="([^"]*)"');

/// The one channel by which a URL reaches JavaScript. `site.js` holds no URLs
/// by rule, so the search index arrives as `data-index="/assets/…?v=<hash>"` —
/// a URL on every page that no `href` or `src` carries, and whose absence
/// breaks search in silence. Only URL-shaped values are taken; the other
/// `data-*` attributes hold Sinhala UI strings.
final RegExp _dataRef =
    RegExp(r'\sdata-[a-z-]+="(/[^"]*|https?://[^"]*)"');

final RegExp _cssRef = RegExp(r'''url\(\s*['"]?([^'")]+)['"]?\s*\)''');

/// The sitemap is the one file that tells a crawler a page exists. A `<loc>`
/// naming nothing is a page Google is invited to fetch and 404 on.
final RegExp _locRef = RegExp(r'<loc>([^<]*)</loc>');

final RegExp _idRef = RegExp(r'\sid="([^"]*)"');

Iterable<String> _urlsIn(String relative, String text) sync* {
  if (relative == 'sitemap.xml') {
    for (final match in _locRef.allMatches(text)) {
      yield _unescape(match.group(1)!);
    }
    return;
  }
  if (relative.endsWith('.css')) {
    for (final match in _cssRef.allMatches(text)) {
      yield match.group(1)!;
    }
    return;
  }
  for (final pattern in [_htmlRef, _metaRef, _dataRef]) {
    for (final match in pattern.allMatches(text)) {
      yield _unescape(match.group(1)!);
    }
  }
}

Set<String> _idsIn(String html) =>
    _idRef.allMatches(html).map((m) => _unescape(m.group(1)!)).toSet();

/// Ids the page declares more than once, and how many times.
///
/// Invisible to the fragment check — a duplicated anchor still resolves, so it
/// passes — but on a grouped chapter the id is what `:has(:target)` keys the
/// single-sutta view off, and a second declaration decides which sutta renders.
/// Invalid HTML besides. The ids are already in hand here.
Map<String, int> _duplicateIds(String html) {
  final counts = <String, int>{};
  for (final match in _idRef.allMatches(html)) {
    counts.update(_unescape(match.group(1)!), (n) => n + 1, ifAbsent: () => 1);
  }
  return counts..removeWhere((_, count) => count < 2);
}

/// Attribute values arrive HTML-escaped. `&amp;` is the one that changes a URL
/// — a query separator written as an entity resolves to a different file — and
/// it is replaced **last**, so that `&amp;lt;` decodes to the text `&lt;`
/// rather than being handed back to the `&lt;` rule and decoded twice.
String _unescape(String value) => value
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');

// ---------------------------------------------------------------------------
// Resolution — the Pages rule
// ---------------------------------------------------------------------------

/// URL path → the root-relative file that answers it, or null.
///
/// The three candidates are Cloudflare Pages' extensionless rule, which
/// `tool/serve.dart` models too. The two are deliberately not shared: that one
/// resolves an incoming *request* against the filesystem and models the
/// `.html` → 308 hop a browser follows, where this resolves an *authored* link
/// against the scanned tree, needs [from] to place a relative URL, and must be
/// case-exact. Same rule, different questions.
String? _resolve(String path, _Tree tree, {required String from}) {
  final segments = <String>[];
  if (!path.startsWith('/')) {
    // Relative, so it is resolved against the directory holding the document —
    // which is how the stylesheet's url("../fonts/…") reaches a font that does
    // not live under /assets/.
    segments.addAll(from.split('/')..removeLast());
  }
  for (final segment in path.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment != '..') {
      segments.add(segment);
      continue;
    }
    // A `..` that climbs out of the build is a broken link, not a file to open.
    if (segments.isEmpty) return null;
    segments.removeLast();
  }
  final relative = segments.join('/');

  // A URL ending in `/` names a directory rather than a page: `data-base`
  // carries `/tipitaka/`, a prefix the script appends a key to. No href on the
  // site ends this way — container TOCs are flat `<key>.html` — so this only
  // ever answers a data-* attribute.
  if (relative.isNotEmpty && path.endsWith('/')) {
    return tree.directories.contains(relative) ? relative : null;
  }

  final base = relative.isEmpty ? 'index' : relative;
  for (final candidate in [base, '$base.html', '$base/index.html']) {
    if (tree.files.contains(candidate)) return candidate;
  }
  return null;
}

/// The origin the build was generated with, read off the landing page's
/// canonical. Every page carries the same one (it arrives as `--origin`), so
/// one file answers for all of them.
String? _detectOrigin(String rootPath) {
  final index = File('$rootPath/index.html');
  if (!index.existsSync()) return null;
  final match = RegExp(r'<link rel="canonical" href="([^"]*)"')
      .firstMatch(index.readAsStringSync());
  return match == null ? null : _normalizeOrigin(match.group(1)!);
}

/// `https://host/` → `https://host`, and null when there is no scheme and host
/// to keep.
///
/// The trailing slash matters more than it looks: nothing equals
/// `https://host/` when the comparison is built as `scheme://authority`, so an
/// origin passed that way sent every one of the site's own absolute URLs to
/// the external pile — and unlike a missing origin, which is fatal, that still
/// printed PASS.
String? _normalizeOrigin(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
  return '${uri.scheme}://${uri.authority}';
}

String _relative(String path, String rootPath) =>
    path.startsWith('$rootPath/') ? path.substring(rootPath.length + 1) : path;

// ---------------------------------------------------------------------------
// The printed report
// ---------------------------------------------------------------------------

class _Report {
  int links = 0;
  int fragments = 0;

  /// Offender → the note printed beside it: the file that asks for a link, or
  /// how often a duplicated id is declared. Sorted on the way out, over a
  /// sorted walk, so two runs over one build print the same report.
  final Map<String, String> brokenTargets = {};
  final Map<String, String> missingFragments = {};
  final Map<String, String> duplicateIds = {};
  final Set<String> externalHosts = {};

  /// A floor, because everything else here passes by finding nothing. If the
  /// extraction patterns stop matching — an attribute reordered, a quote style
  /// changed — every other condition is trivially true and the gate goes green
  /// having checked nothing at all.
  bool get lookedAtAnything => links > 0 && fragments > 0;

  bool get passed =>
      lookedAtAnything &&
      brokenTargets.isEmpty &&
      missingFragments.isEmpty &&
      duplicateIds.isEmpty;

  void print() {
    stdout.writeln('\nlinks   $links references, '
        '$fragments fragments resolved against their target');

    if (externalHosts.isNotEmpty) {
      final hosts = externalHosts.toList()..sort();
      stdout.writeln('external  ${hosts.join(', ')} — not fetched');
    }

    if (!lookedAtAnything) {
      stdout.writeln('\nfound no ${links == 0 ? 'links' : 'fragments'} at all. '
          'The patterns match nothing this build writes, so every check below '
          'passed without looking. Treated as a failure.');
    }

    _section('broken targets', brokenTargets);
    _section('missing fragments', missingFragments);
    _section('duplicate ids', duplicateIds);

    stdout.writeln('');
    stdout.writeln(passed
        ? 'PASS — every internal link resolves, every fragment names an id on '
            'the page it points at, and no page declares an id twice.'
        : 'FAIL — ${brokenTargets.length} broken, '
            '${missingFragments.length} fragments naming nothing, '
            '${duplicateIds.length} ids declared twice.');
  }

  void _section(String title, Map<String, String> offenders) {
    if (offenders.isEmpty) return;
    stdout.writeln('\n$title (${offenders.length})');
    final keys = offenders.keys.toList()..sort();
    for (final key in keys.take(_maxOffendersShown)) {
      stdout.writeln('  $key  ← ${offenders[key]}');
    }
    final rest = keys.length - _maxOffendersShown;
    if (rest > 0) stdout.writeln('  … and $rest more');
  }
}

const int _maxOffendersShown = 20;
