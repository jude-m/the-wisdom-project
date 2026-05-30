# Discussion: Search-result titles & Content Language

**Status:** ✅ Decided 2026-05-30 — see §6. (Design locked; not yet implemented.)
**Scope:** How search-result **titles** and **navigation paths** pick a language.
**Related:** `docs/todo/app_language_and_content_language_plan.md` (the 3-axis model).

---

## 0. TL;DR of the confusion

There are **two kinds of search result**, and "title" means a *different thing* in each:

| Tab | What you searched | What the **title** is | Where the **match** is shown |
|-----|-------------------|-----------------------|------------------------------|
| **Titles** | a sutta/section **name** | **the match itself** (the name that matched) | the title (no snippet) |
| **Full Text** | words **inside** the text | just a **label** for the sutta | the highlighted **snippet** below |

That single fact explains most of the confusion: in the **Titles** tab the title *is* the thing you matched, so "what language should it be in?" is a real question. In the **Full Text** tab the title is only a label, so it should obviously follow your reading preference (Content Language) — the actual match is the snippet.

---

## 1. The three buckets of text in the app

Every string we show falls into exactly one of these. Keeping them straight is the whole game:

| Bucket | Driven by | Rendered via | Examples |
|--------|-----------|--------------|----------|
| **UI chrome** | **App Language** (en / si) | `AppLocalizations.of(context)` | "Settings", "Refine", tab labels like *Top Results* |
| **Data label** | **Content Language** (pali / si) | `formatContentLabel(node.getDisplayName(lang), lang)` | tree nodes, breadcrumbs, reader tab labels, **search title + path** |
| **Verbatim content** | *neither* — it is source text | shown as stored; Pali gets conjunct ligatures | reading panes, the **matched-text snippet** |

Litmus test for any string: *"Which switch changes it — App Language or Content Language?"* If neither, it is verbatim content.

---

## 2. What a `SearchResult` carries

`lib/domain/entities/search/search_result.dart`:

- `title` — a sutta/section name (string, already in one language)
- `subtitle` — the navigation path, e.g. `"Suttapiṭaka > Aṅguttaranikāya > ..."`
- `matchedText` — the actual text that matched (only meaningful for full-text)
- `language` — the language that **matched** (`'pali'` / `'sinhala'`)
- `nodeKey` — the tree node this result belongs to ← **the important one**

The first three are *pre-baked strings*. `nodeKey` is the key that lets us re-derive everything from the tree (where each node has **both** `paliName` and `sinhalaName`).

---

## 3. How it worked **before** (the bug in the screenshot)

Repository: `lib/data/repositories/text_search_repository_impl.dart`

**Title results (`_searchTitles`)** — matches the query against *both* names, then:
```dart
// Prefer Sinhala if it matched, otherwise use Pali
final matchedName = sinhalaMatched ? node.sinhalaName : node.paliName;
final matchedLanguage = sinhalaMatched ? 'sinhala' : 'pali';
// TODO (in code): "lets get the navigator display language as the preference later."
```
So the title was **whatever matched, with Sinhala preferred** — not a user setting.

**Full-text results (`_searchFullText`)** — title chosen from the FTS match language:
```dart
final title = match.language == 'sinh' ? node.sinhalaName : node.paliName;
```

**The path (`_buildNavigationPath`)** — **always Pali**:
```dart
parts.insert(0, parent.paliName.isNotEmpty ? parent.paliName : parent.sinhalaName);
```

**Result:** title in one language (often Sinhala), path hard-coded to Pali →
the mismatch you saw: **කිංදිට්ඨික සූත්‍රය** (Sinhala-style title) over **සුත්තපිටක > අඞ්ගුත්තරනිකායො > …** (Pali path). Neither obeyed Content Language.

---

## 4. What is in the code **right now** (current behaviour)

> ⚠️ This is implemented and analyzer-clean, but **left open for this discussion** — easy to adjust or revert.

Both the title and the path are now re-derived **at display time** from `nodeKey`, using the **same pipeline as the breadcrumbs and tree**:

`lib/presentation/utils/search_result_labels.dart`
```dart
final language = ref.watch(effectiveContentLanguageProvider);
final node = ref.watch(nodeByKeyProvider(result.nodeKey));
final title = formatContentLabel(node.getDisplayName(language), language);
// path = ancestors of the node, each via getDisplayName(language) + formatContentLabel
```

Consequences:
- **Title + path are always consistent** and both follow Content Language.
- They **update live** when you flip the setting (the tiles `ref.watch` it).
- The repo's `result.language` tag is now used **only** for the verbatim snippet (`HighlightedFtsSearchText`) — correct, since the snippet is real matched text.
- **Dictionary** results are untouched (their title is a Pali headword; subtitle is a dictionary name — not Content-Language data).
- Opening a result into a tab now seeds the tab's `paliName`/`sinhalaName` from the **node** (not the single `result.title`), so the tab label can switch too.

