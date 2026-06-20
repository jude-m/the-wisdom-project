# FTS Snippet Text Loading — Per-Hit JSON Reload Fix

> **Status:** ✅ Done — Track A Phase 1 + Phase 2 shipped 2026-06-19. Phase 3
> (isolate) deferred by design (measure first). Track B (server) was already
> satisfied before this work — see below.
> **Source:** `perf-top10-killers.md` item **#2**, expanded into a full plan.
> **Date:** 2026-06-18 (plan) · 2026-06-19 (implemented)
> **Related:**
> - `docs/todo/perf-top10-killers.md` — parent backlog (this is its #2).
> - `docs/todo/perf-search_label_and_tree_lookup_followups.md` — item 1 (repo
>   computes labels the UI discards) and item 2 (`_buildNodeMap` per search) touch
>   the same search path; land them together if convenient.
> - Project direction: per-page **content table in SQLite** as the single runtime
>   source of truth (see "Strategic endgame" below) — that is the eventual root fix.

---

## Implementation status (2026-06-19)

| Item | Status | Notes |
|---|---|---|
| **Track A · Phase 1** — group by file, parse once | ✅ Shipped | `_loadTextForMatch` split into cached `_loadFileJson` + pure `_extractEntryText`; distinct files loaded once before the result loop in `_searchFullText`. |
| **Track A · Phase 2** — cross-search LRU cache | ✅ Shipped | `_fileJsonCache = LRUCache(20)` field on `TextSearchRepositoryImpl`, reusing existing `lib/data/cache/lru_cache.dart`. Landed together with Phase 1. |
| **Track A · Phase 3** — decode off the UI isolate | ⏸️ Deferred (by design) | Phase 1 already collapses N decodes → distinct-file count. Revisit only if a cold first search still janks in `--profile`. Shares the isolate helper with top-10 #3. |
| **Track B · server** — group/cache server-side | ✅ Already satisfied | `server/.../fts_handler.dart` already memoises parsed files in a process-wide `_jsonCache` (`_loadJsonFile`) — *better* than "once per request": once per process. No change made. |
| **Track B · #4** — windowed snippet payload | ❌ Out of scope | Interacts with the B2 highlighter; tracked as a separate measured change. |

**Files touched:** `lib/data/repositories/text_search_repository_impl.dart` only.
`flutter analyze` clean. Tests not written (project convention — separate
test-writer pass; coverage targets listed under [Testing](#testing)).

**Parity preserved:** identical `matchedText ?? <load> ?? ''` fallback chain,
pali-first language fallback, and "missing file → empty snippet for that hit
only" degradation. Same `SearchResult` output for any query.

---

## TL;DR

When full-text search returns matches, the repository fetches the preview snippet
for each hit by **reading and `json.decode`-ing the entire sutta JSON file, once
per hit**. Fifty hits from the same file = fifty full reads + fifty full decodes,
**sequentially, on the UI isolate**. This is the dominant delay between "user hits
Enter" and "results appear."

**The fix:** load + parse each distinct file **once per search**, extract every
needed entry from the in-memory map, and (across searches) keep parsed files in an
`LRUCache`. Optionally move the decode off the UI isolate. On the web/remote path
the *server* does the same work — apply the identical group-once discipline there
so the search endpoint stays fast and its response payload stays small.

---

## The problem (current behavior)

**Where:** `lib/data/repositories/text_search_repository_impl.dart`

`_searchFullText` (line 472) loops over the FTS matches (up to 50) and, for each
one, awaits the snippet load:

```dart
// _searchFullText, ~line 500
for (final match in ftsMatches) {
  ...
  final matchedText = match.matchedText ??              // web: server pre-fills this
      await _loadTextForMatch(                           // native: reload per hit
        match.filename,
        match.eind,
        match.language,
      ) ??
      '';
  ...
}
```

`_loadTextForMatch` (line 648) reads and decodes the **whole file** every call,
then plucks a single entry out of it:

```dart
// _loadTextForMatch, ~line 658
final jsonString =
    await rootBundle.loadString('assets/text/$filename.json'); // full file read
final jsonData = json.decode(jsonString) as Map<String, dynamic>; // full file decode
// ...then index into jsonData['pages'][pageIndex][lang]['entries'][entryIndex]['text']
```

So three things compound:

1. **Re-reads** — `dn-1.json` (200–400 KB) is loaded from the asset bundle once
   *per match*, even when 30 matches all live in `dn-1.json`.
2. **Re-decodes** — the full file is `json.decode`d each time (the expensive part),
   only to keep one entry's `text` and throw the rest away.
3. **Serial + on the UI isolate** — the `for` loop `await`s each call in turn, all
   on the main isolate, so the UI thread is blocked for the whole batch.

Call sites that hit this path: `searchTopResults` (line 103) and
`searchByResultType` → `SearchResultType.fullText` (line 190).

---

## Why this is the #1 results-pane fix

### Client (native: mobile + desktop)

This is the largest single chunk of work between Enter and results. With 50 hits
concentrated in a few large files, the app does dozens of full-file decodes back to
back on the UI isolate — visible as a freeze before results paint. Every other
results-pane item in the backlog (#5 scoped watches, #7 conjunct caching, #10 lazy
lists, B2 highlighter caching) only speeds up painting results that have *already
arrived*; this one decides **when they arrive**.

### Remote (web — calling a server)

The web build does **not** bundle the JSON files, so `_loadTextForMatch` is never
called client-side; instead the **server** "pre-loads the text from JSON files and
attaches it as `match.matchedText`" before responding (see the comment at
`text_search_repository_impl.dart:510-518`). Two consequences:

- **Already good:** the snippet text travels *inline* in the search response. The
  client never fetches sutta files over the network to build previews — so the
  worst-case "client downloads 50 × 200–400 KB per query" is already avoided by
  design. Keep that contract.
- **Still at risk:** if the server builds `matchedText` with the same naive
  per-hit reload, it re-reads/re-parses the same file once per hit **on every
  request**. That is wasted server CPU that collapses under concurrency (many users
  searching at once) and slows the endpoint's response time. The fix below is
  therefore not just a client nicety — it is the shape the server path must also
  take.

So #2 is the one results-pane item whose fix matters identically on the client
*and* on the wire: **"parse each source file once; return only the snippet."**

---

## The fix — Track A: native client (Flutter)

This track changes only the native path (`match.matchedText == null`). Land it in
phases; Phase 1 is the big win and is self-contained.

### Phase 1 — Group by file, parse once per search ✅ Shipped 2026-06-19

Split the current "read + parse + extract" method into a loader and a pure
extractor, then load each **distinct** filename once before the loop.

```dart
// NEW: load + decode a file's JSON once (cache added in Phase 2).
Future<Map<String, dynamic>?> _loadFileJson(String filename) async {
  try {
    final jsonString =
        await rootBundle.loadString('assets/text/$filename.json');
    return json.decode(jsonString) as Map<String, dynamic>;
  } catch (e, st) {
    developer.log('Failed to load $filename', error: e, stackTrace: st,
        name: 'TextSearchRepository');
    return null;
  }
}

// NEW: pure extraction from an already-parsed file — no I/O, no decode.
String? _extractEntryText(
  Map<String, dynamic> jsonData,
  int pageIndex,
  int entryIndex,
  String language,
) {
  final pages = jsonData['pages'] as List<dynamic>?;
  if (pages == null || pageIndex >= pages.length) return null;
  final page = pages[pageIndex] as Map<String, dynamic>;
  // Same language fallback order as today: matched language first, then the other.
  final langOrder = language == 'pali' ? ['pali', 'sinh'] : ['sinh', 'pali'];
  for (final lang in langOrder) {
    final langData = page[lang] as Map<String, dynamic>?;
    final entries = langData?['entries'] as List<dynamic>?;
    if (entries != null && entryIndex < entries.length) {
      final entry = entries[entryIndex] as Map<String, dynamic>;
      final text = entry['text'] as String?;
      if (text != null && text.isNotEmpty) return text;
    }
  }
  return null;
}
```

Then in `_searchFullText`, load distinct files first, extract in the loop:

```dart
// After getting ftsMatches, before building results:
// Distinct files we actually need to read on native (skip ones the server
// already filled — i.e. matchedText != null).
final filesToLoad = ftsMatches
    .where((m) => m.matchedText == null)
    .map((m) => m.filename)
    .toSet();

// Parse each distinct file exactly once.
final parsedFiles = <String, Map<String, dynamic>>{};
for (final filename in filesToLoad) {
  final json = await _loadFileJson(filename);
  if (json != null) parsedFiles[filename] = json;
}

// ...in the loop, replace the per-hit reload with a cheap extraction:
final matchedText = match.matchedText ??
    (parsedFiles[match.filename] != null
        ? _extractEntryText(parsedFiles[match.filename]!, pageIndex,
            entryIndex, match.language)
        : null) ??
    '';
```

Result: **N decodes → number-of-distinct-files decodes** (often 1–5 instead of 50).
That alone removes most of the stall. `_loadTextForMatch` can be deleted once nothing
else references it.

> Minor cleanup it enables: `_searchFullText` already splits `eind` into
> `pageIndex`/`entryIndex` (lines 502-504); `_loadTextForMatch` split it again.
> `_extractEntryText` takes the ints directly, so the double-split goes away.

### Phase 2 — Cross-search LRU cache of parsed files ✅ Shipped 2026-06-19

Searches repeat (refine query, switch tabs, paginate). Cache parsed files so a
second search touching the same file skips the decode entirely. Reuse the existing
`LRUCache` (`lib/data/cache/lru_cache.dart`) — it is TTL-free, which is correct here
because the corpus is immutable.

```dart
// Field on TextSearchRepositoryImpl. Cap chosen to bound memory; each entry is a
// parsed sutta map (~200-400 KB source). ~16-24 files is a safe starting point;
// tune with logStats(). Pairs with the same eviction discipline as #9.
final LRUCache<String, Map<String, dynamic>> _fileJsonCache = LRUCache(20);

Future<Map<String, dynamic>?> _loadFileJson(String filename) async {
  final cached = _fileJsonCache.get(filename);
  if (cached != null) return cached;
  // ...read + decode as above...
  if (decoded != null) _fileJsonCache.put(filename, decoded);
  return decoded;
}
```

> **Note on overlap:** `BJTDocumentLocalDataSourceImpl` parses these same files into
> `BJTDocument` entities (top-10 #3/#9). Routing snippet loads through that repo
> would share one cache — but it does the heavier entity transform we don't need for
> a snippet. A targeted raw-JSON LRU here is lighter and avoids coupling; revisit
> unification only if the duplicate parse paths become a problem.

### Phase 3 — (optional) Move the decode off the UI isolate ⏸️ Deferred

`json.decode` of a 200–400 KB file is CPU-bound. After Phase 1 the count is small,
so measure before adding complexity. If a cold first search still janks:

- `rootBundle.loadString` must stay on the root isolate (platform channel), so load
  the string here, then `await compute(json.decode, jsonString)` for the parse.
- **Better variant:** to avoid copying a huge map back across the isolate boundary,
  decode **and** extract all of that file's needed entries *inside* the isolate, and
  return just a small `Map<eind, snippet>`. Then only small strings cross back, and
  the cache stores snippets rather than giant maps.

Recommended order: ship Phase 1 (+2), measure, then decide on Phase 3. This mirrors
top-10 **#3** (UI-isolate JSON parsing) — solve them with the same isolate helper if
both are tackled.

### Behavior that must be preserved

- The `match.matchedText ?? <load> ?? ''` fallback chain (web pre-fill → native load
  → empty string).
- The language fallback order (matched language first, then the other).
- Error handling: a failed/missing file must not break the whole result set — it
  yields an empty snippet for that hit, exactly as today (just logged once per file
  now instead of once per hit).
- `SearchResult.language` still drives snippet highlighting downstream — unchanged.

---

## The fix — Track B: remote / web server ✅ Already satisfied

> **Found during implementation (2026-06-19):** the server *already* does this.
> `FtsHandler._loadJsonFile` (`server/lib/src/handlers/fts_handler.dart`) memoises
> every parsed file in a process-wide `_jsonCache`, so each file is decoded **once
> per process** — strictly better than the plan's "once per request." Points 1–3
> below were therefore already in place; no server change was made. Point 4
> (windowed payload) remains out of scope. The text below is kept as the rationale.

The server is what populates `match.matchedText` for the web build. Apply the same
discipline there:

1. **Group hits by file, parse once per request** — identical reasoning to Phase 1,
   but the payoff is per-request server CPU and endpoint latency under load.
2. **Cache parsed files server-side** — a process-level LRU (or just hold the files
   in memory; the corpus is immutable). Even simpler on a server: read snippets from
   the content DB (see endgame) instead of JSON.
3. **Keep the snippet inline in the response** — preserve today's contract so the
   client never round-trips for preview text.
4. **(Optional) bound payload with a windowed snippet.** Today `matchedText` is the
   *entire* matched entry's text. For long entries the response carries more bytes
   than the preview needs. Returning a window (±N chars around the match) shrinks the
   payload — but it interacts with the highlighter (B2: `HighlightedFtsSearchText`
   expects to find the query *within* the returned text), so treat windowing as a
   separate, measured change, not part of the core fix.

---

## Strategic endgame: content in SQLite makes this a row lookup

The planned move of per-page text from JSON into a **content table in SQLite** (the
single runtime source of truth for offline mobile and the web API) is the real root
fix for this item. Once text lives in the DB, snippet extraction stops being
"parse a file" and becomes one indexed lookup:

```sql
SELECT text FROM content
WHERE file = ? AND page = ? AND entry = ? AND lang = ?;
```

No file read, no full-document decode, no in-memory map — on **both** native (local
SQLite) and the server (same query). When that lands, Track A/B collapse into a
batched `WHERE (file,page,entry) IN (...)` query and this document closes out.

Until then, the JSON grouping + LRU here is the low-risk interim win — and it is the
exact behavior the DB version replaces, so nothing done now is wasted.

> **Teardown checklist moved to the endgame doc.** The step-by-step list of what to
> delete from here when the content DB lands now lives with the migration that
> triggers it — see **Snippet-path teardown** in
> `docs/todo/reduce_mobile_bundle_size.md`. (This doc archives to *done* once the
> interim fix ships, so the checklist shouldn't ride along with it.)

---

## Effort & impact

| | |
|---|---|
| **Effort** | Phase 1: Low–Medium. Phase 2: Low. Phase 3: Medium (isolate plumbing). |
| **Impact to flows** | None — purely internal to the FTS repo; same `SearchResult` output. |
| **Expected gain** | 5–20× faster "Enter → results" when hits cluster in few files; UI thread stops freezing while results load. Server: lower per-request CPU + faster endpoint under concurrency. |
| **Risk** | Low. No public API change. Main thing to verify: the snippet/language fallback and error behavior match today's output. |

---

## How to measure

Capture a **baseline before** the change and the **same numbers after** — same query,
same device/build — so the win is a number, not a vibe. Use a query that hits many
entries in one or two large files (e.g. a common word concentrated in `dn-1.json`) so
the per-hit reload is at its worst.

### Client (native)

1. **Wall-clock for "Enter → results" (the headline number).**
   Wrap the snippet-loading region of `_searchFullText` in a `Stopwatch` and log it.
   This is the figure that should drop 5–20× when hits cluster in few files.
   ```dart
   final sw = Stopwatch()..start();
   // ...load distinct files + build results...
   developer.log('snippet load: ${sw.elapsedMilliseconds}ms for '
       '${ftsMatches.length} hits / ${filesToLoad.length} files',
       name: 'TextSearchRepository.perf');
   ```

2. **Decode count (proves the mechanism, not just the timing).**
   Add a temporary counter incremented inside `_loadFileJson` right before
   `json.decode`. Run the chosen query and confirm it equals **distinct files**, not
   **hit count** (e.g. `1` instead of `50`). This is the most direct evidence the fix
   works and the cleanest thing to assert in a test (count `rootBundle` reads via a
   fake). Remove the counter after verifying — it is instrumentation, not shipping code.

3. **Cache effectiveness (Phase 2).**
   `LRUCache` already tracks hits/misses. Call `_fileJsonCache.logStats('fts-files')`
   after a few searches and confirm the hit rate climbs as queries are refined/repeated.

4. **UI-thread / frame impact (DevTools).**
   In `flutter run --profile`, open DevTools → **Performance**, record while running the
   search. Before: a long contiguous block of `json.decode` work on the UI (platform)
   thread and dropped frames. After: that block shrinks to the distinct-file count; with
   Phase 3 it moves off the UI thread entirely (visible on a separate isolate track).
   The **Performance overlay** (`P` in the run console) is a quick sanity check — the
   red UI-thread bar on search should flatten.

> Always measure in `--profile`, never `--debug`: debug builds are unoptimised and
> exaggerate decode cost, so the numbers won't reflect what users get.

### Server (web / remote)

5. **Endpoint latency + decodes-per-request.** Time the search handler end-to-end and
   log decodes per request the same way as (2). Confirm it drops to distinct-files.

6. **Behaviour under concurrency (the reason this matters remotely).** Fire N parallel
   identical searches (e.g. `hey`/`ab`/`wrk`, or a small script) and compare **p95
   latency** and **CPU** before/after. The naive per-hit path degrades sharply as N
   rises; the grouped + cached path should stay roughly flat.

7. **Response payload size.** Record `Content-Length` for the search response before/after
   — Track A/B don't change it, but it's the baseline to judge the optional windowed-snippet
   payload optimisation against.

## Acceptance criteria

- A search whose matches concentrate in one file decodes that file **once**, not
  once per hit (verify by log/instrumentation or a counting fake of `rootBundle`).
- Snippets shown are byte-for-byte what the old per-hit path produced for the same
  query (no regression in preview text or highlighting).
- A repeated/refined search reuses cached parsed files (Phase 2) — observable via
  `LRUCache.logStats`.
- Missing/corrupt file still degrades to an empty snippet for affected hits without
  failing the whole search.

---

## Out of scope (tracked elsewhere)

- `_buildNodeMap` rebuilt per search → `perf-search_label_and_tree_lookup_followups.md`
  item 2.
- Repo computing title/subtitle the UI discards → same doc, item 1.
- `HighlightedFtsSearchText` recomputation → top-10 **B2**.
- General UI-isolate JSON parsing (tree.json, sutta opens) → top-10 **#3** (shares the
  Phase 3 isolate helper).

## Testing

Per project convention, tests are **not** written as part of this plan — a separate
test-writer pass covers it. What to cover when that happens: (a) one file with
multiple hits decodes once; (b) snippet + language-fallback parity with the old path;
(c) cache hit on repeated search; (d) missing-file degradation. Pali test text must
be in Sinhala script (e.g. `එවං මෙ සුතං`).
