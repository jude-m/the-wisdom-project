# App / Content Language Split — Test Plan

Status: Layers 1, 2 and 3.1 implemented (2026-06-06). Remaining: 3.3 (refine-dialog
wiring) and the L.* Sinhala-locale render pass.
Covers: commit `81d2900` (split UI "App Language" from data "Content Language")
plus the search-label re-derivation (`searchResultLabels`) and the
`effectiveSearchDisplayLanguageProvider` filter override.

---

## The governing rule (your preference, made concrete)

> Prefer integration tests because they mimic real user behaviour — **but**
> anything that can be proven by a cheaper unit/widget test does **not** need an
> integration test.

So we push every check down to the cheapest layer that can actually prove it,
and we reserve integration tests for the things only a *running app* can prove:

| Layer | What lives here | Why |
|---|---|---|
| **Unit** | Pure functions and provider logic with no widgets (`ProviderContainer` + overrides). | Fastest, most deterministic. The *rules* of the split (clamping, fallbacks, persistence, locale resolution) are pure logic — prove them here. |
| **Widget** | A single widget pumped in isolation with provider overrides. | Proves "when the language provider changes, *this widget* re-renders the right text" without booting the whole app. |
| **Integration** | The full app, driven like a user (tap the settings menu, type a search). | Reserved for **cross-screen journeys** and the **independence claim** — things that only emerge when MaterialApp + data widgets run together. |

**Key consequence:** persistence round-trips and locale resolution are pure
notifier/store logic → **unit**, *not* an expensive app relaunch. Tab/label
rendering for one widget → **widget**, not integration. Integration is spent
only where it earns its cost.

---

## Test matrix at a glance

What each case must prove, and at which layer. ⭐ = highest value.

| ID | Layer | What the test must prove | Status |
|---|---|---|---|
| 1.1 | Unit | `formatContentLabel`: Pali → conjuncts (and ≠ raw), Sinhala → unchanged | ✅ Done |
| 1.2 | Unit | `AppLanguage.fromLocales` honours the *ordered* device list (`[ta,si,en]`→si); `fromStorage` parses / rejects | ✅ Done |
| 1.3 | Unit | `getDisplayName` falls back to the other language when the chosen name is empty | ✅ Done |
| 1.4 | Unit | `availableContentLanguagesProvider` = `[pali, sinhala]` for BJT; unsupported ISO codes are dropped | ✅ Done |
| 1.5 | Unit | `effectiveContentLanguageProvider` clamps an unsupported saved choice to the edition default | ✅ Done |
| 1.6 | Unit | Content Language persists and restores on relaunch; a throwing store still flips state | ✅ Done |
| 1.7 | Unit | App Language defaults to device locale, saved value wins, device default is *not* persisted | ✅ Done |
| 1.8 | Unit | `effectiveSearchDisplayLanguageProvider`: one-language filter drives labels; both-on follows reading pref | ✅ Done |
| 2.1 | Widget | Tab label: Sinhala → raw `sinhalaName`, Pali → `applyConjunctConsonants(paliName)` | ✅ Done |
| 2.2 | Widget | `searchResultLabels` breadcrumb **path** (drops the leaf) in the active language; dictionary fallback; live switch | ✅ Done |
| 2.3 | Widget | Settings content selector lists the available langs, reflects effective, fires `setLanguage` | ✅ Done |
| 3.1 ⭐ | Integration | App vs Content are **independent** — one axis moves, the other doesn't (one label each) | ✅ Done |
| 3.2 | Integration | Content Language across surfaces (breadcrumb / tree / search title / tab) | ✅ Done (staged) |
| 3.3 | Integration | Refine dialog narrowed to one language drives search-label language (wiring only) | ⬜ TODO (extend) |
| — | Manual 👆 | Fresh install resolves device locale → App Language; unsupported locale → fallback | Smoke |

---

## What is already covered (do NOT duplicate)

From `test/presentation/providers/navigation_tree_provider_test.dart`:
- `contentLanguageProvider` defaults to Sinhala; toggles to Pali and back.
- `nodeByKeyProvider`: finds by key, returns null for unknown key / while loading,
  finds deeply nested node. (This is the O(1) index correctness guard — done.)