---

## 5. The open question (this is what needs deciding)

It only really concerns the **Titles** tab (full-text is settled — title = label = Content Language).

> When your **Content Language** differs from the language that **matched your query**, what should a *title result* show?

**Example:** Content Language = Sinhala. You type a Pali word that only appears in the **Pali** name. The sutta's Sinhala name looks unrelated to what you typed.

| Option | Title shows | Pro | Con |
|--------|-------------|-----|-----|
| **A. Content Language always** *(current)* | the node's name in your reading language | consistent with path/tree/tabs; one rule | the title may **not contain your query term**, and there's no snippet to explain the hit |
| **B. Matched language** *(old)* | the name that matched | you always **see why it matched** | inconsistent with path/tree; title & path can disagree; ignores reading preference |
| **C. Content Language + matched hint** | CL name, plus a small muted "matched: «…»" when they differ | best of both; honest | extra UI; slightly busier tile |
| **D. Smart fallback** | CL name **unless** it doesn't contain the query and the other language's does → then the matched name | title usually explains the match while honouring preference | a "magic" rule; harder to predict/test |

**Recommendation to discuss:** **A for full-text (already correct), and A or C for titles.** Option C keeps the clean Content-Language rule but removes the "why did this match?" surprise. Option B re-introduces the title/path mismatch and is the thing we just fixed, so it's the least attractive.

---

## 6. Decision (✅ 2026-05-30)

Add **two language toggles (පාළි / සිංහල)** that gate *which names / text get searched* —
mirroring tipitaka.lk's `columns` filter (`src/components/FilterTree.vue`, `FTS.vue`).
They are a **search scope**, distinct from **Content Language** (a *display* preference).
The model is already there (`SearchState`/`SearchQuery.searchInPali` / `searchInSinhala`,
`setLanguageFilter`, and the caching repo's cache key) — it is just **not yet wired** into
`text_search_repository_impl.dart` or surfaced as UI.

### Titles tab
- Gate each name field by its toggle:
  `paliMatched = matchesQuery(paliName) && searchInPali` (and likewise for Sinhala).
- Still **one result per node** — the loop is over nodes, not name fields, so a sutta that
  matches in both names is already deduped to a single row.
- **Display language** = a new *effective search-result display language*:
  - **both toggles on → Content Language** (unchanged display-time resolver), and
  - **narrowed to one → that language** drives the **title *and* the path**.
  - `searchResultLabels` renders title + path through this one language so they always
    agree and the row always contains / explains the hit.
    *(Chosen: "follow the searched language" — supersedes the A/B/C/D fork below. It is
    Option A when both are on, and a user-directed Option B when narrowed, which removes
    B's old objection. No "matched hint" UI is needed.)*

### Full-text tab
- **both on → search both** (unchanged).
- **one on → add `AND m.language = ?`** in `searchFullText` **and** `countFullTextMatches`
  (precedent: the existing scope clause + the `getSuggestions` language filter in
  `fts_local_datasource.dart`).
- The snippet is verbatim, so it already matches the searched language.

### Guards (don't skip these)
- Toggle is **mandatory** — at least one always on; never both-off.
- The **count path** must take the same filter, or the tab badges desync from the rows.
- The toggle set should be **edition-driven** (`Edition.availableLanguages`), not hard-coded,
  so an edition that lacks a language doesn't show a dead button.
- **Not** shown on the Definitions tab; shown on All / Top Results (which lists Titles + FTS).
- Dictionary search is untouched.

### Decision log
- [x] Full-text title = Content Language label, resolved at display time — **yes**.
- [x] Titles tab policy → **Content Language when both on; follow the searched language when
  narrowed to one** (user-directed A/B hybrid).
- [x] No "matched hint" (Option C) — the narrowed-language title already explains the match.
- [x] Keep the **display-time** approach for *display* language; only the *search filter*
  goes into the repo / datasource. Live updates, reuses the breadcrumb pipeline.

---

## 7. Files involved

- `lib/data/repositories/text_search_repository_impl.dart` — `_searchTitles`, `_searchFullText`, `_buildNavigationPath` (where the old language choice lives)
- `lib/presentation/utils/search_result_labels.dart` — the new display-time resolver
- `lib/presentation/widgets/search/search_results_panel.dart` — `_SearchResultTile`
- `lib/presentation/widgets/search/grouped_fts_tile.dart` — `_buildPrimaryTile`
- `lib/presentation/providers/tab_provider.dart` — `openTabFromSearchResultProvider` (tab seeding)
