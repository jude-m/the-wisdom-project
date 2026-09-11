# Deep Linking & Shareable Sutta URLs

> Status: **ACTIVE PLAN — decisions locked 2026-07-06; reading-layout-in-URL added 2026-07-20** (was Proposal since
> 2026-05-13). **Build phases 1–4 are shipped** (codec, app wiring, research
> citations, SN 15 concordance seed) and so are three of the four test layers;
> what remains is **`?layout=`, the reader-tab share button, `?edition=`,
> Universal/App Links, and layer B's tests** — see Build phases.
> Split out of the former `web-deep-linking-seo-and-shareable-urls.md`
> on 2026-06-11; the SEO / static HTML half lives in
> [`static-web-hosting.md`](../../decisions/static-web-hosting.md)
> and [`../web-strategy/static-html-site-plan.md`](../web-strategy/static-html-site-plan.md).
> First consumer: **AI research citations** (tap a cited source → open in reader) —
> see [`ai-qa-and-suttacentral-reference-resolver-plan.md`](../research/ai-qa-and-suttacentral-reference-resolver-plan.md) Part D.
> Test coverage for all four layers of this path is the last section of this
> doc — **merged in 2026-08-15** from `deep-link-test-coverage-plan.md`, which
> was a test plan for this document and had no reason to be a separate file.
>
> **2026-07-23 — app surface moved to a subdomain.** Flutter web is no longer
> path-split at `/app/*`; it is its own Pages project on **`app.sammaditthi.net`**
> (see `static-web-hosting.md` → "Project topology"). Net effect on URLs: the
> app form is now the **identical path grammar on a different host** — no
> prefix at all. The codec was already host-agnostic, so it needs no change;
> the legacy `/app/` prefix stays *tolerated* on parse for old dev links.

---

## The four scenarios one URL must serve

One universal HTTPS link, e.g. `https://sammaditthi.net/tipitaka/sn-2-3-1-3?e=12.4`:

1. **Inside the app** (research citation, future in-app cross-refs): no OS
   involved — parse the link, open a reader tab at that node/entry.
2. **Browser on a machine without the app**: the URL serves the web page —
   the **static HTML site** owns `/tipitaka/*` on the apex (SEO/LLM surface); the
   Flutter web app lives on **`app.sammaditthi.net`** (own Pages project, 2026-07-23).
   (Until the domain + Pages projects are live, this scenario is dev-only — the
   Dart dev server that used to serve it was retired 2026-07-16.)
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
| **Edition flexibility** | Not in the *path*; optional `?edition=` query, **app surfaces only** *(scope locked 2026-07-21)* | The nodeKey is a *tree address*, not "render BJT". Multi-edition (SuttaCentral, A.P. de Zoysa) is scoped to the **app** (Flutter web on `app.sammaditthi.net` + native); the static site is **BJT-only**. So `?edition=` is a query modifier meaningful only on the app surfaces — the static `/tipitaka/*` pages never emit or read it. Full model in **Editions & the two web surfaces** below. |
| **Router** | **Defer go_router** | The 4 scenarios need link *receiving*, not URL-driven app state. `app_links` (mobile/desktop) + `Uri.base` (web, at startup) feed one LinkOpener that reuses `openTabFromNodeKeyProvider`. go_router's real benefit (address-bar sync in Flutter web) lands on the demoted surface — the static site owns web URLs — and can be adopted later; the codec/opener are exactly what it would call. |
| **Dev scheme** | **`sammaditthi://`** custom scheme, dev/QA only | Universal/App Links can't be verified against localhost (OS fetches `/.well-known/` over real HTTPS). The scheme tests the whole OS→app→reader pipe today, incl. macOS. **Never appears in shared links.** |
| **Link base URL** | `--dart-define=LINK_BASE_URL`, default **`https://sammaditthi.net`** *(2026-09-01)* | Same idiom as `RESEARCH_BASE_URL` — the host is config, not code. The default was `http://localhost:8080` while no domain existed: that was the retired Dart content server's SPA fallback (server gone since 2026-07-16), so it had been pointing at nothing for months, and it is Flutter web's dev port besides. It is the **apex**, not `app.`, for the reason the emit table below gives. Hosting doc open-Q #4, now resolved. |
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

