# Loose Singlish search (strict first, then similar spellings)

## Context

Today Singlish is strict: one typed spelling becomes exactly one Sinhala
spelling (`dhaanaya` → දානය). That's precise for people who know the rules, but
hard to type for complex words. Capitals (`T`/`t`, `Dh`/`dh`), dental vs
retroflex letters and the special codes (`~n`, `KN`) trip people up. Phone
auto-capitalisation also breaks it (`Daanaya` → ඪානය). `daanaya` finds nothing.

Goal: keep strict exactly as it is and add a **second, lower tier** of results
for spellings that *sound like* what was typed. Exact-rule results always come
first. The new tier must be tighter than tipitaka.lk, which returns too much junk.

Decided with the user (2026-10-01):
- **Scope:** every app surface now: main search (titles, full text,
  definitions), find-in-page, the dictionary sheet and highlights. The static
  site gets its own plan later (site.js may not hold Sinhala).
- **Display:** a "Similar spellings" divider before the loose tier. Top Results
  keeps room for loose results (up to 3 exact-rule groups + 2 loose groups per
  category), so `dhamma` still shows ධම්ම even though the exact rules give
  දම්ම first.
- **Stems:** no endings tier for now. Prefix search already finds endings added
  after the typed word (`dhamma` finds dhammo, dhamme, dhammaṃ).

## How tipitaka.lk does it (and why it's noisy)

`@pnfo/singlish-search` (`tipitaka.lk-web/.../node_modules/@pnfo/singlish-search/singlish.js`)
turns the input into *every* Sinhala spelling it could stand for, then searches
for all of them.
- Capitals and vowel length are ignored, and `n` can mean න ණ ඤ ඞ් ං.
- `t`/`th` stay separate (ට vs ත), so `metta`, `tanha` and `satipatthana` find nothing.
- Title search is a substring regex, so it matches anywhere inside a name. That's
  where most of the junk comes from.
- Input is capped at 10 letters (the number of spellings explodes), and its
  full-text search refuses Roman letters entirely.

## The rules (the sweet spot)

These rules were measured on 2026-10-01 against the 892k distinct words in the
full-text index of `bjt.db`. Every one of 34 common queries found the intended word, with ≤10
spellings per word. If vowel length has to be typed exactly, 10 of the 34 are
missed (nibbana, samadhi, rahula, satipatthana, anapanasati…).

- Capitals are ignored, and loose only applies to pure Roman input with ≥3 letters.
- Sound-alike consonants match each other:

| typed | matches |
|---|---|
| k kh | ක ඛ |
| g gh | ග ඝ |
| c ch | ච ඡ |
| j jh q | ජ ඣ |
| t th | ට ඨ ත ථ |
| d dh | ඩ ඪ ද ධ |
| n | න ණ ඤ (ඞ before k/g) |
| p ph | ප ඵ |
| b bh | බ භ |
| l | ල ළ |
| s sh | ස ශ ෂ |
| v w | ව |
| m y r h f | ම ය ර හ ෆ |
| ng / nd / mb | also ඟ / ඬ ඳ / ඹ |
| gn kn ny | also ඤ (gn: ඥ) |
| n or m before a consonant or at the end | also ං (ng at the end too) |

- **Vowels (asymmetric):** a single `a`/`i`/`u` may be short or long, but a
  doubled one (`aa`/`ii`/`uu`) must be long. So `daanaya` finds දානය and not ධනය,
  while `nibbana` finds නිබ්බාන. `e`/`o` length is free (Pali writes ෙ/ො).
  `ee` → ී/ේ/ෙ, `oo` → ූ/ෝ/ො, `ae` → ැ/ෑ, `ai` → ෛ, `au`/`ou` → ෞ, `ru` → also ෘ.
- Spelling rules: two consonants in a row get a hal (්) between them. A
  consonant at the end of a word stays bare in prefix mode, so ධම covers ධම්…
  and ධමා…. A vowel at the start of a word, or after another vowel, becomes a
  full vowel letter (අ, ආ, …).
- **Pruned by the corpus:** a spelling is kept only if real words start with it.
  The check runs once per typed letter, against SQLite's `fts5vocab` view of the
  existing index. That needs no new data and no new files. Each lookup takes
  microseconds; the 34 samples needed 16–357 lookups each, <1 ms in total.

## Design

The rules and the search walk live in one pure-Dart engine. Each search source
gives the engine its own "does this prefix exist?" check (the "oracle").

