# Jaspr Web Client — Prototype Build Spec

> Status: **Build-ready prototype spec.** The earlier strategy/decision content
> is condensed into the *Background* section below; the body is now an
> executable spec for the multi-tab de-risking prototype.
> Captured: 2026-06-06 · Updated: 2026-06-09 · Owner: TBD.
> Related: [`web-deep-linking-seo-and-shareable-urls.md`](./web-deep-linking-seo-and-shareable-urls.md)
> (SEO/SSR), [`both_mode_lazy_builder.md`](./both_mode_lazy_builder.md),
> [`top10-perf-and-bonus.txt`](./top10-perf-and-bonus.txt) (Flutter-web perf —
> several items become moot on a Jaspr web surface).

---

## Background & decisions (abstract)

Replace the **web** surface (currently Flutter CanvasKit) with a
[**Jaspr**](https://jaspr.site) app that renders real HTML with SSR + hydration.
Keep **Flutter for the 5 native apps** (iOS, Android, macOS, Windows, Linux).
Two goals Flutter web structurally can't serve drive this:

1. **SEO / discoverability** — CanvasKit paints to `<canvas>`; crawlers see
   nothing. Jaspr emits real HTML → be the default Google-/LLM-indexed Tipitaka.
2. **Low-/mid-end performance** — WASM cold-start + widget-tree relayout jank
   (font-size, divider drag) largely vanish in HTML/CSS.

Jaspr renders **one** component tree → HTML on the server, then **hydrates the
same DOM** on the client (no canvas, no dual renderer, no flash). We still keep
**two UI codebases** (Flutter native + Jaspr web) — what disappears is two
*renderers of the same page*.

**What's reused vs rebuilt** (measured 2026-06-06; the whole "below the glass"
stack is reused, only the Flutter-only presentation layer is rebuilt):

| Layer | Reuse |
|---|---|
| `packages/wisdom_shared/` (FTS/scope/dictionary SQL, parsers) | ✅ **100%** — 0 Flutter imports |
| `domain/` (entities, `Entry` text-marker logic) | ✅ **~94%** — 3 trivial Flutter leaks (see Phase 1 cleanup doc) |
| `core/utils/` text logic (conjuncts, transliteration, match-finding) | ✅ **~80%** |
| Remote (HTTP) data path + Dart **shelf server** (`server/`) | ✅ **100%** — Jaspr calls it unchanged |
| `presentation/` widgets, `ThemeData` | ❌ **rebuilt** as Jaspr components + CSS |

**Above-the-glass difficulty map** (the `integration_test/` files are the flow
checklist):
- *Easier in Jaspr* — layout switch (CSS grid, kills `_PairHeightSync`), nav
  (links), divider/tab-scroll (native CSS), theme + font-scale (CSS vars, jank
  gone), filter chips, **PTS multi-section** (CSS grid columns).
- *Challenging but doable* — word-tap dictionary lookup (`<span>` per word or
  `caretPositionFromPoint`), custom selection menu (`selectionchange` + popup),
  in-page highlight (CSS Custom Highlight API), **multi-tab** (see below).
- *No hard blockers* — everything is re-authored (effort, not a gap); no canvas
  needed; `jaspr_flutter_embed` is the escape hatch; only real caveat is
  Jaspr pre-1.0.

**Roadmap features** (why this view layer is the right bet): audio = native
`<audio>` (easier than Flutter); bookmarks = `localStorage`/server CRUD; notes =
browser `Range` anchoring (medium); **shared prefs already abstracted** behind
`KeyValueStore` → add a `LocalStorageKeyValueStore`, zero call-site changes;
more editions/PTS = CSS grid + the data side is ready.

**Theming → CSS** — the 3 themes become CSS custom properties toggled on
`<html>`; font scale = a root CSS variable; Noto Sinhala fonts = `@font-face`.
Copy the *values*, change the *mechanism*. The font-size relayout jank **cannot
happen** in CSS.

**Why multi-tab is the crux** — tab state is *already data* (`tab_provider.dart`
holds list/active-index/per-tab layout; scroll offset is already snapshotted),
so the logic ports to `jaspr_riverpod` ~1:1. The genuinely new work is: (1) no
free offscreen keep-alive — choose keep-mounted (memory) vs unmount+restore;
(2) DOM-bound state (FTS highlight `Range`s) must be rebuilt on remount;
(3) the tab↔URL relationship. This is exactly why we prototype it first.

