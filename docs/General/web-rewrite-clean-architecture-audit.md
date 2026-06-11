# Web Rewrite — Clean Architecture Audit & Effort Estimate

> Status: **Study + Plan** — analysis only, no code changed.
> Captured: 2026-06-06.
> Companion to: [`jaspr-web-client-migration.md`](./jaspr-web-client-migration.md),
> [`web-deep-linking-seo-and-shareable-urls.md`](./web-deep-linking-seo-and-shareable-urls.md).
>
> Question this answers: *"If we eventually replace the Flutter-web surface
> with a purpose-built web client, how badly is Clean Architecture broken
> today, what does cleanup cost, and how big is the rewrite?"*

---

## 0. TL;DR

1. **The architecture is in good shape.** The "below the glass" stack
   (domain + data + core + `wisdom_shared` + the shelf server) is essentially
   free of presentation coupling. The dependency rule holds where it matters.
2. **The violations are real but shallow** — **4 domain files** reach outward
   into Flutter/UI for trivial reasons (a label closure, a colour, `setEquals`).
   Fixing all of them is ~½–1 day and makes the domain layer 100% Flutter-free.
   This is worth doing **regardless** of any web decision.
3. **The framework choice changes every reuse number.** The existing
   migration doc assumes **Jaspr (Dart)**, where you reuse logic *in-process*.
   If you go **Next.js (TypeScript)** instead, in-process Dart reuse is **zero** —
   reuse happens **only through the existing HTTP API** (the Dart `shelf` server).
   That flips which cleanup work is valuable.
4. **For Next.js, the package-extraction "backbone task" in the Jaspr doc is
   wasted effort.** The right prep is the opposite: make the **server/API own
   everything the web needs**, so the TS frontend never re-implements business
   logic.
5. **The rewrite is dominated by the presentation layer** (~13.8k hand-written
   LOC, 71 files; widgets alone ~9.7k / 33 files). That gets rebuilt no matter
   which web framework you pick — it *has* to be HTML/CSS on the web.

---

## 1. The one decision that changes all the numbers

Everything below forks on a single question: **is the web client written in
Dart (Jaspr) or in TypeScript/JavaScript (Next.js)?**

| | **Jaspr (Dart)** | **Next.js (TS/JS)** |
|---|---|---|
| Reuse `domain/`, `core/utils/*`, `wisdom_shared` **in-process** | ✅ Yes — it's Dart, you `import` it | ❌ **No** — cannot import Dart at all |
| Reuse the data/search/dictionary logic | Directly, as packages | **Only via the HTTP API** (the shelf server) |
| Languages to maintain forever | 1 (Dart) | 2 (Dart native + TS web) |
| SEO / SSR / SSG | ✅ Native | ✅ Native (best-in-class) |
| Ecosystem maturity | ⚠️ pre-1.0 (`0.23.x`) | ✅ Huge, stable |

**Why this matters so much:** the Jaspr doc's headline — *"reuse ~90–100% of the
non-UI Dart"* — is only true **because Jaspr is Dart**. Swap in Next.js and that
sentence becomes false. With Next.js the only thing you reuse is the **server**,
because JSON over HTTP is the only language both sides speak.

> The good news for the Next.js path: **the server is already a complete data
> contract for the web.** The current Flutter *web* build runs entirely off
> remote HTTP datasources — see `lib/presentation/providers/platform_providers.dart`
> `getWebOverrides()`, which overrides all three datasources (FTS, dictionary,
> document) to their HTTP variants. So "Next.js talks to the existing server"
> isn't a hope; it's the architecture the web build *already* uses.

---

## 2. Architecture audit — how clean are we, really?

Measured 2026-06-06 by dependency-direction grep across `lib/`, `packages/`,
and `server/`.

### 2.1 Scorecard

