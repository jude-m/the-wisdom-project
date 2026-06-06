# Faster Reads (and a Smaller App): Move Text from JSON into SQLite

## Goal

**Primary goal: speed.** Stop loading + parsing whole JSON files at read time.
Move the text into a **per-page content store** in the existing SQLite DB so each
read fetches only the entry/page it needs.

**Bonus: size.** Once the text is in the DB (compressed), the `assets/text/*.json`
files no longer ship, cutting bundle/storage substantially.

**Hard constraint: stays fully offline** — this is a scripture app used on
retreats, planes, poor signal. (This rules out the "fetch text from the server"
option, which is the biggest size win but breaks offline.)

## Where the Speed Comes From (read this first)

The speed win is **granular fetch**, not compression. They are independent:

- **Speed = per-page/per-entry fetch.** Today every read `json.decode`s a whole
  file (0.6–1.2 MB+) just to use one entry. Fetching one row instead removes that
  whole-file parse. This is the win.
- **Size = compression.** Orthogonal. Compressing the stored text shrinks the DB
  but costs only a **sub-millisecond inflate** per read — negligible next to the
  parse it replaces.

So compression is essentially free for speed and buys the size bonus. If you ever
wanted to skip even the sub-ms inflate, you could store the text **uncompressed**
for a slightly larger DB — but inflate is so cheap it's not worth giving up the
size bonus.

## TL;DR

Move the text out of 285 JSON files and into a **compressed, per-page content
table** in the existing SQLite DB, then drop `assets/text/` from the bundle.
The JSON files stay in the repo (the FTS build script reads them from the
filesystem, not the app bundle), so the database still builds — they just aren't
shipped.

```
TODAY (shipped):  95 MB FTS index  +  340 MB JSON            = ~435 MB   offline
PROPOSED:         95 MB FTS index  +  ~42–70 MB compressed text = ~140–165 MB  offline
```

Roughly **a third** of today's footprint, still offline, and faster.

## Performance: Why This Is Faster, Not Slower

A natural worry is "won't decompressing add cost?" No — **JSON parsing is the
bottleneck, not decompression.** The change adds a cheap step and removes an
expensive one.

**Read-time work, today vs proposed:**

| | Today (JSON file) | Proposed (page row) |
|---|------------------|---------------------|
| Data touched | whole file (0.6–1.2 MB+) | one page (tens of KB) |
| I/O | read whole file from bundle | indexed `SELECT` of one blob |
| Expensive op | `json.decode` whole file (~tens of ms) | inflate page (~0.1–0.3 ms) + parse one page |
| Main-isolate jank risk | real on big suttas | much lower (per-page) |

Why inflate is cheap:

- **zlib/gzip inflate ≈ hundreds of MB/s to ~1 GB/s** on a modern phone; a ~60 KB
  page inflates **sub-millisecond**. Dart's `GZipCodec` uses native zlib (C speed).
- **`json.decode` ≈ tens of MB/s** in Dart — it builds a whole tree of
  maps/lists/strings. Parsing a 1 MB file is tens of ms.

So you (a) read far less data and (b) replace a tens-of-ms parse with a sub-ms
inflate. Net: **less work, faster reads, less jank.**

**What's in the blob matters for the parse step:**

- **Snippets** can store **plain text per entry** → inflate gives the string
  directly, **no parse at all**. Fastest possible snippet.
- **Reader** needs structure (footnotes, formatting markers, page metadata), so
  its blob is the page's JSON substructure → inflate **+ parse one page**. Still a
  big win: one page instead of the whole multi-page file.

(Numbers above are ballpark — validate with the micro-benchmark in the steps below
before committing.)

## The Key Insight (measured on real data)

Dropping the JSON does **not** mean stuffing 340 MB into the DB. The 340 MB was
never 340 MB of scripture — it's mostly JSON packaging repeated millions of times
(`"type":`, `"level":`, braces, quotes, indentation), plus uncompressed text.

Measured on `assets/text/` (2026-06):

| Thing | Size |
|-------|------|
| All JSON files (shipped today) | **340 MB** |
| Just the `text` values, uncompressed | 285 MB |
| **Those text values, gzipped** | **41.6 MB** |

So the actual text compresses ~7×. Two things shrink it when it moves into a
table:

1. **Packaging disappears** — `type`/`level` become compact typed columns; no
   braces/quotes/field-names/indentation repeated per entry.
2. **Text compresses ~7×** — store it as compressed blobs.

That's why the DB only grows by ~42–70 MB (compressed text), not 340 MB, while
the 340 MB of JSON vanishes entirely.

