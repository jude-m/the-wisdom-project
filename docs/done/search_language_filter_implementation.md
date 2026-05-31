# Plan: Search Language Filter (පාලි / සිංහල toggles)

**Status:** 📝 Plan — awaiting approval (created 2026-05-30)
**Implements:** the §6 decision in `docs/todo/search_result_titles_content_language.md`.
**Scope:** Wire the already-modelled `searchInPali` / `searchInSinhala` toggles into
the search pipeline, surface them as **two toggle buttons inside the Refine Search
dialog** (above the tree/scope section), and make the **display language** of
title + path follow the searched language when narrowed to one.

---

## 0. What we are (and are NOT) building

**Building**
- Two language toggle buttons (පාලි / සිංහල) **inside the Refine Search dialog**, on
  top of the SCOPE tree section. That dialog is shared by the **Title** and
  **Full‑Text** tabs only.
- The data‑layer filter so those toggles actually narrow *which names / text* get
  searched (Titles **and** Full‑Text), including the **count** path (tab badges).
- A display‑language rule: **both on → Content Language; narrowed to one → that
  language** drives the result title + navigation path.
- Cross‑platform parity: native (local SQLite) **and** web (remote + server).

**NOT touching**
- The **Dictionary** Refine dialog (`RefineDictionaryDialog`) — left exactly as is.
- Definitions tab — no language toggle there.
- The verbatim FTS snippet (`HighlightedFtsSearchText`) — it stays in the matched
  language (`result.language`); it is real matched text, not a label.
- The search‑results cache key — it **already** includes `searchInPali` /
  `searchInSinhala` (`caching_text_search_repository.dart`), so no change needed.

---

## 1. Two independent axes (keep these straight)

| Axis | Question it answers | Where it lives |
|------|--------------------|----------------|
| **Search filter** | *Which* language's names/text do we search? | repo + datasource + server SQL |
| **Display language** | *Which* language do we render the title + path in? | `searchResultLabels` (display time) |

The toggles drive **both**: they set the filter, and — when narrowed to one — they
also become the display language so the row always contains/explains the hit.

---

## 2. File‑by‑file changes

### A. Search filter — data layer

**A1. `lib/domain/entities/search/search_query.dart`** — *no change.*
`searchInPali` / `searchInSinhala` already exist (default `true`).

**A2. `lib/data/repositories/text_search_repository_impl.dart`**
- `_searchTitles(...)`: add params `bool searchInPali = true, bool searchInSinhala = true`.
  Gate the two match booleans:
  ```dart
  final paliMatched    = matchesQuery(paliName)    && searchInPali;
  final sinhalaMatched = matchesQuery(sinhalaName) && searchInSinhala;
  ```
  (Still one result per node — the loop is over nodes, dedupe is unchanged.)
- `_searchFullText(...)`: add the same two params, forward them to the datasource.
- Thread `query.searchInPali` / `query.searchInSinhala` from **all** call sites:
  `searchTopResults` (title + fts), `searchByResultType` (title + fts cases),
  `countByResultType` (title count + `countFullTextMatches`).

**A3. `lib/data/datasources/fts_datasource.dart`** (interface)
- Add `bool searchInPali = true, bool searchInSinhala = true` to **both**
  `searchFullText(...)` and `countFullTextMatches(...)`.

**A4. `lib/data/datasources/fts_local_datasource.dart`**
- Add a small private helper (FTS `meta.language` stores `'pali'` / `'sinh'`):
  ```dart
  /// Returns the FTS language code to filter by, or null when both (or neither)
  /// are selected → no narrowing. 'pali' / 'sinh' match the meta.language column.
  String? _ftsLanguageFilter(bool searchInPali, bool searchInSinhala) {
    if (searchInPali && !searchInSinhala) return 'pali';
    if (searchInSinhala && !searchInPali) return 'sinh';
    return null;
  }
  ```
- `_searchInEdition`: when the filter is non‑null, append `AND m.language = ?` to the
  CTE `WHERE` (the CTE already joins `meta m`) and add the code to `args`
  **after** scope args, **before** `limit`/`offset`.
- `countFullTextMatches`: today it only joins `meta` when `scope` is non‑empty.
  Restructure so it joins `meta` when **scope OR language filter** is present, then
  add `AND m.language = ?` when filtering.

**A5. `lib/data/datasources/fts_remote_datasource.dart`** (web client)
- Add the two params to both methods; send them as query params
  (`searchInPali` / `searchInSinhala`, `'true'`/`'false'`) on `/api/fts/search`
  and `/api/fts/count`, mirroring the existing boolean params.

**A6. `server/lib/src/handlers/fts_handler.dart`** (web backend)
- `_search` and `_count`: parse `searchInPali` / `searchInSinhala` (default `true`),
  compute the same `'pali'`/`'sinh'`/`null` filter, and add `AND m.language = ?`.
  `_count` gets the same scope‑OR‑language meta‑join restructure as A4.

### B. Display language — presentation