From the staged integration edits:
- `breadcrumb_navigation_test.dart`: tree + breadcrumb render Pali with conjuncts
  after `contentLanguageProvider.setLanguage(pali)`.
- `search_flow_integration_test.dart` (test 2.3): search **title** re-derives from
  the node — asserts **both** the Sinhala (unchanged) and Pali (conjuncts) branches.
- `dictionary_editable_word_test.dart`, `scroll_restoration_test.dart`: tab labels
  show the node's `sinhalaName` in the default (Sinhala) Content Language.
- `settings_menu_button_test.dart`: the settings menu renders both selectors and
  updates the providers when an option is chosen.

Everything below is a **gap** against the current suite.

---

## Duplicates vs. intentional layering (read this first)

The one fact that recurs across layers is **"conjunct ligatures are applied on the
Pali branch, never on Sinhala."** That is *not* a duplicate when each layer tests a
**different unit's wiring** to the seam:

- **1.1** tests the seam (`formatContentLabel`) itself — the source of truth for the
  transformation.
- **2.1 / 2.2** test that the *tab widget* and *search labels* actually **call** the
  seam with the right language. They trust 1.1 for correctness; they only prove
  "this widget is wired to it."
- **3.x (integration)** must **not** re-derive the transformation. It only checks
  "the user sees Pali / Sinhala content" — *presence*, not the exact ligature output.

**Rule of thumb:** use `applyConjunctConsonants(...)` / `formatContentLabel(...,pali)`
as the **oracle at most once per unit** (the seam, then each caller's wiring). In
integration, find the *plain* expected display name and assert it's on screen — don't
re-run the transformer as the integration oracle. The edits below remove three places
where the plan broke this rule (all in Layer 3 / search-label title).

---

## Layer 1 — Unit tests (the rules)

These are pure logic. No widgets. Use `ProviderContainer(overrides: [...])`
for the provider ones, plus the in-memory store from `test/helpers/`.

### 1.1 `formatContentLabel` — the single rendering seam
File: `test/presentation/utils/content_text_formatter_test.dart` (new)
- Use one sample string that **actually contains a conjunct**, then assert in a
  single case: Pali → `s.withPaliConjuncts` *and* `!= s` (proves the branch is real,
  not a no-op); Sinhala → `s` unchanged.
- Rationale: this is *the* seam every label surface depends on; one test locks the
  "conjuncts on Pali only, never on Sinhala" invariant. Every other layer trusts it.

### 1.2 `AppLanguage` resolution (pure, device-locale logic)
File: `test/core/localization/app_language_test.dart` (new)
- **Ordered fallback** (the one non-obvious behaviour): `fromLocales([ta, si, en]) == sinhala`
  — Tamil unsupported → honour the 2nd choice, not English. Plus `fromLocales([ta]) ==
  english` and `fromLocales([]) == english` (no match → English).
- `fromStorage`: a valid name parses, `null`/garbage → `null` (caller then falls back
  to device).

### 1.3 `TipitakaTreeNode.getDisplayName` fallback
File: extend `test/` node/entity test (or add a focused one).
- The only thing worth asserting is the **empty-name fallback**: Pali with empty
  `paliName` → `sinhalaName`; Sinhala with empty `sinhalaName` → `paliName`
  (the `ap-pat`/Paṭṭhāna case in the source TODO). The happy path is obvious — skip it.

### 1.4 `availableContentLanguagesProvider` (edition-driven set)
File: `test/presentation/providers/content_language_provider_test.dart` (new)
- For BJT (`bjtEdition`, `availableLanguages: ['pi','si']`) →
  `[ContentLanguage.pali, ContentLanguage.sinhala]` **in that order**.
- One edge: an edition listing an **unsupported ISO code** drops it (the provider
  filters via `ContentLanguage.fromIso` + `whereType`) — proves a future bad edition
  list can't inject a junk language. (This is the only enum-mapping assertion worth
  keeping; the `fromIso('pi')==pali` round-trips are too trivial to test.)

### 1.5 `effectiveContentLanguageProvider` — clamping (the raw-vs-effective split)
File: same as 1.4
- Saved choice **is** supported → effective == saved (raw `pali` under BJT → `pali`).
- Saved choice **not** supported → falls back to `available.first`. Reproduce by
  overriding `currentEditionProvider` with a stub `Edition(availableLanguages: ['si'])`
  and a raw saved value of `pali` → effective == `sinhala`.