| Clean-architecture rule | Verdict | Evidence |
|---|---|---|
| Widgets/screens never import the **data** layer directly | ✅ **Clean** | 0 hits in `lib/presentation/widgets` + `screens` |
| **Domain** never imports **data** or **presentation** | ✅ **Clean** | 0 hits |
| **Data** never imports **presentation** | ✅ **Clean** | 0 hits |
| **core** never imports presentation/data (depends only inward) | ✅ **Clean** | 0 hits |
| Riverpod confined to presentation | ⚠️ **Mostly** | 2 infra exceptions: `core/storage/key_value_store_provider.dart`, `core/theme/theme_notifier.dart` |
| `wisdom_shared` is Flutter-free | ✅ **Clean** | 0 Flutter imports; already shared with the server |
| **Domain** never imports **Flutter / UI** | ❌ **4 leaks** | see §2.3 |
| Presentation reaches the data layer **only through DI wiring** | ⚠️ **By design** | 6 provider files import `data/` — this is the Riverpod composition root (acceptable), see §2.4 |
| Use-case layer used consistently | ❌ **Vestigial** | only 2 of ~6 features go through use cases, see §2.5 |

### 2.2 What's reassuring

The thing you actually worried about — *"is the presentation layer nosing into
the domain / other layers?"* — is **not** happening in the dangerous direction:

- **No widget or screen** imports `lib/data/...` directly. UI talks to the
  domain (entities, repository interfaces) and to providers. That's correct.
- **The domain never reaches into data or presentation.** Dependencies point
  inward, as they should.
- **The pure algorithms are already isolated and Flutter-free**: the FTS query
  builder, scope SQL, and dictionary SQL live in `packages/wisdom_shared`
  (0 Flutter imports, already consumed by the no-Flutter server). The text
  algorithms (`singlish_transliterator`, `pali_conjunct_transformer`,
  `search_match_finder`, `text_utils`, `search_query_utils`) live in
  `core/utils/` and are pure Dart.

So the codebase is **not** a tangled ball. The seam between "view" and
"everything else" is already mostly real.

### 2.3 Violation A — domain reaches *outward* into Flutter/UI (4 files)

