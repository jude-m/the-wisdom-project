# Deep Linking & Shareable Sutta URLs (in-app)

> Status: **Proposal / Design** — not yet started.
> Captured: 2026-05-13. Split out of the former
> `web-deep-linking-seo-and-shareable-urls.md` on 2026-06-11; the SEO / static
> HTML / Jaspr half now lives in
> [`../web-strategy/web-rewrite-strategy.md`](../web-strategy/web-rewrite-strategy.md).
> Owner: TBD.

## Why this matters

Today the Flutter app's URL never changes regardless of which sutta the user
opens. One real problem flows from that:

- **No shareable links.** A user reading DN1 in side-by-side view can't copy a
  link, paste it in WhatsApp, and have the recipient land on the same sutta in
  the same view — on web *or* on mobile.

This is independent of the SEO/discoverability work (which is solved by the
standalone static HTML site — see
[`../web-strategy/web-rewrite-strategy.md`](../web-strategy/web-rewrite-strategy.md)). The two
share one prerequisite — **every sutta needs a stable URL** — but the fix here
is purely about *in-app routing*, and it pays off on **all platforms at once**.

---

## What's already in the codebase that helps us

- `server/lib/src/server_app.dart` — the shelf server already falls back to
  `index.html` for any unknown path. That's the SPA fallback deep links need to
  work at all on web.
- `lib/presentation/models/reader_tab.dart` — `ReaderTab.textId`
  (e.g. `'dn1'`, `'mn100'`, `'sn1-1'`) is explicitly "edition-agnostic".
  Perfect basis for canonical URLs.
- `lib/presentation/models/reader_layout.dart` — `ReaderLayout` enum
  (`paliOnly`, `sinhalaOnly`, `sideBySide`, `stacked`) is what we'd serialize
  into URL query params.

So the foundation is in place — we just don't read or write URL state anywhere.

---

## Deep linking inside the Flutter app (PR1)

This is the foundation. Switch from `home: const ReaderScreen()` to
`go_router`, and let the router drive which sutta is open.

### URL shape

```
/sutta/<textId>[-<slug>]?layout=<mode>&entry=<n>
```

Examples:

- `/sutta/dn1` — Brahmajāla, user's default reading mode.
- `/sutta/dn1-brahmajala?layout=side-by-side` — opens side-by-side.
- `/sutta/mn10?layout=stacked&entry=12` — Satipaṭṭhāna, stacked, jump to
  entry 12.
- `/sutta/sn1-1?layout=pali` — short alias for `paliOnly`.

Rule of thumb:

- **Path = identity** (what content). Stable, canonical, SEO-relevant.
- **Query = view state** (how it's displayed). Optional, overridable.

Two URLs that differ only in query params point to the **same canonical page**
for search engines — but restore different reader modes for humans.

> **Web vs mobile base path.** On web the Flutter app is served under `/app/`
> (`flutter build web --base-href /app/`; see the *Hosting & URL coexistence*
> section of [`../web-strategy/web-rewrite-strategy.md`](../web-strategy/web-rewrite-strategy.md)).
> Because go_router treats the base href as its root, the route definitions
> below stay `/sutta/...` but the **address bar shows `/app/sutta/...`**. On
> mobile there is no base href, so routes sit at the root and Universal/App
> Links bind to `/sutta/*` — which the OS intercepts before the browser ever
> loads the static page. The bare `/sutta/*` paths on web belong to the static
> HTML site (the canonical SEO surface); the app never competes for them.

### What from `ReaderTab` goes in the URL — and what doesn't

| Field | In URL? | Reason |
|---|---|---|
| `textId` | ✅ path | Identity |
| `layout` (paliOnly / sinhalaOnly / sideBySide / stacked) | ✅ query | Sender's intent |
| `entryStart` | ✅ query as `entry` | Content-addressable jump |
| `splitRatio` | ⚠️ optional | Probably skip — let user prefs win |
| `pageIndex` / `pageStart` / `pageEnd` | ❌ | Internal pagination; derive from `entryStart` |
| `scrollOffset` | ❌ | Pixel value, device-specific |
| `contentFileId` | ❌ | Edition-specific; `textId` is edition-agnostic |
| `panes` | ❌ for v1 | Could add later as `?panes=bjt-pali-si,sc-en` |

### Code sketch — `lib/core/routing/app_router.dart`

```dart
final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const ReaderScreen()),
    GoRoute(
      path: '/sutta/:textIdSlug',
      builder: (context, state) {
        // Parse "dn1-brahmajala-sutta" → textId = "dn1".
        // Split on the first dash that comes after a digit so
        // "sn1-1" stays intact and "sn1-1-some-slug" → textId "sn1-1".
        final raw = state.pathParameters['textIdSlug']!;
        final textId = _parseTextId(raw);

        // Read view state from query params (all optional).
        final layout = _parseLayout(state.uri.queryParameters['layout']);
        final entry = int.tryParse(state.uri.queryParameters['entry'] ?? '');

        return ReaderScreen(
          initialTextId: textId,
          initialLayout: layout,       // null → use user's saved preference
          initialEntryStart: entry,    // null → start at entry 0
        );
      },
    ),
  ],
);

ReaderLayout? _parseLayout(String? raw) {
  return switch (raw) {
    'pali' || 'pali-only' => ReaderLayout.paliOnly,
    'sinhala' || 'sinhala-only' => ReaderLayout.sinhalaOnly,
    'side-by-side' || 'sbs' => ReaderLayout.sideBySide,
    'stacked' => ReaderLayout.stacked,
    _ => null, // unknown/missing → fall back to user preference
  };
}
```

### `main.dart` changes

```dart
import 'package:flutter_web_plugins/url_strategy.dart';

void main() async {
  // Clean URLs without "#" — required for SEO-friendly URLs.
  // Server already handles the SPA fallback (server_app.dart).
  usePathUrlStrategy();
  // ... existing init ...
}

// Switch MyApp from MaterialApp to MaterialApp.router:
MaterialApp.router(
  routerConfig: _router,
  // ... existing title, theme, localization ...
);
```

### Keep the address bar in sync as the user navigates

```dart
ref.listen(activeTabProvider, (prev, next) {
  if (next == null) return;
  final qp = <String, String>{
    if (next.layout != ReaderLayout.paliOnly)
      'layout': _layoutToSlug(next.layout),
    if (next.entryStart > 0) 'entry': '${next.entryStart}',
  };
  context.go(Uri(
    path: '/sutta/${next.textId}',
    queryParameters: qp.isEmpty ? null : qp,
  ).toString());
});
```

### End-to-end flow this enables

1. User A reads `dn1`, toggles side-by-side, jumps to entry 12.
   Address bar: `/sutta/dn1?layout=side-by-side&entry=12`.
2. User A copies, pastes into WhatsApp.
3. User B clicks → browser loads that URL → Flutter boots → router fires the
   `/sutta/:textIdSlug` route → `ReaderScreen` opens that sutta in side-by-side,
   scrolled to entry 12.

### Important design decisions to lock in before coding PR1

1. **Slug suffix in URL?** `/sutta/dn1-brahmajala-sutta` vs `/sutta/dn1`.
   *Recommended: slug suffix — better for sharing previews and SEO.*
2. **Layout aliases?** Accept both short (`pali`, `sbs`) and canonical
   (`pali-only`, `side-by-side`)? *Recommended: accept both, emit short.*
3. **Include `entry` for verse jumping?** *Recommended: yes — this is a feature
   shared links uniquely enable.*
4. **Should an explicit query param override user prefs?**
   *Recommended: yes. If the URL says `?layout=side-by-side`, honor it; if
   absent, fall back to saved preference.*

---

## PR1 also unlocks **mobile deep linking** (free)

The same `GoRoute` definitions work identically on web, iOS, and Android. You
write the routes once.

### User experience target

User taps `https://thewisdomproject.app/sutta/dn1?layout=side-by-side` in
WhatsApp on their phone:

```
                  ┌─ App installed?
                  │
       ┌──────────┴──────────┐
       │ YES                 │ NO
       ▼                     ▼
  ┌─────────────────┐   ┌────────────────────┐
  │ App opens       │   │ Browser opens      │
  │ directly to     │   │ that URL → static  │
  │ DN1 side-by-    │   │ HTML page → smart  │
  │ side. No        │   │ banner "Open in    │
  │ browser shown.  │   │ app" → App Store.  │
  └─────────────────┘   └────────────────────┘
```

The OS picks the branch — we don't write the "is app installed?" check. (The
browser fallback lands on the static HTML page from
[`../web-strategy/web-rewrite-strategy.md`](../web-strategy/web-rewrite-strategy.md).)

