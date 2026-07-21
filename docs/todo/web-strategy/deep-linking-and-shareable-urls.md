# Deep Linking & Shareable Sutta URLs

> Status: **ACTIVE PLAN — decisions locked 2026-07-06; reading-layout-in-URL added 2026-07-20** (was Proposal since
> 2026-05-13). Split out of the former `web-deep-linking-seo-and-shareable-urls.md`
> on 2026-06-11; the SEO / static HTML half lives in
> [`../web-strategy/static-web-hosting.md`](../web-strategy/static-web-hosting.md)
> and [`../web-strategy/static-html-site-plan.md`](../web-strategy/static-html-site-plan.md).
> First consumer: **AI research citations** (tap a cited source → open in reader) —
> see [`ai-qa-and-suttacentral-reference-resolver-plan.md`](./research/ai-qa-and-suttacentral-reference-resolver-plan.md) Part D.

---

## The four scenarios one URL must serve

One universal HTTPS link, e.g. `https://sammaditthi.app/tipitaka/sn-2-3-1-3?e=12.4`:

1. **Inside the app** (research citation, future in-app cross-refs): no OS
   involved — parse the link, open a reader tab at that node/entry.
2. **Browser on a machine without the app**: the URL serves the web page —
   the **static HTML site** owns `/tipitaka/*` (SEO/LLM surface); the Flutter web
   app lives under `/app/*`. Until the static site ships, the Dart server's SPA
   fallback serves Flutter web, which parses `Uri.base` at startup.
3. **Mobile browser / device with the app installed**: links **tapped in other
   apps** are intercepted by the OS (Universal Links / App Links) and open the
   app. *Pasted/typed* URLs stay in the browser by OS design — the web page's
   "Open in app" banner covers that case.
4. **WhatsApp / Gmail / any app**: tap → app opens directly (OS interception).
   The rich preview thumbnail comes from the static page's OG meta tags.
   *(Caveat: a few apps open links in their own in-app webview, which can bypass
   the OS interception — the web page's "Open in app" banner (scenario 3) is the
   safety net. A normal chat-link tap in WhatsApp does hand off to the app.)*

## Decisions (locked 2026-07-06)

| Decision | Choice | Why |
|---|---|---|
| **URL identity** | **`/tipitaka/<nodeKey>`** (BJT tree node key, e.g. `sn-2-3-1-3`) | Matches the static-site plan's committed URLs; covers **all** content (commentary `atta-*`, treatises, Vinaya); maps 1:1 to `openTabFromNodeKeyProvider`. ~~`/sutta/<textId>`~~ **superseded**: `ReaderTab.textId` is declared but never populated anywhere — it was never the app's real navigation identity. |
| **Path segment** | **`/tipitaka/`** (class `TipitakaLink`) — renamed from `/sutta/` same day | `/sutta/atta-…` (commentary) was self-contradictory inside one URL. "tipitaka" follows the content-noun pattern of scripture-reference sites (Wikipedia `/wiki/`, Bible.com `/bible/`, Access to Insight literally `/tipitaka/`), names the subject for humans + a small SEO keyword plus. Used in the **umbrella sense** (as tipitaka.lk uses it): aṭṭhakathā is strictly outside the Tipiṭaka — accepted, precedent covers it. |
| **Entry-level target** | Query param **`?e=<pageIndex>.<entryIndexInPage>`** | Path = identity, query = view state. Same coordinates `ReaderTab`/search results already use. Optional; absent → sutta start. |
| **Reading layout** *(added 2026-07-20)* | Query param **`?layout=<ReaderLayout.name>`** — `paliOnly` / `sinhalaOnly` / `sideBySide` / `stacked` | View state, same slot as `?e=`. Token = the enum's `.name`, i.e. the exact string the app **already persists** (`last_reader_layout_provider.dart`), so URL ⇄ storage ⇄ enum need no mapping table. Optional + lenient: absent or unknown → the reader's own preferred layout (`resolveSeedLayout`); a valid token overrides for that open. Path form (`/…/stacked`) rejected (breaks path=identity; needs a static rewrite); hash form (`#stacked`) rejected (collides with the chapter `#<nodeKey>` single-view filter). |
| **Edition flexibility** | Not in the *path*; optional `?edition=` query, **app surfaces only** *(scope locked 2026-07-21)* | The nodeKey is a *tree address*, not "render BJT". Multi-edition (SuttaCentral, A.P. de Zoysa) is scoped to the **app** (Flutter web `/app/*` + native); the static site is **BJT-only**. So `?edition=` is a query modifier meaningful only under `/app/*` — the static `/tipitaka/*` pages never emit or read it. An SC-uid alias (`/s/sn15.3` → redirect) = data + one parse rule. Full model in **Editions & the two web surfaces** below. |
| **Router** | **Defer go_router** | The 4 scenarios need link *receiving*, not URL-driven app state. `app_links` (mobile/desktop) + `Uri.base` (web, at startup) feed one LinkOpener that reuses `openTabFromNodeKeyProvider`. go_router's real benefit (address-bar sync in Flutter web) lands on the demoted surface — the static site owns web URLs — and can be adopted later; the codec/opener are exactly what it would call. |
| **Dev scheme** | **`sammaditthi://`** custom scheme, dev/QA only | Universal/App Links can't be verified against localhost (OS fetches `/.well-known/` over real HTTPS). The scheme tests the whole OS→app→reader pipe today, incl. macOS. **Never appears in shared links.** |
| **Link base URL** | `--dart-define=LINK_BASE_URL`, default **`http://localhost:8080`** | Same idiom as `RESEARCH_BASE_URL`. 8080 = the Dart content server (SPA fallback), so shared links work in dev and on the LAN Windows box. Production host (`sammaditthi.app`) is config, not code. |
| **Citations resolve client-side** | Server `deeplink` stays `null` | The SC→BJT resolver is Dart (`wisdom_shared`); the app already loads it for search-by-reference. `citation.uid → nodeKeyForUid() → open`. No Python duplicate of the concordance. |

