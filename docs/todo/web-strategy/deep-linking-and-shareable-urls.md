# Deep Linking & Shareable Sutta URLs

> Status: **ACTIVE PLAN — decisions locked 2026-07-06; reading-layout-in-URL added 2026-07-20** (was Proposal since
> 2026-05-13). Split out of the former `web-deep-linking-seo-and-shareable-urls.md`
> on 2026-06-11; the SEO / static HTML half lives in
> [`../web-strategy/static-web-hosting.md`](../web-strategy/static-web-hosting.md)
> and [`../web-strategy/static-html-site-plan.md`](../web-strategy/static-html-site-plan.md).
> First consumer: **AI research citations** (tap a cited source → open in reader) —
> see [`ai-qa-and-suttacentral-reference-resolver-plan.md`](../research/ai-qa-and-suttacentral-reference-resolver-plan.md) Part D.
> Test coverage for all four layers of this path is the last section of this
> doc — **merged in 2026-08-15** from `deep-link-test-coverage-plan.md`, which
> was a test plan for this document and had no reason to be a separate file.
>
> **2026-07-23 — app surface moved to a subdomain.** Flutter web is no longer
> path-split at `/app/*`; it is its own Pages project on **`app.<domain>`**
> (see `static-web-hosting.md` → "Project topology"). Net effect on URLs: the
> app form is now the **identical path grammar on a different host** — no
> prefix at all. The codec was already host-agnostic, so it needs no change;
> the legacy `/app/` prefix stays *tolerated* on parse for old dev links.

---

## The four scenarios one URL must serve

One universal HTTPS link, e.g. `https://sammaditthi.app/tipitaka/sn-2-3-1-3?e=12.4`:

1. **Inside the app** (research citation, future in-app cross-refs): no OS
   involved — parse the link, open a reader tab at that node/entry.
2. **Browser on a machine without the app**: the URL serves the web page —
   the **static HTML site** owns `/tipitaka/*` on the apex (SEO/LLM surface); the
   Flutter web app lives on **`app.<domain>`** (own Pages project, 2026-07-23).
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
| **Edition flexibility** | Not in the *path*; optional `?edition=` query, **app surfaces only** *(scope locked 2026-07-21)* | The nodeKey is a *tree address*, not "render BJT". Multi-edition (SuttaCentral, A.P. de Zoysa) is scoped to the **app** (Flutter web on `app.<domain>` + native); the static site is **BJT-only**. So `?edition=` is a query modifier meaningful only on the app surfaces — the static `/tipitaka/*` pages never emit or read it. Full model in **Editions & the two web surfaces** below. |
| **Router** | **Defer go_router** | The 4 scenarios need link *receiving*, not URL-driven app state. `app_links` (mobile/desktop) + `Uri.base` (web, at startup) feed one LinkOpener that reuses `openTabFromNodeKeyProvider`. go_router's real benefit (address-bar sync in Flutter web) lands on the demoted surface — the static site owns web URLs — and can be adopted later; the codec/opener are exactly what it would call. |
| **Dev scheme** | **`sammaditthi://`** custom scheme, dev/QA only | Universal/App Links can't be verified against localhost (OS fetches `/.well-known/` over real HTTPS). The scheme tests the whole OS→app→reader pipe today, incl. macOS. **Never appears in shared links.** |
| **Link base URL** | `--dart-define=LINK_BASE_URL`, default **`http://localhost:8080`** | Same idiom as `RESEARCH_BASE_URL`. (8080 was the retired Dart content server's SPA fallback — server gone since 2026-07-16; the default is now just a harmless placeholder until the production domain exists, hosting doc open-Q #4.) Production host (`sammaditthi.app`) is config, not code. |
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
| `app.<domain>/tipitaka/<nodeKey>` | **Flutter web** (the app, own Pages project) | **multi-edition** (BJT, SC, A.P. de Zoysa…) | ❌ no (`X-Robots-Tag: noindex` on the app project — crawlable-but-noindexed, fixed 2026-07-23; see `static-web-hosting.md`) | Flutter SPA (canvas) |

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
https://app.<domain>/tipitaka/sn-2-3-1-3?e=12.4&layout=sideBySide&edition=sc
     └── app host ──┘└── shared grammar ──┘└──────── modifiers ────────┘
```

- **Landing in (built).** Flutter reads the whole URL once via `Uri.base` at
  startup → the LinkOpener opens that sutta / position / layout / edition. Clean
  `/tipitaka/…` paths need Flutter's **path-URL strategy** (else the default
  ugly `#`-hash form) **+** the app project's **SPA fallback**
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
`app.<domain>` serves the Flutter shell via its own SPA-fallback **rewrite**
(`/*  /index.html  200`) — a static `_redirects` line, **not** a Pages Function.
Nothing inspects a link to reroute it, so the two forms differ only by **host**
(apex vs `app.`); the path is identical.

**Static → app link (on every BJT page).** Each static sutta page carries an
*"Open in the app"* link to `https://app.<domain>/tipitaka/<nodeKey>` with the
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
| **non-BJT** (SC, A.P. de Zoysa) | `https://app.<domain>/tipitaka/<nodeKey>?edition=…` | Flutter web — the only surface that can render it |

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
  The app entitlement lists **both** domains (`applinks:<domain>` +
  `applinks:app.<domain>`; two Android intent-filter hosts). Every emitted form
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
  which is exactly why the 2026-07-23 `app.<domain>` move needs **no codec
  change** — plus the legacy `/app/` base-href form and `sammaditthi://`. Carries
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
  entitlement — **both domains** since 2026-07-23: `applinks:<domain>` and
  `applinks:app.<domain>` (the `app.` Pages project serves its own AASA).
- **Android**: host `/.well-known/assetlinks.json` on **both origins** +
  `autoVerify` https intent-filter for `/tipitaka/*` with **two hosts**
  (`<domain>`, `app.<domain>`).
- All four files are plain static files, each served by its own Pages project.
  The **app-side Dart code needs no change** — the OS just starts delivering
  https URIs through the same `app_links` stream the custom scheme already
  exercises (only the entitlement/intent-filter lists grow by one host).

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
   current `?layout=`), `/.well-known` files + entitlements when the domain is
   live (**both** apex and `app.` origins — see above), `?edition=` param,
   go_router if Flutter-web address-bar UX ever matters, segment-level anchors
   (v2).