## Why This Is the Only Option That Wins on All Three Axes

| Approach | Download/size | Read speed | Offline | Effort |
|----------|--------------|-----------|---------|--------|
| Today | baseline | parses whole files | ✅ | — |
| Per-search memo cache only | same | snippets fixed; reader same | ✅ | tiny |
| Gzip the JSON assets | ↓↓ | same (still parses) | ✅ | low |
| **Compressed content table, drop JSON** ⭐ | ↓ | ✅ per-entry fetch | ✅ | medium–high |
| Mobile → server (reuse web path) | ↓↓↓ | network-bound | ❌ | low |

- **Go-online (reuse `getWebOverrides()`)** is the biggest size win and the infra
  already exists (web runs fully remote), but it **breaks offline** — rejected.
- **Content-storing FTS5** (drop `content=''`) bloats the DB to ~380 MB
  (text duplicated in FTS shadow tables, uncompressed) — rejected.
- **Gzip the JSON assets** keeps the architecture but doesn't help read speed
  (still parses whole files) — viable low-effort fallback, but not the goal.

## Current Runtime Dependencies on JSON

Two code paths read `assets/text/{filename}.json` via `rootBundle` today. Both
must switch to the new content table before the assets can be dropped:

1. **Search snippets** — `_loadTextForMatch` in
   `lib/data/repositories/text_search_repository_impl.dart` (one entry per match).
2. **Reader** — `BJTDocumentLocalDataSourceImpl.loadDocument` in
   `lib/data/datasources/bjt_document_local_datasource.dart` →
   `BJTDocumentParser` (the whole document).

Note: snippet **behavior/UX stays the same** — only its data source changes
(from JSON file → content table). It gets faster, not different.

The FTS build script `tools/bjt-fts-populate.js` reads JSON from the filesystem
(`fs.readFileSync`), so it is unaffected by dropping the asset declaration.

## Proposed Schema

Keep the contentless FTS index (95 MB) for search. Add a sibling table keyed so
both snippet lookups (by entry) and reader loads (by file+page) are indexed.

```sql
-- One compressed blob per page (page = many entries). Chosen over per-entry so
-- the reader can fetch a page in one row, and per-entry compression overhead is
-- avoided. Snippet path fetches the page, decompresses, picks the entry.
CREATE TABLE bjt_content (
  filename TEXT NOT NULL,
  pageIndex INTEGER NOT NULL,
  language TEXT NOT NULL,          -- 'pali' / 'sinh'
  blob BLOB NOT NULL,             -- zlib/gzip of that page's entries (text + footnotes)
  PRIMARY KEY (filename, pageIndex, language)
);
```

- **Snippet**: `eind` already gives `pageIndex`/`entryIndex` → fetch the page row
  → decompress → pick `entryIndex`.
- **Reader**: fetch all pages for `filename` (indexed) → decompress per page →
  assemble the `BJTDocument`. Enables lazy per-page loading later.
- Compression in Dart: `dart:io` `GZipCodec`/`ZLibCodec` (native) — verify the
  decode path is available on all shipped native platforms.
- **Optional max-speed snippet path:** add a `text` column (plain, optionally
  compressed) per entry so the snippet is a single string fetch with **zero
  parse**. Keeps the reader's structured page blob separate. Only worth it if the
  benchmark shows page-parse is a snippet bottleneck.

## Implementation Steps