### What makes this work — two tiny config files

This is **not** the old `wisdomproject://sutta/dn1` custom-scheme approach (no
fallback, looks spammy in chat previews). It's the modern standard:

- **iOS — Universal Links**: host
  `https://thewisdomproject.app/.well-known/apple-app-site-association`
  declaring which paths the app handles. Our shelf server serves it — one more
  route.
- **Android — App Links**: host
  `https://thewisdomproject.app/.well-known/assetlinks.json`.

iOS config example:

```json
// /.well-known/apple-app-site-association
{
  "applinks": {
    "details": [{
      "appID": "TEAMID.com.thewisdomproject.app",
      "paths": ["/sutta/*"]
    }]
  }
}
```

```xml
<!-- ios/Runner/Runner.entitlements -->
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:thewisdomproject.app</string>
</array>
```

Android equivalent: `AndroidManifest.xml` intent filter + `assetlinks.json`.

**Key point**: zero extra Flutter code beyond PR1. When iOS/Android cold-starts
the app from a Universal Link, the OS passes the URL into the Flutter engine and
go_router picks it up via the same routes used on web.

---

## Open questions to answer before coding starts

1. URL shape: pure ID (`/sutta/dn1`) vs slugged
   (`/sutta/dn1-brahmajala-sutta`)? Must match the static site's choice (see the
   web-rewrite-strategy doc) so links are interchangeable.
2. Which `ReaderTab` fields really need to round-trip through URLs? (See table
   above.)
3. Domain for canonical URLs — is `thewisdomproject.app` the production host?
4. Should layout query params *override* the user's saved preference, or only
   set it when the user has no preference? *Recommendation: override only for
   the session, don't persist.*
5. ~~URL-level coexistence with the static HTML site~~ **Resolved 2026-06-12**:
   one origin — static at `/` + `/sutta/*`, app under `/app/*` (build with
   `--base-href /app/`); see the *Hosting & URL coexistence* section of
   [`../web-strategy/web-rewrite-strategy.md`](../web-strategy/web-rewrite-strategy.md).

---

## Notes / loose ends

- `usePathUrlStrategy()` removes the `#` fragment — needed so shared URLs are
  clean and so they line up with the static site's real paths.
- Keep query-param parsing **lenient**. Unknown values → null → fall back to
  defaults. Never throw on a malformed shared URL.
- When mobile deep linking ships, verify that cold-start launches from a
  Universal Link preserve query strings. `go_router` does, but worth one
  integration test.
- Don't forget the navigator's tree state. Opening `/sutta/dn1` should also
  expand the left-side tree to show DN1 highlighted (the existing
  `navigator_sync_provider` machinery should already do this once the tab is
  opened).
</content>
