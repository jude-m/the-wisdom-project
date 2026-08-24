import 'package:wisdom_shared/wisdom_shared.dart';
import 'site_assets.dart';

/// The four things every template needs and no template can work out for
/// itself.
///
/// ## Why they travel together
///
/// Each was threaded in separately, as its own field on `PageTemplate` and its
/// own field on `LandingPage` and its own parameter on `htmlDocument`. They
/// share a shape exactly: decided **once per build**, by the composition root
/// that knows which target it is building for, and then constant for every one
/// of the `FIGURES.realPages` pages that follow. None of them is derivable from
/// a [SitePage].
///
/// P5 is what turned that from a list into a pattern. Adding [origin] — one
/// string — cost two class fields, three constructor parameter lists, three
/// call sites in `sitegen.dart`, one `htmlDocument` signature, two more call
/// sites inside it and two test fixtures: ten edits to carry one value from the
/// place that knows it to the place that prints it. The fifth such value would
/// cost the same again.
///
/// So they are one field now, and the next one is one more line in this class.
/// The templates keep their own parameters for everything that varies *per
/// page*, which is the distinction this draws: [SitePage] is what changes,
/// [SiteBuild] is what does not.
///
/// ## Not a bag of globals
///
/// It is passed, never reached for. A template holding one still cannot invent
/// an origin or a hash, and a test still constructs the build it wants — which
/// is what keeps `PageTemplate` pure in the sense that matters: models in,
/// string out, nothing read from disk or from a static.
class SiteBuild {
  /// Scheme and host this build is being uploaded to, without a trailing slash
  /// — `bin/generate.dart` validates it and strips one, so every caller may
  /// concatenate a root-relative path onto it without checking first.
  ///
  /// The one place an absolute URL can come from. `deploy.sh` computes it from
  /// the same two constants that decide everything else about a deploy, so a
  /// preview canonicalises to the preview and production to production.
  final String origin;

  /// Version stamped into `<meta name="generator">`. **Not** a build id — the
  /// output has to be byte-identical between runs on unchanged input, or
  /// Cloudflare's content-hash dedup re-uploads every file (§11.8).
  final String generatorVersion;

  /// The stylesheet, script, index, emblem and card URLs, each carrying a hash
  /// of its own bytes — see [SiteAssets]. A page cannot know those; the caller
  /// that read the bytes can.
  final SiteAssets assets;

  /// Where a link to a nodeKey must point — [SitePlan.urlFor].
  ///
  /// Every outgoing link written to a key that did not come from a [SitePage]
  /// has to go through this: a TOC child and an අට්ඨකථා twin are both just
  /// keys, and a folded key's bare URL is served by no file.
  final UrlResolver urlFor;

  const SiteBuild({
    required this.origin,
    required this.generatorVersion,
    required this.assets,
    required this.urlFor,
  });

  /// [origin] with a root-relative [path] on the end — the absolute form
  /// `<link rel="canonical">`, `og:url`, `og:image`, `sitemap.xml` and the
  /// JSON-LD trail all need.
  ///
  /// One method rather than a `'$origin$path'` at each of those sites: they
  /// must agree about the join, and the day the origin gains a trailing slash
  /// or loses one there is a single place that decides what that means.
  String absolute(String path) => '$origin$path';
}