- Rationale: BJT supports both languages, so clamping **never fires** under the real
  edition — this provider's whole reason for existing is only exercisable by stubbing
  an edition. Pure provider test is the only sane place for it.

### 1.6 `contentLanguageProvider` persistence (best-effort)
File: same as 1.4
- **Relaunch round-trip:** `setLanguage(pali)` writes the enum `name` under
  `StorageKeys.contentLanguage`; a *new* `ContentLanguageNotifier` over the **same**
  store restores it. (This replaces an app-relaunch integration test.)
- **Throwing store:** a store whose `setString` throws still flips `state` and does
  **not** surface an unhandled async error (the catch+log path).

### 1.7 `appLanguageProvider` defaulting & persistence
File: `test/presentation/providers/app_language_provider_test.dart` (new)
- No saved value → state derives from `deviceLocalesProvider` (override with
  `[Locale('si')]` → `sinhala`).
- Saved value **wins** over device locale (saved `english`, device `[si]` → `english`).
- Device-derived default is **not** persisted; an explicit `setLanguage` is
  (the subtle bit — "tracking the device" must not write until the user chooses).

### 1.8 `effectiveSearchDisplayLanguageProvider` — filter override
File: `test/presentation/providers/search_display_language_provider_test.dart` (new)
- Pali-only filter → `pali`; Sinhala-only filter → `sinhala`.
- Both on (default) → falls back to `effectiveContentLanguageProvider` (override it to
  `pali` and assert it follows).
- Rationale: the "labels follow the narrowed search" rule. Prove it here so the
  integration test only confirms the *wiring*.

---

## Layer 2 — Widget tests (one widget, right text)

Pump a single widget with overrides; assert the rendered text. No full app.

### 2.1 Tab label rendering follows Content Language
File: extend `test/presentation/widgets/tab_bar_widget_test.dart`
- Override `effectiveContentLanguageProvider` (or set `contentLanguageProvider`):
  - Sinhala → tab shows raw `sinhalaName` (fallback chain `sinhalaName ?? paliName ?? label`).
  - **Pali → tab shows `applyConjunctConsonants(paliName)`** ← the branch the
    integration suite does *not* assert (it only checks the Sinhala default).
- Rationale: this is a pure single-widget render reaction; no need to boot the app
  to prove the Pali branch. Closes the gap noted in the earlier test-plan review.
- Not a duplicate: the staged `dictionary_editable_word` / `scroll_restoration`
  integration tests reference the Sinhala tab label only as a *locator* (those tests
  are about scrolling / dictionary editing). This widget test is the **canonical**
  owner of tab-label rendering — don't add language assertions to those integration tests.

### 2.2 `searchResultLabels` — path derivation + fallbacks
File: `test/presentation/utils/search_result_labels_test.dart` (new; widget test
because the function takes a `WidgetRef`)
- Harness: a tiny `ConsumerWidget` whose `build` calls
  `searchResultLabels(ref, result)` and renders `Text(title)` + `Text(path)`.
  Override `navigationTreeProvider` with a small fixed tree (root → parent → leaf).
- **Path is the unique target:** ancestors joined ` > `, **excluding** the leaf
  itself (the source drops the last key), each segment rendered in the active
  language. (The title comes along for free — its two-language rendering is already
  owned by the seam in 1.1 and the staged search-title integration check, so don't
  re-litigate it here.)
- **Dictionary fallback:** a result with an empty/unknown `nodeKey` → returns
  `result.title` / `result.subtitle` verbatim (node lookup is null).
- **Live language switch:** flip `contentLanguageProvider` and `pumpAndSettle` →
  the tile's path re-renders in the new language (it uses `ref.watch`).
- Rationale: the **path** (breadcrumb) and the dictionary fallback are unique to this
  function and far cheaper to prove with a stubbed tree than through a real FTS search.

### 2.3 Settings selectors (extend existing)
File: `test/presentation/widgets/settings_menu_button_test.dart`
- Content selector lists exactly `availableContentLanguagesProvider`
  (Pāḷi + Sinhala for BJT) and highlights `effectiveContentLanguageProvider`.
- Selecting Pāḷi calls `contentLanguageProvider.notifier.setLanguage(pali)`.
- (App selector + "updates providers" is already covered — just add the
  content-selector assertions.)

