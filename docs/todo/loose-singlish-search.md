# Loose Singlish search (strict first, then similar spellings)

## Context

Today Singlish is strict: one typed spelling becomes exactly one Sinhala
spelling (`dhaanaya` → දානය). That's precise for people who know the rules, but
hard to type for complex words. Capitals (`T`/`t`, `Dh`/`dh`), dental vs
retroflex letters and the special codes (`~n`, `KN`) trip people up. Phone
auto-capitalisation also breaks it (`Daanaya` → ඪානය). `daanaya` finds nothing.

Goal: keep strict exactly as it is and add a **second, lower tier** of results
for spellings that *sound like* what was typed. The new tier must be tighter
than tipitaka.lk, which returns too much junk. What comes first is under an A/B
test (2026-10-03): the spelling the text uses most, or, as first decided, the
exact-rule one (see Pending).

Decided with the user (2026-10-01):
- **Scope:** main search (titles, full text, definitions) and highlights. The
  dictionary sheet is parked for a user test (2026-10-03, see Todo). The
  static site gets its own plan later (site.js may not hold Sinhala).
- **Find-in-page stays strict** (decided 2026-10-02). Find-in-page matches
  literally, as in browsers. It still takes strict Singlish, as before.
- **Display:** a "Similar spellings" divider before the loose tier. Top Results
  keeps room for loose results (up to 3 lead groups + 2 loose groups per
  category, 3 loose when the lead finds nothing).
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

**1. Engine**: new `lib/core/utils/loose_singlish_expander.dart`, next to
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
  combinations for multi-word queries, shared evenly between the words.

**2. Oracles (data layer)**
- `FTSDataSource.existingTerms(editionId, candidates, {wholeWords})`:
  - On its first lookup it runs
    `CREATE VIRTUAL TABLE IF NOT EXISTS temp.bjt_vocab USING fts5vocab(main, 'bjt_fts', 'row')`,
    so strict search never depends on it.
  - Query: `SELECT j.value FROM json_each(?) j WHERE EXISTS (SELECT 1 FROM temp.bjt_vocab v WHERE v.term >= j.value AND v.term < j.value || char(1114111))`
    (`term = j.value` when `wholeWords`). The query plan is verified: it uses the
    vocab range index.
- `DictionaryDataSource.existingHeadwords(...)`: the same query shape over
  `dictionary.word` (`idx_word`). The dictionary needs its own oracle because 38%
  of its headwords never begin a corpus word.

**3. Domain + repository**
- `domain/repositories/loose_spelling_repository.dart`:
  `spellingsFor(singlish, {editionIds, isExactMatch})` returns
  `Either<Failure, LooseSpellings>`. The Freezed `LooseSpellings` holds `words`
  (per typed word, checked against the text of the searched editions) and
  `headwords` (one-word queries only, checked against dictionary headwords).
- The impl lives in `data/repositories/`. It runs both walks behind a small LRU
  of pending lookups (the `LRUCache` that `caching_text_search_repository.dart`
  uses), so tab switches and filter changes don't walk again.
- `SearchQuery.looseSpellings` carries the spellings; empty = no loose tier.
  They are part of the cache key in `CachingTextSearchRepository._generateKey`.
- `SearchResult` and `DictionaryEntry` get `@Default(false) bool isLooseMatch`.

**4. Full text (two tiers in one SQL)**
- `packages/wisdom_shared/lib/src/fts/fts_query_builder.dart`: add
  `buildLooseFtsQuery(alternatives, {isExactMatch, isPhraseSearch, isAnywhereInText, proximityDistance})`.
  - One word becomes `(p1* OR p2*)`.
  - AND mode becomes `(a1* OR a2*) (b1* OR b2*)`.
  - Phrase/NEAR modes list every combination: `NEAR(a1* b1*, n) OR …`. FTS5
    can't put OR inside NEAR (verified).
