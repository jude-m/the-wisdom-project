import 'commentary_link.dart';

/// A shareable / universal link to a location in the canon.
///
/// One URL grammar serves every surface (app, static site, OS deep links —
/// see `docs/todo/deep-linking-and-shareable-urls.md`):
///
///     https://<host>[/app]/tipitaka/<nodeKey>[?e=<page>[.<entry>]][#<nodeKey>]
///     sammaditthi://tipitaka/<nodeKey>[?e=<page>[.<entry>]][#<nodeKey>]
///
/// The first form is the shareable one, the second dev/QA only.
///
/// Fragment = **which node on that page**. The static site gives short leaves
/// no file of their own and serves them as a section of a chapter page, so a
/// link to one names the page in the path and the leaf in the fragment. The
/// leaf is the target either way: [nodeKey] is what the reader asked for and
/// [pageKey] is only where it is kept.
///
/// A fragment that is *not* nodeKey-shaped can still carry meaning: the site
/// writes `#via_<canonKey>` on a commentary link to name the sutta the reader
/// followed it *from*. That one is [originKey], and it is the one fragment
/// whose target cannot be read off the URL — see [originId].
///
/// "tipitaka" is used in the umbrella sense (as tipitaka.lk and Access to
/// Insight use it): the nodeKey may point anywhere in the tree — suttas,
/// Vinaya, commentary `atta-*` (strictly outside the Tipiṭaka), treatises.
/// No other link type is ever needed for canon content.
///
/// Path = **identity**: the BJT tree nodeKey (`sn-2-3-1-3`), which addresses
/// every kind of content and maps 1:1 onto the app's navigation. Which
/// *edition* renders at that address is a reader preference, never part of
/// the link.
///
/// Query = **view state**: an optional entry-level position using the same
/// `pageIndex` + `entryIndexInPage` coordinates `ReaderTab` and search results
/// already use. `?e=12.4` → page 12, entry 4; `?e=12` → page 12, entry 0.
///
/// Parsing is deliberately **lenient**: anything that doesn't fit the grammar
/// returns `null` — a malformed shared URL must never throw.
class TipitakaLink {
  /// BJT tree node key, e.g. `sn-2-3-1-3` (always lowercase).
  final String nodeKey;

  /// The page that *serves* [nodeKey], when the path alone would not name the
  /// target — `/tipitaka/<pageKey>#<nodeKey>`.
  ///
  /// Null means the target owns its URL, which is the common case and the only
  /// one the grammar had until the split rule folded `FIGURES.foldedLeaves`
  /// leaves onto chapter pages. It may also *equal* [nodeKey], for the chapters
  /// anchored on their first leaf: there the bare path is the whole run and the
  /// fragment is the one sutta, so the repetition is the question being asked
  /// (`SitePage.anchorsRunOnLeaf`). **It is addressing, not identity**: where
  /// this is set, [nodeKey] is what the reader asked for and this is only where
  /// it is kept, so a consumer reads that one field and only a link *builder*
  /// needs this one. [originKey] is where that stops holding — there the path
  /// names the page, nothing in the URL names the target, and it has to be
  /// resolved through the tree. Which page serves a key is `SitePlan`'s answer,
  /// never a guess from the tree — see [SitePlan.urlFor].
  final String? pageKey;

  /// Optional page override (`?e=<page>…`). Null → open at the node's own
  /// start coordinates from the tree.
  final int? pageIndex;

  /// Optional entry-in-page override (`?e=<page>.<entry>`). Only meaningful
  /// together with [pageIndex]; null with a page present means entry 0.
  final int? entryIndex;

  /// The canon sutta a reader followed `අට්ඨකථා` *from*, when the link came
  /// through an origin marker (`#via_<canonKey>`) — null on every other link.
  ///
  /// **Which door, not which node.** Several suttas can share one vaṇṇanā, so
  /// the way back has several right answers and the URL has to say which one
  /// the reader is owed. [nodeKey] stays what the path named, because the
  /// vaṇṇanā itself is usually a folded leaf the path cannot name: a consumer
  /// with the tree turns this key into the vaṇṇanā with [crossLinkTargetKey],
  /// which is the same answer the marker's own position on the page gives.
  ///
  /// Excludes [pageKey]: both are written into the fragment, and a URL has
  /// only one.
  final String? originKey;