### SEO is NOT this plan's job (and is unaffected by it)

Flutter web renders to canvas — crawlers see an empty shell **with or without
go_router**. Google/LLM/preview-bot traffic on `/tipitaka/*` is served by the
static HTML site (full text in source). This plan only decides what happens
when a *human with the app* uses the same URL. The single shared contract
between the two plans is the URL shape `/tipitaka/<nodeKey>` — identical on both
sides, per the static plan's C3.

---

## Editions & the two web surfaces (scope locked 2026-07-21)

Two sibling surfaces share **one URL grammar** but split the work:

| Path | Surface | Edition(s) | Indexed? | Renderer |
|---|---|---|---|---|
| `/`, `/tipitaka/<nodeKey>` | **Static site** | **BJT only** | ✅ yes — the SEO surface | plain HTML, zero-JS |
| `/app/…`, `/app/tipitaka/<nodeKey>` | **Flutter web** (the app) | **multi-edition** (BJT, SC, A.P. de Zoysa…) | ❌ no (`robots` Disallow `/app/`) | Flutter SPA (canvas) |

- **Static = BJT-only, by design.** Its motivation is BJT-based discoverability /
  SEO / fast reading — not an edition browser. This *deletes* all multi-edition SEO
  machinery (no `hreflang`/`canonical` edition pages) from the static side.
- **Multi-edition lives only in the app.** Editions are already app-side data
  (`Edition` entity + registry + per-edition datasource — see
  [`multi_edition_architecture.md`](./multi_edition_architecture.md)).
- **`?edition=<editionId>`** (e.g. `sc`, `apz`) is therefore a query modifier only
  meaningful under `/app/*`; the static site never emits or reads it. Token = the
  `editionId` the app already stores → URL ⇄ registry, no mapping table (same trick
  as `?layout=`).

### Flutter-web URLs — same grammar, `/app/` prefix

A full app URL stacks the same modifiers on the same permanent node address:

```
https://host/app/tipitaka/sn-2-3-1-3?e=12.4&layout=sideBySide&edition=sc
         └base┘└─── shared grammar ───┘└──────── modifiers ────────┘
```

- **Landing in (built).** Flutter reads the whole URL once via `Uri.base` at
  startup → the LinkOpener opens that sutta / position / layout / edition. Clean
  `/app/tipitaka/…` paths need Flutter's **path-URL strategy** (else the default
  ugly `#`-hash form) **+** a host **SPA fallback** (`/app/* → /app/index.html`) so
  deep URLs serve the shell instead of 404. The `TipitakaLink` codec already strips
  the `/app/` base.
- **Sharing out (planned).** Flutter web is a SPA, so the **address bar does not
  auto-track** in-app navigation (no `go_router` — deferred). Sharing is therefore
  an explicit reader-tab **"copy link / share"** button that *builds* the canonical
  URL from the tab's state (node + `e` + layout + edition), in the form the
  **Sharing & resolution** rule picks below — identical on native and web. This is
  why go_router isn't needed for correctness.
- **go_router (optional, later).** Adds live address-bar sync + browser
  back/forward + copy-straight-from-the-bar. Additive; the share button already
  covers sharing.

### Sharing & resolution *(open sub-decision resolved 2026-07-21)*

**Routing — each URL opens its own surface; no edge compute.** `/tipitaka/*` are
real static files (served directly); `/app/*` is the Flutter shell via one
SPA-fallback **rewrite** (`/app/*  /app/index.html  200`) — a static `_redirects`
line, **not** a Pages Function. Nothing inspects a link to reroute it, so the two
forms differ only by the `/app/` prefix.

