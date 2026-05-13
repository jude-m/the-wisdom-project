# Web Deep Linking, SEO, and Shareable Sutta URLs

> Status: **Proposal / Design** — not yet started.
> Captured: 2026-05-13.
> Owner: TBD.

## Why this matters

Today the Flutter web build is a single-page app served from `/`. The
URL never changes regardless of which sutta the user opens. Three real
problems flow from that:

1. **No shareable links.** A user reading DN1 in side-by-side view
   can't copy a link, paste it in WhatsApp, and have the recipient land
   on the same sutta in the same view.
2. **No SEO.** Flutter web renders to a `<canvas>` (CanvasKit). Even
   when Googlebot executes our JS, it sees an opaque canvas instead of
   "Brahmajāla Sutta… එවං මෙ සුතං…". The site is effectively invisible
   to search engines.
3. **No discoverability for AI/LLM training.** Most LLM crawlers don't
   run JS at all; they ingest raw HTML. With no per-sutta HTML pages
   they can't cite, reference, or learn from the content.

These are three different problems with three different fixes — but
they all share one prerequisite: **every sutta needs a stable URL**.

---

## What's already in the codebase that helps us

- `server/lib/src/server_app.dart:91-101` — the shelf server already
  falls back to `index.html` for any unknown path. That's the SPA
  fallback we need for deep links to work at all.
- `lib/presentation/models/reader_tab.dart:60-63` — `ReaderTab.textId`
  (e.g. `'dn1'`, `'mn100'`, `'sn1-1'`) is explicitly described as
  "edition-agnostic". Perfect basis for canonical URLs.
- `server/lib/src/handlers/text_handler.dart` — already exposes
  `/api/text/<fileId>` and reads the same data we'd render to HTML.
- `lib/presentation/models/reader_layout.dart` — `ReaderLayout` enum
  (`paliOnly`, `sinhalaOnly`, `sideBySide`, `stacked`) is what we'd
  serialize into URL query params.

So the foundation is in place — we just don't read or write URL state
anywhere.

---

## The three-layer solution

Each layer is independently shippable and addresses a different
audience.

| Layer | Audience | Fixes |
|---|---|---|
| 1. Flutter routing | Humans on web | Shareable links |
| 2. Server-side HTML rendering | Googlebot, LLMs | SEO, AI ingestion |
| 3. Sitemap + robots + JSON-LD | Search engines at scale | Crawl discoverability |

---

## Layer 1 — Deep linking inside the Flutter app (PR1)

This is the foundation. Switch from `home: const ReaderScreen()` to
`go_router`, and let the router drive which sutta is open.

### URL shape

```
/sutta/<textId>[-<slug>]?layout=<mode>&entry=<n>
```

Examples:

- `/sutta/dn1` — Brahmajāla, user's default reading mode.
- `/sutta/dn1-brahmajala?layout=side-by-side` — opens side-by-side.
- `/sutta/mn10?layout=stacked&entry=12` — Satipaṭṭhāna, stacked, jump
  to entry 12.
- `/sutta/sn1-1?layout=pali` — short alias for `paliOnly`.

Rule of thumb:

