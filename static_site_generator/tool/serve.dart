import 'dart:io';

import 'package:static_site_generator/render/cache_headers.dart';

/// Previews the generated site the way Cloudflare Pages will serve it.
///
///     dart run static_site_generator/tool/serve.dart
///     dart run static_site_generator/tool/serve.dart --port 9000 --dir /tmp/site
///
/// For a check against the real thing rather than this imitation, deploy to a
/// Cloudflare Pages preview instead: `./scripts/static_site/deploy.sh`. This is
/// the offline path — no network, no auth, no upload.
///
/// A plain static server is not good enough here. Every link the generator
/// writes is **extensionless** — `href="/tipitaka/an-1-2"` against a file named
/// `an-1-2.html` — because that is the URL Cloudflare Pages serves and the one
/// `rel="canonical"` and the sitemap will name. Point `python3 -m http.server`
/// at `build/` and the pages render but every link 404s, which reads as a
/// generator bug and is not one.
///
/// So this mirrors the two Pages behaviours that the output depends on:
///
///  * `/tipitaka/an-1-2` → `tipitaka/an-1-2.html`
///  * `/tipitaka/an-1-2.html` → 308 to the extensionless form
///
/// The redirect matters as much as the rewrite: it is what makes a stray
/// `.html` link show up as a URL change in the address bar instead of quietly
/// working locally and splitting into two indexed URLs in production.
///
/// Read-only. It never writes to the directory it serves.
Future<void> main(List<String> args) async {
  final _Options options;
  try {
    options = _Options.parse(args);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln('');
    stderr.writeln(_usage);
    exitCode = 2;
    return;
  }

  if (options.showHelp) {
    stdout.writeln(_usage);
    return;
  }

  final root = Directory(options.directory);
  if (!root.existsSync()) {
    stderr.writeln('No such directory: ${root.path}');
    stderr.writeln('Build one first:');
    stderr.writeln('  dart run static_site_generator/bin/generate.dart '
        '--root an-1');
    exitCode = 1;
    return;
  }

  final HttpServer server;
  try {
    // Loopback, not `anyIPv4`: this serves an unfinished site off a laptop and
    // has no business being reachable from the rest of the network.
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, options.port);
  } on SocketException catch (error) {
    stderr.writeln('Cannot listen on port ${options.port}: ${error.message}');
    stderr.writeln('Another server is probably already running. '
        'Pass --port to pick a different one.');
    exitCode = 1;
    return;
  }

  final rootPath = root.absolute.path;
  stdout.writeln('serving   $rootPath');
  stdout.writeln('at        http://localhost:${options.port}/');
  stdout.writeln('');
  stdout.writeln('try       http://localhost:${options.port}/tipitaka/an-1');
  stdout.writeln('stop      Ctrl+C');
  stdout.writeln('');

  await for (final request in server) {
    await _handle(request, rootPath);
  }
}

Future<void> _handle(HttpRequest request, String rootPath) async {
  final response = request.response;
  final path = request.uri.path;

  if (request.method != 'GET' && request.method != 'HEAD') {
    response.statusCode = HttpStatus.methodNotAllowed;
    await response.close();
    _log(request, response.statusCode);
    return;
  }

  // Pages redirects `/x.html` to `/x`, so a link written with the extension
  // changes the address bar rather than silently resolving. Reproduced here so
  // that mismatch is visible in preview instead of at deploy time.
  if (path.endsWith('.html')) {
    response.statusCode = HttpStatus.permanentRedirect;
    response.headers.set(
      HttpHeaders.locationHeader,
      path.substring(0, path.length - '.html'.length),
    );
    await response.close();
    _log(request, response.statusCode);
    return;
  }

  // Pages *consumes* `_headers` — it reads the caching rules out of it at
  // deploy time and never serves the file. It sits in the build directory all
  // the same, so a preview that streams it back is offering a URL production
  // does not have.
  //
  // Stricter than production on purpose, and the one place this server is.
  // Pages has no `404.html` yet, so it answers this path — and every other
  // unknown one — with `200` and the landing page (measured 2026-08-15; it is
  // item A1 in docs/todo/web-strategy/static-site-backlog.md). Refusing here
  // says the file is not a page; mirroring the soft-404 would only reproduce
  // a bug.
  if (path == '/$cacheHeadersOutputPath') {
    response.statusCode = HttpStatus.notFound;
    response.headers.contentType = ContentType.html;
    response.write('<h1>404</h1><p><code>$path</code> is read by Cloudflare '
        'Pages at deploy time and is never served as a page.</p>');
    await response.close();
    _log(request, response.statusCode);
    return;
  }

  final file = _resolve(path, rootPath);
  if (file == null) {
    response.statusCode = HttpStatus.notFound;
    response.headers.contentType = ContentType.html;
    // The second line is the common case and is not a bug: on a partial build
    // the breadcrumbs still climb to ancestors above `--root`, and every canon
    // page links to its atta-* twin under a different root entirely. Without
    // saying so, the first dead breadcrumb reads as a generator fault.
    response.write('<h1>404</h1><p>No file for <code>$path</code>.</p>'
        '<p>If this key exists in the tree, it was outside this build&rsquo;s '
        '<code>--root</code>. Rebuild with <code>--root all</code>.</p>');
    await response.close();
    _log(request, response.statusCode);
    return;
  }

  response.headers.contentType = _contentTypeOf(file.path);
  // The point of the preview is to see the build that is on disk right now.
  response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
  if (request.method == 'HEAD') {
    response.headers.contentLength = file.lengthSync();
    await response.close();
  } else {
    await response.addStream(file.openRead());
    await response.close();
  }
  _log(request, response.statusCode);
}

