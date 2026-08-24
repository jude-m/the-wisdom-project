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

  /// The page that *serves* [nodeKey], when the site does not give the target
  /// its own file — `/tipitaka/<pageKey>#<nodeKey>`.
  ///
  /// Null means the target owns its URL, which is the common case and the only
  /// one the grammar had until the split rule folded `FIGURES.foldedLeaves`
  /// leaves onto chapter pages. **It is addressing, not identity**: [nodeKey]
  /// is always what the reader asked for, so every consumer reads that one
  /// field and only a link *builder* needs this one. Which page serves a key is
  /// `SitePlan`'s answer, never a guess from the tree — see [SitePlan.urlFor].
  final String? pageKey;

  /// Optional page override (`?e=<page>…`). Null → open at the node's own
  /// start coordinates from the tree.
  final int? pageIndex;

  /// Optional entry-in-page override (`?e=<page>.<entry>`). Only meaningful
  /// together with [pageIndex]; null with a page present means entry 0.
  final int? entryIndex;

  /// [pageKey] is dropped when it repeats [nodeKey]: a page's own key never
  /// carries a fragment, so the two together are one address written twice.
  /// [parse] already collapses that form on the way in; normalising here too
  /// means the state cannot be *held*, so `parse(link.toUri(…)) == link` holds
  /// for every value the constructor accepts — including a hand-written one,
  /// which is the only way the pair could ever have been built.
  const TipitakaLink({
    required this.nodeKey,
    String? pageKey,
    this.pageIndex,
    this.entryIndex,
  }) : pageKey = pageKey == nodeKey ? null : pageKey;

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
    // one. Any other fragment (`#top`, a footnote id) is not a target and
    // leaves the path key alone.
    final fragment = uri.fragment.toLowerCase();
    final servedElsewhere = fragment.isNotEmpty &&
        fragment != pathKey &&
        _nodeKeyPattern.hasMatch(fragment);

    final (page, entry) = _parseEntry(uri.queryParameters[entryParam]);
    return TipitakaLink(
      nodeKey: servedElsewhere ? fragment : pathKey,
      pageKey: servedElsewhere ? pathKey : null,
      pageIndex: page,
      entryIndex: entry,
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
      fragment: pageKey == null ? null : nodeKey,
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
      fragment: pageKey == null ? null : nodeKey,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TipitakaLink &&
      other.nodeKey == nodeKey &&
      other.pageKey == pageKey &&
      other.pageIndex == pageIndex &&
      other.entryIndex == entryIndex;

  @override
  int get hashCode => Object.hash(nodeKey, pageKey, pageIndex, entryIndex);

  @override
  String toString() => 'TipitakaLink(nodeKey: $nodeKey, pageKey: $pageKey, '
      'pageIndex: $pageIndex, entryIndex: $entryIndex)';
}