---

## Layer 3 — Integration tests (only what a running app can prove)

### 3.1 ⭐ App Language and Content Language are INDEPENDENT (highest value)
File: `integration_test/language_independence_test.dart` (new)
This is the headline claim of `81d2900` and is asserted **nowhere** today.
Integration's only job here is to prove the two axes are **orthogonal** — *not* to
re-verify the conjunct transformation (1.1 owns that; 3.2 already shows Pali on the
data surfaces). So pick **one** chrome string and **one** data label and watch them
move independently:
1. Capture a localized chrome string (a settings label) and one tree node name.
2. Switch **App Language → Sinhala** → the chrome string localizes (and
   `MaterialApp.locale` is `si`) **while that one data label is unchanged**.
3. Switch **Content Language → Pali** → that one data label switches to its Pali
   form **while the chrome string is unchanged**.
- Keep it to the single before/after pair on each axis — don't sweep tree + tab +
  search; one data label is enough to prove independence.
- Why integration: orthogonality only emerges when MaterialApp localization and the
  data widgets run together. No lower layer can prove "one axis moved, the other didn't."

### 3.2 Content Language end-to-end across surfaces (mostly DONE — confirm coverage)
Already covered by the staged edits: breadcrumb + tree (`breadcrumb_navigation_test`),
search title both branches (`search_flow` test 2.3), tab labels Sinhala
(`dictionary_editable_word`, `scroll_restoration`). **No new test needed** — the
search *path* and dictionary fallback move to the widget test (2.2).
- Honest exception to the "presence, not transformation" rule: `search_flow` test 2.3
  asserts against `formatContentLabel(...)` as its oracle — slightly stricter than
  "just check it works". It's the single search-title integration check and already
  passing, so **leave it as-is** rather than loosen a green test for purity.

### 3.3 Search filter drives label language (wiring check, lower priority)
File: extend `integration_test/search_flow_integration_test.dart` or the refine dialog test
- With reading preference = Sinhala, open the refine dialog and **narrow to Pāḷi
  only** → result titles render in Pali (conjuncts), proving the dialog is wired to
  `effectiveSearchDisplayLanguageProvider`.
- Why only a thin integration check: the *rule* is unit-tested in 1.8; integration
  only needs to confirm the dialog toggles actually feed that provider. Keep it to
  one case.

---

## Manual smoke checks (👆 not automated)

- **Fresh install, device locale = `si`** → App Language defaults to Sinhala.
  (The pure resolution is unit-tested in 1.2; faking the real platform locale list
  in a test is flaky, so verify the real device path by hand once.)
- Unsupported device locale (e.g. Tamil-only) → falls back per the ordered list / English.

---

## Suggested priority

1. **3.1** — App vs Content independence (biggest coverage gap, headline claim).
2. **1.5 / 1.6 / 1.7** — clamping + persistence + locale defaulting (the rules with
   zero current coverage; cheap and high-signal).
3. **1.8 + 3.3** — search-filter label language (rule + thin wiring check).
4. **2.1 / 2.2** — tab Pali branch + `searchResultLabels` path & dictionary fallback.
5. **1.1–1.4 + 2.3** — seam / locale resolution / getDisplayName fallback /
   available-set + settings selector extensions (fast, fill-in coverage).

---

## Notes for whoever writes these

- Reuse the in-memory store helpers (`test/helpers/fake_key_value_store.dart`,
  `integration_test/test_overrides.dart` → `keyValueStoreOverride()` gives a fresh
  store per call, so state never leaks between tests).
- Pali content is in **Sinhala script** (e.g. දීඝනිකාය) — assert against
  `applyConjunctConsonants(...)` / `formatContentLabel(..., pali)` as the oracle, never
  hand-typed romanized strings.
- Per project convention, test code is written by the test-generator agent / on
  explicit request — this document is the **plan only**.

---

## Localization labels (ARB) — coverage from the Sinhala labels pass (2026-06-01)

A related but distinct workstream from the App/Content split above. This pass
(a) tokenized 11 hardcoded UI strings so they route through `AppLocalizations`,
and (b) corrected/improved 10 Sinhala values + added 4 new keys
(`themeLight`, `backspace`, `searchLanguageLabel`, `clearAll`). Full record:
`docs/done/sinhala_localization_audit.md` and `docs/done/sinhala_translation_table.md`.