- `FTSDataSourceImpl.searchFullText`:
  - When loose spellings are given, tier 0 is `MATCH strict` and tier 1 is
    `MATCH '(loose) NOT (strict)'`, joined with `UNION ALL` inside the existing
    CTE and ordered `ORDER BY tier, score, id`.
  - The scope and language filters are unchanged. `FTSMatch` gains `isLooseMatch`.
  - Verified on `bjt.db`: `dhamma` gives 327 strict + 36,401 loose rows in ~90 ms
    (native).
- `countFullTextMatches` counts `(strict) OR (loose)`.
- A `looseOnly` flag lets Top Results fetch the loose groups on their own. The
  full tab pages through both tiers in order.

**5. Titles and definitions** (`TextSearchRepositoryImpl`)
- `_searchTitles`:
  - The current matching becomes tier 0.
  - Tier 1 is names where a corpus spelling starts a word, and that didn't
    match strictly. (Substring matching, as tipitaka.lk does, is mostly junk.)
    In exact mode this uses the same word-boundary checks. Each tier keeps the
    existing sort.
- `_searchDefinitions` / `_countDefinitions`:
  - The dictionary SQL uses `(strict range) OR (loose ranges)` with
    `CASE … AS tier`, ordered by tier first, then the existing `dictionaryOrderBy`.
  - `appendDictionaryAnyWordMatch` in `wisdom_shared/.../dictionary_sql_helpers.dart`
    matches several words.
- `searchTopResults`: per category, up to 3 strict + 2 loose groups, or 3
  loose when the strict tier found nothing. The other methods return both
  tiers in order.

**6. Presentation**
- `SearchStateNotifier` (`search_state.dart`): after the debounce and before
  any query, it looks up the spellings once (`spellingsFor`, guarded by the
  same request id) into `SearchState.looseSpellings`. Every `SearchQuery` it
  builds carries them. Only pure Roman input of ≥3 letters gets any
  (`LooseSinglishExpander.appliesTo`).
- `SearchMatchFinder.looseSpellings`: a word matches if it matches the strict
  word or any of its spellings; the phrase/exact logic stays the same.
  `FtsHighlightState` carries them, built once as `SearchState.ftsHighlight`,
  for the result snippets (`HighlightedFtsSearchText`) and for the reader after
  opening a result (`TextEntryWidget._computeSearchRanges`).
- Results lists (`search_results_panel.dart`): a "Similar spellings" divider
  before the first loose item or group (`SimilarSpellingsDivider.aboveFirstLoose`).
  A `GroupedFTSMatch` counts as loose when its primary match is loose.
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
4. Find-in-page: dropped 2026-10-02, it stays strict (see Context).
5. Dictionary sheet: parked 2026-10-03 (see Todo).
6. Update `docs/general/how_search_works.md` (Step 1 + Step 4: the two tiers).

## Verification

- `dart run build_runner build --delete-conflicting-outputs`, then `flutter analyze`.
- `flutter run -d macos`, then try:
  - `daanaya` → දානය results (no strict ones exist).
  - `dhamma` → දම්ම first, then ධම්ම under the divider, with ධම්ම visible in Top Results.
  - `nibbana`, `samadhi`, `rahula`, `satipatthana`, `metta`, `Sathi` (capital).
  - `panna` → පඤ්ඤා among the similar-spelling definitions.
  - Find-in-page with `sathi` → සති only (strict, as before).
  - `ka` (2 letters) → strict only.
  - Sinhala input → unchanged.
- Web: `flutter run -d chrome` and repeat a few. This proves `fts5vocab` and
  `json_each` work under wasm.
- Tests: not written by me (CLAUDE.md). The test agent should cover:
  - the engine against the sample words above,
  - `buildLooseFtsQuery`, the tiered SQL and the repository tiers/reserved room,
  - `SearchMatchFinder` alternatives.
- Existing tests that expect "no results" for Singlish input may now see loose
  ones: `search_flow_integration_test`. Ask before running `flutter test`.

