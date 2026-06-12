# Web Rewrite — Phase 3: Remaining Sharing Opportunities

> Status: **Ideas / backlog** — not scheduled. Captured 2026-06-10.
> Companion to:
> [`web-rewrite-clean-architecture-audit.md`](./web-rewrite-clean-architecture-audit.md),
> [`web-rewrite-phase2-shared-package-extraction.md`](./web-rewrite-phase2-shared-package-extraction.md),
> [`jaspr-prototype-findings.md`](./jaspr-prototype-findings.md).
>
> Precondition: Phase 2 done (web client imports `wisdom_text` /
> `wisdom_domain` instead of its prototype copies).

## 0. Context

After Phase 2, all *high-value* logic sharing is done. The duplication that
remains is presentation-layer, and most of it should **stay** duplicated
(§4). These are the three genuine opportunities left, ordered by value.
None blocks the real web build from starting — item 3 is simply the first
thing that build needs.

---

## 1. Shared UI strings (highest value — real duplication today)

**Problem**: the web client hardcodes its Sinhala labels (පාළි, layout
names, tab strip text…) while the app's source of truth is
`lib/core/localization/l10n/app_en.arb` / `app_si.arb`. As the web UI grows
(settings, dictionary, menus), labels will drift between platforms — and the
SI conventions were hard-won (see `docs/done/sinhala_localization_audit.md`).

**Approach**: ARB is plain JSON and the `intl` machinery is pure Dart — only
the `flutter gen_l10n` wrapper is Flutter-bound.

- Move the ARB files into a shared package (`packages/wisdom_l10n/` or fold
  into an existing one).
- App keeps `gen_l10n`, pointed at the new path
  (`l10n.yaml` → `arb-dir`).
- Web client generates from the *same* ARB via `intl_translation` /
  `slang`-style codegen, or — simpler — a small build step that emits a
  Dart map of `key → {en, si}` consts. The prototype needed only ~15
  strings; a generated const map may be all the web ever needs.

**When**: as soon as the real web build adds its second screen's worth of
labels. Doing it for the prototype's handful of strings is premature.

## 2. Design tokens → one source of truth

**Problem**: `web_client_prototype/web/styles.css` re-declares colors,
font sizes and spacing that already exist in the app's theme files. Two
places to update on every theme tweak.

**Approach**: a tiny shared token layer — plain Dart consts (hex strings,
numeric sizes, font names), **no Flutter types**:

- Flutter themes construct `Color(...)`/`TextStyle(...)` *from* the tokens
  (the ongoing ThemeExtension consolidation — e.g. the dictionary-badge
  colour move — is converging on exactly the structure this needs; see
  memory of the text_entry_theme conventions).
- A trivial build script (`dart run tool/emit_css_tokens.dart`) emits the
  same tokens as CSS custom properties → checked-in `tokens.css` that
  `styles.css` consumes.

**When**: when the web client gets real theming (light/dark, font-scale UI).
Until then the prototype's hand-written CSS variables are fine.

## 3. Serve the nav tree from the API (first task of the real build)

**Problem**: the prototype hardcodes 5 nav items
(`web_client_prototype/lib/src/nav_items.dart`); the real hierarchy lives in
`assets/data/tree.json`, which the server already ships on disk but does not
expose.

**Approach**:

- New endpoint `GET /api/tree` in `server/` (static file serve or parsed +
  cached — the file is read-only at runtime).
- Tree-node models go in `wisdom_domain` (they're the client-side decoders
  of an API contract, same rationale as `FTSMatch` in Phase 2 §1.3).
- Web client replaces `nav_items.dart` with a real tree navigator fed from
  the endpoint. SSR can preload the top level via `PreloadStateMixin`.

**When**: immediately when the real (non-prototype) web build starts —
it's the entry point of the whole browsing experience.

---

## 4. Deliberate non-goals (don't share these)

- **State layer / tab notifiers**: Riverpod is pure Dart so sharing is
  *possible*, but the prototype proved web wants different semantics —
  non-reactive `ScrollRegistry` instead of reactive scroll offsets, an MRU
  keep-alive policy with no Flutter equivalent. The shared part (the
  `ReaderTab` model) is ~50 lines; the coupling cost exceeds the
  duplication cost. (jaspr-prototype-findings §finding 2.)
- **Widgets/components**: different rendering paradigms by design; CSS
  replaces whole Flutter mechanisms (e.g. `_PairHeightSync` → one grid
  rule). Nothing to share.
- **Repository implementations**: the app's data layer is
  platform-conditional (local DB on native); the web client's thin
  `WisdomApiClient` is the correct web-shaped counterpart, not duplication.

## 5. Related but orthogonal

The planned **content-DB single source** (text JSON → per-page SQLite as the
runtime source of truth) is server/data-layer architecture. It benefits both
clients equally but changes nothing about how much code the web client
shares — track it separately.