- **Path = identity** (what content). Stable, canonical, SEO-relevant.
- **Query = view state** (how it's displayed). Optional, overridable.

Two URLs that differ only in query params point to the **same canonical
page** for search engines (we'll emit `<link rel="canonical">` in
PR2) — but restore different reader modes for humans.

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
  // Server already handles the SPA fallback (server_app.dart:91).
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
3. User B clicks → browser loads that URL → Flutter boots → router
   fires the `/sutta/:textIdSlug` route → `ReaderScreen` opens that
   sutta in side-by-side, scrolled to entry 12.

### Important design decisions to lock in before coding PR1

1. **Slug suffix in URL?** `/sutta/dn1-brahmajala-sutta` vs `/sutta/dn1`.
   *Recommended: slug suffix — better for sharing previews and SEO.*
2. **Layout aliases?** Accept both short (`pali`, `sbs`) and canonical
   (`pali-only`, `side-by-side`)? *Recommended: accept both, emit
   short.*
3. **Include `entry` for verse jumping?** *Recommended: yes — this is a
   feature shared links uniquely enable.*
4. **Should an explicit query param override user prefs?**
   *Recommended: yes. If the URL says `?layout=side-by-side`, honor it;
   if absent, fall back to saved preference.*

---

## Layer 1 also unlocks **mobile deep linking** (free with PR1)

The same `GoRoute` definitions work identically on web, iOS, and
Android. You write the routes once.

### User experience target

User taps `https://thewisdomproject.app/sutta/dn1?layout=side-by-side`
in WhatsApp on their phone:

```
                  ┌─ App installed?
                  │
       ┌──────────┴──────────┐
       │ YES                 │ NO
       ▼                     ▼
  ┌─────────────────┐   ┌────────────────────┐
  │ App opens       │   │ Browser opens      │
  │ directly to     │   │ that URL → SSR     │
  │ DN1 side-by-    │   │ page (Layer 2) →   │
  │ side. No        │   │ smart banner       │
  │ browser shown.  │   │ "Open in app" →    │
  │                 │   │ App Store.         │
  └─────────────────┘   └────────────────────┘
```

The OS picks the branch — we don't write the "is app installed?" check.

### What makes this work — two tiny config files

This is **not** the old `wisdomproject://sutta/dn1` custom-scheme
approach (no fallback, looks spammy in chat previews). It's the modern
standard:

- **iOS — Universal Links**: host
  `https://thewisdomproject.app/.well-known/apple-app-site-association`
  declaring which paths the app handles. Our shelf server serves it —
  one more route.
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

Android equivalent: `AndroidManifest.xml` intent filter +
`assetlinks.json`.

**Key point**: zero extra Flutter code beyond PR1. When iOS/Android
cold-starts the app from a Universal Link, the OS passes the URL into
the Flutter engine and go_router picks it up via the same routes used
on web.

---

## Layer 2 — Server-rendered HTML for the same URL (PR2)

Solves SEO and AI-crawler discoverability. The insight: the Dart shelf
server already has the data via `/api/text/<fileId>`. Add a *parallel*
HTML route at the **same path** browsers and bots hit.

### Why server-rendered, not "prerender Flutter"

Flutter web paints to `<canvas>`. Prerendering the Flutter app
produces a canvas in the DOM, which is just as unreadable to bots as
the live app. The only viable path is rendering real semantic HTML
from the same data source, on the server.

We have a custom Dart shelf server already. Adding one HTML handler
costs almost nothing — no external prerender service, no extra infra.

### Hooking it into `server_app.dart`

Before the existing static-file handler at `server_app.dart:67`:

```dart
// Match /sutta/<textIdSlug>
if (request.url.path.startsWith('sutta/')) {
  return SuttaHtmlHandler(db, logger, assetsPath).handle(request);
}
```

### The handler

1. Parse `textId` from path.
2. Load sutta JSON (same data `/api/text/...` returns).
3. Render an HTML template with:
   - `<title>` and `<meta name="description">`.
   - Open Graph / Twitter Card tags for nice chat link previews.
   - Full Pali + Sinhala text as real DOM (`h1`, `h2`, `p`).
   - `<link rel="canonical">` pointing to the slugged path.
   - JSON-LD structured data (`Book` / `CreativeWork`).
   - `flutter_bootstrap.js` so humans get the live app once Flutter
     loads.

Skeleton:

```dart
String renderSuttaHtml(Sutta s) => '''
<!DOCTYPE html>
<html lang="si">
<head>
  <meta charset="UTF-8">
  <title>${escape(s.paliName)} (${escape(s.textId)}) — The Wisdom Project</title>
  <meta name="description" content="${escape(s.firstParagraph)}">

  <meta property="og:title" content="${escape(s.paliName)}">
  <meta property="og:description" content="${escape(s.firstParagraph)}">
  <meta property="og:type" content="article">
  <meta property="og:url" content="https://thewisdomproject.app/sutta/${s.textId}">

  <link rel="canonical" href="https://thewisdomproject.app/sutta/${s.textId}-${s.slug}">

  <script type="application/ld+json">${jsonLdFor(s)}</script>

  <base href="/">
</head>
<body>
  <!-- What Googlebot and LLM crawlers actually read -->
  <article id="ssr-content">
    <h1>${escape(s.paliName)}</h1>
    <h2>${escape(s.sinhalaName)}</h2>
    ${renderEntriesAsHtml(s.entries)}
  </article>

  <!-- Flutter takes over for humans -->
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
''';
```

### Why this isn't "cloaking"

Cloaking = showing different content to bots vs. humans. We're showing
the **same content** to everyone; humans then get a JS upgrade to an
interactive reader. Google explicitly endorses this as
"progressive enhancement".

### Caching

SSR pages are deterministic per `textId` — cache aggressively:

```
Cache-Control: public, max-age=86400, stale-while-revalidate=604800
```

`_gzipMiddleware` in `server_app.dart:120` already compresses HTML.

---

## Layer 3 — Sitemap + robots.txt + JSON-LD (PR3)

Solves "Google needs to discover all ~10,000 suttas," not just whatever
gets linked externally.

```dart
// server_app.dart
if (request.url.path == 'sitemap.xml') return sitemapHandler.handle();
if (request.url.path == 'robots.txt')  return robotsHandler.handle();
```

- Sitemap iterates the same source `navigation_tree_provider` consumes
  and emits one `<url>` per sutta.
- `robots.txt` allows crawl and points to the sitemap.
- Each SSR page already includes JSON-LD from Layer 2.

This is what takes us from "Google found one page" to "Google indexed
10,000 pages."

---

## Suggested rollout order

| PR | Scope | Audience served |
|---|---|---|
| **PR1** | `go_router`, `/sutta/:textId`, URL ↔ tab sync, path strategy | Humans on web (sharing) |
| **PR2** | `SuttaHtmlHandler` rendering full HTML at `/sutta/<id>` | Googlebot, LLM crawlers |
| **PR3** | `sitemap.xml`, `robots.txt`, JSON-LD polish | Search engines at scale |
| **PR4** | Pretty slugs, social cards, smart "Open in app" banner | Polish |

Each PR is independently shippable and testable.

---

## Open questions to answer before coding starts

1. URL shape: pure ID (`/sutta/dn1`) vs slugged (`/sutta/dn1-brahmajala-sutta`)?
2. Which `ReaderTab` fields really need to round-trip through URLs?
3. Domain for canonical URLs — is `thewisdomproject.app` the production host?
4. Do search / dictionary / tree nodes also deserve URLs in v1, or only
   suttas? (Recommendation: suttas only — they're the highest-value SEO
   asset by far.)
5. Should layout query params *override* the user's saved preference,
   or only set it when the user has no preference? (Recommendation:
   override only for the session, don't persist.)

---

## Notes / loose ends

- `usePathUrlStrategy()` is required for SEO — the `#` fragment is
  never sent to the server, so without it bots can't reach the SSR
  page.
- Keep query-param parsing **lenient**. Unknown values → null →
  fall back to defaults. Never throw on a malformed shared URL.
- When mobile deep linking ships, verify that cold-start launches from
  a Universal Link preserve query strings. `go_router` does, but worth
  one integration test.
- Don't forget the navigator's tree state. Opening `/sutta/dn1` should
  also expand the left-side tree to show DN1 highlighted (the existing
  `navigator_sync_provider` machinery should already do this once the
  tab is opened).