**Static → app link (on every BJT page).** Each static sutta page carries an
*"Open in the app"* link to `/app/tipitaka/<nodeKey>` with the page's own
`?e=`/`?layout=` query — a plain `<a href>`, zero-JS, literally the page's own URL
with the `/app/` prefix added. It's the doorway from the indexed BJT page into the
full multi-edition reader (and on a phone with the app installed, the OS opens the
**native** app instead — golden rule 1). No logic needed — it's the mechanical
reverse of the emit rule.

**Which form to share — web default = static (the "better gift").** When a link
is bound for the *web* (recipient has no app), the default surface is the
**static site**: faster, indexed, real WhatsApp preview, degrades best — and it
*still* opens the native app if installed, *still* offers "Open in app" if not.
Static is BJT-only, so the emit rule keys on **edition**, not on where you clicked:

| Reading | Share button emits | Web-fallback lands on |
|---|---|---|
| **BJT** | `/tipitaka/<nodeKey>` | static site — the better gift |
| **non-BJT** (SC, A.P. de Zoysa) | `/app/tipitaka/<nodeKey>?edition=…` | Flutter web — the only surface that can render it |

So a BJT reading shared from *anywhere* (static, Flutter web, or native) emits
`/tipitaka/`; a non-BJT reading can only be `/app/…?edition=` (static can't render
it). Escape hatch (rare): a secondary "copy app link instead" for someone who
explicitly wants the Flutter-web form — one smart default, never two co-equal
buttons.

**Golden rules — invariant of the emit choice** (they live a layer *below* the
share button, so no emit model can compromise them):
- *Installed → native app opens* — guaranteed by the App-Links files
  (`apple-app-site-association` / `assetlinks.json`) claiming **both** `/tipitaka/*`
  **and** `/app/tipitaka/*`. Every emitted form opens the app when installed.
- *Deep link → correct in-app location* — guaranteed by the `TipitakaLink` codec:
  it strips the `/tipitaka/` or `/app/` prefix and reads the same
  `nodeKey`+`e`+`layout`+`edition`, landing on the exact sutta/position/layout/edition.

The emit choice therefore affects **only** what a *no-app web recipient* sees
(static vs Flutter shell) — never the installed-app path or in-app navigation.
*Asterisk (constant, not caused by any model):* a link tapped inside WhatsApp's own
in-app browser may not auto-fire the Universal Link (OS/WebView limit) — the static
page's "Open in app" banner is the safety net, one more vote for BJT → `/tipitaka/`.

---

## Architecture

```
                 ┌──────────────────────────────────────────┐
                 │  wisdom_shared: TipitakaLink codec (pure) │
                 │  parse(Uri) ⇄ build(baseUrl)              │
                 │  {nodeKey, pageIndex?, entryIndex?}       │
                 └───────┬──────────────┬───────────────┬────┘
   in-app sources        │              │               │      future consumers
   ┌─────────────────────┴──┐   ┌───────┴────────┐   ┌──┴──────────────────┐
   │ research citation tap  │   │ app_links      │   │ static-site generator│
   │ (uid → resolver →      │   │ stream (OS) +  │   │ / Dart server        │
   │ nodeKey → TipitakaLink)│   │ Uri.base (web) │   │ (same URL grammar)   │
   └─────────────────────┬──┘   └───────┬────────┘   └─────────────────────┘
                         ▼              ▼
                 ┌──────────────────────────────────────────┐
                 │  LinkOpener (presentation provider)       │
                 │  await tree ready → nodeByKey → open tab  │
                 │  via openTabFromNodeKeyProvider(+page/e)  │
                 └──────────────────────────────────────────┘
```

- **Codec** lives in `packages/wisdom_shared/lib/src/links/tipitaka_link.dart` —
  pure Dart, shared with the server and the future static generator. Lenient
  parsing (malformed → `null`, never throw). Accepts `http(s)` on any host,
  the `/app/` base-href form, and `sammaditthi://`. Carries
  `{nodeKey, pageIndex?, entryIndex?, layout?}`; `layout` is the raw
  `ReaderLayout.name` token so the package stays Flutter-free (it never imports
  the enum) — the sink resolves token→enum leniently.
- **LinkOpener** awaits `navigationTreeProvider.future` (cold-start links can
  arrive before the tree loads), validates the node exists, then opens through
  the existing tab machinery — deep links behave exactly like tree/search opens.
- **Incoming links**: `app_links` package (iOS/Android/macOS — cold + warm
  start, custom scheme + universal links); on web, parse `Uri.base` once at
  startup. Flutter's built-in deep-link navigation is disabled
  (`FlutterDeepLinkingEnabled=false` / `flutter_deeplinking_enabled=false`) so
  it never races the plugin.