| ID | What the test must prove | Status |
|---|---|---|
| L.1 ⭐ | Changed / new ARB values render under `Locale('si')` (the translations themselves) | New |
| L.2 | `recent_search_overlay`: `clearAll` label renders + "Clear All" tap fires (no test file today) | New |
| L.3 | `settings_menu_button`: Reset button reads `l10n.reset` | Extend |
| L.4 | `refine_search_dialog`: localized title / `SCOPE` header / `Clear` button | Extend |
| L.5 | Optional: localized tooltips & chips (scope `Refine` chip, `Close`, `Backspace`) | Optional |

### Status: nothing breaks (so these are "harden coverage", not "fix breakage")

- **Every existing widget test pumps the English locale** (`AppLocalizations.localizationsDelegates`;
  `dictionary_bottom_sheet_test` hard-sets `Locale('en')`). The pass changed **only
  Sinhala values** and left all **English values identical**, so every `find.text('Light'/'Pali'/…)`
  assertion still matches.
- **No test asserts any of the old Sinhala strings** (සැකසීම් / සූක්ෂම / පාලි / අටුවාව …),
  so the value changes break nothing either.
- Confirmed-coupled-but-passing: `refine_search_dialog_test.dart:162`
  `expect(find.text('LANGUAGE'), findsNothing)` now resolves via
  `searchLanguageLabel` (EN `"Language".toUpperCase()` == "LANGUAGE"); and
  `settings_menu_button_test.dart:35` `find.text('Light')` now exercises `l10n.themeLight`.

### The real gap: there is **zero Sinhala-locale rendering coverage** anywhere

All tests run in English, so the Sinhala translations — the entire point of this
pass — are unverified. Closing this is the highest-value addition.

### L.1 ⭐ Sinhala-locale render test (highest value, purely additive)
File: extend the relevant widget tests, or a new `*_si_test.dart`, pumping
`locale: const Locale('si')`.
- Assert the changed/new values render: **සැකසුම්** (settings), **පාළි** (pali label),
  **සෙවුම සීමා කිරීම** (refineSearch), **අට්ඨකථා** (commentary), **ආලෝකවත්** (themeLight),
  **මකන්න** (backspace), **සියල්ල ඉවත් කරන්න** (clearAll), **සෙවුම් භාෂා සීමා කරන්න**
  (searchLanguageLabel header).
- Oracle: read the value from `AppLocalizations` / the `.arb`, never hand-typed,
  to stay robust to future wording tweaks.

### L.2 `recent_search_overlay` — **no test file exists**
File: `test/presentation/widgets/recent_search_overlay_test.dart` (new)
- The widget had no coverage and just gained localization (`clearAll`) + an
  `AppLocalizations` import. Prove it renders the `clearAll` label (EN "Clear All",
  SI සියල්ල ඉවත් කරන්න) and that the "Clear All" tap fires its callback.

### L.3 `settings_menu_button_test.dart` (extend)
- Add: Reset button now reads `l10n.reset` (currently unasserted).
- Optionally fold the `themeLight` / Sinhala-locale checks from L.1 here.
- (Note: the unrelated `.first` edit from the split work also lives in this file.)

### L.4 `refine_search_dialog_test.dart` (extend)
- The localized `Refine Search` title, `SCOPE` header (now `l10n.scope.toUpperCase()`),
  and `Clear` button are untested. Add assertions; consider a SI-locale case that the
  language header reads **සෙවුම් භාෂා සීමා කරන්න**.

### L.5 Optional — no breakage, just no assertions for newly-localized bits
- `scope_filter_chips_test.dart` → the `Refine` chip (now `l10n.refine`).
- `search_results_panel_test.dart` → `Close` tooltip (now `l10n.close`).
- `dictionary_bottom_sheet_test.dart` → `Backspace` / `Close` tooltips.

### Localization-pass priority
1. **L.1** — Sinhala-locale rendering (the only thing proving the translations).
2. **L.2** — `recent_search_overlay` (a whole widget with no test).
3. **L.3 / L.4** — Reset / refine-dialog localized labels.
4. **L.5** — optional tooltip/chip assertions.
