# Jaspr Web Client Migration — Plan

> Status: **Proposal / Decision record** — not yet started.
> Captured: 2026-06-06.
> Owner: TBD.
> Related: [`web-deep-linking-seo-and-shareable-urls.md`](./web-deep-linking-seo-and-shareable-urls.md)
> (SEO/SSR — see its "Architectural alternatives" section, this is Option B),
> [`both_mode_lazy_builder.md`](./both_mode_lazy_builder.md) and
> [`top10-perf-and-bonus.txt`](./top10-perf-and-bonus.txt) (Flutter-web perf —
> several items become moot on a Jaspr web surface).

---

## TL;DR

Replace the **web** surface (currently Flutter CanvasKit) with a
[**Jaspr**](https://jaspr.site) app that renders real HTML with true SSR +
hydration. Keep **Flutter for the 5 native apps** (iOS, Android, macOS,
Windows, Linux). The web client reuses ~90–100% of the non-UI Dart (models,
shared logic, text formatters, search/dictionary logic, the shelf API) and
rebuilds only the **presentation layer** as Jaspr components + CSS.

This is driven by two goals Flutter web structurally can't serve:

1. **SEO / discoverability** — be the default Google- and LLM-indexed home
   for Tipitaka. CanvasKit paints to `<canvas>`; crawlers see nothing.
2. **Low-/mid-end device performance** — the heavy WASM cold-start and the
   widget-tree relayout jank (font size, divider drag) largely vanish in
   HTML/CSS.

---

## The decision

| Surface | Framework | Why |
|---|---|---|
| iOS / Android / macOS / Windows / Linux | **Flutter** (unchanged) | Local DB, no SEO concern, one codebase for 5 stores. Flutter's sweet spot. |
| Public web | **Jaspr** (new) | Real HTML = SEO + fast on weak devices. A reading site is HTML/CSS's home turf. |

### What this kills: the two-renderer hack

The shelf-SSR plan in the SEO doc is a *workaround* because **Flutter
CanvasKit cannot hydrate server HTML** — it boots, discards the server DOM,
and paints a canvas on top. That means two renderers of the same content kept
in sync forever (drift = cloaking risk) plus a content flash.

Jaspr renders **one** component tree → HTML on the server, then **hydrates the
same DOM** on the client. No canvas, no "Flutter takes over," no dual
renderer, no flash. This *is* the proper architecture.

> Terminology, so it doesn't confuse later: we still have **two UI
> *codebases*** (Flutter native + Jaspr web). What disappears is **two
> *renderers of the same web page***. Different thing.

---

## What's reused vs rebuilt (measured 2026-06-06)

| Layer | Reuse | Evidence |
|---|---|---|
| `packages/wisdom_shared/` (FTS query builder, scope SQL, dictionary helpers) | ✅ **100%** | **0** Flutter imports — already shared with the no-Flutter server |
| `domain/` (entities, models, `Entry` text-marker logic) | ✅ **~94%** | 47 files, only **3** import Flutter (trivially: `IconData`/`Color`) |
| `core/utils/` text logic (`pali_conjunct_transformer`, `search_match_finder`, `singlish_transliterator`, `text_utils`, `string_extensions`, `search_query_utils`) | ✅ **~80%** | 11 files, only **2** Flutter-coupled (`responsive_utils`, `platform_utils` — UI-platform concerns) |
| Remote (HTTP) data path | ✅ mostly | **3** remote datasources already hit the shelf API — the same path Flutter web uses today |
| Dart **shelf server** + API (`server/`) | ✅ **100%** | Jaspr calls it unchanged (or absorbs it later) |
| `presentation/` widgets, screens, `ThemeData` | ❌ **rebuilt** | Flutter-coupled UI — must be HTML/CSS on web regardless |

**Headline:** the entire "below the glass" stack is reused. Only the
SEO-invisible, Flutter-only presentation layer is rebuilt — and that layer has
to be HTML/CSS on web anyway.

### Why you cannot reuse the widgets

Jaspr is **not** Flutter. It has its own `Component` model that renders to real
HTML elements (`div`, `span`, `p`) + CSS — not Flutter `Widget`s /
`RenderObject`s. So `MultiPaneReaderWidget`, `TreeNodeWidget`, the search panel,
etc. are **re-authored** as Jaspr components. The mental model is Flutter-shaped
(build methods, composition, props), so it's familiar, not alien. No automated
Widget→Component converter exists; it's manual re-authoring — but in the same
language, sharing the same models.

---

## Theming → CSS (and the jank disappears)

`ThemeData` does not carry over, but the **design** does:

- The 3 themes (light / dark / warm) → **CSS custom properties** (a palette of
  CSS variables) toggled by a class/attribute on `<html>`.
- Font scale → a CSS variable / root `font-size`.
- Fonts (Noto Sans/Serif Sinhala) → `@font-face` (the values/files carry over;
  only the loading mechanism changes from `pubspec` to CSS).

You copy the actual color/spacing/font **values**; only the **mechanism**
changes.

> **Payoff that addresses the real pain:** the font-size jank diagnosed in the
> perf addendum (whole-app `ThemeData` swap → full widget-tree relayout)
> **cannot happen in CSS** — changing a CSS variable reflows through the
> browser's native layout engine; there is no widget tree to rebuild. Same for
> the divider drag: the dual-column reader becomes a CSS grid with a native
> `resize` handle — simpler code *and* jank-free. The perf fixes in
> `both_mode_lazy_builder.md` and the font-scale addendum still matter for
> **native**, but on **web** they're moot once it's HTML/CSS.

---

## Backbone task: extract the reusable Dart into shared packages

Today `domain/` and `core/utils/` live **inside the Flutter app's `lib/`**, so
Jaspr can't import them. The foundational task is to move the reusable,
Flutter-free Dart into shared package(s) that **both** the Flutter app and the
Jaspr web app depend on.

```
packages/
  wisdom_shared/      # exists — FTS/scope/dictionary SQL, parsers (0 Flutter)
  wisdom_domain/      # NEW — entities/models, Entry text-marker logic,
                      #       failures, repository interfaces (Flutter-free)
  wisdom_text/        # NEW (or fold into shared) — pali_conjunct_transformer,
                      #       search_match_finder, singlish_transliterator,
                      #       text_utils, string_extensions, search_query_utils
```

- Move the **3 domain files** and **2 util files** that import Flutter out of
  the shared boundary (or decouple them — most use Flutter only for `Color` /
  `IconData`, which become CSS/enum on web).
- The Flutter app then depends on these packages instead of its own `lib/`
  copies. **This cleans up the Flutter app too** (clearer layering), so it's
  not throwaway work.
- This is the highest-leverage early task — everything else builds on it.

---

## Phased task plan

Each phase is independently shippable. Phases 0–3 deliver the SEO goal; 4–5 are
parity/ops.

### Phase 0 — Foundation & spike (de-risk first)
- [ ] Add a `web_client/` Jaspr package to the monorepo (beside `server/`).
- [ ] Extract reusable Dart into shared packages (see backbone task above).
- [ ] **Spike: one sutta page.** Fetch from the existing shelf API → render
      Pali/Sinhala as real HTML with SSR → confirm: view-source shows the text
      (crawlable), it hydrates, Sinhala renders via `@font-face`. This proves
      the thesis cheaply and surfaces any hidden Flutter coupling.

### Phase 1 — Core reading experience
- [ ] Routing: `/sutta/<id>` (the SEO doc's URL scheme — in Jaspr these are
      just real URLs; no `go_router` indirection).
- [ ] Reader layouts (single / side-by-side / stacked) as components + CSS
      grid/flex; resizable divider via native CSS `resize`.
- [ ] Text-marker rendering (`**bold**`, `__underline__`, `{footnote}`) → HTML
      spans, reusing the `Entry` logic.
- [ ] Theme system → CSS variables; fonts → `@font-face`.

### Phase 2 — Navigation & search
- [ ] Tree navigator as nested HTML lists (lighter than the Flutter version),
      reusing `tree.json` + tree-building logic.
- [ ] Search → call existing FTS API; reuse `wisdom_shared` query/scope logic;
      render results as HTML.
- [ ] Dictionary lookup (click word → popup), reusing dictionary API + helpers.

### Phase 3 — SEO (the actual goal)
- [ ] Per-sutta `<title>` / meta description / Open Graph / Twitter Card.
- [ ] JSON-LD structured data (`CreativeWork` / `Book`).
- [ ] `sitemap.xml` (all ~10k suttas) + `robots.txt`.
- [ ] **SSG**: pre-render all suttas to static HTML at build → perfect
      indexability, instant load, cheap hosting. This is what makes us "the
      default Tipitaka web."

### Phase 4 — State, settings, polish
- [ ] Reading prefs / layout state (Jaspr state or `jaspr_riverpod`).
- [ ] Persistence via `localStorage` (replaces `shared_preferences` on web).
- [ ] Settings, font slider (now jank-free), language/script toggles.
- [ ] Responsive / mobile web layout.

### Phase 5 — Cutover
- [ ] Drop `flutter build web` and the `run_mac.sh` strip-the-DBs pipeline.
- [ ] Web = Jaspr; native = Flutter. Update deploy scripts.

---

## Costs & risks (go in clear-eyed)

- **Two UI codebases forever.** Flutter native + Jaspr web can drift; every web
  feature is built twice. This is the real ongoing tax. Mitigation: keep web
  scope focused on the high-value reading/search/dictionary core, not blanket
  parity.
- **Presentation layer is the bulk of the ~30k LOC** — but the web **MVP**
  needs read / navigate / search / dictionary (the SEO-valuable core), not full
  app parity. MVP scope < whole app.
- **HTML/CSS learning curve.** New territory if still learning Flutter.
  Encouraging: a reading site's CSS is far simpler than app CSS, and Jaspr's
  component model is Flutter-shaped.
- **Jaspr is pre-1.0** (`0.23.x` as of 2026-06), single-maintainer OSS that
  Google *uses but does not own*. Mitigations: it's open source + pure Dart
  (forkable/patchable); **keep Jaspr at the replaceable view layer** — all
  data/search/content logic stays in `wisdom_shared` + the shelf server, which
  we own outright. Pin the version; budget for occasional migrations pre-1.0.

---

## Open questions to lock before Phase 1

1. **Package split** — one `wisdom_domain` package, or fold everything into
   `wisdom_shared`? (Recommend a thin split so UI-platform code never leaks in.)
2. **Data source** — Jaspr server calls the existing shelf API (simplest), or
   eventually absorb the API into Jaspr's backend? (Recommend: call existing
   shelf first; revisit later.)
3. **SSG vs SSR vs hybrid** — pre-render all 10k suttas (SSG) for the canonical
   content, SSR/CSR for interactive search/dictionary? (Recommend: SSG for
   suttas — best SEO + cheapest; dynamic for search.)
4. **State management** — `jaspr_riverpod` (familiar) vs Jaspr's built-in state?
5. **Staging** — ship the SEO doc's shelf-SSR (Option A) first as a fast
   stopgap, *or* go straight to Jaspr? (The two aren't exclusive: Option A gets
   us indexed risk-free while Jaspr is built/evaluated.)
6. **Production host** — confirm `thewisdomproject.app` (also blocks the SEO
   doc's canonical URLs).

---

## References

- [Jaspr — official site](https://jaspr.site)
- [Jaspr — Google Open Source Blog (why Google rebuilt dart.dev/flutter.dev on it)](https://opensource.googleblog.com/2026/04/jaspr-why-web-development-in-dart-might-just-be-a-good-idea.html)
- [jaspr on pub.dev (v0.23.1, publisher schultek.dev)](https://pub.dev/packages/jaspr)
- [HTML-in-Canvas at Google I/O 2026 — the in-Flutter alternative (origin trial; watch, don't bank)](https://verygood.ventures/blog/google-io-2026/)
