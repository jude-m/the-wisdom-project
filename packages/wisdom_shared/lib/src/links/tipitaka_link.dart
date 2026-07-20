/// A shareable / universal link to a location in the canon.
///
/// One URL grammar serves every surface (app, static site, OS deep links —
/// see `docs/todo/deep-linking-and-shareable-urls.md`):
///
///     https://<host>[/app]/tipitaka/<nodeKey>[?e=<page>[.<entry>]]   ← shareable
///     sammaditthi://tipitaka/<nodeKey>[?e=<page>[.<entry>]]          ← dev/QA only
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

  /// Optional page override (`?e=<page>…`). Null → open at the node's own
  /// start coordinates from the tree.
  final int? pageIndex;

  /// Optional entry-in-page override (`?e=<page>.<entry>`). Only meaningful
  /// together with [pageIndex]; null with a page present means entry 0.
  final int? entryIndex;

  const TipitakaLink({required this.nodeKey, this.pageIndex, this.entryIndex});

  /// The dev/QA custom scheme (never used in shared links).
  static const String customScheme = 'sammaditthi';

  /// The path segment that precedes the nodeKey: `/tipitaka/<nodeKey>`.
  static const String pathSegment = 'tipitaka';

  /// Query parameter carrying the entry position: `e=<page>[.<entry>]`.
  static const String entryParam = 'e';

  /// nodeKeys are lowercase alphanumeric runs joined by single hyphens.
  static final RegExp _nodeKeyPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

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
    final nodeKey = segments.last.toLowerCase();
    if (!_nodeKeyPattern.hasMatch(nodeKey)) return null;

    final (page, entry) = _parseEntry(uri.queryParameters[entryParam]);
    return TipitakaLink(nodeKey: nodeKey, pageIndex: page, entryIndex: entry);
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
        nodeKey,
      ],
      queryParameters: entryValue == null ? null : {entryParam: entryValue},
    );
  }

  /// The dev/QA form: `sammaditthi://tipitaka/<nodeKey>[?e=…]`.
  Uri toCustomSchemeUri() {
    final entryValue = _entryValue;
    return Uri(
      scheme: customScheme,
      host: pathSegment,
      pathSegments: [nodeKey],
      queryParameters: entryValue == null ? null : {entryParam: entryValue},
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TipitakaLink &&
      other.nodeKey == nodeKey &&
      other.pageIndex == pageIndex &&
      other.entryIndex == entryIndex;

  @override
  int get hashCode => Object.hash(nodeKey, pageIndex, entryIndex);

  @override
  String toString() =>
      'TipitakaLink(nodeKey: $nodeKey, pageIndex: $pageIndex, entryIndex: $entryIndex)';
}