**Backbone (for the real build, not the prototype):** extract the reusable Dart
(`domain/`, `core/utils/`) into shared packages so both Flutter and Jaspr depend
on them — and finish the [Phase 1 domain-Flutter-free cleanup](./web-rewrite-phase1-domain-flutter-free.md).
The prototype can skip this by pointing at `lib/` directly or copying the few
files it needs.

---

## Locked decisions for this prototype

| # | Decision | Choice |
|---|---|---|
| 1 | **Data source** | Run the existing Dart **shelf server locally**; prototype fetches the real API. |
| 2 | **URL / id scheme** | **`/sutta/<fileId>`** (raw fileId, e.g. `dn-1`) — matches the API directly; pretty slugs later. |
| 3 | **Rendering mode** | **SSR page + hydrated client island** — proves the SEO/hydration thesis *and* multi-tab together. |
| 4 | **Open research questions** (keep-alive, tab↔URL) | Agent **implements one primary approach + reports findings** (true prototype). |

---

## Prototype build spec

### Goal — what it must prove
The prototype exists to **de-risk multi-tab + SSR/hydration before committing
months to the rewrite.** It is throwaway-or-grow. It must answer:

- Does a server-rendered `/sutta/<fileId>` page **hydrate into the interactive
  reader with no flash**, and does view-source show the Sinhala text?
- Can a hydrated Jaspr SPA **hold several suttas open as tabs**, switch between
  them, and **preserve each tab's scroll position**?
- Does **`jaspr_riverpod` carry the `tab_provider` model** the way
  `flutter_riverpod` does today?
- **Keep-alive:** which policy is acceptable on a weak device, and at what tab
  count?
- **Tab ↔ URL:** opening `/sutta/<fileId>` directly gives one crawlable page
  *and* seeds the tab workspace.
- Does it **feel faster** than Flutter web on a throttled device?

### Stack & scaffold
- New Jaspr package `web_client_prototype/` in the monorepo (beside `server/`). Do **not**
  touch the Flutter app or extract shared packages yet — for the prototype,
  import the handful of needed Dart files from `lib/` directly or copy them.
- Deps: `jaspr`, `jaspr_riverpod`, `jaspr_router`; dev: `jaspr_builder`,
  `build_runner`. **Pin** the latest `0.23.x` (verify on pub.dev — pre-1.0).
- Jaspr mode: **server** (SSR). The reader + tab shell are a **`@client`
  island** that hydrates; the sutta text is server-rendered into the initial
  HTML so it's crawlable.

### Data layer — run the shelf server locally
The API already exists and has CORS enabled, so the Jaspr dev server (different
port) can call it.

```bash
# from repo root
cd server
dart pub get
dart run bin/server.dart            # listens on :8080, assets default ../assets
# (ensure ../assets has text/*.json and the FTS/dict .db files — the app already ships these)
```

**API contract** (base `http://localhost:8080`):

| Need | Endpoint | Notes |
|---|---|---|
| Sutta text | `GET /api/text/<fileId>` | Returns raw BJT JSON for `assets/text/<fileId>.json` (fileId e.g. `dn-1`, `mn-1`). Parse with `BJTDocumentParser.parseDocument(fileId, json)` → `BJTDocument`. |
| FTS / title search | `GET /api/fts/search` (+ `/count`, `/suggestions`) | Exact query params + result shape: copy from `lib/data/datasources/fts_remote_datasource.dart` (the canonical client). |
| Dictionary (deferred) | `GET /api/dict/lookup` (+ `/search`, `/count`) | Not in prototype scope; listed for completeness. |

### What to build (and what to reuse)
1. **Routing** — `/sutta/<fileId>` (jaspr_router). The same route both
   server-renders the doc and seeds the client tab shell.