## Out of scope / notes

- The static site: its own plan. Precompute a loose key per name at build time;
  site.js then matches using only English letters.
- An endings (stems) tier: revisit after real use.
- Find-in-page, if Singlish there keeps finding nothing: show similar spellings
  only when the strict spelling finds nothing on the page, with a note saying so.
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
  - Engine: `lib/core/utils/loose_singlish_expander.dart`.
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
  - `isLooseMatch` on `SearchResult`, `DictionaryEntry` and `FTSMatch`.
  - wisdom_shared:
    - `buildLooseFtsQuery` (reuses `buildFtsQuery` per combination) and
      `spellingCombinations` (cap 64, shared evenly between the words).
    - `appendDictionaryAnyWordMatch`, plus `dictionaryTieredOrderBy`, which
      shares its row order with `dictionaryOrderBy`.
  - FTS datasource: one `UNION ALL` CTE with a `tier` column. A `looseOnly`
    flag is used for the Top Results room, and counts use `(strict) OR (loose)`.
    The SQL shape was checked on `bjt.db`.
  - Dictionary datasource: `lookupWord`/`searchDefinitions` now share
    `_selectEntries`; `searchDefinitions` takes `looseSpellings`/`looseOnly`.
    The SQL was checked on `dict.db`.
  - `TextSearchRepositoryImpl`: for a non-Singlish query every datasource call
    is unchanged, so the existing mock stubs still match.
    - Top Results: up to 3 strict + 2 loose per category (3 loose when strict
      finds nothing). Loose FTS groups skip suttas already shown.
    - Definitions get loose spellings only for one-word queries.
- Step 3 done 2026-10-01:
  - `SearchMatchFinder.looseSpellings`: per-word options, used only when they
    line up word for word. With none it behaves exactly as before.
  - Snippets centre on the finder's first match, the start of the text when
    none shows. Before this, a query absent from the text indexed -1 and threw.
  - `GroupedFTSMatch`: strict matches lead a group. `isLooseMatch` is true only
    when no match in the group is strict.
  - Divider: `SimilarSpellingsDivider` + ARB `similarSpellings`, placed before
    the first loose item or group in Top Results and in every tab.
  - Gotcha: `flutter gen-l10n` must run outside the sandbox (the wrapper writes
    an engine stamp into the Flutter cache).
- Step 4 rolled back 2026-10-02: find-in-page is strict again.
  `in_page_search_state.dart` and `in_page_search_provider.dart` match `main`.
  `TextEntryWidget` keeps only the reader's search highlight
  (`FtsHighlightState.looseSpellings`).
- Step 5 (dictionary sheet) rolled back 2026-10-03: parked, see Todo.
  `dictionary_params`, `dictionary_provider` and `dictionary_bottom_sheet`
  match `main`; `lookupWord` lost its loose parameter.
  - Noticed: `dictionarySearchProvider`/`dictionaryCountProvider` have no
    caller in `lib` (only a test). Cleanup candidate; not touched.
- Review fixes done 2026-10-03 (the simple ones; analyze clean, tests not run):
  - One flow: the notifier looks up the spellings once per search, before the
    counts and results; `SearchQuery.looseSpellings` carries them into the
    repository, which no longer knows `LooseSpellingRepository`. One repository
    call (`spellingsFor`) returns the text and headword spellings together.
  - `spellingsFor` checks every edition in `editionIds` (was `'bjt'` only).
    `SearchQuery.editionsToSearch` now holds the "none chosen = BJT" rule that
    `TextSearchRepositoryImpl` repeated three times.
  - One name, `looseSpellings`, at every layer. `singlishTextFor`,
    `LooseSpellings.singleWord` and the `appliesTo` check in the repository are
    gone; `expand` keeps the only check.
  - Highlights: the tiles take one `FtsHighlightState` instead of four fields;
    `HighlightedFtsSearchText` uses one finder for centring and highlighting
    (its own phrase search is gone; in separate-word mode the snippet now
    centres on the first word found, not the closest cluster).
  - The divider rule lives in `SimilarSpellingsDivider.aboveFirstLoose`.
  - `loose_singlish.dart` → `loose_singlish_expander.dart`.
