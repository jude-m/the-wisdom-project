# Static Web — Hosting (Cloudflare Pages), SEO Plumbing & the App Boundary

> Status: **Direction decided 2026-06-11; hosting reworked for Cloudflare Pages
> 2026-07-20** (the Dart content server is being retired).
> This is the **hosting + deployment + crawl-plumbing** companion to the build
> spec, [`static-html-site-plan.md`](./static-html-site-plan.md), which
> owns the *generator* and the page shape (zero-JS navigator, the 4 reading
> layouts, per-sutta-vs-grouped file boundaries). To avoid duplication, page-shape
> detail is **not** repeated here — this doc is only *where the files live and how
> crawlers find them.*
> The demoted Jaspr-rewrite analysis (Options compare, clean-architecture audit,
> shared-package extraction) now lives in [`jaspr/`](./jaspr/).
> Companion todo docs: [`../todo/serverless-deployment-decision.md`](../todo/serverless-deployment-decision.md)
> (backends), [`../todo/deep-linking-and-shareable-urls.md`](../todo/deep-linking-and-shareable-urls.md)
> (in-app link receiving + URL grammar).
>
> ⚠️ **URL identity** is the bare `nodeKey` under `/tipitaka/` (e.g.
> `/tipitaka/sn-2-3-1-3`), locked 2026-07-06 — **not** the older `/sutta/<textId>`
> examples that predate that decision.

---

## TL;DR — the two decisions

