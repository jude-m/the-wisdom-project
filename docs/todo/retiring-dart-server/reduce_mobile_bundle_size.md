# Faster Reads (and a Smaller App): Move Text from JSON into SQLite

> **UPDATE 2026-07-16 — CONFIRMED, and promoted to the keystone of a server-free
> architecture.** Decisions from a follow-up study:
>
> - **Same file, not a new DB.** `bjt_content` is a sibling of the **contentless**
>   `bjt_fts` in one `.db` (they share an update lifecycle). Keep FTS contentless +
>   **compressed** blobs + manual snippet — do *not* switch to FTS5 external-content
>   (it needs uncompressed text and would kill the size win). `dict.db` stays a
>   **separate** file (independent, rare updates).
> - **One engine everywhere: [Drift](https://pub.dev/packages/drift)** replaces raw
>   `sqflite`. Native FFI on mobile/desktop, **wasm + OPFS in the browser**. Bundles
>   *one* SQLite version on every platform (kills per-OS FTS variance). Adopt it
>   *thin* — raw SQL via `customSelect` for this read-only canon; reserve the
>   query-builder for future *writable* tables (bookmarks/history).
> - **Web reads this DB CLIENT-SIDE** (Drift wasm/OPFS), not from a server →
>   **retires the Dart content server**, Flutter web becomes fully static.
> - **Delivery: download-once to OPFS on web** (offline), refreshed via **monthly
>   batched** rebuilds (confirmed acceptable). Content+FTS co-versioned via a small
>   manifest + content-hashed filenames; `dict.db` versioned separately.
>   **Host the blobs on Cloudflare R2, not Cloudflare Pages** — the content+FTS DB
>   (~140–165 MB) and `dict.db` (~167 MB) each exceed **Pages' 25 MiB per-file
>   limit**, whereas R2 has no per-file cap and **zero egress** (already the
>   media/audio store). The Flutter bundle + static HTML sit on one Pages project;
>   only the heavy DBs live on R2. Details in
>   [`static-web-hosting.md`](../../decisions/static-web-hosting.md)
>   (Free-tier fit).
> - **Verify first (flag):** FTS5 in the Drift wasm build — high confidence
>   (standard `unicode61` tokenizer; prebuilt `sqlite3.wasm` ships
>   `SQLITE_ENABLE_FTS5`) but confirm with a one-file spike (open real `bjt-fts.db`
>   on web, run a `MATCH`).
> - Companion: [`serverless-deployment-decision.md`](../serverless-deployment-decision.md)
>   — now largely moot (zero always-on infra; the research server is the only backend).

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
The JSON files stay in the repo — the FTS build script and the static site
generator both read them from the filesystem, not the app bundle — so the database
still builds and the HTML site still generates. They just aren't shipped.

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

1. **Search snippets** — `_searchFullText` in
   `lib/data/repositories/text_search_repository_impl.dart`, via the interim
   group-once loader (`_loadFileJson` + `_extractEntryText`, memoised in
   `_fileJsonCache`). Was a per-match `_loadTextForMatch`; replaced 2026-06-19 by the
   memo-cache quick win. See **Snippet-path teardown** below for what to delete when
   repointing.
2. **Reader** — `BJTDocumentLocalDataSourceImpl.loadDocument` in
   `lib/data/datasources/bjt_document_local_datasource.dart` →
   `BJTDocumentParser` (the whole document).

Note: snippet **behavior/UX stays the same** — only its data source changes
(from JSON file → content table). It gets faster, not different.

Two **build-time** consumers read the same JSON from the filesystem rather than the
bundle, so neither is affected by dropping the asset declaration — and both are why
the files stay in the repo:

- `tools/bjt-fts-populate.js` (`fs.readFileSync`) — builds the FTS index.
- `static_site_generator/lib/data/corpus_reader.dart` — builds the public HTML site.

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
- **Reader**: the reader no longer opens whole files — it opens a **slice**
  (`SliceIndex` in `wisdom_shared` maps a nodeKey to its entry range;
  `DocumentSlice` / `ReaderUnit` in `lib/domain/entities/reader/`). Fetch only the
  page rows that slice spans → decompress → assemble. The per-page laziness this
  table was going to "enable later" is already the shape the reader wants.
- **Keep the stored format platform-neutral.** Node writes this table
  (`better-sqlite3`), Dart reads it. No Freezed models or app-specific types in the
  blob — just the page's JSON substructure.
- Compression in Dart: `dart:io` `GZipCodec`/`ZLibCodec` (native) — verify the
  decode path is available on all shipped native platforms.
- **Optional max-speed snippet path:** add a `text` column (plain, optionally
  compressed) per entry so the snippet is a single string fetch with **zero
  parse**. Keeps the reader's structured page blob separate. Only worth it if the
  benchmark shows page-parse is a snippet bottleneck.

## Implementation Steps

1. **Lock the safety net first.** The suite already covers the search *engine*
   well: `integration_test/search_flow_integration_test.dart` pins exact result
   counts against the real FTS DB, and every reader integration test constructs the
   real `BJTDocumentLocalDataSourceImpl` over real assets — so an engine swap or a
   garbled read fails loudly. It covers snippet **text**, the parser, and any file
   outside the `dn-1` family not at all. Close those three gaps first:
   - **Corpus-wide parity script.** For all 285 files, every entry, assert
     `inflate(bjt_content row) == the JSON entry text`, footnotes included.
     `static_site_generator/tool/plan_corpus.dart` already walks the whole corpus
     through `lib/data/corpus_reader.dart` — this is a comparison bolted onto an
     existing walker, not a new one. Write it now, run it the moment step 5
     populates a table, and keep it as that script's own verification step. Without
     it, a populate bug touching only (say) the Vinaya files ships silently.
   - **Golden snippets.** Record today's output for ~5 real queries **before**
     anything changes, then require the migration to reproduce it exactly. The
     teardown below demands snippets stay "byte-for-byte identical" and nothing
     checks that today — `_loadFileJson` / `_extractEntryText` have no coverage at
     all, so empty or wrong snippets currently pass green.
   - **A real-page fixture test for `BJTDocumentParser`.** It has none, and it is
     the seam the new blob feeds.
2. **Prove the speed win (primary goal).** Write a throwaway `dart run`
   micro-benchmark on a few real files that times, for the same target entry:
   (a) today's path — `rootBundle.loadString` + `json.decode` the whole file; vs
   (b) proposed — inflate one page blob (+ parse that page for the reader case).
   Confirm (b) is meaningfully faster before building anything. Test a small file
   *and* a large sutta (the large one is where today's whole-file parse hurts).
3. **Measure the size bonus.** Build a throwaway content table compressed **per
   page** (not one big stream) and record the real DB size. The 41.6 MB figure is
   whole-corpus gzip; per-page will be larger (~50–70 MB expected). Confirm the
   total DB lands well under today's 435 MB.
4. **Also measure the real release artifact.** APK/AAB/IPA compress text assets
   on build, so the JSON's *download* impact today may already be ~70–110 MB
   (not 340 MB). The 340 MB mainly hits on-device storage. Know both numbers.
5. Extend `tools/bjt-fts-populate.js` to populate `bjt_content` (compress per
   page) alongside the existing `_fts` / `_meta` tables.
6. Add a local content datasource that reads + decompresses from `bjt_content`.
7. Repoint snippet path (now `_loadFileJson`/`_extractEntryText` in `_searchFullText`)
   and reader (`BJTDocumentLocalDataSourceImpl`) at the content datasource — see
   **Snippet-path teardown** below for the exact deletions.
8. Remove `- assets/text/` from `pubspec.yaml`. Keep the files in the repo.
9. Verify offline reading + search snippets on a real device. Check first-launch
   DB copy time (`_initializeEdition` copies the asset DB to the documents dir;
   a bigger DB = bigger one-time copy + double on-disk during install).
10. **Web now reads this DB client-side** (Drift wasm/OPFS) — see the top banner.
    The old `getWebOverrides()` → server route is being retired, not extended.

### Snippet-path teardown (step 7 detail)

The interim memo-cache fix
([`perf-fts-snippet-text-loading.md`](../../done/perf-fts-snippet-text-loading.md),
shipped 2026-06-19) is deliberately isolated, so repointing the snippet path at the content
table is a clean ~2-method + 1-field deletion, not a rewrite. The call-site shape
(`matchedText ?? <load> ?? ''`, grouped before the loop) is already what the batched
DB query wants — you replace the *loader*, not the loop. Delete / replace:

**Client — `lib/data/repositories/text_search_repository_impl.dart`**
- [ ] `_fileJsonCache` field (`LRUCache(20)`) — gone; SQLite's page cache handles
      reuse, nothing heavy left to memoise.
- [ ] `_loadFileJson(...)` — gone (no file read / `json.decode`).
- [ ] `_extractEntryText(...)` — gone (replaced by the row `SELECT` + page inflate).
- [ ] In `_searchFullText`: the `filesToLoad` grouping + pre-loop decode → replace
      with one batched lookup (`WHERE (filename,pageIndex,language) IN (...)`,
      decompress, pick `entryIndex`) for all `matchedText == null` hits, then index
      the rows in the loop. Keep the web-prefill skip and the `?? ''` degradation.
- [ ] `import '../cache/lru_cache.dart'` — drop iff nothing else uses `LRUCache`.
- [ ] Preserve the language fallback order (matched lang first, then the other) in
      the row pick so snippets stay byte-for-byte identical.

**Server — nothing to port.** `server/lib/src/handlers/fts_handler.dart` has its own
`_loadTextForMatch` / `_loadJsonFile` / `_jsonCache`, but the whole `server/` tree is
being deleted (see [`README.md`](./README.md)) — web reads the same DB client-side
through Drift. It goes with the server; do not repoint it at `bjt_content`.

**Becomes moot (don't build):**
- [ ] Top-10 #2 Phase 3 (decode off the UI isolate) — a row lookup never janks.
- [ ] Track B #4 (windowed payload) — windowing becomes a substring on the fetched
      row, decoupled from any file parse.

**Verify after teardown:** snippet + highlighting parity for the same query,
missing-row degrades to an empty snippet, and the native search path no longer reads
`assets/text/*.json` at runtime.

## Open Questions / Risks

- **Compression granularity**: per-page (proposed) vs per-entry vs per-document.
  Page balances reader fetch size against compression ratio; revisit after the
  size measurement (step 3).
- **First-launch copy**: the content+FTS DB (~140–165 MB) copies to the documents
  dir on first run and lives twice during install — and `dict.db` (167 MB) already
  copies to that same place, so the real first-run cost is ~310–330 MB written, not
  the content DB alone. Still far better than today's 95 MB + 167 MB copied
  alongside 340 MB of un-copied assets, but confirm device storage + copy time
  against the sum.
- **Reader rewrite risk**: this touches the reader (higher-risk code than
  search). Stage it: land the content table + snippet repoint first, reader
  second, drop the assets last.
- **Footnotes / formatting markers**: ensure the blob preserves everything the
  `BJTDocumentParser` needs (footnotes, `**bold**`/`__underline__`/`{footnote}`
  markers, page metadata), not just the bare `text`.

## Related

- [`README.md`](./README.md) — the parent plan: retiring the Dart content server.
- `docs/general/how_search_works.md` — the search pipeline (Step 5 reads JSON).
- [`perf-fts-snippet-text-loading.md`](../../done/perf-fts-snippet-text-loading.md)
  — the shipped memo-cache fix this migration tears down.