## Notes

- **Short/alias URLs — PARKED 2026-07-26.** SC uids (`sn15.3`) resolve
  **in-app only** (citation → `sc-to-bjt.json` → nodeKey), never as a public URL:
  no `/s/sn15.3`, no bare `/sn15.3`, no redirect layer. The concordance is
  unaffected — it still grows to full sutta+Vinaya coverage (~4,000) for the RAG
  corpus. What changes: the P5 mechanism gate serves **one** feature (the
  grouped-leaf links), not two.
- Keep parsing **lenient** — unknown/malformed parts → defaults, never throw.
- **Grouped-sutta fragments (found 2026-07-22; fix LOCKED same day — user
  requires exact-sutta deep links even for grouped suttas):** a grouped sutta's
  canonical URL is `…/tipitaka/<vaggaKey>#<leafKey>` (static plan §6).
  `TipitakaLink.parse` currently ignores fragments → the app would open the
  *vagga*, not the sutta. **Required with static P5:** extend the codec — if the
  fragment matches the nodeKey pattern, prefer it over the path key (the opener
  can sanity-check it's a descendant). OS link delivery does preserve fragments.
  **Converse hole (also LOCKED, static plan §13.2):** the share button emits the
  **leaf** URL (`/tipitaka/an-2-64`) even for a grouped sutta — a no-app web
  recipient 404s unless something answers at the leaf URL. The requirement is
  locked; the *mechanism* (stub files vs Cloudflare Bulk Redirects) is a P5
  decision gate — see the hosting doc's "Grouped-leaf clean URLs". Together the two fixes complete the matrix: *both* URL
  forms land on the exact sutta for *both* app and no-app recipients, and the
  share button never needs to know grouping exists.
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

---

# Test coverage

> Status: **Parked 2026-07-29** on branch `feat/static-site`. Written after the
> code review of `packages/wisdom_shared/test/links/tipitaka_link_test.dart`
> (the first test the link codec ever had). Layer **A is done**; the A2 sweep
> and layers B–D are not started.
>
> Everything above owns the URL *grammar* and the decisions; this section only
> says **what proves it works**.
>
> The review's own findings (F1–F7), simplifications and the untested-edge list
> were applied directly to the test file (56 → 67 tests) and are **not**
> repeated here. Layer A below assumes them. Two findings are deferred and do
> live here: **F5** (corpus sweep, § A2 — it belongs outside `test/`) and
> **F6** (nothing runs these tests automatically, last section).

## TL;DR

Four layers carry a deep link. One has tests.

| Layer | Code | Tests today |
|---|---|---|
| **A** URL codec | `packages/wisdom_shared/lib/src/links/tipitaka_link.dart` | 68 (2026-07-29) — every shape in A covered; corpus sweep **A2 outstanding** |
| **B** Reference resolver | `packages/wisdom_shared/lib/src/refs/suttacentral_ref_resolver.dart` | **zero** |
| **C** Static-site URL emission | `static_site_generator/lib/domain/site_page.dart`, `lib/render/page_template.dart` | **zero** automated (no `test/` dir); five-URL hand-testing sheet in C2 |
| **D** App-side wiring | `lib/presentation/providers/deep_link_provider.dart`, `widgets/app/deep_link_listener.dart` | **zero** |

Recommended order: **A2 + B** (pure Dart, no new infra, sub-second) → **C** →
**D**. C catches a class of bug nothing else can; D is worth little until
Universal Links are live on a real domain.

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

## A — extend `packages/wisdom_shared/test/links/tipitaka_link_test.dart`

> **DONE 2026-07-29** (67 → 68 tests). All nine shapes below are covered; the
> table stays as the record of *why* each is pinned. **A2 is not done.**

No new files or dependencies. Each shape below was probed against the current
implementation on 2026-07-29; the stated behaviour is what it does *today*.

| Shape | Today | Why it needs pinning |
|---|---|---|
| `…/tipitaka/sn-2-3#sn-2-3-1-3` | fragment **dropped** → opens the vagga | The locked grouped-vagga form (see "Grouped-sutta fragments" above). Pin the baseline + `TODO`, so the day `parse` starts preferring a nodeKey-shaped fragment it shows as a deliberate flip, not a silent one. |
| `…?layout=stacked` | ignored, link survives | Part of the documented grammar (layout decision, 2026-07-20) but **not implemented anywhere in `lib/`**. Also test `?e=12.4&layout=stacked` for param independence. |
| `https://sammaditthi.app/tipitaka/<key>` | parses | The static-site production host. |
| `https://app.sammaditthi.app/tipitaka/<key>` | parses | The Flutter-web host — same path, no `/app/` prefix (topology decision, 2026-07-23). |
| `SAMMADITTHI://TIPITAKA/SN-2-3` | **parses** | Uppercase works on the custom scheme (`Uri` lowercases the host) but *not* on https — see F2. Whichever way that resolves, both forms need a test. |
| `sammaditthi://foo/tipitaka/<key>` | parses | Wrong custom-scheme host is tolerated as a path prefix. Intended? |
| `?e=1&e=2` | last wins → page 2 | |
| `?E=12.4` | ignored (param is case-sensitive) | |
| `…/tipitaka//sn-2-3` | parses (empty segments skipped) | |

### A2 — corpus sweep: every real nodeKey parses (review finding F5)

Not in `test/`. `_nodeKeyPattern` is the one gate every deep link passes, and
the test file only pins **3** of the 53 dotted keys — a regression test for the
bug we know about, silent about key #54 or any other shape in the tree. Sweep
every key in `assets/data/tree.json`:

```dart
for (final key in tree.keys) {
  if (TipitakaLink.tryParse('https://x/tipitaka/$key') == null) {
    failures.add(key); // this node can never be deep-linked
  }
}
```

Turns "we fixed the dots" into "**no key in the corpus is unlinkable**".

Belongs in `static_site_generator/tool/verify_corpus_invariants.dart`, not the
package: `wisdom_shared` is Flutter-free by design, can't reach `assets/`, and a
16k-node load does not belong in a sub-second suite — same split already used
for markers and tree. ~10 lines, `TipitakaLink.tryParse` only, no shim.

**Snapshot, not a guarantee.** Re-run after every `tree.json` sync from
tipitaka.lk (see the canon-sync workflow): a newly-introduced dotted or
odd-shaped key breaks links again, and only this check would notice.

## B — new `packages/wisdom_shared/test/refs/suttacentral_ref_resolver_test.dart`

`SuttaCentralRefResolver` is the other half of the citation path and has never
been tested. It feeds **two** shipped features: tappable research citations
(`citation_source_sheet.dart:99-102`) and the "type SN 15.3 → jump" search.

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

## C — new `static_site_generator/test/` — codec ⇄ generator agreement

**The gap that matters.** The generator builds the same URL grammar
independently and nothing checks the two agree.

Pointers re-located 2026-08-16 — the generator has moved since this was written,
and in one respect for the better: every href now funnels through **one** helper
rather than five hand-built strings, and that helper takes the path segment from
the codec itself.

- `lib/domain/site_page.dart:15` — `String tipitakaUrl(String nodeKey) =>
  '/${TipitakaLink.pathSegment}/$nodeKey';`, with `SitePage.url` at `:50`.
  **The segment can no longer drift** (it is `TipitakaLink`'s own constant);
  the *shape* around it is still built here and still unchecked, which is what
  the test is for.
- `lib/render/page_template.dart:68` — breadcrumb ancestors (`tree.ancestorsOf`)
- `lib/render/page_template.dart:274` — canon ↔ aṭṭhakathā twin cross-link
- `lib/render/page_template.dart:97` — child lists on container TOCs (`tocList`)
- `lib/render/page_template.dart:369` — `id="<nodeKey>"` anchors (the `:target`
  single-view targets, i.e. the `#fragment` link targets — live on the dev
  deploy, hand-testing sheet in C2)
- `lib/render/site_chrome.dart:134,174,196` — breadcrumb, up-link and TOC list
  items, all through the same helper

Once Universal Links are live, **every static-site href is also an app deep
link** — the OS intercepts the tap. A divergence means the link works in a
browser and dies in the app, which is exactly the failure users report as "the
app opened on the wrong page".

Test: emit pages from a synthetic tree (including the dotted commentary keys —
`atta-ap-dhs-2-1-1.1` and friends, 53 of them in the real tree), then assert
every emitted `href` and `id` round-trips through `TipitakaLink.parse` back to
the same nodeKey.

`test: ^1.24.0` is already a dev-dependency there; only the `test/` directory is
missing. **Timing:** `lib/domain` and `lib/render` were in flux when this was
written — the generator has since landed, so the full href sweep is now the
version to write.

### C2 — hand-testing sheet: five live fragment pages

C's `id="<nodeKey>"` anchors are no longer "future" targets — they are live and
working on the dev deploy. These five URLs are the manual check, verified
2026-08-14 against that build (14,752 pages, 146 grouped).

Origin `https://dev.sammaditthi-dev.pages.dev` — Pages project `sammaditthi-dev`,
preview branch `dev`. Production is `https://sammaditthi.pages.dev`; swap the
host and every path below still holds.

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

**This proves the browser half only.** Per the first row of A's table, the codec
still **drops** a nodeKey-shaped fragment, so the same URL that opens one sutta
in a browser opens the whole vagga in the app. These five are the fixtures to
re-run the day that flips.

Grouped pages are exactly the files containing `class="chapter"`; anchor ids are
always `<pageKey>-<n>`, `n` from 1:

```sh
cd static_site_generator/build/tipitaka
grep -rl 'class="chapter"' .                        # the 146
grep -o 'class="sutta" id="[^"]*"' sn-1-1-7.html    # anchors on one page
```

## D — new app-side tests (flutter_test)

The "out of scope" gap from the review: **nothing in `test/` or
`integration_test/` references `TipitakaLink` or the deep-link path at all.**

`test/presentation/providers/deep_link_provider_test.dart` —
`openTipitakaLinkProvider` (`deep_link_provider.dart:38-63`):

- `entryStart` derivation (`:46-47`): page **with** entry → that entry; page
  **without** entry → `0` (start of page, never the node's own entry); **no**
  page → `null` (node's own coordinates)
- tree load fails → returns `false`, opens nothing
- unknown nodeKey (`openTabFromNodeKeyProvider` → `-1`) → `false`
- success → switches `selectedAppSectionProvider` to `AppSection.reader` and
  syncs the navigator, *from any section* (Home/Research/Notes)
- `tipitakaLinkUrlBuilderProvider` uses `LINK_BASE_URL` (default
  `http://localhost:8080`)

`test/helpers/mocks.dart` and `pump_app.dart` already exist.

**Skip `DeepLinkListener` itself** unless something breaks: mocking the
`app_links` stream and `Uri.base` is heavy, and its logic is three lines
(parse → mounted check → fire-and-forget) already covered either side.

## One command runs the package tests — shipped 2026-08-06

Root `flutter test` still does not recurse into `packages/`, and
`.github/workflows/` is still empty, so this was once "only if someone types
`dart test` inside the package". It is now `tools/check-dart-packages.sh`:
`dart analyze` + `dart test` in `packages/wisdom_shared`,
`static_site_generator` and `server`, ~35s for all three. Three callers run it —
`tools/validate-release.sh` (Step 6), `scripts/web/deploy.sh` (Phase 2) and
`scripts/bjt-sync-regen/sync-regen.sh` (Step 5, straight after a corpus
re-sync).

It covers the three Dart packages only. Root `flutter test` was left out on
purpose: different runner, 45 files, and the integration half needs a device —
folding it in produces a command nobody runs.