**1. Engine**: new `lib/core/utils/loose_singlish.dart`, next to
`singlish_transliterator.dart`.
- `LooseSinglishExpander.expand(String singlish, PrefixOracle oracle, {bool exact})`
  returns `List<List<String>>`: the surviving Sinhala spellings for each typed word.
- `typedef PrefixOracle = Future<Set<String>> Function(Set<String> candidates, {required bool wholeWords});`
- The walk:
  - It reads the input one letter at a time.
  - Each partial spelling is a state: the Sinhala committed so far, any
    not-yet-final consonant, and the position in the input.
  - All candidates for one step go to the oracle in one call.
  - At the end, only the shortest prefixes are kept.
- Safety caps: at most 16 spellings per word, 512 states per step, and 64
  combinations for multi-word queries.

**2. Oracles (data layer)**
- `FTSDataSource.existingTerms(editionId, candidates, {wholeWords})`:
  - When an edition opens, `_initializeEdition` runs
    `CREATE VIRTUAL TABLE IF NOT EXISTS temp.bjt_vocab USING fts5vocab(main, 'bjt_fts', 'row')`.
  - Query: `SELECT j.value FROM json_each(?) j WHERE EXISTS (SELECT 1 FROM temp.bjt_vocab v WHERE v.term >= j.value AND v.term < j.value || char(1114111))`
    (`term = j.value` when `wholeWords`). The query plan is verified: it uses the
    vocab range index.
- `DictionaryDataSource.existingHeadwords(...)`: the same query shape over
  `dictionary.word` (`idx_word`). The dictionary needs its own oracle because 38%
  of its headwords never begin a corpus word.

**3. Domain + repository**
- New `domain/repositories/loose_spelling_repository.dart`:
  - `corpusSpellings(singlish, {isExactMatch})` and
    `dictionarySpellings(singlish, {isExactMatch})`.
  - Both return `Either<Failure, LooseSpellings>`. `LooseSpellings` is a Freezed
    entity holding `List<List<String>> words`.
- The impl lives in `data/repositories/`. It holds the engine plus the two
  oracles, behind a small LRU cache: one debounced query triggers the
  titles/FTS/count/highlight calls, and they share one expansion. Reuse the LRU
  that `caching_text_search_repository.dart` already uses.
- `SearchQuery` gets `@Default('') String singlishText`: the typed Roman text,
  `''` = no loose tier. Also add it to the cache key in
  `CachingTextSearchRepository._generateKey`.
- `SearchResult` and `DictionaryEntry` get `@Default(false) bool isLooseMatch`.
  Regenerate Freezed afterwards.

**4. Full text (two tiers in one SQL)**
- `packages/wisdom_shared/lib/src/fts/fts_query_builder.dart`: add
  `buildLooseFtsQuery(alternatives, {isExactMatch, isPhraseSearch, isAnywhereInText, proximityDistance})`.
  - One word becomes `(p1* OR p2*)`.
  - AND mode becomes `(a1* OR a2*) (b1* OR b2*)`.
  - Phrase/NEAR modes list every combination: `NEAR(a1* b1*, n) OR …`. FTS5
    can't put OR inside NEAR (verified).
- `FTSDataSourceImpl.searchFullText`:
  - When loose alternatives are given, tier 0 is `MATCH strict` and tier 1 is
    `MATCH '(loose) NOT (strict)'`, joined with `UNION ALL` inside the existing
    CTE and ordered `ORDER BY tier, score, id`.
  - The scope and language filters are unchanged. `FTSMatch` gains `isLooseMatch`.
  - Verified on `bjt.db`: `dhamma` gives 327 strict + 36,401 loose rows in ~90 ms
    (native).
- `countFullTextMatches` counts `(strict) OR (loose)`.
- A `tiers` option (strict-only, loose-only, both) lets Top Results fetch
  3 strict groups + 2 loose groups. The full tab pages through both tiers in order.

**5. Titles and definitions** (`TextSearchRepositoryImpl`)
- `_searchTitles`:
  - The current matching becomes tier 0.
  - Tier 1 is names that contain any corpus spelling and didn't match strictly.
    In exact mode this uses the same word-boundary checks. Each tier keeps the
    existing sort.
- `_searchDefinitions` / `_countDefinitions`:
  - The dictionary SQL uses `(strict range) OR (loose ranges)` with
    `CASE … AS tier`, ordered by tier first, then the existing `dictionaryOrderBy`.
  - Extend `appendDictionaryWordMatch` in `wisdom_shared/.../dictionary_sql_helpers.dart`
    to take several words.
- `searchTopResults`: per category, up to 3 strict + 2 loose groups (new
  constant). The other methods return both tiers in order.