- Ranking, engine changes and the web check done 2026-10-03 (background agent
  in its own worktree; merged here, analyze clean, tests not run):
  - Usage: the rows of the text that use a spelling, summed from the
    `fts5vocab` `doc` column (`FTSDataSource.termUsage`). Not `cnt`: one
    passage repeating a word would outweigh it.
  - `LooseSinglishExpander.rank`: spellings under 10% of the top one are
    dropped. The strict spelling is always kept: first if it has 10% of the
    top usage, otherwise last.
  - `SearchQuery.leadText` (each word's first spelling) is what titles, full
    text and counts list first. Definitions still lead with the strict query.
  - One typed word: below the divider, each spelling gets its own SQL tier, in
    usage order, then BM25. A spelling an earlier one covers is skipped (කර
    covers කර්). Phrases keep one tier for all combinations: a tier each would
    repeat the NEAR matching up to 64 times. Loose titles follow spelling order.
  - Dictionary: a tier per headword spelling, by usage. Inside a tier, a
    headword that is the whole spelling (or its long-ā form) comes first, then
    the headwords most dictionaries list.
  - The switch: `kMostUsedSpellingLeads` in `search_provider.dart`. `false`
    puts the strict spelling first again; the 10% cut and the per-spelling
    order stay on in both modes.
  - Engine: `kh gh jh ph bh` mean only the aspirate. IAST letters are folded in
    the loose engine only, so strict search still finds nothing for `nibbāna`.
  - Web: `fts5vocab`, `json_each`, the temp table and the usage query work in
    Chrome (release build, headless). Every spelling, tier, first result and
    count matched macOS.

## Todo

- **Dictionary sheet (parked 2026-10-03).** The user will run a user test of
  main search first, then revisit. The parked work gave Singlish typed into the
  sheet's search box the loose tier: `DictionaryLookupParams` carried the typed
  text, the lookup and count providers fetched the headword spellings and
  passed them to `lookupWord`/`countDefinitions`, and the sheet showed the
  divider. When it comes back, take the spellings from
  `spellingsFor(...).headwords` and the divider from
  `SimilarSpellingsDivider.aboveFirstLoose`.

## Pending: review findings (2026-10-02)

A read-only review of steps 0–5. All of it was fixed on 2026-10-03 (see
Status) except the decisions below. The import cycle went with the dictionary
sheet.

**Keep the `fts5vocab` table.** It's a read-only view of the index's own word
list, made in `temp`, so nothing is copied or written to `bjt.db`. Measured
2026-10-02 on `bjt.db` (sqlite3, read-only): a prefix probe through it takes
≤0.25 ms. Without it, the only probe is `MATCH 'ධ*' LIMIT 1`, at 16–170 ms
each, and one word needs up to hundreds of probes. It works on web too
(checked 2026-10-03).

### Decisions for the user (2026-10-03)

1. **Keep the most-used-first order?** Try both with `kMostUsedSpellingLeads`.
   With the new order, a demoted strict spelling's results come last: for
   `dhamma`, 41,688 ධම්ම rows above the divider and the 333 දම්ම rows at the
   very end of the full-text tab. Should `false` also bring back BM25 order and
   every spelling (the exact old behaviour)?
2. **Definitions lead with the strict query.** `dhamma` shows 3 දම්ම
   definitions before ධම්ම (the same for `panna`, `nibbana`). Should they
   follow the text's lead?
3. **Start the loose tier at 4 letters?** The agent says keep 3: 4-letter
   half-words cost about the same (web Top Results: `dham` +138 ms, `sang`
   +190, `kara` +84 vs `sat` +158, `kar` +185). Only `dha` is bad (+377 ms on
   a 518 ms strict search), because its spellings are single letters. A
   narrower rule, no loose tier when a spelling is a single letter, would fix
   just that.
4. **Phrases are slow on web:** `evam me sutam` +627 ms on Top Results.
   Dropping a strict spelling that begins no word of the text would cut its
   combinations from 18 to 12. Not done.
5. Snippet and reader highlights match inside words (see Minor). Fixing it
   changes strict highlighting too.

Still ambiguous after the ranking: `dana` (දන leads, දාන second), `samatha`
and `sila` (strict passes the 10% test).

### Ranking results (2026-10-03)

The agent drove the real data layer on macOS (debug build), before (the
review-fix code) and after:

| Query | First full-text result, before → after | Rows per tier, after |
|---|---|---|
| sati | සටි (strict, 4 rows) → සති | 7,513 + 4 |
| dhamma | දම්ම (strict) → ධම්ම | 41,688 + 333 |
| jhana | ජනො → ඣාන | 4,721 |
| khandha | ඛන්ද (strict, 6 rows) → ඛන්ධ | 7,595 + 5 |
| sangha | සාඞ්ගණ… → සඞ්ඝ | 9,581 / 2,443 / 2,196 |
| satipatthana | සතිපට්ඨන → සතිපට්ඨාන | 1,805 |
| metta | මෙට්ට (strict) → මෙත්ත | 2,015 + 35 |
| nibbana | නිබ්බන (strict) → නිබ්බාන | 3,642 + 75 |
| nibbāna | nothing → නිබ්බාන | 3,642 |
| panna | පන්නරස (strict) → පඤ්ඤා | 12,825 / 1,887 / 469 |
| karuna | කරුන (strict, 13 rows) → කරුණා | 10,469 + 3 |
| vedana | වෙදානාය → වෙදනා | 5,973 / 5,111 |
| evam me sutam | only under the divider → එවං මෙ සුතං above it | 534 + 12 |
| dana | ධන → දන (දාන second) ✗ | 15,171 / 6,692 / … |
| samatha | සමත (strict) → same ✗ | 3,953 / 1,856 / 429 |

Loose definitions now lead with පඤ්ඤා (`panna`), කරුණා, ඣාන, වෙදනා,
ඛන්ධ, සඞ්ඝ, බුද්ධ and මෙත්තා.

Web timings in ms (headless Chrome, release build). The spellings lookup runs
once per search, before its queries:

| Query | Spellings lookup | Top Results: strict → with loose | Full tab | Counts |
|---|---|---|---|---|
| sat | 35 | 31 → 189 | 15 → 151 | 24 → 62 |
| kar | 37 | 61 → 246 | 45 → 218 | 27 → 78 |
| dha | 69 | 518 → 895 | 455 → 816 | 192 → 346 |
| dham | 37 | 34 → 172 | 19 → 135 | 24 → 49 |
| dhamma | 47 | 31 → 143 | 16 → 109 | 23 → 47 |
| satipatthana | 38 | 24 → 35 | 3 → 15 | 23 → 26 |
| evam me sutam | 35 | 39 → 666 | 21 → 642 | 41 → 296 |

The integration counts the tests pin didn't move (mahaasathi, waasawa,
aanandha); test 2.4 still expects 40 rows where 44 now show.