/// URL path → file on disk, applying the Pages extensionless rule.
///
/// Returns null when nothing matches, **including** when the resolved path
/// escapes the served directory. `..` in a request is the standard traversal
/// attempt; this only ever listens on loopback, but a preview server that will
/// hand out `~/.ssh/id_rsa` to a curious browser tab is not worth the two lines
/// saved.
File? _resolve(String path, String rootPath) {
  final decoded = Uri.decodeComponent(path);
  final relative = decoded.startsWith('/') ? decoded.substring(1) : decoded;
  final base = relative.isEmpty ? 'index' : relative;

  for (final candidate in [
    '$rootPath/$base',
    '$rootPath/$base.html',
    '$rootPath/$base/index.html',
  ]) {
    final file = File(candidate);
    final resolved = file.absolute.path;
    if (!resolved.startsWith('$rootPath/')) continue;
    if (file.existsSync()) return file;
  }
  return null;
}

/// Only the types this site actually ships. A wrong `Content-Type` on the WOFF2
/// subsets is the failure that shows up as "the Sinhala conjuncts look wrong",
/// which is exactly the thing the preview exists to check.
ContentType _contentTypeOf(String path) {
  if (path.endsWith('.html')) return ContentType.html;
  if (path.endsWith('.css')) {
    return ContentType('text', 'css', charset: 'utf-8');
  }
  if (path.endsWith('.woff2')) return ContentType('font', 'woff2');
  // Without this the site's one script fell through to `application/octet-
  // stream`. A classic `<script src>` still runs under that — which is worse
  // than failing, because the preview then behaves unlike any host that sends
  // `X-Content-Type-Options: nosniff`, and the difference only shows up in
  // production.
  if (path.endsWith('.js')) {
    return ContentType('text', 'javascript', charset: 'utf-8');
  }
  if (path.endsWith('.json')) return ContentType.json;
  if (path.endsWith('.xml')) return ContentType('application', 'xml');
  if (path.endsWith('.svg')) return ContentType('image', 'svg+xml');
  return ContentType.binary;
}

void _log(HttpRequest request, int status) =>
    stdout.writeln('${status.toString().padRight(4)}${request.uri.path}');

/// Directory holding this package, so `build/` resolves whether the tool is run
/// from the repo root or from inside `static_site_generator/`. Read off
/// `Platform.script` for the same reason `bin/generate.dart` does.
final String _packageRoot = File.fromUri(Platform.script).parent.parent.path;

class _Options {
  final String directory;
  final int port;
  final bool showHelp;

  const _Options({
    required this.directory,
    required this.port,
    required this.showHelp,
  });

  static const Set<String> _valueFlags = {'--dir', '--port'};

  static _Options parse(List<String> args) {
    final values = <String, String>{};
    var showHelp = false;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '-h' || arg == '--help') {
        showHelp = true;
        continue;
      }

      final separator = arg.indexOf('=');
      final name = separator < 0 ? arg : arg.substring(0, separator);
      if (!_valueFlags.contains(name)) {
        throw FormatException('Unknown option "$arg".');
      }

      final String value;
      if (separator >= 0) {
        value = arg.substring(separator + 1);
      } else if (i + 1 < args.length) {
        value = args[++i];
      } else {
        throw FormatException('Missing value for $name.');
      }
      if (value.isEmpty) throw FormatException('Empty value for $name.');

      values[name] = value;
    }

    // 8083, not 8787: 8787 is wrangler's own default port, and this repo now
    // runs wrangler regularly (scripts/static_site/deploy.sh, research_server).
    // 8083 is the next free slot in the dev port map — 8080 Flutter web on
    // macOS, 8081 Flutter web on the Windows box, 8082 research server.
    final rawPort = values['--port'] ?? '8083';
    final port = int.tryParse(rawPort);
    if (port == null || port < 1 || port > 65535) {
      throw FormatException('--port must be 1–65535, got "$rawPort".');
    }

    return _Options(
      directory: values['--dir'] ?? '$_packageRoot/build',
      port: port,
      showHelp: showHelp,
    );
  }
}

const String _usage = '''
Preview server for the generated site — The Wisdom Project

  dart run static_site_generator/tool/serve.dart [options]

Serves extensionless URLs the way Cloudflare Pages does, so local preview
matches production.

Options
  --dir <path>    Directory to serve      (default: <package>/build)
  --port <n>      Port to listen on       (default: 8083)
  -h, --help      Show this help
''';