**6. Presentation**
- `search_query_utils.dart`: add `singlishTextFor(raw)`. It returns the
  sanitized raw text when that is pure Roman with ≥3 letters, otherwise `''`.
  It's shared by both notifiers and the dictionary sheet.
- `SearchStateNotifier` (`search_state.dart`):
  - Put `singlishText` into `SearchQuery`.
  - After the debounce, fetch `corpusSpellings` (guarded by the same request id)
    into a new `looseSpellings` state field, for highlights.
- `SearchMatchFinder`: accept per-word alternatives. A word matches if it matches
  the strict word or any alternative; the phrase/exact logic stays the same, run
  over the alternatives. The alternatives are passed in from:
  - `HighlightedFtsSearchText` (snippets),
  - `FtsHighlightState` → `TextEntryWidget._computeSearchRanges` (the reader
    after opening a result),
  - in-page search.
- Results lists (`search_results_panel.dart` and the tile builders): add a
  "Similar spellings" divider before the first loose item or group. A
  `GroupedFTSMatch` counts as loose when its primary match is loose.
- `InPageSearchNotifier`: fetch corpus spellings and match in **reading order**,
  strict and loose together. It's a jump-through list, so tiers don't apply.
  `TextEntryWidget._computeInPageSearchRanges` uses the same alternatives.
- Dictionary sheet:
  - `DictionaryLookupParams` gets `singlishText`.
  - Its provider fetches `dictionarySpellings` and asks the repository for both tiers.
  - Add the same divider.
- ARB `similarSpellings`: EN "Similar spellings". SI proposal: "සමාන අක්ෂර
  වින්‍යාස" (confirm the wording).

## Steps

Branch `feat/loose-singlish-search` (big feature). The uncommitted `site.js` /
`search_dialog.dart` edits are the user's; leave them alone. Work step by step,
with handover notes in the doc.

0. Copy this plan to `docs/todo/loose-singlish-search.md` (CLAUDE.md rule).
1. Engine, the two oracles and `LooseSpellingRepository`. Check that
   `fts5vocab` + `json_each` work on web (Drift wasm); fall back to `VALUES (?),…`
   if `json_each` is missing.
2. Full-text tiers + titles + definitions, plus the entity and cache-key fields.
3. Results UI: the divider, the Top Results reserved room, and highlights
   (snippets + reader).
4. Find-in-page.
5. Dictionary sheet.
6. Update `docs/general/how_search_works.md` (Step 1 + Step 4: the two tiers).

## Verification

- `dart run build_runner build --delete-conflicting-outputs`, then `flutter analyze`.
- `flutter run -d macos`, then try:
  - `daanaya` → දානය results (no strict ones exist).
  - `dhamma` → දම්ම first, then ධම්ම under the divider, with ධම්ම visible in Top Results.
  - `nibbana`, `samadhi`, `rahula`, `satipatthana`, `metta`, `Sathi` (capital).
  - Find-in-page with `sathi`, and the dictionary sheet with `panna`.
  - `ka` (2 letters) → strict only.
  - Sinhala input → unchanged.
- Web: `flutter run -d chrome` and repeat a few. This proves `fts5vocab` and
  `json_each` work under wasm.
- Tests: not written by me (CLAUDE.md). The test agent should cover:
  - the engine against the sample words above,
  - `buildLooseFtsQuery`, the tiered SQL and the repository tiers/reserved room,
  - `SearchMatchFinder` alternatives.
- Existing tests that expect "no results" for Singlish input may now see loose
  ones: `search_flow_integration_test`, `in_page_search_test`,
  `dictionary_editable_word_test`. Ask before running `flutter test`.

## Out of scope / notes

- The static site: its own plan. Precompute a loose key per name at build time;
  site.js then matches using only English letters.
- An endings (stems) tier: revisit after real use.
- Loose matching for Sinhala-script input (න/ණ, ල/ළ typing slips): possible
  later with the same engine.
- Side finding (measured 2026-10-01): 16,724 DPD headwords in `dict.db` contain ZWJ, and only 1,031 of
  them also exist without it. Typed and tapped lookups strip ZWJ, so ~15.7k
  headwords can't be reached today. That needs a separate fix: strip ZWJ in
  `tools/dict-populate.js` and rebuild.
- The strict transliterator doesn't map a lone `c` (`paticca` → පටිccඅ). The
  loose tier covers it; strict stays as it is.

## Status / handover