| URL | Surface | Edition(s) | Indexed? | Renderer |
|---|---|---|---|---|
| apex — `/`, `/tipitaka/<nodeKey>` | **Static site** | **BJT only** | ✅ yes — the SEO surface | plain HTML, zero-JS |
| `app.sammaditthi.net/tipitaka/<nodeKey>` | **Flutter web** (the app, own Pages project) | **multi-edition** (BJT, SC, A.P. de Zoysa…) | ❌ no (`X-Robots-Tag: noindex` on the app project — crawlable-but-noindexed, fixed 2026-07-23; see `static-web-hosting.md`) | Flutter SPA (canvas) |

- **Static = BJT-only, by design.** Its motivation is BJT-based discoverability /
  SEO / fast reading — not an edition browser. This *deletes* all multi-edition SEO
  machinery (no `hreflang`/`canonical` edition pages) from the static side.
- **Multi-edition lives only in the app.** Editions are already app-side data
  (`Edition` entity + registry + per-edition datasource — see
  [`multi_edition_architecture.md`](../multi_edition_architecture.md)).
- **`?edition=<editionId>`** (e.g. `sc`, `apz`) is therefore a query modifier only
  meaningful on the app origin; the static site never emits or reads it. Token = the
  `editionId` the app already stores → URL ⇄ registry, no mapping table (same trick
  as `?layout=`).

### Flutter-web URLs — same grammar, `app.` subdomain (updated 2026-07-23)

A full app URL stacks the same modifiers on the same permanent node address —
the **identical path** the apex uses, just on the app host (no prefix):

```
https://app.sammaditthi.net/tipitaka/sn-2-3-1-3?e=12.4&layout=sideBySide&edition=sc
     └── app host ──┘└── shared grammar ──┘└──────── modifiers ────────┘
```

- **Landing in (the read is built; the clean-URL half is not).** Flutter reads
  the whole URL once via `Uri.base` at startup → the LinkOpener opens that sutta
  / position / edition (layout is not built). Clean `/tipitaka/…` paths need
  Flutter's **path-URL strategy** — not set anywhere in `lib/` or `web/` today,
  so the app host still produces the ugly `#`-hash form — **+** the app
  project's **SPA fallback**
  (`/* /index.html 200` — safe there: the project contains nothing but the app)
  so deep URLs serve the shell instead of 404. The `TipitakaLink` codec is
  host-agnostic, so app-host URLs parse as-is; its `/app/`-prefix stripping is
  now legacy tolerance for old dev links.
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

**Routing — each URL opens its own surface; no edge compute.** Apex
`/tipitaka/*` are real static files (served directly); the app project on
`app.sammaditthi.net` serves the Flutter shell via its own SPA-fallback **rewrite**
(`/*  /index.html  200`) — a static `_redirects` line, **not** a Pages Function.
Nothing inspects a link to reroute it, so the two forms differ only by **host**
(apex vs `app.`); the path is identical.

**Static → app link (on every BJT page).** Each static sutta page carries an
*"Open in the app"* link to `https://app.sammaditthi.net/tipitaka/<nodeKey>` with the
page's own `?e=`/`?layout=` query — a plain **absolute** `<a href>` (cross-origin
now), zero-JS, literally the page's own URL on the app host. It's the doorway
from the indexed BJT page into the full multi-edition reader (and on a phone
with the app installed, the OS opens the **native** app instead — golden
rule 1). No logic needed — it's the mechanical reverse of the emit rule.

**Which form to share — web default = static (the "better gift").** When a link
is bound for the *web* (recipient has no app), the default surface is the
**static site**: faster, indexed, real WhatsApp preview, degrades best — and it
*still* opens the native app if installed, *still* offers "Open in app" if not.
Static is BJT-only, so the emit rule keys on **edition**, not on where you clicked:

| Reading | Share button emits | Web-fallback lands on |
|---|---|---|
| **BJT** | apex `/tipitaka/<nodeKey>` | static site — the better gift |
| **non-BJT** (SC, A.P. de Zoysa) | `https://app.sammaditthi.net/tipitaka/<nodeKey>?edition=…` | Flutter web — the only surface that can render it |

