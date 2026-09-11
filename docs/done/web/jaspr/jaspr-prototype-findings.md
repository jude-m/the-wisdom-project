# Jaspr Prototype — Findings

> Status: **Prototype built & verified** (2026-06-10).
> Companion to: [`jaspr-web-client-migration.md`](./jaspr-web-client-migration.md) (the build spec),
> [`web-rewrite-clean-architecture-audit.md`](./web-rewrite-clean-architecture-audit.md).
> Code: `web_client_prototype/` (branch `feature/jaspr-web-prototype`).

## Verdict up front

**Every question the prototype existed to answer came back positive.** SSR +
hydration works without a flash, multi-tab with scroll preservation works, the
`tab_provider` model ported essentially 1:1 to `jaspr_riverpod`, in-process
reuse of the pure-Dart logic (transliterator, query pipeline, marker parsing,
document parser) worked exactly as the audit predicted, and the release client
bundle is **~120 KB gzipped** (vs multi-MB CanvasKit). The one real cost
surfaced twice in one day: **pre-1.0 ecosystem version friction** (details
below). Nothing surfaced that argues against Jaspr; the framework call can now
be made on strategy (one language + small bundle vs ecosystem maturity), not on
technical risk.

## What was verified (automated, 14/14 checks)

A puppeteer harness drove the real app in headless Chrome
(SSR server + local shelf API both running):

| Spec question | Result |
|---|---|
| `/sutta/dn-1` server-renders the text (view-source shows Sinhala, `**bold**` → `<strong>`, entry classes, side-by-side grid) | ✅ curl-verified, 30 entries in initial HTML |
| Hydration without flash | ✅ island's first client render reproduces SSR exactly (see *Hydration contract* below); no console errors |
| Multi-tab: open from nav / search, switch, close | ✅ 7 tabs exercised |
| Per-tab scroll preserved across switches | ✅ scrollTop restored exactly (1500 → 1500) |
| `tab_provider` model on `jaspr_riverpod` | ✅ ported ~1:1 (Notifier API instead of StateNotifier) |
| Keep-alive policy | ✅ MRU cap of 3: with 7 tabs open, exactly 3 tab hosts mounted in DOM |
| Tab ↔ URL | ✅ address bar follows active tab via `replaceState`; deep link seeds the workspace |
| Search → open in tab | ✅ Singlish `bhagavaa` → භගවා **in-process** (the Jaspr reuse payoff), FTS via API, result opens at the matched page and auto-scrolls to the entry anchor |

Screenshots: side-by-side reader, multi-tab workspace with search results,
Pali-only layout (taken 2026-06-10; re-run `/tmp/wisdom_e2e/shot.js`).

## The two research questions

### 1. Keep-alive
Implemented: **active tab + 2 most-recent stay mounted** (hidden via
`display:none`), older tabs are unmounted and rebuilt from state on
re-activation.

- `display:none` drops the browser's native scroll position — irrelevant,
  because scroll is restored from the registry on every activation anyway
  (so the *same* code path serves hidden-and-remounted tabs).
- Tab switch latency was imperceptible in testing, including re-mounting an
  unmounted tab (~1MB JSON parse + render of a 2-page window).
- **Open**: the "memory feel at 8–10 tabs on a 6× throttled device" judgement
  is inherently manual — run the *Try it* steps below with DevTools CPU
  throttling. The cap is one constant (`keepAliveTabCount` in
  `web_client_prototype/lib/src/state/providers.dart`).

### 2. Tab ↔ URL
Implemented: **address bar reflects the active tab** (`history.replaceState`
on switch/open/close; deep link seeds the first tab).

- Feels right, and `replaceState` means tab switching does **not** grow
  back-button history.
- Consequence to be aware of: Back returns to the previous *page load*
  (e.g. the home page), not the previously active tab. That matched my
  expectation of a workspace app, but the alternative (workspace URL + tabs
  as pure client state) remains easy to switch to later — it's one helper
  (`replaceUrl` in `dom_utils.dart`).

## Findings worth carrying into the real build

1. **The hydration contract is: island params must fully determine the first
   render.** The island receives only primitives (fileId, page window JSON
   string, counts); providers are seeded from them via `ProviderScope`
   overrides, so server and client first-render identically — no flash. The
   full ~1MB document is fetched *after* hydration and only ever extends the
   DOM. The embedded 2-page window costs ~13 KB of HTML.
2. **Don't make scroll offset reactive state on the web.** The Flutter app
   keeps `scrollOffset` in tab state; in Jaspr that would re-render the text
   DOM on every scroll tick. The prototype uses a non-reactive
   `ScrollRegistry` (snapshot continuously, read only on activation). This is
   the one place the `tab_provider` port deviated — by design, not necessity.
3. **The pure-Dart reuse thesis holds.** `singlish_transliterator`,
   `search_query_utils`, `text_utils`, `Entry.markedRanges`, and
   `BJTDocumentParser` were copied in unchanged (Freezed swapped for plain
   classes) and ran identically on the SSR server and in the browser. The
   real build should extract them into the shared package (Phase 2) instead
   of copying.
4. **CSS really does erase whole problem classes.** Side-by-side is one
   `grid-template-columns` rule (no `_PairHeightSync`), tab overflow is
   `overflow-x: auto`, font scale is a CSS variable. The layout-switch jank
   the audit worried about cannot occur.
5. **Bundle / startup**: release client JS is **~454 KB raw / ~120 KB
   gzipped** (dart2js, split into main + island part loaded on demand), plus
   the page itself is usable *before* JS arrives (SSR). The compiled server
   binary (`jaspr build` → `build/jaspr/app`, ~8 MB) serves the same SSR.

## The cost side: pre-1.0 friction, observed twice in one session

- **jaspr_cli 0.23.x requires Dart ≥ 3.11**; Flutter's bundled SDK was 3.10.4
  at build time. Worked around with a standalone Dart SDK, then **resolved
  properly the same day by upgrading Flutter to 3.44.1 (Dart 3.12.1)** —
  one toolchain again, `flutter analyze` clean after the upgrade. (The
  standalone SDK at `~/development/dart-standalone/` is now unnecessary and
  can be deleted.)
- **riverpod 3.3.2 (released the day of this build) broke jaspr_riverpod
  0.4.5** (internal `Vsync` type change) → pinned `riverpod: 3.2.1`.
- Both fit the audit's mitigation ("pin the version, budget migrations"), but
  they're a preview of the maintenance texture of this path.

All jaspr packages are pinned exactly in `web_client_prototype/pubspec.yaml`
(jaspr 0.23.1, jaspr_riverpod 0.4.5, jaspr_router 0.8.2, riverpod 3.2.1).

## Out of scope (deliberately untouched)

Dictionary, tree navigator, word-tap lookup, in-page find, selection menu,
themes/font-scale UI, tab persistence (`localStorage`), per-route titles/meta
(SEO work), production hosting. The spec's *Deferred* section stands.

## Try it

```bash
# 1. content API (terminal 1)
cd server && dart run bin/server.dart            # :8080

# 2. web client (terminal 2) — Flutter ≥3.44 bundles Dart ≥3.12, no extra SDK needed
cd web_client_prototype && jaspr serve -p 8081

# open http://localhost:8081/sutta/dn-1  (view-source → the text is there)
# throttled-feel test: DevTools → Performance → CPU 6× slowdown, open 8-10 tabs
```

Automated check harness (needs both servers up):
`cd /tmp/wisdom_e2e && node test.js`.