- Step 0 done 2026-10-01: branch `feat/loose-singlish-search`, this doc.
- Step 1 done 2026-10-01:
  - Engine: `lib/core/utils/loose_singlish.dart`.
  - Oracles: `FTSDataSource.existingTerms` (a temp `{edition}_vocab` fts5vocab
    table, created on its first call so strict search never depends on it;
    cleared on `close`) and
    `DictionaryDataSource.existingHeadwords` (uses `idx_word`, query plan checked).
  - `LooseSpellings` entity, and `LooseSpellingRepository` + impl. The impl's
    LRU holds pending futures, so concurrent callers share one walk;
    `LRUCache.remove` was added for that.
  - `looseSpellingRepositoryProvider` lives in `search_provider.dart`.
  - The Dart engine, run against the real word list, finds all 34 sample targets.
    Each word needs about one oracle round per typed letter. The web
    `sqlite3.wasm` contains `fts5vocab` + `json_each`, but they haven't been run
    in Chrome yet.
  - Gotcha: run `build_runner` with the SDK binary
    (`flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics`). The `dart`
    wrapper on the PATH writes into the Flutter cache, and the sandbox blocks that.
- Step 2 done 2026-10-01 (data layer only):
  - `SearchQuery.singlishText`, plus `isLooseMatch` on `SearchResult`,
    `DictionaryEntry` and `FTSMatch`.
  - wisdom_shared:
    - `buildLooseFtsQuery` (reuses `buildFtsQuery` per combination) and
      `spellingCombinations` (cap 64).
    - `appendDictionaryAnyWordMatch`, plus `dictionaryTieredOrderBy`, which
      shares its row order with `dictionaryOrderBy`.
  - FTS datasource: one `UNION ALL` CTE with a `tier` column. A `looseOnly`
    flag is used for the Top Results room, and counts use `(strict) OR (loose)`.
    The SQL shape was checked on `bjt.db`.
  - Dictionary datasource: `lookupWord`/`searchDefinitions` now share
    `_selectEntries`, with `looseWords`/`looseOnly`. The SQL was checked on `dict.db`.
  - `TextSearchRepositoryImpl` gains an optional `looseSpellingRepository`.
    Without it, or for a non-Singlish query, every datasource call is
    unchanged, so the existing mock stubs still match.
    - Top Results: up to 3 strict + 2 loose per category. Loose FTS groups
      skip suttas already shown.
    - Definitions get loose spellings only for one-word queries.
  - `singlishText` is in the search cache key.
  - Not yet: nothing sets `singlishText` (step 3 does).
- Step 3 done 2026-10-01:
  - `singlishTextFor(raw)` lives in `search_query_utils.dart`. It feeds
    `SearchQuery.singlishText` (in `_buildSearchQuery`) and
    `SearchState.looseSpellings`. The notifier loads the spellings after the
    debounce, unawaited, sharing the repository's cached lookup.
  - `SearchMatchFinder.looseAlternatives`: per-word options, used only when they
    line up word for word. With no alternatives it behaves exactly as before.
  - Snippets: a loose result centres on its first spelling match. Before this,
    a query absent from the text would have indexed -1 and thrown.
  - `GroupedFTSMatch`: strict matches lead a group. `isLooseMatch` is true only
    when no match in the group is strict.
  - Divider: `SimilarSpellingsDivider` + ARB `similarSpellings`, placed before
    the first loose item or group in Top Results and in every tab.
  - The reader highlight goes through `FtsHighlightState.looseAlternatives`.
  - Gotcha: `flutter gen-l10n` must run outside the sandbox (the wrapper writes
    an engine stamp into the Flutter cache).
- Step 4 done 2026-10-01 (find-in-page):
  - `InPageSearchState.looseAlternatives`. The notifier fetches them after the
    debounce and skips the result if the user kept typing.
  - Matches are found in reading order, strict and loose together.
  - `TextEntryWidget` reads the active tab's alternatives the way it already
    reads `activeFtsHighlightProvider`, so no new widget parameters were needed.
- Step 5 done 2026-10-01 (dictionary sheet):
  - `DictionaryLookupParams.singlishText`. The lookup and count providers
    fetch `dictionarySpellings` themselves, so the exact-match toggle is
    respected. This adds a two-way import between `dictionary_provider` and
    `search_provider`; `navigator_sync_provider` and `tab_provider` already do
    the same.
  - The "one word only" rule lives in `dictionarySpellings`, and
    `LooseSpellings.singleWord` is shared by both callers.
  - The divider takes `horizontalPadding: 0` in the sheet.
  - Noticed: `dictionarySearchProvider`/`dictionaryCountProvider` have no
    caller in `lib` (only a test). Cleanup candidate; not touched.