2. **Reader component** — render `Entry` text markers (`**bold**`,
   `__underline__`, `{footnote}`) as HTML spans. **Port the marker-parsing logic
   from `lib/domain/entities/content/entry.dart`** (it's Flutter-free data).
   Single + side-by-side layout via CSS grid. Build it to **render the active
   document from state**, not a hardcoded doc — that's what keeps multi-tab
   additive.
3. **Tab shell** (`@client`, `jaspr_riverpod`) — open N docs, switch tabs.
   **Port the state model from `lib/presentation/providers/tab_provider.dart` +
   `lib/presentation/models/reader_tab.dart`.** Snapshot/restore scroll offset
   per tab (the model already does this).
4. **Navigator + search** — a minimal nav list + a title/FTS search box that
   calls `/api/fts/search` and **opens results into tabs** (exercise the real
   "find → open in tab" flow). Reuse `wisdom_shared` query/scope logic +
   `singlish_transliterator` / `search_query_utils` in-process (the Jaspr win).
5. ~5 real suttas is enough content.

### The two research questions — as instructions
- **Keep-alive:** implement **keep ~2–3 most-recent tabs mounted, snapshot +
  unmount the rest**; on re-activation restore from state. Run with **Chrome
  DevTools CPU throttling (6×) / a low-end profile**, push to ~8–10 open tabs,
  and **report**: memory feel, switch latency, any scroll/jank issues, and
  whether a different cap behaves better.
- **Tab ↔ URL:** implement **address bar reflects the active tab**
  (`/sutta/<fileId>` updates on tab switch via `history.replaceState`-style
  routing; deep-linking opens that sutta as the first tab). **Report** whether
  this feels right or fights the back button, and note the alternative
  (workspace URL + tabs as pure client state).

### Build order
- [ ] Scaffold `web_client_prototype/` Jaspr server-mode app; "hello sutta" SSR page.
- [ ] Wire the data layer to the local shelf API; render one real sutta
      server-side (confirm view-source shows the Sinhala text).
- [ ] Port `Entry` marker rendering → HTML spans; single + side-by-side CSS grid.
- [ ] Make it a hydrating `@client` island; confirm no flash on hydration.
- [ ] Port `tab_provider` state to `jaspr_riverpod`; tab bar + open/switch.
- [ ] Scroll snapshot/restore per tab; the keep-alive policy above.
- [ ] Minimal navigator + title/FTS search that opens into tabs.
- [ ] Throttled-device pass; write up the findings (the two questions + feel).

### Proven when
Several suttas open in tabs, switching preserves scroll, the page is
server-rendered + hydrated (view-source shows the text), search opens into tabs,
and it feels good on a throttled device — **plus a short findings note** on
keep-alive and tab↔URL. That's the green light for the full build.

---

## Costs & risks (clear-eyed)
- **Two UI codebases forever** — every web feature is built twice. Mitigation:
  keep web scope on the high-value reading/search core.
- **Presentation is the bulk of the rewrite** (~14k LOC presentation today) —
  but the prototype touches only a thin vertical slice of it.
- **HTML/CSS learning curve** — a reading site's CSS is far simpler than app CSS,
  and Jaspr's component model is Flutter-shaped.
- **Jaspr pre-1.0** (`0.23.x`, single-maintainer OSS Google uses but doesn't
  own) — it's open-source pure Dart (forkable); keep it at the replaceable view
  layer; pin the version.

---

## Deferred — the full build, after the thesis is proven
Once the prototype greenlights it, the real project (separate planning) covers:
shared-package extraction + [Phase 1 cleanup](./web-rewrite-phase1-domain-flutter-free.md);
reader parity (stacked layout, word-tap dictionary, in-page search, selection
menu); tree navigator; theming → CSS variables; **SEO** (per-sutta meta,
JSON-LD, `sitemap.xml` for all ~10k suttas, optional SSG pre-render); prefs via
`localStorage`; and cutover (drop `flutter build web`). Open items to lock then:
package split shape, SSG-vs-SSR per surface, staging (ship the SEO doc's
shelf-SSR stopgap in parallel?), and production host.

---

## References
- [Jaspr — official site](https://jaspr.site) · [Docs](https://docs.jaspr.site)
- [Jaspr — Google Open Source Blog](https://opensource.googleblog.com/2026/04/jaspr-why-web-development-in-dart-might-just-be-a-good-idea.html)
- [jaspr on pub.dev (v0.23.1, publisher schultek.dev)](https://pub.dev/packages/jaspr)
- [HTML-in-Canvas at Google I/O 2026 — the in-Flutter alternative (watch, don't bank)](https://verygood.ventures/blog/google-io-2026/)
