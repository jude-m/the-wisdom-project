# Web Rewrite Strategy — SEO, the Static HTML Site, and Jaspr

> Status: **Proposal / Design** — direction decided 2026-06-11, not yet started.
> Split out of the former `web-deep-linking-seo-and-shareable-urls.md` on
> 2026-06-11. The in-app deep-linking / shareable-URL half now lives in
> [`../todo/deep-linking-and-shareable-urls.md`](../todo/deep-linking-and-shareable-urls.md).
> Companion docs (all in this folder):
> [`web-rewrite-clean-architecture-audit.md`](./web-rewrite-clean-architecture-audit.md),
> [`jaspr-web-client-migration.md`](./jaspr-web-client-migration.md),
> [`jaspr-prototype-findings.md`](./jaspr-prototype-findings.md).

## TL;DR — the decision (2026-06-11)

For a **single maintainer**, the durable answer to "be the default
Google-/LLM-indexed home for the Tipitaka, and serve readers on the slowest
connections" is a **standalone, honest, static HTML site** (think
[buddhadust.net](https://buddhadust.net/backmatter/indexes/sutta/sutta_toc.htm)),
**not** a Jaspr rewrite of the rich app.

- **Build** the pure static HTML site (SSG, flat files) as a first-class
  product: a no-JS navigator + a very basic search. This serves SEO, LLMs,
  bots, slow connections, and casual "read one sutta from a link" readers.
- **Keep** the existing Flutter web app as the interactive reader, linked
  from the static site.
- **Demote** the full Jaspr rewrite to "revisit only if web-app perf becomes a
  real, voiced complaint, or if Option C (HTML-in-Canvas) matures." The
  prototype proved it's *viable*; it is no longer on the critical path.

The rest of this doc records why, and the concrete shape of the static site.

---

## Why this matters

Today the Flutter web build is a single-page app served from `/`. The
URL never changes regardless of which sutta the user opens, and the page paints
to a `<canvas>`. Three real problems flow from that:

1. **No SEO.** Flutter web renders to a `<canvas>` (CanvasKit). Even when
   Googlebot executes our JS, it sees an opaque canvas instead of
   "Brahmajāla Sutta… එවං මෙ සුතං…". The site is effectively invisible to
   search engines.
2. **No discoverability for AI/LLM training.** Most LLM crawlers don't run JS
   at all; they ingest raw HTML. With no per-sutta HTML pages they can't cite,
   reference, or learn from the content.
3. **Bad on the slowest connections / weakest devices.** Multi-MB CanvasKit
   cold-start + WASM is the opposite of what someone on a 2G connection or a
   low-end phone needs to read a sutta.

(The fourth problem — *no shareable links inside the app* — is a different
concern with a different fix; it lives in
[`../todo/deep-linking-and-shareable-urls.md`](../todo/deep-linking-and-shareable-urls.md).)

---

## What's already in the codebase that helps us

- `server/lib/src/server_app.dart` — the shelf server already serves the
  Flutter web static build **and** the API, with gzip + caching middleware.
  Adding HTML routes (or serving pre-generated HTML files) is incremental.
- `server/lib/src/handlers/text_handler.dart` — already reads the same
  per-sutta data (`assets/text/<fileId>.json`) we'd render to HTML.
- `server/lib/src/handlers/fts_handler.dart` — full-text search already
  exists; a basic server-rendered search results page is mostly a thin HTML
  view over it.
- `lib/presentation/models/reader_tab.dart` — `ReaderTab.textId`
  (e.g. `'dn1'`, `'mn100'`, `'sn1-1'`) is "edition-agnostic" — the natural
  basis for canonical URLs.
- `packages/wisdom_shared/` — the `**bold**`/`__underline__`/`{footnote}`
  marker parsing and document parsing are pure Dart with **zero Flutter
  imports**; the Jaspr prototype already exercised `**bold**` → `<strong>`.
  That's the only "renderer" the static site needs, and it already exists.

So the foundation is in place. The static site is mostly *new HTML templates
fed by data the server already has*.

---

## Architectural alternatives — three options

> Originally captured 2026-06-06 after reviewing the 2026 Dart web landscape
> (Jaspr, HTML-in-Canvas). Updated 2026-06-11 with the static-site reframe
> below.

The historical framing treated server-rendered HTML as a "stopgap" because it
described a **hacky** version of it (render HTML, then boot
`flutter_bootstrap.js` so the CanvasKit canvas swaps in on top). That version
has real problems — see Option A. The **standalone static site** (Option A′)
sidesteps all of them.

### Option A — Bot-only SSR that swaps into Flutter: the *hacky* version
Server-render HTML at `/sutta/<id>`, then load `flutter_bootstrap.js` so
Flutter "takes over" for humans.
- Bots get real HTML; SEO works.
- **But:** Flutter CanvasKit cannot *hydrate* server HTML — it boots, discards
  the server DOM, and paints a `<canvas>`. So you run **two renderers of the
  same content** (an HTML template + Flutter widgets) that must be kept in sync
  forever (drift = cloaking risk), plus a visible content flash on the canvas
  swap. Humans still get the heavy CanvasKit experience.
- **Verdict: don't.** This is the version that earned "stopgap / workaround."

### Option A′ — Standalone static HTML site: the *honest* version ✅ chosen
A genuinely separate, lightweight HTML site that is **its own destination**
(like buddhadust.net). No canvas-swap, no `flutter_bootstrap.js` on these
pages. The page links to "Open in the full reader app" — it does **not**
secretly become it.

This one decision deletes every objection to Option A:

| Objection to Option A | Applies to A′? |
|---|---|
| Two renderers to keep in sync | ❌ The HTML site is the only renderer of *that* surface |
| Cloaking risk (bot HTML ≠ human canvas) | ❌ Humans and bots get the *same* HTML page |
| Content flash on canvas swap | ❌ There is no canvas on these pages |

It is not a compromise — it is just a normal static website, which is exactly
what the inspiration (buddhadust.net) is. Concrete shape in the next section.

### Option B — Jaspr: a full SSR + hydration rewrite of the rich app
[Jaspr](https://jaspr.site) is a Flutter-like component framework that renders
natively to HTML/CSS/DOM with real SSR + hydration + SSG, in Dart.
- Real HTML for everyone *and* an interactive app — fixes SEO, slow-device
  perf, and keeps the rich reading experience, all on one web surface.
- Reuses our pure-Dart logic (`wisdom_shared`, domain models) in-process; the
  shelf API stays as the data source. The
  [prototype](./jaspr-prototype-findings.md) verified SSR+hydration without
  flash, multi-tab with scroll preservation, ~120 KB gzipped client bundle,
  and in-process reuse — 14/14 e2e checks.
- **Cost:** a *second full UI codebase* (Flutter native + Jaspr web), re-authoring
  the entire presentation layer (multi-tab, word-tap dictionary, selection
  menu, in-page highlight, themes, font-scale), **plus** pre-1.0 ecosystem
  churn — the prototype hit two version breakages in a single day
  (`jaspr_cli` ≥ Dart 3.11; `riverpod` 3.3.2 broke `jaspr_riverpod`, pinned to
  3.2.1).
- **Why it's demoted, not chosen:** for a solo maintainer, the static site
  (A′) already covers the *stated* goals (SEO, LLM, slow internet, casual
  readers), and the rich app *already exists* in Flutter web. Jaspr's unique
  remaining benefit — give the rich app to web users without CanvasKit
  weight/jank — is real but narrow, and not worth a second pre-1.0 UI codebase
  *right now*.

### Option C — HTML-in-Canvas: the keep-one-codebase future (watch, don't bank)
A Chrome API (Google I/O 2026) letting the canvas embed real HTML elements —
would give Flutter Web crawlable text, native selection/copy, accessibility,
and translation **without leaving Flutter** (single codebase).
- **Status:** Chrome *origin trial* (experimental), Chrome-only, timeline
  uncertain. Do not stake a launch on it. Track it as the path that could make
  both A′ and B unnecessary for the single-codebase ideal.

### Recommendation
**Ship Option A′ (standalone static HTML site)** as the discoverability +
slow-connection surface. **Keep Flutter web** as the interactive app. **Defer
Option B (Jaspr)** to a someday-maybe; **track Option C**. Keep Flutter for the
5 native apps regardless. Note that A′ and B aren't mutually exclusive — if the
rich web app ever *does* move to Jaspr, the data→HTML rendering logic A′ builds
is directly reusable.

---

## The static HTML site (Option A′) — concrete shape

This is small because the server already has the data.

### Generation: prefer SSG over live SSR
Pre-render all ~10,000 suttas to flat `.html` files at **build time** by
iterating the same navigation tree + reading the same `assets/text/<id>.json`.

- Flat files = CDN-cacheable, zero server compute, and pages survive even if
  the API/DB is down. This *is* the buddhadust model.
- Live SSR on the shelf server stays available as a fallback if freshness
  without rebuilds is ever needed — but SSG is more robust and cheaper to run.

### The navigator with zero JavaScript
Native `<details>`/`<summary>` gives a collapsible tree out of the box — no
framework, works on the slowest device, fully crawlable. The tree source is the
same one `navigation_tree_provider` consumes.

### Text rendering
Reuse the `**bold**`/`__underline__`/`{footnote}` → HTML logic from
`wisdom_shared` (already exercised by the prototype). This is the only renderer
the static site maintains, and it's tiny.

### Search — three honest options, cheapest first
1. **None.** buddhadust has none; the tree + Google does the work. Defensible.
2. **Server-rendered FTS results** (recommended sweet spot): a plain
   `<form method="get">` → `/search?q=…` → an HTML results page backed by the
   existing `FtsHandler`. "A very basic search is enough." ~Half a day.
3. Prebuilt client-side index — **skip**; it fights the zero-JS / slow-internet
   ethos.

### Fonts caveat for slow connections
Pali-in-Sinhala-script needs a Noto Sinhala webfont (hundreds of KB), which
slightly undercuts the "slowest internet" goal. Let it fall back to the system
Sinhala font and load the webfont only as a progressive enhancement
(`font-display: swap`).

### What you give up / honest risks
1. **You're not fixing Flutter web itself.** It still has no SEO and still
   ships CanvasKit; you're *routing around* it (discoverability via the static
   site, interactivity via the app). Fine *if* inbound web traffic lands on the
   static pages and they're good enough — for reading a sutta, they will be.
2. **Two web surfaces = an information-architecture problem.** Need clear,
   non-confusing linking: "Read full text" (static) ↔ "Open in the full reader
   app." Get this wrong and it feels like two half-products.
3. **Possible endgame worth naming:** if the static site gets good enough,
   Flutter web could eventually be *retired entirely* (native apps + static web
   only) — a big maintenance win for one person. Don't force it; but it's the
   direction this opens.

---

## SEO / HTML surface — implementation layers

These layers build the static site + its crawl plumbing. (The former Layer 1,
in-app deep linking, moved to the deep-linking doc.)

| Layer | Audience | Fixes |
|---|---|---|
| HTML pages (SSG `/sutta/<id>` + `<details>` navigator) | Googlebot, LLMs, slow connections, casual readers | SEO, AI ingestion, low-end perf |
| Sitemap + robots + JSON-LD | Search engines at scale | Crawl discoverability |

### HTML page rendering

The insight: the data already exists (`assets/text/<id>.json`, the same data
`/api/text/<fileId>` returns). Render real semantic HTML from it — `h1`/`h2`/`p`,
Pali + Sinhala as real DOM — at the canonical path.

Each page includes:
- `<title>` and `<meta name="description">`.
- Open Graph / Twitter Card tags for chat link previews.
- `<link rel="canonical">` pointing to the slugged path.
- JSON-LD structured data (`Book` / `CreativeWork`).
- A clear link to "Open in the full reader app" (the Flutter web app) — **no**
  `flutter_bootstrap.js` auto-boot on these pages (that's what made Option A
  hacky).

Skeleton (whether emitted at build time as a file, or by a shelf handler):

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
</head>
<body>
  <article id="ssr-content">
    <h1>${escape(s.paliName)}</h1>
    <h2>${escape(s.sinhalaName)}</h2>
    ${renderEntriesAsHtml(s.entries)}
  </article>
  <p><a href="/app/sutta/${s.textId}">Open in the full reader app →</a></p>
</body>
</html>
''';
```

#### Why this isn't "cloaking"
Cloaking = showing different content to bots vs. humans. The static site shows
the **same content** to everyone — there is no separate human canvas version of
*these pages*. (The Flutter app is a clearly-separate surface the user opts into
via a link.)

#### Caching
HTML pages are deterministic per `textId` — cache aggressively. As flat SSG
files behind a CDN this is automatic; as a shelf handler:

```
Cache-Control: public, max-age=86400, stale-while-revalidate=604800
```

`_gzipMiddleware` in `server_app.dart` already compresses HTML.

### Sitemap + robots.txt + JSON-LD

Solves "Google needs to discover all ~10,000 suttas," not just whatever gets
linked externally.

```dart
// server_app.dart (or emitted as static files at build time)
if (request.url.path == 'sitemap.xml') return sitemapHandler.handle();
if (request.url.path == 'robots.txt')  return robotsHandler.handle();
```

- Sitemap iterates the same source the navigator uses and emits one `<url>` per
  sutta.
- `robots.txt` allows crawl and points to the sitemap.
- Each HTML page already includes JSON-LD.

This is what takes us from "Google found one page" to "Google indexed 10,000
pages."

---

## Hosting & URL coexistence — one domain, path-split (decided 2026-06-12)

Both surfaces live on **one origin** (`sammaditti.com`), split by path. The
existing shelf server already serves both the API and static files, so this is
routing order, not new infrastructure.

| URL | Served by | Indexed? |
|---|---|---|
| `/` | static site home (= the landing page) | ✅ canonical |
| `/sutta/dn1` | static HTML page | ✅ canonical |
| `/search?q=…` | static server-rendered results | ✅ |
| `/app` | Flutter web (boots the SPA) | ❌ noindex |
| `/app/sutta/dn1` | Flutter web (go_router route) | ❌ noindex |
| `/api/…` | existing API (same origin for both) | ❌ |

The static site owns the bare `/sutta/*` paths (the SEO-valuable ones); the app
lives under `/app/*`. Same content, two surfaces, one origin → **no CORS** (both
call `/api/…` same-origin).

### The root is the content home, NOT a splash page

`/` is the static content home, and that page **doubles as the landing page**
with a prominent "Open the full reader app →" call-to-action. We deliberately do
**not** build a separate contentless splash that just offers two links:

- The root domain is the single strongest SEO/LLM asset — a bare two-link splash
  wastes it on a doormat with nothing to index.
- A "choose your experience" interstitial is a known anti-pattern (the old
  "click to enter" / "mobile vs desktop" splash) — a mandatory extra click for
  every visitor, including the slow-connection and bot audiences the static site
  exists for.
- We lose nothing: the content home *is* the landing page and still carries the
  app CTA.

**Hard rule: never auto-redirect `/` → `/app`.** That hands the root URL to the
un-indexable canvas and punishes weak-device readers. The app is opt-in via a
button, never the default destination of the root.

### Server routing (ordered prefix check in `server_app.dart`)

```dart
(Request request) async {
  final path = request.url.path;
  if (path == 'healthz')        return healthHandler.handle(request);
  if (path.startsWith('api/'))  return topRouter.call(request);      // shared API

  // Flutter web app — rooted under /app/
  if (path == 'app' || path.startsWith('app/')) {
    final res = await flutterStaticHandler(request);
    // SPA fallback must point at the APP's index, not the static site's 404:
    if (res.statusCode == 404) return serveFile('$flutterWebRoot/index.html');
    return res;
  }

  return staticSiteHandler(request);   // everything else → static HTML site
}
```

> ⚠️ The single most important change vs today: the SPA `index.html` fallback
> must be **scoped to `/app/`**. The current global 404→`index.html` fallback in
> `server_app.dart` would make the Flutter shell swallow the static URLs.

### Four gotchas that bite if missed

1. **Build Flutter with the right base href:** `flutter build web --base-href /app/`.
   This writes `<base href="/app/">`; go_router then treats `/app/` as its root,
   so an in-app route `/sutta/dn1` shows as `/app/sutta/dn1` automatically — no
   hardcoded `/app` in routes.
2. **Service-worker scope = `/app/`.** Building with `--base-href /app/` confines
   `flutter_service_worker.js` to `/app/`. Verify it: a SW that escapes to `/`
   would intercept/cache the *static* pages and silently break the "works with no
   JS / on the slowest connection" promise. (Serve with
   `Service-Worker-Allowed: /app/` if you ever need to be explicit.)
3. **Keep the app out of the index:** `robots.txt` → `Disallow: /app/`; the
   Flutter `index.html` gets `<meta name="robots" content="noindex">`; static
   pages emit `<link rel="canonical">` to their own `/sutta/...` URL, never to
   `/app/...`.
4. **One origin = no CORS.** Both surfaces call `/api/…` same-origin, so the
   currently-permissive `Access-Control-Allow-Origin: *` can later be tightened.

### Path (`/app`) vs subdomain (`app.sammaditti.com`)

Use **`/app`** while one shelf server serves both API + static: same origin
(zero CORS), one deploy, shared storage. A subdomain only earns its keep later
if the static site moves to a pure CDN while the app stays on the server (then
it gives natural cache/SW/cookie isolation at the cost of DNS + CORS setup).

### Composes with mobile deep links

- **Mobile:** the OS intercepts `sammaditti.com/sutta/dn1` → opens the native app
  (the `paths: ["/sutta/*"]` rule in the deep-linking doc).
- **Web:** the same `/sutta/dn1` serves the static page, which links to
  `/app/sutta/dn1`.
- The web app's internal URLs all live under `/app/...` and never collide with
  the indexed static paths.

One coherent scheme across static web, app web, and mobile.

---

## Open questions to answer before coding starts

1. URL shape for static pages: pure ID (`/sutta/dn1`) vs slugged
   (`/sutta/dn1-brahmajala-sutta`)? *Recommended: slugged — better previews/SEO.*
2. Domain for canonical URLs — is `thewisdomproject.app` the production host?
3. Do search / dictionary / tree nodes also deserve HTML pages in v1, or only
   suttas? *Recommended: suttas only — highest-value SEO asset by far; plus the
   `<details>` tree page itself as the navigator.*
4. SSG build pipeline: where does it run (CI step? part of the server build?),
   and where do the flat files get served from (CDN? the shelf static handler)?
5. ~~How do the static site and the Flutter web app coexist at the URL level?~~
   **Resolved 2026-06-12** — see *Hosting & URL coexistence* above: one origin,
   static at `/` + `/sutta/*`, app at `/app/*`, root is the content home (not a
   splash), never auto-redirect `/` → `/app`.

---

## Notes / loose ends

- A static-first surface means the `#`-fragment URL strategy concern from the
  old SPA setup is irrelevant here — these are real paths to real files.
- Keep any query-param parsing **lenient**. Unknown values → fall back to
  defaults. Never throw on a malformed URL.
- The navigator page should mirror the app's tree so a reader landing on a
  sutta can move around without JS.
</content>