### Tester findings

The measurements below were taken before the 2026-10-03 fixes. Tested as a
user would on 2026-10-02, with 80 typed queries: Pali terms,
phone capitals, misspellings and Sinhala words in Singlish. The real engine
ran against the real `bjt.db` word list and `dict.db` headwords. Row counts and
timings come from sqlite3 on `bjt.db` (native).

**Verdict: worth keeping.** For casual typing, strict alone mostly finds
nothing:
- Pali terms typed plainly (sati, metta, buddha, satipatthana…): strict reaches
  the intended word for 9 of 56, loose for 56 of 56.
- Titles: strict finds none for sati, dhamma, sutta, metta, satipatthana or
  khandha. Loose finds them all (satipatthana → 27).
- Phrases (`evam me sutam`, `sabbe sankhara anicca`): strict finds 0 rows; loose
  finds the passage.
- Phone capitals (`Metta`, `Sathi`, `Buddha`, `Daanaya`): strict finds nothing;
  loose finds all of them.
- Finding the spellings takes about 1 ms (native).

**What shows first** (fixed by the ranking):

| First thing the user sees | Queries |
|---|---|
| The intended word (strict was right) | 15 |
| Nothing strict; the answer starts under the divider | 48 |
| The wrong word | 17 |

- `sati` shows 4 rows of සටි first; the ~7.9k rows for සති come after the
  divider.
