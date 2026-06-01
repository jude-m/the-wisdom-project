# Test Plan — Pali/Sinhala Search-Language Toggle

**Status:** ✅ COMPLETE — 2026-06-01. All planned tests are written and passing.
This doc is now both the design rationale **and** the single record of what shipped
(the former `docs/todo/test_coverage_findings.md` has been folded in here and deleted).

## ✅ Delivered & passing

Feature tests (Part B of the old findings doc):

| # | What | File | Runner |
|---|------|------|--------|
| §3a | Repo title-gating + FTS filter-value passthrough (incl. count/badge parity) | extended `test/data/repositories/text_search_repository_impl_test.dart` | `flutter test` |
| §3b | `effectiveSearchDisplayLanguageProvider` truth table | `test/presentation/providers/search_display_language_provider_test.dart` | `flutter test` |
| §3c | `m.language = ?` filters real rows (in-memory `sqflite_common_ffi`, via the client `ScopeFilterService` seam) | `test/data/datasources/fts_language_filter_sql_test.dart` | `flutter test` |
| §4a | Refine-dialog toggle: renders segments, **can't deselect the last**, hides when <2 languages | `test/presentation/widgets/refine_search_dialog_test.dart` | `flutter test` |
| §4b | Result-tile label follows the search language + flips live | extended `test/presentation/widgets/search_results_panel_test.dart` | `flutter test` |
| §5 | ONE E2E smoke: toggle → re-search → real SQLite filter → badge counts (partition invariant) | `integration_test/search_language_toggle_test.dart` (+ `setSearchLanguages` helper, hooked into `all_tests.dart`) | `flutter test -d macos` |
| §6 | Server clause filters real `sqlite3` rows + whitelist degrades unknown→both | `server/test/handlers/fts_handler_test.dart` | `dart test` |

`wisdom_shared` coverage (Part A of the old findings doc):

| # | What | File | Runner |
|---|------|------|--------|
| A1 | **The big one** — redirected the `buildFtsQuery` matrix at the REAL shared function (deleted the hand-copied `test/data/datasources/fts_datasource_test.dart`) | `packages/wisdom_shared/test/fts/fts_query_builder_test.dart` | `dart test` |
| A2 | Dictionary SQL helpers — LIKE-injection escaping + `dict_id IN (...)` lock-step | `packages/wisdom_shared/test/dictionary/dictionary_sql_helpers_test.dart` | `dart test` |
| A4 | `parseCsvToSet` + `inferTargetLanguage` pins | `…/test/utils/csv_parser_test.dart`, `…/test/dictionary/dictionary_language_test.dart` | `dart test` |

Already done in prior sessions: `packages/wisdom_shared/test/scope/scope_filter_sql_test.dart`
(the clause/param string contract) and `test/domain/entities/search/search_language_scope_test.dart`
(the `fromFlags` truth table).

## Deliberately NOT added (documented gaps)

- **A3 `ScopePatterns`** — already transitively covered: `ScopeOperations` is a thin wrapper
  and `test/domain/entities/search/scope_operations_test.dart` exercises `getPatternsForScope`
  + `isNodeCoveredBy`. Don't double-test.
- **§3c / §6 against the real `FTSDataSourceImpl` / `FtsHandler`** — neither exposes a DB-injection
  seam, and adding one purely for tests would be a production test-shim. Instead both tests seed an
  in-memory DB and drive the **real shared clause builder** (`ScopeFilterSql` / `ScopeFilterService`)
  through the SAME SQL skeleton the production code uses. The string contract is covered by
  `scope_filter_sql_test.dart`; the real end-to-end client path is covered by §5.

**Feature:** The පාළි / සිංහල search toggle in the refine dialog (which language(s) Title + FTS search look in), plus the "narrowed search drives the result-label display language" decision.
**Related:**
- `docs/discussion/search_result_titles_content_language.md` §6 (the locked design)
- `docs/todo/search_language_filter_implementation.md`

---

## 0. Code surfaces under test

| Layer | File | What changed |
|-------|------|--------------|
| Repo | `lib/data/repositories/text_search_repository_impl.dart` | `_searchTitles` gates each name field by `searchInPali`/`searchInSinhala`; `_ftsLanguageFilter` maps the two bools → `'pali'`/`'sinh'`/`null`; passthrough in `searchTopResults`, `searchByResultType`, `countByResultType` |
| Datasource | `lib/data/datasources/fts_local_datasource.dart` | `AND m.language = ?` clause in `searchFullText`; `countFullTextMatches` now joins meta when scope **or** language filter present (`needsMetaJoin`) |
| Provider | `lib/presentation/providers/search_display_language_provider.dart` | `effectiveSearchDisplayLanguageProvider` — both on → Content Language; narrowed to one → that language |
| Labels | `lib/presentation/utils/search_result_labels.dart` | now reads `effectiveSearchDisplayLanguageProvider` instead of `effectiveContentLanguageProvider` |
| UI | `lib/presentation/widgets/search/refine_search_dialog.dart` | `SegmentedButton` toggle above the tree (mandatory `emptySelectionAllowed:false`, edition-driven, hidden when <2 languages) |
| State | `lib/presentation/providers/search_state.dart` | `setLanguageFilter` triggers re-search + recount |
| Server (web) | `server/lib/src/handlers/fts_handler.dart` | same `AND m.language = ?` clause in `/search` and `/count` |