**B1. New provider — `lib/presentation/providers/search_provider.dart`**
```dart
/// The language the search‑result *title + path* render in.
/// Both toggles on → Content Language (display preference). Narrowed to one →
/// that language, so the row always contains/explains the matched term.
final searchResultDisplayLanguageProvider = Provider<ContentLanguage>((ref) {
  final pali    = ref.watch(searchStateProvider.select((s) => s.searchInPali));
  final sinhala = ref.watch(searchStateProvider.select((s) => s.searchInSinhala));
  if (pali && !sinhala) return ContentLanguage.pali;
  if (sinhala && !pali) return ContentLanguage.sinhala;
  return ref.watch(effectiveContentLanguageProvider);
});
```
(New imports: `content_language_provider.dart`, `content_language.dart`.)

**B2. `lib/presentation/utils/search_result_labels.dart`**
- Swap `effectiveContentLanguageProvider` → `searchResultDisplayLanguageProvider`
  (one line + doc‑comment tweak). Everything downstream (formatter, ancestor path)
  is unchanged and still rebuilds live.

### C. Mandatory guard — at least one language on

**C1. `lib/presentation/providers/search_state.dart` → `setLanguageFilter`**
```dart
void setLanguageFilter({bool? pali, bool? sinhala}) {
  final newPali    = pali    ?? state.searchInPali;
  final newSinhala = sinhala ?? state.searchInSinhala;
  if (!newPali && !newSinhala) return;                 // never both‑off
  if (newPali == state.searchInPali &&
      newSinhala == state.searchInSinhala) return;     // no real change
  state = state.copyWith(searchInPali: newPali, searchInSinhala: newSinhala);
  _refreshSearchIfNeeded();
}
```
- `clearFilters()` already resets both to `true` — keep.

### D. UI — Refine Search dialog

**D1. `lib/presentation/widgets/search/refine_search_dialog.dart`**
- Insert a `_buildLanguageSection(...)` between the header and the SCOPE section:
  - A label row "Search in" (localized, see D2).
  - A Material 3 `SegmentedButton<ContentLanguage>`:
    - segments built from `availableContentLanguagesProvider` (**edition‑driven**),
    - labels: `l10n.paliLanguageLabel` / `l10n.sinhalaLanguageLabel` (existing),
    - `multiSelectionEnabled: true`, `emptySelectionAllowed: false`
      (Flutter itself then blocks deselecting the last one — the guard, in the UI),
    - `selected` derived from `searchInPali`/`searchInSinhala` ∩ available,
    - `onSelectionChanged` → `setLanguageFilter(pali: …, sinhala: …)`.
- `_resetToDefaults()`: also call `setLanguageFilter(pali: true, sinhala: true)`.

**D2. Localization** — `app_en.arb` + `app_si.arb`, then regenerate
(`flutter gen-l10n` runs via `generate: true`):
- Add `searchInLanguageLabel`:
  - en: `"Search in"`
  - si: **proposed** `"සොයන භාෂාව"` ← please confirm/adjust the Sinhala wording.

---

## 3. Behaviour matrix (after the change)

| Toggles | Titles tab | Full‑Text tab | Display language (title + path) |
|---------|-----------|---------------|---------------------------------|
| both on | match either name | search both langs | Content Language |
| පාලි only | match Pali name only | `AND m.language='pali'` | Pali |
| සිංහල only | match Sinhala name only | `AND m.language='sinh'` | Sinhala |
| both off | *(impossible — guarded)* | — | — |

Counts (tab badges) take the identical filter, so badges never desync from rows.

---

## 4. Edge cases / guards checklist

- [ ] At least one language always on — enforced **twice**: `SegmentedButton`
      (`emptySelectionAllowed:false`) and `setLanguageFilter` (early return).
- [ ] Count path filtered identically (repo title count, FTS `countFullTextMatches`,
      server `_count`).
- [ ] Toggle set is **edition‑driven** (`availableContentLanguagesProvider`), not
      hard‑coded — a future single‑language edition shows one locked segment.
- [ ] Not shown on Definitions; Dictionary refine dialog untouched.
- [ ] FTS snippet keeps `result.language` (verbatim) — untouched.
- [ ] Cache key already includes both flags — verified, no change.

---

## 5. Cross‑platform

- **Native** (`FTSDataSourceImpl`): SQL `AND m.language = ?` (A4).
- **Web** (`FTSRemoteDataSourceImpl` → `FtsHandler`): query params + server SQL
  (A5 + A6).

---

## 6. Tests

Per `CLAUDE.md`, **no tests written here.** Adding optional params with defaults
keeps existing tests compiling. Existing suites that *should* later gain coverage
(flag for the test‑writer agent):
- `test/data/datasources/fts_datasource_test.dart`
- `test/data/repositories/text_search_repository_impl_test.dart`
- `test/presentation/providers/search_state_notifier_test.dart`

---

## 7. Decisions (confirmed 2026-05-30)

- **Control style:** Material 3 `SegmentedButton` (multi-select, `emptySelectionAllowed:false`).
- **Sinhala "Search in" header:** `"සොයන භාෂාව"` (en: `"Search in"`).