1. **Prove the speed win first (primary goal).** Write a throwaway `dart run`
   micro-benchmark on a few real files that times, for the same target entry:
   (a) today's path — `rootBundle.loadString` + `json.decode` the whole file; vs
   (b) proposed — inflate one page blob (+ parse that page for the reader case).
   Confirm (b) is meaningfully faster before building anything. Test a small file
   *and* a large sutta (the large one is where today's whole-file parse hurts).
2. **Measure the size bonus.** Build a throwaway content table compressed **per
   page** (not one big stream) and record the real DB size. The 41.6 MB figure is
   whole-corpus gzip; per-page will be larger (~50–70 MB expected). Confirm the
   total DB lands well under today's 435 MB.
3. **Also measure the real release artifact.** APK/AAB/IPA compress text assets
   on build, so the JSON's *download* impact today may already be ~70–110 MB
   (not 340 MB). The 340 MB mainly hits on-device storage. Know both numbers.
4. Extend `tools/bjt-fts-populate.js` to populate `bjt_content` (compress per
   page) alongside the existing `_fts` / `_meta` tables.
5. Add a local content datasource that reads + decompresses from `bjt_content`.
6. Repoint snippet path (`_loadTextForMatch`) and reader
   (`BJTDocumentLocalDataSourceImpl`) at the content datasource.
7. Remove `- assets/text/` from `pubspec.yaml`. Keep the files in the repo.
8. Verify offline reading + search snippets on a real device. Check first-launch
   DB copy time (`_initializeEdition` copies the asset DB to the documents dir;
   a bigger DB = bigger one-time copy + double on-disk during install).
9. (Web unaffected — `getWebOverrides()` already routes web to the server.)

## Quick Win (do regardless)

Ship the per-search decode memo cache from
`docs/todo/search_redundant_json_parsing.md` now. It removes the only real
snippet perf nit with zero size cost and is independent of this migration.

## Open Questions / Risks

- **Compression granularity**: per-page (proposed) vs per-entry vs per-document.
  Page balances reader fetch size against compression ratio; revisit after the
  size measurement (step 2).
- **First-launch copy**: a ~140–165 MB DB copies to the documents dir on first
  run and lives twice during install. Still far better than today's 95 MB copy +
  340 MB un-copied assets, but confirm device storage + copy time.
- **Reader rewrite risk**: this touches the reader (higher-risk code than
  search). Stage it: land the content table + snippet repoint first, reader
  second, drop the assets last.
- **Footnotes / formatting markers**: ensure the blob preserves everything the
  `BJTDocumentParser` needs (footnotes, `**bold**`/`__underline__`/`{footnote}`
  markers, page metadata), not just the bare `text`.

## Relationship to a Next.js Web Rewrite (single source of truth)

Confirmed direction:

- **Mobile stays Flutter** (offline, local-first). This task is *not* throwaway.
- **The web client is being rewritten** (Flutter web → Next.js).
- **One source of truth is wanted**, and the web side should also stop using JSON.

This makes the task **more valuable, not less** — the content store stops being a
mobile-only optimization and becomes the **single canonical runtime store** that
*both* platforms read:

```
            assets/text/*.json   ← build-time IMPORT only (not shipped, not served)
                   │  tools/bjt-fts-populate.js
                   ▼
        ┌─────────────────────────────┐
        │  content DB (FTS index +     │   ← the single source of truth at runtime
        │  per-page content + meta)    │
        └─────────────────────────────┘
            │                       │
   bundled & read locally     read server-side
            ▼                       ▼
   Flutter mobile (offline)   Next.js backend → Next.js frontend
```

What this resolves / implies:

- **JSON is demoted to a build-time import.** Neither mobile nor web reads JSON at
  runtime. The content DB is canonical. (No runtime JSON anywhere = your "web can
  ditch the JSON" goal.)
- **Design the schema platform-neutral**, not Flutter-specific. A Node/Dart
  backend will read the same tables (`better-sqlite3`, Dart `sqlite3`, etc.), and
  the same **FTS5 index** powers search on both mobile and server. Keep
  app-specific logic (Freezed models, etc.) *out* of the stored format.
- **Backend choice stays open and orthogonal.** Whether Next.js reuses the
  existing Dart server or gets its own Node backend, it reads the same content DB.
  Decide that separately; it doesn't change this task.

### Compression in a shared store

Compression was a **mobile-local** size win. In the shared model:

- **Recommended:** keep text **compressed per page** in the canonical DB. Mobile
  keeps the size bonus; the web backend inflates per request (sub-ms, cacheable);
  HTTP `Content-Encoding: gzip/br` handles the wire separately. The brief
  inflate-then-recompress on the server is negligible.
- **Alternative:** store text **uncompressed** — zero server-side inflate and
  fastest possible mobile reads (no inflate at all), at the cost of a bigger
  mobile DB (~380 MB). Valid given speed is the primary goal and size is only a
  bonus; pick this if you'd rather not inflate on the server and don't mind the
  larger mobile footprint.

Either way, hide compression behind a content-access layer so both platforms
share one logical interface.

### Sequencing

Independent workstreams, but they share data — so **settle the canonical format
once** before building, or you'll design a mobile-only store and redo it for the
new backend. Suggested order: (1) memo-cache quick win anytime → (2) lock the
content-DB schema as the shared source of truth → (3) build it → (4) point
Flutter mobile and the new web backend at it → (5) drop runtime JSON on both.

## Related

- `docs/general/how_search_works.md` — the search pipeline (Step 5 reads JSON).
- `docs/todo/search_redundant_json_parsing.md` — the memo-cache quick win.