- `dhamma` shows 376 rows of දම්ම before any ධම්ම.
- With the most-used-first rule, 8 queries still don't get the intended word
  first. Most are genuinely ambiguous (`dana`, `bana`, `samatha`, `sila`).

**Junk at the top of the loose tier** (fixed by the ranking): BM25 favours rare words, and
wrong spellings are rare. In the top 10 loose rows:
- `dana`: all 10 match ධන ("wealth").
- `jhana`: ජන/ජාන/ජඤ outnumber ඣාන.
- `samatha`: most rows come from rare spellings (සමට, සාමත…).

**Dictionary loose tier** (fixed by the ranking), the 2 loose definitions in
Top Results:

| Typed | Shown | Wanted |
|---|---|---|
| panna | පඤ්ඤ, පඤ්ඤත්ත | පඤ්ඤා |
| karuna | කරුඤ්ඤා, කරුණං | කරුණා |
| jhana | ජඤ්ඤ, ජණ්ණු | ඣාන |
| vedana | වෙදනක, වෙදනට්ට | වෙදනා |

The intended headword is always among the loose spellings; only the order is
wrong. In the loose tier, `is_exact` compares against the strict word, so it is
never 0 there.

**Top Results room** (fixed): strict finds nothing for 48 of the 80 queries,
so in most searches the whole answer gets only 2 rows per category.

**Titles: substring vs word start** (word start since 2026-10-03), measured on
`tree.json`:

| Typed | Substring | Word start | What word start loses |
|---|---|---|---|
| jhana | 356 | 52 | mostly junk (සංයොජන, රාජන්තෙපුර…) |
| khandha | 248 | 132 | mostly කණ්ඩ junk |
| sati | 146 | 40 | some real compounds (කායගතාසතිවග්ගො, අනුස්සතිවග්ගො) |
| satipatthana | 27 | 25 | චතුසතිපට්ඨානසුත්තං, the DN 22 commentary |
| dhamma | 379 | 147 | අභිධම්මපිටක, අධම්මවග්ගො |

Word start removes most of the junk but loses some real compounds. DN 22
still matches, but only through its spaced Sinhala name (මහා සතිපට්ඨාන
සූත්‍රය). With the Pali-only filter it would be lost (Pali name
මහාසතිපට්ඨානසුත්තං).

**Combination cap** (shared evenly since 2026-10-03): none of 7 real phrases
hit it (the largest, `ekam samayam bhagava`, has 63 of 64). The risk is real
for longer phrases. Spellings are now ranked by usage, so the rarest are cut
first.

**Speed, native** (web timings are under "Ranking results"). One ranked page
(both tiers, ORDER BY, LIMIT 50),
including ~10 ms of sqlite3 start-up:

| Query | Strict only | Strict + loose |
|---|---|---|
| dhamma | 21 ms | 82 ms |
| sat | 23 ms | 132 ms |
| kar | 116 ms | 180 ms |
| dha (mid-typing) | 391 ms | 826 ms |

Three typed letters expand to one-letter prefixes (`dha` → ද ධ ඩ ඪ), so a
half-typed word is the most expensive case. Option: start the loose tier at 4
letters.