**Contract to protect:** the DB stores Sinhala as `'sinh'` (not `'sinhala'`); the app surfaces `'sinhala'`. `_ftsLanguageFilter` returns the DB values `'pali'`/`'sinh'`.

---

## 1. Guiding principle (the cost trade-off)

> **Test each behavior at the lowest level that can reproduce it faithfully. Use integration only to prove the layers are wired together with real dependencies — never to check logic permutations.**

For this feature, almost all risk lives in **pure logic + one SQL contract**, not in app wiring. So:

- **Widget tests are the sweet spot** for "I want user-behavior fidelity but cheap": they fire real taps and trigger real rebuilds (user-like) with mocked data (fast, deterministic, no real DB). ~80% of the "behaves as a user expects" confidence at ~unit-test cost.
- **`integration_test/` is reserved for ONE real-DB smoke flow.** Its job is "are all layers wired with real deps", not logic.

**Recommended allocation:** ~14 unit + ~6 widget + **1** integration.
The "mostly integration" alternative would be ~12 slow, flaky tests re-verifying logic the unit tests already nailed.

| Level | Mimics user? | Speed | Use it for |
|-------|--------------|-------|------------|
| Unit | ✗ | ⚡⚡⚡ | Logic permutations, filter-value mapping, display-language truth table, SQL |
| Widget | ✓ (taps + rebuilds) | ⚡⚡ | Toggle UI contract + "right-language label reaches the screen and updates live" |
| Integration | ✓✓ (real app + DB) | 🐢 | **One** end-to-end: search → refine → toggle → results change |

---

## 2. Existing test infrastructure (already available)

- `sqflite_common_ffi: ^2.4.0+2` (dev dep) → in-memory SQLite for fast datasource SQL tests.
- `mockito: ^5.4.4` + generated `test/helpers/mocks.mocks.dart` (already regenerated for the new `language` param).
- `test/data/repositories/text_search_repository_impl_test.dart` — has a fake tree + `MockFTSDataSource`; extend it for repo tests.
- `test/data/datasources/fts_datasource_test.dart` — existing datasource test to extend for SQL.
- `test/presentation/widgets/search_results_panel_test.dart` — already pumps the panel with mocked state + a fake tree node; extend for the label test.
- `integration_test/` — rich harness: `search_flow_integration_test.dart`, and `search_test_helper.dart` exposing `pumpSearchApp`, `searchFor`, `waitForSearchResults`, `switchToTab`, `tapScopeChip`, `refineScope`, `expectCounts`, etc. Integration tests use the **real** navigation tree + DB from assets (no mocks).
- **No `server/test/` dir** — server tests are net-new infra.

---

## 3. Unit tests (the bulk — fast, exhaustive)

### 3a. Repo — title gating + filter-value passthrough
**File:** extend `test/data/repositories/text_search_repository_impl_test.dart`

Title gating (`_searchTitles`, in-memory, no DB):
- Pali-only → includes a node matching only its Pali name
- Pali-only → excludes a node matching only its Sinhala name
- Sinhala-only → mirror of the above
- both on → includes a node matching either name (unchanged behavior)
- node matching BOTH names → still exactly **one** result (dedup invariant)
- Pali-only composes with scope (gating ∧ scope, not ∨)

Filter-value passthrough (assert the arg captured by the mock — tests the private
`_ftsLanguageFilter` *through the public API*, so no `@visibleForTesting` shim):
- both on → `searchFullText` called with `language: null`
- Pali-only → `language: 'pali'`
- Sinhala-only → `language: 'sinh'` ← guards the `'sinh'` vs `'sinhala'` contract
- `countByResultType` passes the **same** language to `countFullTextMatches`
  ← **the count/badge-parity regression guard**

### 3b. Display-language provider (the heart of the decision)
**File (new):** `test/presentation/providers/search_display_language_provider_test.dart`
Pure `ProviderContainer`, override `searchStateProvider` + `contentLanguageProvider`. No widgets.

Truth table:
- both on + content=Sinhala → Sinhala
- both on + content=Pali → Pali
- Pali-only + content=Sinhala → **Pali** (narrowing overrides reading pref)
- Sinhala-only + content=Pali → **Sinhala**
- both off (defensive) → falls back to content language