1. **Discoverability surface = a standalone, honest static HTML site** (SSG flat
   files, in the spirit of [buddhadust.net](https://buddhadust.net)) — **not** a
   Jaspr rewrite of the rich app. It serves SEO, LLM crawlers, bots, the slowest
   connections, and casual "read one sutta from a link" readers. Full rationale
   (Options A / A′ / B / C, and the built Jaspr prototype) is in
   [`jaspr/`](./jaspr/); the short version is below.
2. **Hosting = Cloudflare Pages, fully static, no content server.** The Dart
   shelf server is being retired: all read-only canon (per-page text + FTS +
   dictionary) moves **client-side into SQLite via [Drift](https://pub.dev/packages/drift)**
   — native FFI on mobile/desktop, **wasm + OPFS** in the browser (download-once)
   — so **Flutter web becomes a static bundle too.** The only backend left is the
   scale-to-zero **research (RAG) Worker**. Net: **zero always-on infrastructure**
   (source: [`../todo/serverless-deployment-decision.md`](../todo/serverless-deployment-decision.md)
   update 2026-07-16).

Keep Flutter for the native apps **and** the web app. The static site *links into*
the web app via a plain button — it never secretly becomes it.

---

## Why static, in three lines

Flutter web paints to `<canvas>` (CanvasKit), so crawlers and LLMs see an opaque
canvas, not "Brahmajāla Sutta… එවං මෙ සුතං…". Real static HTML fixes all three of:
**SEO**, **AI/LLM ingestion** (most LLM crawlers don't run JS at all), and
**slow-device reading** (no multi-MB WASM cold-start). We *route around* Flutter's
SEO gap rather than fixing Flutter web itself.

> **Watch-item — Option C (HTML-in-Canvas).** A Chrome origin trial that would let
> Flutter web embed real HTML (crawlable text, native selection) *without leaving
> Flutter* — the single-codebase endgame that could make both the static site and
> a Jaspr rewrite unnecessary. Experimental, Chrome-only. **Track, don't bank.**

---

## App ↔ site boundary — share the core, not the HTML (2026-06-14)

The generated HTML is a **build output of the web surface, not a content source
for the app.** Feeding the same HTML into the Flutter app (WebView / `flutter_html`)
to collapse the two pipelines was **rejected** — it forfeits the app's native text
selection, word-tap dictionary, and in-page search, and the 4 layouts are CSS on
the web but Flutter widgets in the app regardless. The shared seam is the
**structured content + `wisdom_shared` logic** both renderers already consume
(→ native widgets for the app, → HTML/CSS for the site), *not* the rendered HTML.

Companion app decision: the app's **reading unit is a single sutta** (micro-suttas
grouped by vagga), dropping continuous cross-sutta scroll. A bounded sutta is only
tens of entries, so the app renders it eagerly — cheap *and* preserving cross-page
text selection — which is why the [`../done/both_mode_lazy_builder.md`](../done/both_mode_lazy_builder.md)
lazy migration was dropped.

---

## Hosting on Cloudflare Pages — two static builds, one scheme

Two things ship as **static builds**; one **Worker** stays. Nothing is always-on.

| Surface | Build artifact | Served by | Indexed? |
|---|---|---|---|
| Static HTML site (`/`, `/tipitaka/*`) | SSG (`static_site_generator/`) → flat `.html` | **Cloudflare Pages** | ✅ canonical |
| Flutter web app (`/app/*`) | `flutter build web` — canon DB in **Drift wasm/OPFS**, downloaded once in-browser | **Cloudflare Pages** | ❌ noindex |
| Research Q&A | TypeScript on **Cloudflare Workers** (scale-to-zero) | Workers | ❌ |

- **No content API on this origin.** Text / FTS / dictionary are *client-side*
  (Drift). The app's only network backend is the research Worker.
- **CORS now applies to the research call** (the app on Pages → the Worker on a
  different origin). Today it's pinned to the tester origin, with the App Check
  gate deferred (serverless doc §6). Content reads have *no* API, so *no* CORS.

### Free-tier fit — files, HTTPS, bandwidth (verified 2026-07-20)

All of this is the **free** Pages plan:

- **HTTPS is automatic and free.** Every project is served over HTTPS on
  `‹project›.pages.dev` out of the box (Cloudflare wildcard cert). A custom domain
  (`sammaditthi.app`) gets a **free auto-provisioned SSL cert** (Universal SSL) +
  HTTP→HTTPS redirect. This is precisely what lets the App-Links `.well-known`
  files (below) be fetched over real HTTPS — the OS requirement for Universal /
  App Links.
- **File cap = 20,000 files per site.** The **whole canon** (all nikāyas +
  commentaries `atta-*` + Abhidhamma) generates **~14,900 files** under the current
  page model (~12,900 sutta + chapter pages — the ones in `sitemap.xml` — plus
  ~2,000 container TOC pages). Fits with ~5,000 headroom. Note grouping the
  formulaic runs (prototype plan §6/§13.1) **saves ~1,450 files** vs
  one-page-per-micro-sutta — so grouping helps the file budget *and* SEO.
- **Bandwidth and requests are unlimited** on the static side — Googlebot, GPTBot,
  ClaudeBot and human readers never hit a metered wall. This directly serves the
  SEO / LLM-ingestion / slow-connection goals.
- **Single-file max 25 MiB** — every generated page is far under (largest is one
  full commentary node).

### One Pages project (path-split) — recommended

Preserve the old plan's clean URL scheme, but let **Cloudflare Pages** do the
routing the retired shelf server used to do:

- Static site at `/` and `/tipitaka/*`; Flutter web under **`/app/*`**.
- Build Flutter with **`flutter build web --base-href /app/`** — writes
  `<base href="/app/">` and confines `flutter_service_worker.js` to `/app/`
  (a SW that escapes to `/` would cache the static pages and break the
  "works with no JS / on the slowest connection" promise — verify it stays scoped).
- **SPA fallback scoped to `/app/`** via a Pages [`_redirects`](https://developers.cloudflare.com/pages/configuration/redirects/)
  rule (`/app/* /app/index.html 200`) or `_routes.json`. **Not a global
  404 → index.html** — that would let the Flutter shell swallow the indexed static
  URLs (the single most important gotcha, same as the old shelf plan).
- Same origin → the "Open in app" button is a plain same-site link; simplest.

### Two projects (subdomain) — the later option

A second Pages project on `app.<domain>` gives natural cache / service-worker /
cookie isolation, at the cost of DNS setup and being cross-origin. Reserve it for
if/when the surfaces need to scale independently; path-split is fine to start.

### The nav button (static → app) and the root rule

- **Button:** a plain `<a href="/app/tipitaka/<nodeKey>">Open in the full reader
  app →</a>`. **No `flutter_bootstrap.js` auto-boot on the static pages** — that
  auto-swap-into-canvas is exactly what made the rejected "Option A" hacky.
- **Root `/` is the content home *and* the landing page** (carries the app CTA) —
  never a contentless splash, and **never auto-redirect `/` → `/app`**. Auto-redirect
  would hand the strongest SEO/LLM URL to the un-indexable canvas and punish
  weak-device readers.

### App Links / `.well-known` — static files on Pages

When the production domain is live, the OS-interception files are **plain static
files Cloudflare Pages serves directly** (no server needed):

- iOS/macOS: `/.well-known/apple-app-site-association` (`"paths": ["/tipitaka/*"]`).
- Android: `/.well-known/assetlinks.json` (+ `autoVerify` intent-filter in the app).

Details and the app-side receiver live in the deep-linking plan; the app code
needs no change — the OS just starts delivering `https` URIs through the same
`app_links` stream the dev custom scheme already exercises.

---

## SEO / crawl plumbing (owned here, per the prototype plan)

The prototype plan (§10/§12) delegates the crawl-discovery layer to this doc.
The SSG emits all of it as static files:

- **Per page:** `<title>`, `<meta name="description">`, `<link rel="canonical">`
  (self), Open Graph / Twitter Card tags (chat previews), JSON-LD
  (`Book` / `CreativeWork`).
- **`sitemap.xml`:** one `<url>` per **distinct sutta file + chapter file** (not
  the content-free redirect stubs) — this is what takes Google from "found one
  page" to "indexed ~13,000 pages" (full-canon count, §"Free-tier fit" above).
- **`robots.txt`:** allow crawl, point to the sitemap, `Disallow: /app/`.
- **Keep the app out of the index:** the Flutter `index.html` gets
  `<meta name="robots" content="noindex">`; static pages canonical to their own
  `/tipitaka/...` URL, **never** to `/app/...`.
- **Not cloaking:** the static site shows the *same* HTML to bots and humans;
  the Flutter app is a clearly separate surface the user opts into via the button.

---

## Open questions (post-server)

1. **Static-site search.** Server-rendered FTS is **gone** (no server). Options:
   (a) **none** — the tree + Google (buddhadust does this; defensible); (b) a link
   into the app's search; (c) a small client-side index (fights the zero-JS /
   slow-internet ethos — the prototype plan already leaned against it). *Defer* —
   search was out of scope for the prototype anyway.
2. **Production domain** (`sammaditthi.app`?) — feeds canonical URLs, OG tags, and
   the App Links `.well-known` files.
3. **One Pages project (path-split) vs two (subdomain).** *Lean: path-split.*
4. **`LINK_BASE_URL`** for shared links moves from the `:8080` dev server default
   to the Pages production domain (deep-linking plan).

---

## Superseded — the old shelf-server hosting model (kept for provenance)

The former model served **both** surfaces from one origin via the Dart `shelf`
server: ordered prefix routing in `server_app.dart` (`healthz` / `api/` / `app/` /
static), gzip + cache middleware, `/api/…` same-origin (so "no CORS"), and a
global `index.html` fallback scoped to `/app/`. That is **retired with the content
server** (canon → client-side Drift; research → Worker). The *intent* carries over
unchanged — static at `/`, app at `/app/*`, root is the content home, never
redirect `/` → `/app` — only the **mechanism** changes: Cloudflare Pages static
hosting + `_redirects`, instead of shelf routing. The old per-sutta HTML was going
to be rendered by a shelf handler *or* SSG; now it is **only** SSG flat files.
