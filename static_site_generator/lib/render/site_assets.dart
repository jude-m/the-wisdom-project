/// Every file a page links that is not another page, and the cache token on
/// each of their URLs.
///
/// `_headers` serves all of them `immutable` for a year, so **the URL is the
/// only thing that can tell a returning reader their copy is stale**. This file
/// is what makes each URL change when its bytes do — computed by the build,
/// with nothing for anyone to remember.
///
/// Five files, four tokens:
///
/// | file                | token                                     |
/// |---------------------|-------------------------------------------|
/// | `site.css`          | hash of the CSS                           |
/// | `site.js`           | hash of the script **and** the index      |
/// | `search-index.json` | the same hash                             |
/// | `emblem.png`        | hash of the image                         |
/// | `fonts/*.woff2`     | one hash of all eight faces, in the CSS   |
///
/// ## Why not a hand-bumped token
///
/// There was one: `searchContractVersion`, a `'1'` in `search_index.dart` whose
/// own instruction was to bump it "in the same edit that moves a field" of an
/// index row. That is the wrong trigger, and it was the only one on offer,
/// because the two files it stamped are *copied* rather than generated and had
/// no content to hash at the point the `<head>` was written.
///
/// A field move is not the only way those files change. An upstream re-sync
/// shifts nodeKeys and adds suttas; a vagga crossing `shortLineChars` regroups
/// and every leaf under it gets a new `chapterIdx`; a bug in
/// the matcher gets fixed. None of those moves a field, so none earns a bump —
/// and each of them, under `immutable`, leaves a reader who opened search once
/// holding last month's index for a year. Its rows still resolve, to URLs that
/// no longer exist, which Cloudflare currently answers with `200` and the
/// landing page. Wrong answers that look like working ones.
///
/// The emblem and the fonts had the opposite problem: no token at all, and a
/// week of `max-age` as the compromise. That is not hypothetical either — the
/// bundled Noto faces are missing welded glyphs for ඤ්ජ, ඤ්ඡ and ණ්ඩ, and the fix
/// is a re-subset under the same eight file names. Hashing them means the fix
/// arrives on the next page load instead of within a week, and it collapses
/// `_headers` to one tier.
///
/// ## One token over both the script and the index, not one each
///
/// `site.js` reads an index row by field *position* — `KEY, PALI, SINHALA,
/// PARENT, CHAPTER, MARKED`. The two files are one contract, and two
/// independent hashes would let a fresh script pair with a cached index from
/// before a field moved: plausible results pointing at the wrong sutta, which
/// is the exact failure the old token existed to prevent.
///
/// Hashing the concatenation keeps that guarantee and adds the one the token
/// never had: **either both URLs change or neither does**, and any change to
/// either file changes them. The separator is a NUL — neither UTF-8 JSON nor
/// the script can contain one — so bytes cannot migrate across the join and
/// hash the same.
///
/// Nothing else here is paired, so nothing else shares a token. The stylesheet
/// is paired with the HTML, which is never cached and so never stale: a rule
/// and the class it matches ship together or the page renders broken, and that
/// is a question about the CSS alone. The fonts share one token because
/// `subset_fonts.sh` regenerates all eight together, and eight tokens would be
/// eight answers to one question.
///
/// ## What it costs
///
/// A change to any of them rewrites the `<head>` of every page in the build
/// (`FIGURES.realPages`) — the fonts included, since their token rides inside
/// the CSS whose hash the pages carry — so the whole corpus re-uploads on the
/// next deploy instead of a handful of files. That is what `immutable` costs;
/// a hand-bumped token paid it too. It is why asset work is worth batching,
/// and why content edits, which touch only the pages they touch, are
/// unaffected.
///
/// [contentHash] is FNV-1a: change detection, not cryptography, which is the
/// question being asked. Same inputs give the same URLs, so §11.8's
/// byte-determinism survives.
library;

import '../domain/content_hash.dart';