So a BJT reading shared from *anywhere* (static, Flutter web, or native) emits
the apex `/tipitaka/` form; a non-BJT reading can only be the `app.` form with
`?edition=` (static can't render it). Escape hatch (rare): a secondary "copy app
link instead" for someone who explicitly wants the Flutter-web form — one smart
default, never two co-equal buttons.

**Golden rules — invariant of the emit choice** (they live a layer *below* the
share button, so no emit model can compromise them):
- *Installed → native app opens* — guaranteed by the App-Links files
  (`apple-app-site-association` / `assetlinks.json`) served on **both origins**:
  the apex claims `/tipitaka/*`, and the `app.` project serves its own pair
  claiming the same paths (each Pages project hosts its own `.well-known/`).
  The app entitlement lists **both** domains (`applinks:sammaditthi.net` +
  `applinks:app.sammaditthi.net`; two Android intent-filter hosts). Every emitted form
  then opens the app when installed.
- *Deep link → correct in-app location* — guaranteed by the `TipitakaLink` codec:
  it is host-agnostic and reads the same `/tipitaka/` path grammar on either
  origin (legacy `/app/` prefix still tolerated), landing on the exact
  sutta/position/layout/edition via `nodeKey`+`e`+`layout`+`edition`.

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
   │ (uid → resolver →      │   │ stream (OS) +  │   │ (same URL grammar)   │
   │ nodeKey → TipitakaLink)│   │ Uri.base (web) │   │                      │
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
  parsing (malformed → `null`, never throw). Accepts `http(s)` on any host —
  which is exactly why the 2026-07-23 `app.sammaditthi.net` move needs **no codec
  change** — plus the legacy `/app/` base-href form and `sammaditthi://`. Carries
  `{nodeKey, pageKey?, pageIndex?, entryIndex?, originKey?}` — `pageKey` is the
  path key a nodeKey-shaped fragment overrode, `originKey` the canon sutta a
  merged vaṇṇanā was entered by. **`layout` is not among them**: `?layout=` is a
  locked decision that has never been built — see the `?layout=` note below.
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
| `layout` | ✅ query `?layout=` | **Locked v1 2026-07-20, not yet built** (see Decisions). Optional; absent → the reader's preferred layout. Token = `ReaderLayout.name`. |
| `splitRatio`, `scrollOffset`, `panes`, `contentFileId` | ❌ | Device/edition-specific view state |

## Universal / App Links — when the domain is live

Unchanged from the original research. **Unparked 2026-09-01**: `sammaditthi.net`
is registered, so the only thing still standing between this and shipping is
attaching the apex to the `sammaditthi` Pages project in the ops account. The
four files below are static, and each Pages project serves its own pair:

- **iOS/macOS**: host `https://sammaditthi.net/.well-known/apple-app-site-association`
  (`appID`, `"paths": ["/tipitaka/*"]`), + `com.apple.developer.associated-domains`
  entitlement — **both domains** since 2026-07-23: `applinks:sammaditthi.net` and
  `applinks:app.sammaditthi.net` (the `app.` Pages project serves its own AASA).
- **Android**: host `/.well-known/assetlinks.json` on **both origins** +
  `autoVerify` https intent-filter for `/tipitaka/*` with **two hosts**
  (`sammaditthi.net`, `app.sammaditthi.net`).
- All four files are plain static files, each served by its own Pages project.
  The **app-side Dart code needs no change** — the OS just starts delivering
  https URIs through the same `app_links` stream the custom scheme already
  exercises. The platform declarations, however, are written from scratch:
  `AndroidManifest.xml` today carries only the `sammaditthi://` custom scheme
  (no https intent-filter at all), and no `associated-domains` entitlement
  exists in `ios/` or `macos/`.

Dev-testing reality: custom scheme = full pipe today (all platforms);
Android http intent-filter on the LAN box = chooser-based testing; iOS
Universal Links = only with the real domain.

---

## Build phases

Phases 1–4 are **shipped**: the `TipitakaLink` codec in `wisdom_shared`, the app
wiring (`LINK_BASE_URL`, `openTipitakaLinkProvider`, explicit
`pageIndex`/`entryStart` on `openTabFromNodeKeyProvider`, `app_links` +
`Uri.base` listeners, `sammaditthi://` on iOS/macOS/Android with Flutter's
built-in deeplink handler disabled), research citations (tap → bottom sheet →
**Open in reader** when `uid` resolves, graceful "not linked yet" otherwise,
**Copy link** building the canonical URL), and the `sc-to-bjt.json` seed grown
to all of SN 15. The full concordance build tool stays a separate task (see the
resolver plan §B.4 / findings doc).

**What is left, in the order it unblocks itself:**

1. **`?layout=` — decided 2026-07-20, never built.** Nothing in `lib/` or the
   codec mentions it. The work is one field on `TipitakaLink` (raw
   `ReaderLayout.name` token, so the package stays Flutter-free and never
   imports the enum), the lenient token→enum mapping in the single sink
   `openTipitakaLinkProvider` (null/unknown → `resolveSeedLayout`), a `layout`
   argument through `openTabFromNodeKeyProvider`, and the ~8-line static-site
   enhancement in the static plan §7.
2. **Share / copy-link on reader tabs.** `tipitakaLinkUrlBuilderProvider` exists
   and already goes through `SitePlan.servingLink`, but its only caller is
   `citation_source_sheet.dart` — no reader tab emits a link. This is the whole
   "Sharing out" half of the emit table above, and it is what *produces*
   `?layout=`, so the two are one piece of work rather than two.
3. **`?edition=` param** — a modifier on the URL the share button builds, so it
   follows 2.
4. **Universal / App Links**: `/.well-known` files on **both** origins +
   entitlement + Android `autoVerify` intent-filter (see above), Flutter web's
   path-URL strategy and the app project's SPA fallback, and the cold-start
   query-string integration test.
5. **Later**: go_router if Flutter-web address-bar UX ever matters,
   segment-level anchors (v2).

## Notes

- **Short/alias URLs — PARKED 2026-07-26.** SC uids (`sn15.3`) resolve
  **in-app only** (citation → `sc-to-bjt.json` → nodeKey), never as a public URL:
  no `/s/sn15.3`, no bare `/sn15.3`, no redirect layer. The concordance is
  unaffected — it still grows to full sutta+Vinaya coverage (~4,000) for the RAG
  corpus. What changes: the P5 mechanism gate serves **one** feature (the
  grouped-leaf links), not two.
- Keep parsing **lenient** — unknown/malformed parts → defaults, never throw.
- **Grouped-sutta fragments (found 2026-07-22; fix LOCKED same day — user
  requires exact-sutta deep links even for grouped suttas): ✅ BOTH HALVES SHIPPED
  2026-08-23** (grouping plan S8). A folded leaf's canonical URL is
  `…/tipitaka/<pageKey>#<leafKey>` (static plan §6).
  - **Inbound.** `TipitakaLink.parse` prefers a nodeKey-shaped fragment over the
    path key and keeps the path key as `pageKey`, so the leaf opens and the page
    it came from is not lost. The descendant sanity-check turned out to be the
    wrong test — a mid-vagga chapter's leaves are its *siblings*, not its
    descendants — so the opener asks `SitePlan` instead: the target opens only
    when `plan.pageOf(fragment)` is the page named in the path, and otherwise
    the page does, which is what keeps a decorative `#top` from resolving the
    whole link to nothing. Asking the *tree* ("is this a real node") was the
    first shape and is the weaker question: it accepts a fragment naming a node
    served by some other page, where the site would show the path's page. Same
    map as the outbound half, so both directions agree with the site. The tree
    remains the fallback if the plan cannot be built — opening a link must not
    be where a snapshot problem first surfaces as an exception.
  - **Outbound.** The share button emits the URL the site actually serves —
    `plan.servingLink(link)` fills in the page, the fragment keeps the leaf —
    rather than a bare leaf URL that 404s. **This is a deliberate deviation from
    the line this bullet used to end on** ("the share button never needs to know
    grouping exists"): that held only once *something* answered at the leaf URL,
    and the mechanism for that (stub files vs Cloudflare Bulk Redirects) is still
    open at the P5 gate — see the hosting doc's "Grouped-leaf clean URLs". Rather
    than hand out URLs that 404 until a gate that has been deferred twice
    resolves, the app asks the plan. The knowledge stays in one place —
    `SitePlan`, which is where "which page serves this key" already lived for the
    site — so no caller grows its own idea of grouping. When P5 lands, the leaf
    URL starts working too and **both** forms land on the exact sutta, which is
    what the matrix always required; nothing here needs undoing.
- **`?layout=` — one token set, both surfaces, backward-compatible. NOT BUILT**
  (decided 2026-07-20; nothing in the codec or `lib/` reads or writes it — see
  build phases). Token = `ReaderLayout.name`; absent/unknown → the reader's
  preferred layout (`resolveSeedLayout`), a valid token overrides for that open.
  Doing the lenient token→enum mapping in the single sink
  `openTipitakaLinkProvider` (`deep_link_provider.dart`) is what keeps
  **existing consumers unchanged**: the live one — **AI research citations**
  (`CitationSourceSheet` → `TipitakaLink(nodeKey: …)`, Part D) — passes no
  layout and keeps opening in the preferred layout. `?layout=` is to be
  *produced* by the reader-tab "copy link" (from the tab's current layout) and
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

---

# Test coverage

> Status: **updated 2026-09-11.** Written after the code review of
> `packages/wisdom_shared/test/links/tipitaka_link_test.dart` (the first test
> the link codec ever had). **A, C and D are done**, A2 included; **B is the
> one layer still at zero.**
>
> Everything above owns the URL *grammar* and the decisions; this section only
> says **what proves it works**.

## TL;DR

Four layers carry a deep link. Three have tests.

| Layer | Code | Tests today |
|---|---|---|
| **A** URL codec | `packages/wisdom_shared/lib/src/links/tipitaka_link.dart` | 90, plus 58 in `test/pages/site_plan_test.dart` for the page the link resolves to; corpus sweep A2 done |
| **B** Reference resolver | `packages/wisdom_shared/lib/src/refs/suttacentral_ref_resolver.dart` | **zero** |
| **C** Static-site URL emission | `static_site_generator/lib/domain/site_page.dart`, `lib/render/page_template.dart` | 34 in `static_site_generator/test/`; five-URL hand-testing sheet in C2 |
| **D** App-side wiring | `lib/presentation/providers/deep_link_provider.dart`, `widgets/app/deep_link_listener.dart` | 13 |

**B** is what is left: pure Dart, no new infra, sub-second.

## The surface

```
"SN 15.3"  ──parseRef──►  "sn15.3"  ──concordance──►  "sn-2-3-1-3"      ← B
                                                            │
static-site href   /tipitaka/<key>   ───────────────────────┤           ← C
OS link            sammaditthi://tipitaka/<key>?e=12.4  ────┤
web start URL      Uri.base  ───────────────────────────────┤
                                                            ▼
                                                   TipitakaLink.parse   ← A
                                                            │
                                            openTipitakaLinkProvider    ← D
                                                            ▼
                                                       tab opens
```

## A — `packages/wisdom_shared/test/links/tipitaka_link_test.dart` — DONE

All nine shapes below are covered; the table stays as the record of *why* each
is pinned. Each was probed against the implementation on 2026-07-29; the stated
behaviour is what it does *today*.

| Shape | Today | Why it needs pinning |
|---|---|---|
| `…/tipitaka/sn-2-3#sn-2-3-1-3` | fragment **wins** → opens the leaf, path kept as `pageKey` | ✅ Shipped 2026-08-23; the deliberate flip is made and pinned in `tipitaka_link_test.dart`. Still worth covering here: a fragment that names no node (falls back to the page), and a `.html` suffix on the path. |
| `…?layout=stacked` | ignored, link survives | Part of the documented grammar (layout decision, 2026-07-20) but **not implemented anywhere in `lib/`**. Also test `?e=12.4&layout=stacked` for param independence. |
| `https://sammaditthi.net/tipitaka/<key>` | parses | The static-site production host. |
| `https://app.sammaditthi.net/tipitaka/<key>` | parses | The Flutter-web host — same path, no `/app/` prefix (topology decision, 2026-07-23). |
| `SAMMADITTHI://TIPITAKA/SN-2-3` | **parses** | Uppercase works on the custom scheme (`Uri` lowercases the host) but *not* on https. Both forms are pinned. |
| `sammaditthi://foo/tipitaka/<key>` | parses | Wrong custom-scheme host is tolerated as a path prefix. Intended? |
| `?e=1&e=2` | last wins → page 2 | |
| `?E=12.4` | ignored (param is case-sensitive) | |
| `…/tipitaka//sn-2-3` | parses (empty segments skipped) | |

### A2 — corpus sweep: every real nodeKey parses — DONE

`_verifyLinks` in `static_site_generator/tool/verify_corpus_invariants.dart`,
outside `test/` because `wisdom_shared` is Flutter-free by design and a 16k-node
load does not belong in a sub-second suite — the same split already used for
markers and tree. It went further than "every key parses": it round-trips every
key the plan serves through `urlFor` → `TipitakaLink.tryParse` →
`resolveTarget`, and checks every door into a merged vaṇṇanā is an inverse of
`canonKeysCoveredBy`.

**Snapshot, not a guarantee.** Re-run after every `tree.json` sync from
tipitaka.lk (see the canon-sync workflow): a newly-introduced dotted or
odd-shaped key breaks links again, and only this check would notice.

## B — new `packages/wisdom_shared/test/refs/suttacentral_ref_resolver_test.dart`

`SuttaCentralRefResolver` is the other half of the citation path and has never
been tested. It feeds **two** shipped features: tappable research citations
(`citation_source_sheet.dart:102-103`) and the "type SN 15.3 → jump" search.

Pure Dart with an injected concordance `Map`, so it is table-testable exactly
like the codec:

- `parseRef` accepts `"SN 15.3"`, `"sn 15.3"`, `"SN15.3"`, `"sn15.3"` → `sn15.3`
- **anchoring**: `"metta123"` and `"see SN 15.3 here"` must *not* parse
  (the regex is anchored precisely so ordinary search words don't fire)
- unknown book (`"xy1.2"`) → null; multi-dot (`"an3.65"`, `"sn15.3.1"`)
- `displayRef` round trip: `sn15.3` ⇄ `SN 15.3`, `dhp1` → `Dhp 1`, unknown book
  falls back to UPPERCASE, non-matching input returned unchanged
- `resolveToNodeKey` miss (well-formed ref, absent from the concordance) → null
- `isReady` false on an empty map

**Fixture, not the asset.** `assets/data/sc-to-bjt.json` is still the SN 15 seed
(20 entries, 1.1 KB) and `wisdom_shared` must keep building standalone — use a
handful of copied rows. When the full concordance is generated by
`tools/suttacentral_map/`, a "every uid resolves to a key that exists in
tree.json" sweep belongs in
`static_site_generator/tool/verify_corpus_invariants.dart`, not here — same
split the package already uses for markers and tree.

Effort: ~20 tests, one new file.

## C — `static_site_generator/test/` — codec ⇄ generator agreement — DONE

**The gap that mattered.** The generator builds the same URL grammar
independently and nothing checked the two agree. Once Universal Links are live,
**every static-site href is also an app deep link** — the OS intercepts the tap.
A divergence means the link works in a browser and dies in the app, which is
exactly the failure users report as "the app opened on the wrong page".

Two things closed it. Every href now funnels through **one** helper rather than
five hand-built strings, and that helper takes the path segment from the codec
itself (`TipitakaLink.pathSegment`), so **the segment can no longer drift**.
The shape around it is pinned by `test/wiring_contract_test.dart`: `hrefFor`
builds exactly the URL `SitePlan.urlFor` writes, chapter sections are anchored
by nodeKey, a folded leaf points at its chapter, a mid-vagga chapter's anchor
leaf points at its own row, and a leaf with its own file carries no chapter.
`verify_corpus_invariants.dart` then runs the same agreement over the whole
corpus rather than a synthetic tree (§ A2).

### C2 — hand-testing sheet: five live fragment pages

C's `id="<nodeKey>"` anchors are no longer "future" targets — they are live and
working on the dev deploy. These five URLs are the manual check, verified
2026-08-14 against that build (14,752 pages, 146 grouped).

Origin `https://dev.sammaditthi-dev.pages.dev` — Pages project `sammaditthi-dev`,
preview branch `dev`. Production is `https://sammaditthi.net`; swap the host and
every path below still holds.

Open each **with** the fragment (one sutta showing) and **without** it (the whole
vagga). That pair is the test — it is `:has(:target)` doing the single-view, so
only the browser can prove it.

| Link | Covers |
|---|---|
| [`/tipitaka/sn-1-1-7#sn-1-1-7-3`](https://dev.sammaditthi-dev.pages.dev/tipitaka/sn-1-1-7#sn-1-1-7-3) | Baseline. SN Devatāsaṃyutta, 7. අන්වවග්ගො, 10 prose suttas, middle anchor. |
| [`/tipitaka/atta-sn-1-1-7#atta-sn-1-1-7-3`](https://dev.sammaditthi-dev.pages.dev/tipitaka/atta-sn-1-1-7#atta-sn-1-1-7-3) | Commentary twin of the row above — same vagga, aṭṭhakathā side, 10 anchors. The pair to open side by side. |
| [`/tipitaka/sn-4-1-17#sn-4-1-17-30`](https://dev.sammaditthi-dev.pages.dev/tipitaka/sn-4-1-17#sn-4-1-17-30) | Most anchors in the corpus: 30 suttas, 47 KB, a peyyāla run. Also the **last** anchor. |
| [`/tipitaka/kn-thig-1#kn-thig-1-18`](https://dev.sammaditthi-dev.pages.dev/tipitaka/kn-thig-1#kn-thig-1-18) | Verse, not prose — Therīgāthā ekakanipāta, 18 gāthā entries, last anchor. |
| [`/tipitaka/vp-pct-1-3-1#vp-pct-1-3-1-1`](https://dev.sammaditthi-dev.pages.dev/tipitaka/vp-pct-1-3-1#vp-pct-1-3-1-1) | Different piṭaka — Vinaya sekhiya rules, 10 entries, **first** anchor. |

Between them: canon and commentary, prose and verse, Sutta and Vinaya, first /
middle / last anchor, and the largest grouped page there is.

Two gotchas, both found the hard way:

- **Drop the `.html`.** `/tipitaka/sn-1-1-7.html` 308-redirects to
  `/tipitaka/sn-1-1-7`. The fragment survives the redirect (browsers reapply it
  to the target), but the extensionless form is the real URL.
- **Keep the `dev.` prefix.** `sammaditthi-dev.pages.dev` without it addresses the
  project's *production* branch and 404s on these paths.

**This proves the browser half only** — `:has(:target)` single-view is
browser-side and nothing but a browser can show it. The app half of these same
five URLs is covered in code since 2026-08-23: the codec prefers the
nodeKey-shaped fragment and `SitePlan` decides which page serves it, so each one
opens the same single sutta in the app that it shows here.

Grouped pages are exactly the files containing `class="chapter"`; anchor ids are
always `<pageKey>-<n>`, `n` from 1:

```sh
cd static_site_generator/build/tipitaka
grep -rl 'class="chapter"' .                        # the 146
grep -o 'class="sutta" id="[^"]*"' sn-1-1-7.html    # anchors on one page
```

## D — app-side tests (flutter_test) — DONE

`test/presentation/providers/deep_link_provider_test.dart` covers
`openTipitakaLinkProvider`: `entryStart` derivation (page **with** entry → that
entry; page **without** entry → `0`, the start of the page and never the node's
own entry; **no** page → `null`, the node's own coordinates), a tree that will
not load opening nothing, an unknown nodeKey opening nothing, a successful open
switching `selectedAppSectionProvider` to `AppSection.reader` and syncing the
navigator from any section, and `tipitakaLinkUrlBuilderProvider` honouring
`LINK_BASE_URL`.

**`DeepLinkListener` itself is deliberately untested** unless something breaks:
mocking the
`app_links` stream and `Uri.base` is heavy, and its logic is three lines
(parse → mounted check → fire-and-forget) already covered either side.

## One command runs the package tests — shipped 2026-08-06

Root `flutter test` still does not recurse into `packages/`, and
there is no `.github/workflows/`, so this was once "only if someone types
`dart test` inside the package". It is now `tools/check-dart-packages.sh`:
`dart analyze` + `dart test` in `packages/wisdom_shared`,
`static_site_generator` and `server`, ~35s for all three. Three callers run it —
`tools/validate-release.sh` (Step 6), `scripts/web/deploy.sh` (Phase 2) and
`scripts/bjt-sync-regen/sync-regen.sh` (Step 5, straight after a corpus
re-sync).

It covers the three Dart packages only. Root `flutter test` was left out on
purpose: different runner, 45 files, and the integration half needs a device —
folding it in produces a command nobody runs.
