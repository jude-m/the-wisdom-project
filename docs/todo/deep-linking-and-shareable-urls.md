# Deep Linking & Shareable Sutta URLs

> Status: **ACTIVE PLAN — decisions locked 2026-07-06** (was Proposal since
> 2026-05-13). Split out of the former `web-deep-linking-seo-and-shareable-urls.md`
> on 2026-06-11; the SEO / static HTML half lives in
> [`../web-strategy/web-rewrite-strategy.md`](../web-strategy/web-rewrite-strategy.md)
> and [`../web-strategy/static-html-prototype-plan.md`](../web-strategy/static-html-prototype-plan.md).
> First consumer: **AI research citations** (tap a cited source → open in reader) —
> see [`ai-qa-and-suttacentral-reference-resolver-plan.md`](./ai-qa-and-suttacentral-reference-resolver-plan.md) Part D.

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

## Decisions (locked 2026-07-06)

| Decision | Choice | Why |
|---|---|---|
| **URL identity** | **`/tipitaka/<nodeKey>`** (BJT tree node key, e.g. `sn-2-3-1-3`) | Matches the static-site plan's committed URLs; covers **all** content (commentary `atta-*`, treatises, Vinaya); maps 1:1 to `openTabFromNodeKeyProvider`. ~~`/sutta/<textId>`~~ **superseded**: `ReaderTab.textId` is declared but never populated anywhere — it was never the app's real navigation identity. |
| **Path segment** | **`/tipitaka/`** (class `TipitakaLink`) — renamed from `/sutta/` same day | `/sutta/atta-…` (commentary) was self-contradictory inside one URL. "tipitaka" follows the content-noun pattern of scripture-reference sites (Wikipedia `/wiki/`, Bible.com `/bible/`, Access to Insight literally `/tipitaka/`), names the subject for humans + a small SEO keyword plus. Used in the **umbrella sense** (as tipitaka.lk uses it): aṭṭhakathā is strictly outside the Tipiṭaka — accepted, precedent covers it. |
| **Entry-level target** | Query param **`?e=<pageIndex>.<entryIndexInPage>`** | Path = identity, query = view state. Same coordinates `ReaderTab`/search results already use. Optional; absent → sutta start. |
| **Edition flexibility** | Not encoded in the URL | The nodeKey is a *tree address*, not "render BJT": when more editions exist (SuttaCentral, A.P. de Zoysa), the app opens the address in the user's main edition. Forcing one later = optional `?edition=` param; an SC-uid alias (`/s/sn15.3` → redirect) = data + one parse rule. Additive either way. |
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
  the `/app/` base-href form, and `sammaditthi://`.
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
| `layout` | ❌ v1 | User preference wins; add `?layout=` later if wanted |
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
   `openTabFromNodeKeyProvider` gains optional explicit `pageIndex`/`entryStart`,
   `app_links` + `Uri.base` listeners, platform config (`sammaditthi://` on
   iOS/macOS/Android; disable Flutter's built-in deeplink handler).
3. **Research citations** — citation tap → bottom sheet (cited source: ref +
   title + snippet) → **Open in reader** when `uid` resolves via the shared
   resolver; graceful "not linked yet" otherwise; **Copy link** action builds
   the canonical URL.
4. **Concordance pilot coverage** — grow `sc-to-bjt.json` seed to all of SN 15
   (title-confirmed), matching the ingested pilot corpus. Full build tool stays
   a separate task (see the resolver plan §B.4 / findings doc).
5. **Later**: share/copy-link on reader tabs, `/.well-known` files + entitlements
   when the domain is live, SC-uid alias URLs, `?edition=` param, go_router if
   Flutter-web address-bar UX ever matters, segment-level anchors (v2).

## Notes

- Keep parsing **lenient** — unknown/malformed parts → defaults, never throw.
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