/// Directory holding everything below, under the output root.
///
/// Every path in it is versioned, which is what lets `_headers` cache the whole
/// directory with one rule instead of naming four files and forgetting the
/// fifth.
const String assetsOutputDir = 'assets';

/// Paths under the output directory — where the build writes, and the file the
/// URLs above are built from. **Paths, not URLs**: each URL carries a query
/// string that no file on disk ever will.
///
/// All four here rather than beside the code that generates each one, because
/// the caching rule has to name the directory they share and deriving that from
/// one of them would make the other three look independent of it.
const String stylesheetOutputPath = '$assetsOutputDir/site.css';
const String siteScriptOutputPath = '$assetsOutputDir/$siteScriptFileName';
const String searchIndexOutputPath = '$assetsOutputDir/search-index.json';
const String emblemOutputPath = '$assetsOutputDir/$emblemFileName';

/// The site's one script, under the generator's `assets/` and the output's.
const String siteScriptFileName = 'site.js';

/// A committed 200×200 derivative of `assets/icons/app_logo.png`, produced by
/// `static_site_generator/assets/make_emblem.sh` — see that script for why the
/// 634 KB source is never shipped.
///
/// Named separately from its output path because it is a file the build
/// *copies*: the name is read from the generator's own `assets/` as well as
/// written to the output's.
const String emblemFileName = 'emblem.png';

/// The URLs the pages link, decided once per build.
///
/// Threaded through the templates like `generatorVersion` is: a page cannot
/// know these, and the composition root can.
class SiteAssets {
  /// `/assets/site.css?v=<hash of the CSS>`.
  final String stylesheet;

  /// `/assets/site.js?v=<hash of the script and the index together>`.
  final String script;

  /// `/assets/search-index.json?v=<the same hash>`.
  final String searchIndex;

  /// `/assets/emblem.png?v=<hash of the image>`.
  final String emblem;

  const SiteAssets({
    required this.stylesheet,
    required this.script,
    required this.searchIndex,
    required this.emblem,
  });

  /// Derives every URL from the bytes that will be written.
  ///
  /// [script] and [emblem] are files the build *copies* rather than generates,
  /// and either can be absent — the case `SiteGenerator` already warns about.
  /// An absent one arrives here empty: the URL is still emitted and still 404s,
  /// exactly as before, and the build stays deterministic.
  ///
  /// The fonts have no URL here because no page names a font file. Their token
  /// reaches the browser inside the stylesheet, so it is already folded into
  /// [css] by the time this is called — see [fontsVersion].
  factory SiteAssets.forContent({
    required String css,
    required String script,
    required String searchIndex,
    required List<int> emblem,
  }) {
    final searchVersion = contentHash('$script$_nul$searchIndex');
    return SiteAssets(
      stylesheet: '/$stylesheetOutputPath?v=${contentHash(css)}',
      script: '/$siteScriptOutputPath?v=$searchVersion',
      searchIndex: '/$searchIndexOutputPath?v=$searchVersion',
      emblem: '/$emblemOutputPath?v=${contentHashOfBytes(emblem)}',
    );
  }
}

/// One token for the eight WOFF2 faces, from the bytes of all of them.
///
/// A hash of hashes rather than of the concatenation: the faces are 328 KB
/// together and joining them into one buffer to hash it once would be the
/// build's largest allocation for no better answer. Order is `webFontFaces`'s,
/// which is fixed, so the token is stable across runs (§11.8).
///
/// Callers pass the faces they actually found on disk. A missing face is
/// already a loud warning in `SiteGenerator._readFonts`; leaving it out of the
/// token as well means the build that ships seven faces and the build that
/// ships eight do not claim to be the same fonts.
String fontsVersion(Iterable<List<int>> faces) =>
    contentHash(faces.map(contentHashOfBytes).join(_nul));

/// Separator between two hashed inputs, so bytes cannot migrate across the
/// join and hash the same. Neither UTF-8 JSON, JavaScript source, nor a hex
/// digest can contain one.
const String _nul = '\u0000';