### 3c. Datasource SQL (the 'pali'/'sinh' contract, against real SQLite)
**File:** extend `test/data/datasources/fts_datasource_test.dart` with `sqflite_common_ffi`
in-memory — seed a tiny `_fts`+`_meta` with 1 Pali row + 1 Sinhala row for the same nodeKey.
- `language:'pali'` → returns only the Pali row
- `language:'sinh'` → returns only the Sinhala row
- `language:null` → returns both
- count with `language:'pali'` and empty scope → joins meta and counts 1
  ← guards the new `needsMetaJoin` branch
- count with scope + language → both clauses applied

Cheapest faithful test of the actual SQL; catches the column-value contract without booting the app.

---

## 4. Widget tests (user-fidelity, cheap)

### 4a. The toggle in RefineSearchDialog
**File (new):** `test/presentation/widgets/refine_search_dialog_test.dart`
Pump the dialog with overridden providers.
- renders two segments labelled Pali / Sinhala, both selected initially
- tapping "Sinhala" (when both on) calls `setLanguageFilter(pali:true, sinhala:false)`
- **MANDATORY:** tapping the only selected segment does NOT deselect it (state stays ≥1)
  ← the `emptySelectionAllowed:false` guarantee
- edition with <2 languages → toggle is hidden (override `availableContentLanguagesProvider`
  with one language → expect `SizedBox.shrink`)

### 4b. Result tile shows the right-language label + live update (the payoff)
**File:** extend `test/presentation/widgets/search_results_panel_test.dart`
- content=Sinhala, both on → tile title renders the Sinhala name
- content=Sinhala, Pali-only → tile title renders the **Pali** name (narrowing reaches pixels)
- flipping the toggle re-renders the tile into the other language live (pump + expect)

4b is the single most valuable widget test: it transitively exercises
`effectiveSearchDisplayLanguageProvider` → `searchResultLabels` → the tile, proving the
decision is visible to a user.

---

## 5. Integration test (exactly ONE)

**File (new):** `integration_test/search_language_toggle_test.dart`, reusing `search_test_helper.dart`
(add one `setSearchLanguages(['Pali'])` helper that opens refine + taps the segment).

**One happy-path flow:**
1. `pumpSearchApp` → `searchFor('<term with both Pali & Sinhala FTS hits>')` → `waitForSearchResults`.
2. Capture FTS badge count with **both** on.
3. Open refine → set **Pali-only** → wait.
4. Assert the FTS badge count **decreased** (or stayed ≤), and a known Sinhala-only-name
   title result disappeared from the Title tab.
5. Set **both** again → counts return.

**Assertion style — use invariants/relations, not absolute numbers** (real `bjt-fts.db` content
can change): assert `paliOnlyCount ≤ bothCount`, and presence/absence of a specific stable
result — never `expect(count, 47)`.

Its job is to prove the **whole chain wired with the real DB** (toggle → state → re-search →
real SQLite `m.language` filter → re-render → badges), which nothing below can prove. One flow
is enough because every permutation is already covered in §3–§4.

---

## 6. Server (separate, lower priority)

The web path has its **own** SQL in `server/lib/src/handlers/fts_handler.dart`, and there's
currently **no `server/test/` dir**. If web matters before launch, add one Dart test there
mirroring §3c (in-memory sqlite, assert the `AND m.language = ?` clause filters). Otherwise
note it as a known coverage gap — the client is covered, the server SQL is not.

---

## 7. Deliberately skip

- Don't test `_ftsLanguageFilter` directly (private — assert via the captured mock arg; no prod test-shim).
- Don't re-test the truth table in integration — it's nailed in §3b.
- Don't assert absolute DB result counts in integration (brittle).
- No new Freezed/codegen tests — the `searchInPali`/`searchInSinhala` state fields already existed.

---

## 8. Suggested write order (best ROI first)

1. **§3a + §3b** (logic + the decision rule) — highest value, minutes to run.
2. **§4b** (the visible payoff) — catches wiring regressions.
3. **§3c** (SQL contract) — guards the `'sinh'` gotcha.
4. **§4a** (toggle UI, incl. mandatory + edition-hide).
5. **§5** (the one integration smoke).
6. **§6** (server) — only if web is in scope for this release.

---

## 9. File map

| Action | Path |
|--------|------|
| Extend | `test/data/repositories/text_search_repository_impl_test.dart` (§3a) |
| New | `test/presentation/providers/search_display_language_provider_test.dart` (§3b) |
| Extend | `test/data/datasources/fts_datasource_test.dart` (§3c) |
| New | `test/presentation/widgets/refine_search_dialog_test.dart` (§4a) |
| Extend | `test/presentation/widgets/search_results_panel_test.dart` (§4b) |
| New | `integration_test/search_language_toggle_test.dart` (§5) + helper in `search_test_helper.dart` |
| New (optional) | `server/test/handlers/fts_handler_test.dart` (§6) |