**Measured cuts** (both keep reach at 79 of 80; both done 2026-10-03):
- Typed `kh gh jh ph bh` mean the aspirated letter only. `th`/`dh` stay loose,
  because Singlish writes dental ත/ද with them. Spellings drop from 335 to 303.
  Share of the loose tier that is the intended word: `jhana` 21% → 99%,
  `khandha` 76% → 93%, `sangha` 49% → 68%.
- Drop spellings under 10% of the top spelling's usage: 335 → 122.

**Measured additions:**
- Fold IAST before the loose step (ā ī ū → aa ii uu; ṭ ḍ ṇ ḷ → t d n l;
  ñ ṅ → n; ṃ ṁ → m). Text copied from SuttaCentral (`nibbāna`,
  `satipaṭṭhāna`) found nothing. Folded, 12 of 12 reach the word (done
  2026-10-03).
- Not taken for now: a typed single consonant may also be doubled (`nibana`, `mogallana`,
  `vipasana`, `kasapa`). Reached goes from 86 to 91 of 92 for 14% more
  spellings; candidates per round double, but the number of rounds doesn't
  change. `bikhu` still misses: Pali doubles an aspirate as ක්ඛ, which needs a
  rule of its own.

**Minor**
- Exact mode: `arahant` finds nothing. The typed final consonant becomes
  අරහන්ත් (with a hal); the Pali word is අරහන්ත. Not taken for now.
- Snippet and reader highlights match anywhere inside a word (ධම්ම lights up in
  අධම්මො), while FTS matched only word starts. It's the same for strict today,
  but more spellings make it show more often.

**Existing tests** (run 2026-10-02, before the find-in-page rollback):
- Unit suite: 644 passed. `dictionary_editable_word_test`: 4 passed.
- `search_flow_integration_test`: 31 passed, 1 failed. Test 2.4 (`waasawa`,
  exact) expects 40 full-text rows and gets 44: the extra 4 are වාසවා, the
  long-vowel form. That's an expected change, so update the test.

**Tests for the test agent.** 49 were prototyped and passing in a scratch
session; they're not in the repo.
- Engine, with a fake word list:
  - `appliesTo`: ≥3 letters; no Sinhala, digits or `~` codes.
  - The sound-alike rules: `dh` both ways, capitals ignored, a single vowel
    either length, a doubled vowel long only, ඞ/ං for `n`.
  - Prefix mode keeps the shortest spelling; exact mode keeps whole words only.
  - Empty when honest: an x/z letter, or one unmatched word.
  - One oracle call per letter, and the cap of 16.
- `buildLooseFtsQuery`:
  - Each shape, and the cap bias.
  - All six modes parse on the bundled SQLite with the real Sinhala tokenizer,
    both as `(loose) NOT (strict)` and as `(strict) OR (loose)`.
  - The loose tier never repeats a strict row.
- The `existingTerms` SQL (`fts5vocab` + `json_each`) on the bundled SQLite:
  prefixes and whole words.
- `SearchMatchFinder` alternatives: one word, none (same as before), misaligned
  (ignored), phrase, exact phrase, separate words.
- `LooseSpellingRepositoryImpl`:
  - No database call for non-Singlish input; the text walk asks every edition
    in `editionIds`.
  - Concurrent callers share one walk, including across letter case.
  - Prefix and exact results are cached apart.
  - A failure returns a Left and is retried next time.
  - `headwords`: one-word queries only.
- `spellingCombinations`: the room is shared evenly (2 × 16 → 8 × 8; three
  words → 4 × 4 × 4), in the same order as before.
- Top Results: 3 strict + 2 new loose groups (suttas already shown are
  skipped), or 3 loose when strict finds nothing. Loose titles only where a
  spelling starts a word.
- `SearchStateNotifier`: one spellings lookup per search, before the counts
  and results; a stale lookup is dropped, and a failed one leaves the strict
  results intact.