  /// [pageKey] may repeat [nodeKey], and the pair is then one address, not one
  /// written twice: `<key>#<key>` asks a chapter for the leaf it is anchored on
  /// rather than for the whole run. This used to be normalised away here, and
  /// collapsed in [parse], on the reasoning that a page's own key never carries
  /// a fragment — true of every page except the one kind that is a run of them.
  ///
  /// Both ends were relaxed together, so `parse(link.toUri(…)) == link` still
  /// holds for every value the constructor accepts.
  const TipitakaLink({
    required this.nodeKey,
    this.pageKey,
    this.pageIndex,
    this.entryIndex,
    this.originKey,
  }) : assert(pageKey == null || originKey == null,
            'pageKey and originKey both claim the fragment');

  /// The dev/QA custom scheme (never used in shared links).
  static const String customScheme = 'sammaditthi';

  /// The path segment that precedes the nodeKey: `/tipitaka/<nodeKey>`.
  static const String pathSegment = 'tipitaka';

  /// Query parameter carrying the entry position: `e=<page>[.<entry>]`.
  static const String entryParam = 'e';

  /// Tolerated on an incoming path, never written on an outgoing one.
  static const String _htmlSuffix = '.html';

  /// nodeKeys are lowercase alphanumeric runs joined by single separators.
  ///
  /// Hyphen is the usual one (`sn-2-3-1-3`), but 53 commentary nodes carry a
  /// **dot** inside a segment — `atta-ap-dhs-2-1-1.1`, `atta-vp-cv-3-2.5`,
  /// `atta-ap-vbh-6-1.91` — all under `atta-ap-*` / `atta-vp-cv-*`. Rejecting
  /// them here made deep links to those 50 leaves resolve to null.
  ///
  /// This is a *syntactic* guard only; whether the key exists is the tree's
  /// business, so a well-formed key that names nothing resolves to "not found"
  /// exactly like a typo'd `sn-99-99` does.
  static final RegExp _nodeKeyPattern = RegExp(r'^[a-z0-9]+(?:[-.][a-z0-9]+)*$');

  /// Parses a URI into a [TipitakaLink], or `null` if it isn't one.
  ///
  /// Accepts `http`/`https` on any host (so localhost, LAN boxes and the
  /// production domain all work), a base-href prefix (`/app/tipitaka/…`), and
  /// the [customScheme] form.
  static TipitakaLink? parse(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final isCustom = scheme == customScheme;
    if (!isCustom && scheme != 'http' && scheme != 'https') return null;

    // Effective path segments. In `sammaditthi://tipitaka/x` the "tipitaka"
    // part parses as the URI *host*, so fold it back into the segment list.
    final segments = <String>[
      if (isCustom && uri.host.isNotEmpty) uri.host.toLowerCase(),
      ...uri.pathSegments.where((s) => s.isNotEmpty),
    ];

    // ".../tipitaka/<nodeKey>" — the nodeKey must be the final segment,
    // directly after "tipitaka" (tolerates any prefix, e.g. the web app's
    // /app/ base href).
    if (segments.length < 2) return null;
    if (segments[segments.length - 2] != pathSegment) return null;
    // The site's files are `<nodeKey>.html` and its links are extensionless,
    // but a URL copied from a browser that was served the file directly (or
    // from the generator's own output) carries the extension. No nodeKey ends
    // in `.html`, so stripping it can only help.
    var pathKey = segments.last.toLowerCase();
    if (pathKey.endsWith(_htmlSuffix)) {
      pathKey = pathKey.substring(0, pathKey.length - _htmlSuffix.length);
    }
    if (!_nodeKeyPattern.hasMatch(pathKey)) return null;

    // A nodeKey-shaped fragment names the *target*: the site folds short
    // leaves onto a chapter page and links to them as `<chapter>#<leaf>`, so
    // the fragment is the sutta the reader asked for and the path is merely
    // the file carrying it. Reading the path alone would silently open the
    // chapter's anchor sutta instead — a wrong answer that looks like a right
    // one. A fragment that cannot be a nodeKey at all (a footnote id, an empty
    // one) is not a target and leaves the path key alone.
    //
    // A fragment repeating the path key is a target too, and is kept as one.
    // Same key on both sides, different questions: bare, that path is a chapter
    // showing its whole run; with the fragment it is the anchor sutta alone.
    // Collapsing it here erased the difference on the way in.
    //
    // A `via_` fragment is neither: it names the canon sutta the reader came
    // *from*, and the underscore is what keeps it out of the shape above. See
    // [originId] — the target it implies needs the tree, so it is carried as
    // [originKey] and resolved by whoever opens the link. The two cases need no
    // precedence rule between them: the pattern admits no underscore, so no
    // fragment can satisfy both.
    //
    // The payload is held to that same pattern, for the reason the path key is:
    // one that cannot name a node cannot be resolved into one, so reporting it
    // would describe a door that is not there.
    final fragment = uri.fragment.toLowerCase();
    final targeted = fragment.isNotEmpty && _nodeKeyPattern.hasMatch(fragment);
    final door = canonKeyFromOriginId(fragment);
    final origin =
        door != null && _nodeKeyPattern.hasMatch(door) ? door : null;

    final (page, entry) = _parseEntry(uri.queryParameters[entryParam]);
    return TipitakaLink(
      nodeKey: targeted ? fragment : pathKey,
      pageKey: targeted ? pathKey : null,
      pageIndex: page,
      entryIndex: entry,
      originKey: origin,
    );
  }

