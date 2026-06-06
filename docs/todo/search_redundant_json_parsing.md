# Search: Avoid Re-Parsing the Same JSON File Per Match

## Current State

When full-text search results are built, each match needs a preview snippet of
the matched line. The FTS database only returns **metadata** (`filename`, `eind`,
`nodeKey`) — not the text — so the repository opens the JSON file to fetch the
snippet.

In `lib/data/repositories/text_search_repository_impl.dart`, `_searchFullText`
calls `_loadTextForMatch` once **per match**:

```dart
Future<String?> _loadTextForMatch(String filename, String eind, String language) async {
  // ...
  final jsonString =
      await rootBundle.loadString('assets/text/$filename.json'); // reads whole file
  final jsonData = json.decode(jsonString) as Map<String, dynamic>; // parses whole file
  // jump to pages[pageIndex] -> entries[entryIndex]
}
```

Two costs hide here:

1. **`rootBundle.loadString`** reads the whole file. Flutter's `rootBundle` is a
   `CachingAssetBundle`, so the raw *string* is cached after the first read —
   this part is cheap on repeat.
2. **`json.decode`** parses the whole file into a `Map`. This is **not** cached.
   It runs fresh on every call.

## The Problem

Full-text search overfetches (`_groupedSearchOverfetchMultiplier = 7`), so a
single search can produce many matches, and **many of them share the same
`filename`** (multiple matches inside one sutta/document).

Because there's no decoded-JSON cache, the same file gets fully `json.decode`d
once **per match**. Example: 21 overfetched matches, all from the same document
= the entire document is parsed 21 times in one search.

- The string read is cheap after the first (rootBundle cache).
- The **parse** (`json.decode`) is the wasted work — O(file size) repeated N
  times for N matches in the same file.

## Why This Is Common — Nested Sub-Matches

This isn't an edge case; the app is *designed* to surface many matches from one
sutta. `GroupedFTSMatch.fromSearchResults`
(`lib/domain/entities/search/grouped_fts_match.dart`) groups the flat FTS results
by `nodeKey` (sutta/section) into a **primary match** plus **secondary matches**,
which `grouped_fts_tile.dart` renders as a "See X more" expandable list.

Every one of those nested matches needed its snippet loaded via
`_loadTextForMatch` — and they all share the same file. There are actually **two
layers** of file sharing:

1. **Within one group** — all sub-matches in a sutta point at the same
   `contentFileId`, i.e. the same JSON file.
2. **Across groups** — different suttas can live in the *same* content file
   (multiple suttas share one file).

So a single search that shows "3 suttas, 7 matches each" can re-parse the same
one or two files ~20 times.

This is also why the memo must be keyed by **`filename` / `contentFileId`**, not
`nodeKey`: keying by filename collapses *both* layers of redundancy into one
parse per file.

## Proposed Fix

Memoize the **decoded** document map per file, scoped to a single
`_searchFullText` call. Parse each unique file once, reuse for every match in it.

```dart
// Inside _searchFullText, before the loop:
final decodedDocs = <String, Map<String, dynamic>>{};

// _loadTextForMatch (or an inline helper) checks the map first:
final jsonData = decodedDocs[filename] ??= json.decode(
  await rootBundle.loadString('assets/text/$filename.json'),
) as Map<String, dynamic>;
```

Effect: N matches across K unique files → K parses instead of N parses
(K ≤ N, often K ≪ N).

### Notes / decisions to make
- **Scope of the cache**: per-call (a local `Map` passed in) keeps memory bounded
  and avoids stale data — preferred. A longer-lived cache would need an eviction
  policy and isn't needed for the immediate win.
- **Web path is unaffected**: on web, `match.matchedText` is pre-attached by the
  server, so `_loadTextForMatch` isn't called. This fix only helps native.
- **Signature change**: `_loadTextForMatch` would need to accept the shared map
  (or be inlined into `_searchFullText`). Keep it a private helper.

## Impact

| | Before | After |
|---|--------|-------|
| Parses per search | One per match (N) | One per unique file (K) |
| Worst case (all matches in 1 file) | N full parses | 1 full parse |
| Line lookup within a file | O(1) (unchanged) | O(1) (unchanged) |
| Memory | — | + one decoded map per unique file, freed after the call |

## Priority

Low–medium. Not a correctness bug — purely wasted CPU on the native search
path. Worth doing if full-text search latency becomes noticeable, especially for
queries that match heavily within a few large documents.

## Related

- `docs/general/how_search_works.md` — full search pipeline (this is step 5,
  "Finding the JSON doc").