### What from `ReaderTab` goes in the URL (unchanged analysis, re-keyed)

| Field | In URL? | Reason |
|---|---|---|
| `nodeKey` | ✅ path | Identity (was `textId` — superseded, see Decisions) |
| `pageIndex` + `entryStart` | ✅ query `e=` | Content-addressable jump |
| `layout` | ✅ query `?layout=` | **Locked v1 2026-07-20** (see Decisions). Optional; absent → the reader's preferred layout. Token = `ReaderLayout.name`. |
| `splitRatio`, `scrollOffset`, `panes`, `contentFileId` | ❌ | Device/edition-specific view state |

## Universal / App Links — when the domain is live

Unchanged from the original research; parked until `sammaditthi.app` exists:

- **iOS/macOS**: host `https://<domain>/.well-known/apple-app-site-association`
  (`appID`, `"paths": ["/tipitaka/*"]`), + `com.apple.developer.associated-domains`
  entitlement `applinks:<domain>`.
- **Android**: host `/.well-known/assetlinks.json` + `autoVerify` https
  intent-filter for `/tipitaka/*`.
- Both files can be served by the Dart shelf server (one route each) or the
  static site host. The **app-side code needs no change** — the OS just starts
  delivering https URIs through the same `app_links` stream the custom scheme
  already exercises.

Dev-testing reality: custom scheme = full pipe today (all platforms);
Android http intent-filter on the LAN box = chooser-based testing; iOS
Universal Links = only with the real domain.

---

## Build phases

1. **`TipitakaLink` codec** in `wisdom_shared` (+ export).
2. **App wiring** — `LINK_BASE_URL` config, LinkOpener provider,
   `openTabFromNodeKeyProvider` gains optional explicit `pageIndex`/`entryStart`/`layout`
   (the sink `openTipitakaLinkProvider` maps the codec's raw `layout` token →
   `ReaderLayout?`, lenient; null → `resolveSeedLayout`),
   `app_links` + `Uri.base` listeners, platform config (`sammaditthi://` on
   iOS/macOS/Android; disable Flutter's built-in deeplink handler).
3. **Research citations** — citation tap → bottom sheet (cited source: ref +
   title + snippet) → **Open in reader** when `uid` resolves via the shared
   resolver; graceful "not linked yet" otherwise; **Copy link** action builds
   the canonical URL.
4. **Concordance pilot coverage** — grow `sc-to-bjt.json` seed to all of SN 15
   (title-confirmed), matching the ingested pilot corpus. Full build tool stays
   a separate task (see the resolver plan §B.4 / findings doc).
5. **Later**: share/copy-link on reader tabs (the shared URL carries the tab's
   current `?layout=`), `/.well-known` files + entitlements
   when the domain is live, SC-uid alias URLs, `?edition=` param, go_router if
   Flutter-web address-bar UX ever matters, segment-level anchors (v2).

## Notes

- Keep parsing **lenient** — unknown/malformed parts → defaults, never throw.
- **`?layout=` — one token set, both surfaces, backward-compatible.** Token =
  `ReaderLayout.name`; absent/unknown → the reader's preferred layout
  (`resolveSeedLayout`), a valid token overrides for that open. The single sink
  `openTipitakaLinkProvider` (`deep_link_provider.dart`) does the lenient
  token→enum mapping, so **existing consumers need no change**: the live one —
  **AI research citations** (`CitationSourceSheet` → `TipitakaLink(nodeKey: …)`,
  Part D) — passes no layout and keeps opening in the preferred layout. `?layout=`
  is *produced* by the reader-tab "copy link" (from the tab's current layout) and
  *consumed* by incoming OS/shared links. The static HTML site honours the same
  token via the ~8-line enhancement in
  [`../web-strategy/static-html-site-plan.md`](../web-strategy/static-html-site-plan.md)
  §7 (still works with no JS).
- **Out-of-range `?e=` values** (code-review 2026-07-06, deferred): the reader
  already clamps (`multi_pane_reader_widget` sublist-clamp; entries via
  `.skip()`), so a stale `?e=9999.4` shows the "No content to display" empty
  state — no crash, but not the ideal "degrade to the node's own start".
  Proper fix = reset the tab's coordinates when the loaded content proves them
  out of range (page count is unknown at open time). Do this when links go
  public and re-pagination between releases makes stale links a real
  population.
- Deep-link opens reuse the tab machinery, so navigator tree sync
  (`syncNavigatorToActiveTabProvider`) behaves as with any other open.
- When Universal Links ship, verify cold-start launches preserve query strings
  (one integration test).