  /// Convenience over [parse] for raw strings (clipboard, config, tests).
  static TipitakaLink? tryParse(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null) return null;
    return parse(uri);
  }

  /// `"12.4"` → (12, 4); `"12"` → (12, null); anything else → (null, null).
  static (int?, int?) _parseEntry(String? raw) {
    if (raw == null || raw.isEmpty) return (null, null);
    final parts = raw.split('.');
    if (parts.length > 2) return (null, null);
    final page = int.tryParse(parts[0]);
    if (page == null || page < 0) return (null, null);
    if (parts.length == 1) return (page, null);
    final entry = int.tryParse(parts[1]);
    if (entry == null || entry < 0) return (page, null);
    return (page, entry);
  }

  /// The `e=` query value for this link, or null when there is no position.
  String? get _entryValue {
    final page = pageIndex;
    if (page == null) return null;
    final entry = entryIndex;
    return entry == null ? '$page' : '$page.$entry';
  }

  /// Builds the canonical shareable URL against [baseUrl]
  /// (e.g. `http://localhost:8080` → `http://localhost:8080/tipitaka/<nodeKey>`).
  /// Any path on the base (e.g. `https://host/app`) is preserved as a prefix.
  Uri toUri(String baseUrl) {
    final base = Uri.parse(baseUrl);
    // A scheme-less base ("sammaditthi.app") parses as a path, producing a
    // broken URL. Developer-controlled input (LINK_BASE_URL) → dev-time guard.
    assert(base.hasScheme,
        'baseUrl must include a scheme, e.g. https://sammaditthi.app — got "$baseUrl"');
    final entryValue = _entryValue;
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      pathSegments: [
        ...base.pathSegments.where((s) => s.isNotEmpty),
        pathSegment,
        pageKey ?? nodeKey,
      ],
      queryParameters: entryValue == null ? null : {entryParam: entryValue},
      fragment: _fragment,
    );
  }

  /// The dev/QA form: `sammaditthi://tipitaka/<nodeKey>[?e=…]`.
  Uri toCustomSchemeUri() {
    final entryValue = _entryValue;
    return Uri(
      scheme: customScheme,
      host: pathSegment,
      pathSegments: [pageKey ?? nodeKey],
      queryParameters: entryValue == null ? null : {entryParam: entryValue},
      fragment: _fragment,
    );
  }

  /// The one fragment both writers share: the target when the path is only the
  /// page carrying it, the origin marker when the link came through one, and
  /// nothing when the path already names the node. The constructor's assert is
  /// what makes those three exclusive.
  String? get _fragment {
    if (pageKey != null) return nodeKey;
    final origin = originKey;
    return origin == null ? null : originId(origin);
  }

  @override
  bool operator ==(Object other) =>
      other is TipitakaLink &&
      other.nodeKey == nodeKey &&
      other.pageKey == pageKey &&
      other.pageIndex == pageIndex &&
      other.entryIndex == entryIndex &&
      other.originKey == originKey;

  @override
  int get hashCode =>
      Object.hash(nodeKey, pageKey, pageIndex, entryIndex, originKey);

  @override
  String toString() => 'TipitakaLink(nodeKey: $nodeKey, pageKey: $pageKey, '
      'pageIndex: $pageIndex, entryIndex: $entryIndex, '
      'originKey: $originKey)';
}