This is the genuine Clean-architecture break. It's the **opposite** direction
from what you feared (it's domain→UI, not presentation→domain), and every case
is shallow:

| File | What it pulls in | Why it's wrong | Fix |
|---|---|---|---|
| `lib/domain/entities/search/search_scope_chip.dart` | `flutter/widgets.dart` (`BuildContext`) + `AppLocalizations` | The entity stores a *localization label closure* and resolves it from a `BuildContext`. A label is a UI concern. | Keep only `id` + `nodeKeys` (pure data) in domain; resolve the label in a presentation helper. |
| `lib/domain/entities/search/search_result_type.dart` | `AppLocalizations` | Enum extension returns localized display strings. | Move the label mapping to presentation. |
| `lib/domain/entities/dictionary/dictionary_info.dart` | `flutter/material.dart` | The data (`id/name/abbreviation/targetLanguage`) is pure, but `getColor(dictId, ThemeData)` is a UI method living in domain. | Move `getColor` to a presentation theme helper; domain keeps the data map. |
| `lib/domain/entities/dictionary/dictionary_filter_operations.dart` | `flutter/foundation.dart` | Pure filter logic — imported Flutter **only** for `setEquals`. | Replace `setEquals` with `package:collection`'s `SetEquality` (or a 2-line helper). |

Two of these (`search_scope_chip`, `search_result_type`) also import
`core/localization/...AppLocalizations`, i.e. the innermost layer reaching out to
generated localization. Same fix: labels belong in presentation.

After this, **the domain layer is 100% Flutter-free** — which is the single most
useful precondition for *any* future where the view layer is replaced.

### 2.4 "Violation" B — providers import the data layer (this is fine)

Six providers import `lib/data/...` directly:

```
presentation/providers/search_provider.dart        → fts datasources, caching repo, ...
presentation/providers/dictionary_provider.dart    → dictionary datasource + repo
presentation/providers/document_provider.dart      → bjt document datasource + repo
presentation/providers/navigation_tree_provider.dart
presentation/providers/platform_providers.dart     → the 3 remote datasources
presentation/providers/recent ... (recent searches)
```

This looks like a layer jump, but it isn't a smell: **the providers are the
dependency-injection composition root.** Something has to construct
`Repository(DataSource(...))` and hand it to the UI; in Riverpod that's the
provider file. The *widgets* stay clean (they read providers, not datasources).

The only thing to note for the rewrite: this wiring is Flutter/Riverpod-specific,
so a new web client re-creates its own composition root. That's expected and
cheap — it's wiring, not logic.

### 2.5 Violation C — the use-case layer is vestigial

`lib/domain/usecases/` contains only two files
(`load_bjt_document_usecase.dart`, `load_navigation_tree_usecase.dart`), used by
two providers. Search, dictionary, and recent-searches **bypass** use cases and
call repositories directly. So the layer is half-present — inconsistent rather
than harmful. Either complete it (a use case per feature) or drop it and call
repositories from providers everywhere. Low priority; cosmetic for the rewrite.

### 2.6 Platform coupling (not an architecture violation, but matters for web)

The data layer imports `flutter/services.dart` in several datasources —
`rootBundle` for loading bundled JSON/SQLite assets
(`tree_local_datasource.dart`, `fts_local_datasource.dart`,
`dictionary_local_datasource.dart`, `bjt_document_local_datasource.dart`,
`text_search_repository_impl.dart`). This is correct (it's the *local* path used
by native apps); the **remote** datasources are the web path and have no such
coupling. It's a platform seam, already abstracted behind the datasource
interface — not something to "fix", just something to know.

---

## 3. What's reused vs rebuilt — by target

### 3.1 Size of the codebase (hand-written LOC, generated excluded)

| Layer | Files | LOC | Fate on web |
|---|---:|---:|---|
| `lib/presentation/` | 71 | **13,802** | **Rebuilt** (it's Flutter widgets) |
| ├ widgets | 33 | 9,671 | rebuilt as components/CSS |
| ├ providers | 26 | 3,066 | re-expressed as web state |
| ├ models | 4 | 311 | re-expressed (view-models) |
| ├ screens / utils / keyboard | 8 | 754 | rebuilt |
| `lib/core/theme/` | 6 | 1,440 | values carry → CSS variables |
| `lib/core/` (non-theme) | 25 | 2,802 | mixed (utils reusable; storage/version platform) |
| `lib/data/` | 20 | 3,032 | remote path reusable; local path = native-only |
| `lib/domain/` | 31 | 2,241 | **reusable logic** (once Flutter-free) |
| `packages/wisdom_shared/` | — | 397 | reusable (already Flutter-free) |
| `server/` | — | 1,041 | **reused as the backend** |

### 3.2 Reuse table — Jaspr

| Stack | Reuse | How |
|---|---|---|
| `wisdom_shared`, `domain/`, `core/utils/*` | ✅ ~95–100% | imported directly (Dart) |
| remote datasources + shelf server | ✅ 100% | called unchanged |
| `presentation/` widgets + `ThemeData` | ❌ rebuilt | Jaspr components + CSS |

→ **Jaspr rewrite ≈ the presentation layer only.** Logic comes along for free.

### 3.3 Reuse table — Next.js (the path you're leaning toward)

| Stack | Reuse | How |
|---|---|---|
| shelf server + JSON API | ✅ 100% | Next.js calls it over HTTP |
| `wisdom_shared`, `domain/`, `core/utils/*` | ⚠️ **only if it's behind the API** | cannot import Dart; reachable only as endpoints |
| Logic that's **client-only today** | ❌ re-port to TS *or* move server-side | see §3.4 |
| `presentation/` + theme | ❌ rebuilt | React/TSX + CSS |

→ **Next.js rewrite ≈ presentation layer + a small TS re-port of client-only
logic (or move that logic into the server).** The big data/search/dictionary
brains stay in Dart, server-side, untouched.

### 3.4 The "client-only logic gap" (the thing that bites Next.js)

Some logic the web experience needs currently runs **only in the Flutter client**
and is **not** exposed by the server. Today the Flutter web build does this work
locally before/after calling the API. A Next.js client can't — so each item
must either **move into the server** (cheap; it's already Dart) or be
**re-implemented in TypeScript**.

| Logic | Where it lives now | Server has it? | Recommendation for Next.js |
|---|---|---|---|
| Singlish→Sinhala transliteration + query normalization (strip ZWJ, sanitize) | `core/utils/singlish_transliterator.dart` (196), `search_query_utils.dart`, `text_utils.dart` | ❌ **No** — server receives the *already-converted* query | **Move into the server** (do normalization at the API boundary). Smallest, safest. |
| In-page "find on page" match offsets / highlighting | `core/utils/search_match_finder.dart` (223) | ❌ No (pure presentation) | Re-implement in TS (it's a view feature). |
| Text-marker parsing (`**bold**`, `__underline__`, `{footnote}`) | domain `entry.dart` computes ranges; `text_entry_widget.dart` renders | partial | Have the API return structured spans, **or** parse in TS. |
| Pali conjunct ligatures (Pali-in-Sinhala-script display) | `core/utils/pali_conjunct_transformer.dart` (220) | ❌ No | Move server-side or re-port. |
| FTS result grouping by sutta (`GroupedFTSMatch`) | domain entity, used at display time | ❌ No | Server-side grouping, or TS. |

Total re-port surface if you do it all in TS: **~600–900 LOC of pure functions**
(plus tests). Most of it is *better* moved server-side, which shrinks the TS
re-port to roughly just the in-page-find highlighter.

> **Strategic consequence:** the Jaspr doc's "backbone task — extract reusable
> Dart into `wisdom_domain` / `wisdom_text` packages" is **only valuable for the
> Jaspr path.** For Next.js those packages can't be imported, so that work is
> wasted. The Next.js-equivalent backbone task is **"push the client-only logic
> into the server so the API is the complete contract."**

---

## 4. Cleanup plan

Ordered by leverage. Everything in Phase 1 is **good regardless** of the web
decision (it improves the native app's layering too). Phases 2A/2B fork by target.

### Phase 1 — Make the domain Flutter-free (do this anyway) — ~½–1 day
1. `dictionary_filter_operations.dart`: drop `flutter/foundation`, replace
   `setEquals` with `package:collection` `SetEquality` (or a tiny helper).
   → pure domain logic, zero behaviour change.
2. `dictionary_info.dart`: move `getColor(dictId, ThemeData)` to a presentation
   helper (e.g. `presentation/utils/dictionary_colors.dart`); keep the data map
   in domain. Drop `flutter/material`.
3. `search_result_type.dart`: move the localized-label mapping to a presentation
   helper; domain keeps the enum.
4. `search_scope_chip.dart`: keep `id` + `nodeKeys` in domain; move the
   `AppLocalizations` label resolution to presentation.
5. Verify with `grep -rl "package:flutter" lib/domain` → expect **0 hits**.

*(Note: this touches production code and a few tests; per project convention,
flag that tests for the moved label/colour helpers should be added by the test
agent.)*

### Phase 1.5 — Tidy (optional, low priority)
- Decide the use-case layer: complete it or remove the two stragglers.
- Move the two Riverpod providers out of `core/` (`key_value_store_provider`,
  `theme_notifier`) into presentation, or accept them as infra (low value).

### Phase 2A — IF Jaspr — extract shared packages
- `wisdom_domain` (entities, failures, repo interfaces — now Flutter-free) and
  `wisdom_text` (the `core/utils` text algorithms). Flutter app + Jaspr both
  depend on them. (This is the Jaspr doc's backbone task — only do it here.)

### Phase 2B — IF Next.js — make the server the complete contract
- Move query normalization (Singlish→Sinhala, ZWJ strip, sanitize) to the API
  boundary in the shelf server, so the client sends raw text and the server
  normalizes. (Removes the biggest client-only gap.)
- Decide per item in §3.4 whether marker-parsing / conjunct-transform / grouping
  is done server-side (return structured JSON) or in TS.
- Treat the API as a versioned, documented contract (it already powers Flutter
  web — formalize it).

---

## 5. Rewrite effort estimate (rough)

Treat these as **relative** sizing, not calendar promises.

### What is unavoidable on *either* web framework
- Rebuild the presentation layer: **~13.8k LOC across 71 files**, dominated by a
  handful of large widgets:
  - `multi_pane_reader_widget.dart` (897) — the core reader; the hardest piece.
  - `dictionary_bottom_sheet.dart` (740), `search_results_panel.dart` (654),
    `text_entry_widget.dart` (616), `tab_bar_widget.dart` (544),
    `reader_action_buttons.dart` (469), `dual_column_pane.dart` (460),
    `refine_search_dialog.dart` (464), and the rest.
- Re-create theme as CSS variables (values from `core/theme`, ~1.4k LOC of Dart →
  a much smaller CSS file).
- Re-create the composition root / state wiring.

**But the MVP is much smaller than the whole app.** The SEO-valuable core is
*read + navigate + search + dictionary*. Settings, keyboard shortcuts, tab
persistence, in-page find, multi-edition panes, etc. are parity work that can
follow. The MVP is roughly the reader + tree + search panel + dictionary popup.

### Jaspr-specific add-ons
- Extract shared packages (Phase 2A): small, mechanical.
- Learn Jaspr's component model (Flutter-shaped — low friction) + CSS.
- Carry the pre-1.0 framework risk (pin version, budget migrations).

### Next.js-specific add-ons
- **Zero Dart reuse on the client** — but the server already covers the data
  brains, so this mostly means "build a normal frontend against an existing API."
- Re-port / relocate the client-only logic in §3.4 (~600–900 LOC, much of it
  better moved server-side).
- Maintain a **second language ecosystem** forever (the real ongoing tax).
- In exchange: the most mature SSR/SSG/SEO story available, and a far larger
  hiring/AI-assist surface than Jaspr.

### Honest bottom line
- **Phase 1 cleanup (domain Flutter-free): small and worth doing now.** It is
  *not* a blocker and *not* big.
- **The rewrite itself is a genuine project**, but its size is set by the
  *presentation layer* (which must be rebuilt for the web in any framework),
  **not** by architecture debt. Our architecture debt is minor. We are not
  "paying down a mess before we can start" — we're in a position to start the
  view rewrite whenever the framework call is made.
- **Framework choice is the lever, not cleanliness.** Jaspr minimizes total work
  (one language, reuse logic) at the cost of maturity. Next.js maximizes web
  quality and ecosystem at the cost of a permanent second codebase and zero
  client-side Dart reuse — mitigated by leaning hard on the already-capable API.

---

## 6. Recommended next step

1. **Do Phase 1 now** (domain Flutter-free) — it's cheap, improves the native
   app, and de-risks every web future. No framework decision required.
2. **Make the framework call** (Jaspr vs Next.js) using §1 — chiefly:
   *do we accept a second language forever (Next.js) to get a mature ecosystem +
   best SEO, or keep one language (Jaspr) and accept pre-1.0 risk?*
3. **Then** pick Phase 2A or 2B — but **don't** start the package-extraction
   backbone until the framework is chosen, because it's only worth it for Jaspr.

> Reminder of prior art: the SEO doc's **Option A (shelf-SSR stopgap)** can ship
> independently and get the content indexed *now*, regardless of which durable
> client wins — it buys time to make this decision without pressure.
