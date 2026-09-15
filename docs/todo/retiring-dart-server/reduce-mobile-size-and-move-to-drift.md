# Faster Reads (and a Smaller App): Move Text into SQLite and the App onto Drift

> **Status 2026-09-14:** steps 1–4 done; blob layout decided — one page per
> blob, **plain zlib**. A compression sample would win back most of the
> download and is kept as an optional later step (**Compression sample —
> optional, later**). Step 6 moves the app from `sqflite` to Drift, in the same
> branch as the content table; step 7 makes an app update actually replace the
> copied databases. Next: step 5.

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
>   and `dict.db` each exceed **Pages' 25 MiB per-file
>   limit** by an order of magnitude, whereas R2 has no per-file cap and **zero egress** (already the
>   media/audio store). The Flutter bundle + static HTML sit on one Pages project;
>   only the heavy DBs live on R2. Details in
>   [`static-web-hosting.md`](../../decisions/static-web-hosting.md)
>   (Free-tier fit).
> - **~~Verify first (flag):~~ FTS5 in the Drift wasm build — PASSED 2026-09-11.**
>   `SQLITE_ENABLE_FTS5` is in the shipped binary, and the real `bjt-fts.db`
>   returns byte-identical rows through it — 15 queries × 7 engine
>   configurations, including the Sinhala `tokenchars` charlist honoured for
>   *writes* as well as reads. The spike found a different blocker instead (the
>   WAL header flag) and three live bugs in this repo: see **What the
>   Drift/wasm spike changed** below, and the full write-up in
>   `drift-fts5-wasm-spike-results.md` in this folder.
> - Companion: [`serverless-deployment-decision.md`](../serverless-deployment-decision.md)
>   — now largely moot (zero always-on infra; the research server is the only backend).

## Goal

**Primary goal: speed.** Stop loading + parsing whole JSON files at read time.
Move the text into a **per-page content store** in the existing SQLite DB so each
read fetches only the entry/page it needs.

**Bonus: size — on iOS.** Once the text is in the DB (compressed), the
`assets/text/*.json` files no longer ship: on-device storage falls by 35% on
iOS, and probably *rises* on Android (see **Size — the bonus, on two axes**).
The *download* rises, 92 → 114 MB: the JSON already compresses inside the
APK/IPA and a pre-compressed blob cannot. Accepted for now — speed is the goal —
and a compression sample can bring it back to 95 MB later. Measured both ways
below.

**Hard constraint: stays fully offline** — this is a scripture app used on
retreats, planes, poor signal. (This rules out the "fetch text from the server"
option, which is the biggest size win but breaks offline.)

## Where the Speed Comes From (read this first)

The speed win is **granular fetch**, not compression. They are independent:

- **Speed = per-page/per-entry fetch.** Today every read `json.decode`s a whole
  file (0.6–1.2 MB+) just to use one entry. Fetching one row instead removes that
  whole-file parse. This is the win.
- **Size = compression.** Orthogonal *to speed*. Compressing the stored text
  shrinks the DB but costs only a **sub-millisecond inflate** per read —
  negligible next to the parse it replaces.

So compression is essentially free for speed. Blob size is one knob for three
things — compression unit, fetch unit, download size — and this plan sets it
for fetch: one page per blob. A compression sample would later split the knob,
compressing one page nearly as well as eight. See **Blob size — decided**.

## TL;DR

Move the text out of 285 JSON files and into a **compressed, per-page content
table** in the existing SQLite DB, then drop `assets/text/` from the bundle.
The JSON files stay in the repo — the FTS build script and the static site
generator both read them from the filesystem, not the app bundle — so the database
still builds and the HTML site still generates. They just aren't shipped.

```
TODAY (shipped):  95 MB FTS index  +  339 MB JSON  = 434 MB bundled
PROPOSED:         95 MB FTS index  +   77 MB table  = 172 MB bundled
```

Measured, not projected — see **What the measurements said** below. On an
iPhone that is 529 MB today against 344 MB (the DB is copied out of the bundle
on first launch, so its size counts twice and the JSON's counts once). Android
likely goes the other way, 187 → 286 MB, because it never unpacks the APK.

**Download: 92 MB today, 114 MB after.** An APK/IPA is a zip, today's JSON
deflates inside it to 46 MB, and a pre-compressed blob cannot be compressed
again. A per-language compression sample would bring it back to 95 MB without
slowing reads; it is deferred, not rejected.

## Performance: Why This Is Faster, Not Slower

A natural worry is "won't decompressing add cost?" No — **JSON parsing is the
bottleneck, not decompression.** The change adds a cheap step and removes an
expensive one.

**Read-time work, today vs proposed:**

| | Today (JSON file) | Proposed (page row) |
|---|------------------|---------------------|
| Data touched | whole file, 0.1–3.9 MB | one page, ~1.2 KB stored |
| I/O | read whole file from bundle | indexed `SELECT` of one blob |
| Expensive op | `json.decode` whole file, 0.6–19 ms | inflate + parse one page, 0.03 ms |
| Main-isolate jank risk | real on big suttas | gone on the snippet path |

Why inflate is cheap:

- **zlib/gzip inflate ≈ hundreds of MB/s to ~1 GB/s** on a modern phone; a ~5 KB
  page inflates **sub-millisecond**. Dart's `ZLibDecoder` uses native zlib (C speed).
- **`json.decode` ≈ tens of MB/s** in Dart — it builds a whole tree of
  maps/lists/strings. Parsing a 1 MB file is tens of ms.

So you (a) read far less data and (b) replace a tens-of-ms parse with a sub-ms
inflate. Net: **less work, faster reads, less jank.**

**What's in the blob:** the page's JSON substructure, for snippets and the
reader alike → inflate **+ parse one page**. A per-entry plain-text column for
snippets was considered and dropped: the page fetch is already 0.03 ms (see the
schema).

(Validated 2026-09-11 — the benchmark is step 2, the numbers are below.)

## The Key Insight (measured on real data)

Dropping the JSON does **not** mean stuffing 340 MB into the DB. The 340 MB was
never 340 MB of scripture — it's mostly JSON packaging repeated millions of times
(`"type":`, `"level":`, braces, quotes, indentation), plus uncompressed text.

Measured on `assets/text/` (2026-06, re-measured 2026-09-11):

| Thing | Size |
|-------|------|
| All JSON files (shipped today) | **339 MB** |
| Just the `text` values, uncompressed | 285 MB |
| **Those text values, gzipped as one stream** | **42 MB** |

That last row reads like a floor and is not one. gzip's window is 32 KB, so a
single stream over 285 MB holds no more history than a stream over one large
document — and this one interleaves `pali` and `sinh` page by page, while
grouping a document's pages by language does strictly better: **41 MB**. What
costs bytes is how finely the text is cut, not how big the stream around it is.
Plain per-page blobs give up a third of the ratio, because each one starts
compressing from nothing. That is what ships; a compression sample would win
most of it back (see **Compression sample — optional, later**).

Two things shrink it when it moves into a table:

1. **Packaging disappears** — `type`/`level` become compact typed columns; no
   braces/quotes/field-names/indentation repeated per entry.
2. **Text compresses** — 7× as one stream, **4.2× per page**, which is what
   ships, and 5.9× per page with a compression sample.

So the table costs 77 MB on disk while 339 MB of JSON vanishes entirely.

## Why This Is the Only Option That Wins on All Three Axes

Download and on-device storage moved apart once both were measured, so they get
a column each. Today's JSON is enormous on disk and cheap in the archive; a
compressed blob is the reverse.

| Approach | Download | On device (iOS) | Read speed | Offline | Effort |
|----------|----------|-----------|-----------|---------|--------|
| Today | 92 MB | 529 MB | parses whole files | ✅ | — |
| Per-search memo cache only | same | same | snippets fixed; reader same | ✅ | tiny |
| Gzip the JSON assets | ~same | ↓↓ | same (still parses) | ✅ | low |
| **Compressed content table, drop JSON** ⭐ | 114 MB | 344 MB | ✅ per-page fetch | ✅ | medium–high |
| Mobile → server (reuse web path) | ↓↓↓ | ↓↓↓ | network-bound | ❌ | low |

- **Go-online (reuse `getWebOverrides()`)** is the biggest size win and the infra
  already exists (web runs fully remote), but it **breaks offline** — rejected.
- **Content-storing FTS5** (drop `content=''`) bloats the DB to ~380 MB
  (text duplicated in FTS shadow tables, uncompressed) — rejected.
- **Gzip the JSON assets** keeps the architecture but doesn't help read speed
  (still parses whole files) — viable low-effort fallback, but not the goal.

## What the Measurements Said

Steps 2–4 below, run 2026-09-11 on the vendored corpus by two throwaway
scripts: `tools/bjt-content-spike.js` builds the real table into a copy of the
bundled DB, `tools/bench_content_read.dart` times reads out of it.

**Neither is in git** — both are gitignored, with a comment there saying when
to delete them — so the numbers below are the record, not the scripts. What is
worth keeping out of them moves into `tools/bjt-fts-populate.js` at step 5 and
into the datasource at step 6, both noted where they land.

The table it built was checked by the safety net rather than by eye —
`verify_corpus_invariants.dart --content-db tools/bjt-content-spike.db` —
which compared every one of the corpus's entries against its row and found no
divergence. That is section 5 arming itself on a table that existed for the
first time, which was the whole point of writing it before there was one.

### Speed — the primary goal, and it is not close

Same target text, warm, median of enough runs to fill two seconds. Path A reads
the whole file and `json.decode`s it; path B fetches the row(s) and inflates.

| File | JSON | Snippet A → B | Reader A → B |
|------|------|---------------|--------------|
| `kn-khp` (smallest) | 0.1 MB | 0.60 → 0.05 ms (**13×**) | 0.64 → 0.19 ms (**3.4×**) |
| `kn-nc` (median) | 1.0 MB | 4.76 → 0.03 ms (**140×**) | 4.91 → 0.24 ms (**20×**) |
| `dn-1` | 0.9 MB | 3.79 → 0.03 ms (**126×**) | 3.88 → 2.58 ms (**1.5×**) |
| `anya-vm` (largest) | 3.9 MB | 18.75 → 0.03 ms (**586×**) | 19.22 → 0.24 ms (**80×**) |

**The snippet path is settled**: a row fetch is flat in file size, so the win
grows with the file and is already two orders of magnitude at the median.

**The reader path is not flat**, and `dn-1` says why: its slice spans 34 of the
file's 74 pages, so B does most of A's work. The win is not "a row instead of a
file", it is *the fraction of the file the slice leaves unread*. A sweep of
1,411 leaves across 32 files puts the tail at:

| | |
|---|---|
| speed-up, p50 | **45×** |
| speed-up, p10 | 14× |
| slice covers its file, p50 | 2% |
| slice covers its file, p90 | 6% |
| slices slower than today | **1 of 1,411** — `atta-dn-1-1`, 5.58 → 5.82 ms |

So the wide slice is rare and its worst case is a quarter of a millisecond, not
a regression worth designing around. Fetching a whole span in one
`BETWEEN` query rather than two statements per page is worth a further 5–10% —
free, and the shape step 6 should write.

One thing the benchmark does **not** measure: it reads with `File.readAsString`,
not `rootBundle.loadString`, warm, and in-process rather than through sqflite's
platform channel or Drift's isolate. All three cut in today's favour, so these
ratios are a floor.

### Size — the bonus, on two axes

| | Today | **Plain per page (ships)** | Per page + sample (later) |
|---|-------|----------|----------|
| Bundled | 94.8 MB DB + 339.2 MB JSON = **434 MB** | **172 MB** | 150 MB |
| On device, iOS (unpacked + the DB's copy) | **529 MB** | **344 MB** | 300 MB |
| On device, Android (APK stays zipped + the DB's copy) | 92 + 95 = **187 MB** | **286 MB** | 245 MB |
| **Download** (deflated, as an APK/IPA carries it) | 45.5 + 46.5 = **92 MB** | **114 MB** | 95 MB |

Both layouts at the 8 KB pages the pipeline now sets: the index plus the
content table from **Blob size — decided**. The download rises 22 MB, and that
is structural: the JSON is enormous and highly compressible, so the archive
already gets it down to 46 MB, while a compressed blob is paid in full on disk
and on the wire. A compression sample would cut the rise to 3 MB. The 2026-06
estimate of "~70–110 MB" for the JSON's download impact was high by half.

(Measured by deflating each file the way a zip stores an entry. A real APK
would confirm it, but there is no Android SDK on this machine, and iOS needs a
signed build; the arithmetic an archive does is the same either way.)

**On device, the two phones go opposite ways.** iOS unpacks the app on
install, so today's 339 MB of JSON sits on the phone in full and dropping it is
a large saving. Android keeps the APK as a zip and reads assets out of it —
Flutter's Gradle plugin sets no `noCompress`, so `.json` and `.db` are stored
deflated — so today costs only the 92 MB APK plus the DB's copy, and the
migration *adds* ~99 MB (~58 MB with a compression sample). Speed is the goal,
so this changes the headline, not the plan. Derived, not measured: one
`flutter build apk --analyze-size` confirms it.

**What is left of that rise is mobile-only, and reads backwards on web.** The row above
is an APK/IPA — an archive that deflates the JSON for free. The web has no
archive. Today's plan for it (spike §8b) is to serve the same 285 JSON files
and let the client do what the server does, which costs, *per results page*,
~27 conditional GETs and 3–4 MB transferred to parse ~34 MB of JSON in the tab
— repeated, unbounded, and never offline. The content table replaces all of it
with bytes already downloaded:

| | Web, serving JSON | Web, content table |
|---|---|---|
| One-time | 47.6 MB (FTS, gzipped) | 47.6 + ~68 MB blobs ≈ **116 MB** |
| Per results page | ~27 GETs, 3–4 MB, 34 MB parsed | one row fetch |
| Offline | ✗ | ✓ |

So on web this migration is not a download regression at all: it converts an
unbounded per-use cost into a bounded one-time one, and it is the only thing
here that makes web offline possible. The "download rises" framing above is
true of the phone and false of the browser, and both surfaces read this table.

### SQLite page slack, and the knob that moves it

Measured on the plain per-page blobs (2026-09-11): 67.2 MB of blobs made an
85 MB table. The other 18.1 MB is SQLite leaving space on the floor:
every blob is under 4 KB (1.2 KB on average, 3.8 KB at the largest), so a 4 KB
page fits two or three of them and wastes what is left — and a blob past
half a page gets one to itself. The page size is the cheapest knob in the whole
plan — content table alone, same rows:

| `page_size` | 4 KB | 8 KB | 16 KB | 32 KB |
|---|---|---|---|---|
| on disk | 85.4 MB | 77.2 MB | 73.5 MB | 71.9 MB |

Against it: a bigger page reads more to get one blob, and `cache_size` counts
pages, so the same setting holds 4× the memory at 16 KB.

**Decided: 8 KB, and it is no longer step 5's call** — the build pipeline sets
it, so the content table inherits it whatever step 5 writes. Two things moved
after this table was measured:

- The constraint this section stated — *"it has to be set on a **new** database
  before the first write, and changing it later means `VACUUM`, which will not
  do it while the DB is in WAL mode"* — **is wrong**, in the useful direction.
  `VACUUM INTO` builds a new file and takes the page size from the source
  *connection*, so it works from a WAL source and needs no foresight.
  Measured on the real index: **0.4 s**. It is a post-pass, not a schema
  decision, and it now runs on every build (see the pipeline section).
- A second, independent reason to want it: the Drift/wasm spike measured 8 KB
  pages **halving the web read I/O** (1,384 → 703 reads, first query 505 →
  325 ms). The disk saving and the web saving are the same knob turned once.

On this index alone the rebuild is near-neutral on size (99.4 → 99.2 MB — it is
mostly FTS b-tree, not small blobs). The 8 MB is the content table's, and it is
saved **twice**, because the DB is copied out of the bundle on first launch.

### Blob size — decided 2026-09-14: one page per blob, plain zlib

**Chosen:** one blob per page, as the contract already says, zlib level 9, no
compression sample.

**Why plain.** Reads are the goal, and plain is as fast as anything measured —
a little faster than with a sample, natively and in Chrome. It is also the
simplest format to read on every platform: `dart:io`, `package:archive` and the
browser's `DecompressionStream` all read plain zlib as it is. What it costs is
download: about 19 MB more than with a sample, on phone and web alike. The
sample stays measured and ready — **Compression sample — optional, later**.

Whole corpus, every blob decoded back and compared to the source JSON — in
Node, in Dart (native and pure Dart), and a 999-page sample in Chrome. Zero
mismatches anywhere.

| layout | download (zipped) | on disk (8 KB pages) | snippet read | reader p50 / p90 | web read (Chrome) |
|---|---|---|---|---|---|
| **1 page, plain** | **68.1 MB** | **76.9 MB** | **76 µs** | **1× / 1×** | **0.25 ms** |
| 4 pages, plain | 51.5 MB | 73.7 MB | 222 µs | 2.9× / 3.6× slower | — |
| 8 pages, plain | 46.7 MB | 55.4 MB | 412 µs | 5.1× / 6.8× slower | 0.45 ms |
| 1 page + sample | 49.7 MB | 55.1 MB | 80 µs | 1.02× / 1.06× | 0.34 ms |
| 4 pages + sample | 43.8 MB | 60.2 MB | 227 µs | 2.9× / 3.6× slower | — |

Content table only — add the FTS index (45.5 MB zipped) for the whole download.
Reader columns are 1,411 real slices from every 9th file, against one plain page.
The whole-document floor is still 41.0 MB, and per entry is still out (1.67×
worse than per page).

**Why not more pages per blob.** Eight plain pages download 21 MB less than
one, but every read decodes eight pages to use one — 5× slower natively, and
nearly twice the cost on web. Four pages saves 17 MB for 3× slower reads. Speed
is the goal, so neither.

**Smaller findings:**
- **Level 9** saves another 0.6 MB and doubles the build's compress time
  (25 → 48 s). Reads are unchanged, so step 5 uses it.
- **Platforms.** Android, iOS, macOS, Windows and Linux all decode through
  `dart:io`, one zlib built into the Dart runtime, so they behave the same;
  only macOS was run. On web, `package:archive` has no browser floor (see
  **The blob decoder needs a web path**). Play caps the compressed base
  download at 200 MB: the two databases take ~143 MB of it.

The throwaway scripts (a Node size builder, a Dart read benchmark, a
headless-Chrome test) lived in a session scratchpad, not the repo; the numbers
above are the record.

### Compression sample — optional, later

Measured 2026-09-13 and ready to pick up if the download starts to matter.
Nothing in steps 5–11 depends on it.

**What a compression sample is.** About 32 KB of typical text — the words and
phrases that recur across the canon — which the compressor treats as if it had
already seen it. Each page then refers back to that text instead of spelling it
out again, so a small page compresses nearly as well as a big chunk while a read
still unpacks one page. Unpacking needs the exact same bytes, so the sample
ships in the DB.

**Not `dict.db`.** zlib and zstd call this a *preset dictionary*, and their APIs
name it `dictionary`. It has nothing to do with word meanings, and this work
does not touch `dict.db`. This doc says **compression sample** everywhere, so
the two never blur.

**What it buys, against plain** — download and storage only; reads are a wash:

| | plain (ships) | with sample |
|---|---|---|
| Download, phone | 114 MB | 95 MB |
| One-time download, web | ~116 MB | ~97 MB |
| Bundled | 172 MB | 150 MB |
| On device, iOS / Android | 344 / 286 MB | 300 / 245 MB |
| Snippet read, native | 76 µs | 80 µs |
| One page read, web (Chrome) | 0.25 ms | 0.34 ms |

**What it costs:**
- Two committed build inputs, one per language, and a script to retrain them.
- A second table in the same file, so blobs and samples never update apart:

  ```sql
  CREATE TABLE bjt_content_sample (
    language TEXT PRIMARY KEY,       -- 'pali' / 'sinh'
    sample BLOB NOT NULL
  );
  ```
- A web decoder that works around the sample (below), with its own checksum
  checks, and section 5 narrowed to zlib with the header's sample flag set.
- **Every blob changes when it lands**, so each user downloads the whole
  database once. The DB ships with the app — bundled on mobile, deployed
  together on web — so an old app never meets a new DB; on mobile that relies
  on step 7. The same holds for every later retrain: free while updates ship
  whole files, as the prestudy plans, not if partial updates are ever added.

**How, if picked up:**
- **Samples are committed files, trained by a script, never at build time.**
  Train once per language with `zstd --train --maxdict=40000` over every 4th
  page (zstd calls its output a dictionary) and keep the last 32 KB. Training
  on every build would let a new zstd or a small text change alter every blob
  and force a full re-download for nothing; a command written only in a doc
  invites a hand-run that compresses worse with nothing failing. A stale sample
  still works, just a little worse, so retrain deliberately.
- **`zstd --train` beats a simple Node frequent-phrase builder** by 2.4 MB; the
  Node builder is the fallback if zstd is unavailable.
- **Per language beats shared** — one sample for both costs 1.9 MB more.
- **Native needs zlib framing, not raw deflate.** `dart:io`'s
  `ZLibDecoder(dictionary:)` only applies the sample when the zlib header asks
  for it; raw deflate plus a sample fails with `Filter error, bad data`. The
  header carries the sample's checksum, so a blob decoded with the other
  language's sample throws in both Node and Dart instead of returning garbage.
  Load each language's sample once, not per read.
- **Web decoders don't accept a sample, and don't need to.** Neither the
  browser's `DecompressionStream` nor `package:archive` takes one (archive's
  zlib decoder returns failure when the header's sample flag is set). Standard
  deflate gets around it: strip the 6-byte zlib header and 4-byte trailer, put
  the sample in front as an *uncompressed block*, decode, and cut the first
  32 KB off the output. Then check what zlib would — the sample's checksum in
  the header (bytes 2–5), the page's in the trailer (`getAdler32`) — so a wrong
  sample or a damaged blob throws on web exactly as natively. Verified in Chrome
  (999/999) and in pure Dart over the whole corpus: under 0.1 ms per read over a
  plain blob in Chrome, and no slower than plain in pure Dart (119 vs 127 µs),
  because the blobs are smaller. `DecompressionStream` with `deflate-raw` needs
  Chrome/Edge 103, Firefox 113 or Safari 16.4; `package:archive` has no floor.

## What the Drift/wasm spike changed (2026-09-11)

The FTS5-in-wasm spike passed its gate, and its write-up
(`drift-fts5-wasm-spike-results.md`, copied into this folder) reviewed this
repo on the way past. Five of its findings land on the work below; each claim
here was re-verified locally against the shipped databases before being written
down, because a spike's numbers are its machine's.

### The build pipeline is now three steps, not one — and it was shipping a bug

Both generators ended in `VACUUM`. They now end in `finalizeDatabase`
(`tools/db-finalize.js`, shared by `bjt-fts-populate.js` and
`dict-populate.js` — `dict.db` is a shipped asset too, and reaches the browser
through the same wasm build):

```bash
PRAGMA page_size = 8192; VACUUM INTO 'tmp.db';   # from the WAL source
ANALYZE;                                          # on the rebuilt file
# assertShippableHeader: bytes 0-15 are the magic, 18/19 < 2
# then, and only then, swap tmp.db into place
```

The assert runs on the temp file, before the swap, so a database that fails it
never reaches the path the release build reads.

Three unrelated problems, one pass:

- **The WAL flag would have blocked the web build outright.** Both scripts set
  `journal_mode = WAL` for write speed, which leaves header bytes 18/19 at 2.
  Verified: both shipped databases carry `2/2` today. The wasm SQLite Drift
  ships is compiled `SQLITE_OMIT_WAL` and rejects such a file on the **first
  prepare** — `SQLITE_NOTADB (26): file is not a database`, before any FTS5
  code runs, saying nothing about WAL, on a file that opens fine everywhere
  else. This is the sort of thing that costs a week.
- **8 KB pages**, as above.
- **`ANALYZE` — and this one is a live bug on phones, not a web concern.**
  `bjt-fts.db` ships with no `sqlite_stat1` (verified), so the planner guesses
  on the scope + language query `ScopeFilterSql` builds, sees
  `idx_bjt_meta_language`, and drives the join from the meta side — one FTS
  MATCH per `pali` row. Re-measured here on the real index (`බුද්ධ*`, `dn-%`,
  `pali`, 128 hits, SQLite 3.51.1):

  | | plan | time |
  |---|---|---|
  | as shipped | `SEARCH m USING INDEX idx_bjt_meta_language` | **8,736 ms** |
  | after `ANALYZE` (60 ms, 6 rows) | `SCAN t VIRTUAL TABLE ... SEARCH m USING INTEGER PRIMARY KEY` | **8 ms** |

  A thousandfold, for 60 ms at build time. Newer SQLite happens to pick the
  good plan unaided — but `sqflite` on Android uses the **system** SQLite,
  whose version tracks the OS, so some users are on the nine-second path right
  now. The fix cannot wait for the engine.

Also added: `tools/validate-release.sh` step 1 checks the header of every
database in `assets/databases/`. There is no CI in this repo, so the
pre-release script is the gate. It re-implements `assertShippableHeader`'s two
conditions in `od` rather than calling it: a second implementation is the point,
because this one must run without node and must catch a database that arrived
from a backup or a hand-run `sqlite3` instead of from a generator.

> **The shipped assets are still WAL-flagged** — the two *generators* were
> changed, not the two databases (they are untracked, so this cannot ride in a
> commit). Both need fixing: `npm run generate-fts` and `npm run generate-dict`
> in `tools/`, or the repair one-liner `validate-release.sh` prints, on **both**
> `bjt-fts.db` and `dict.db`.

One consequence worth noting: once both generators end in `VACUUM INTO`, the
un-checkpointed-WAL branch in `verify_corpus_invariants.dart` becomes
unreachable for our own builds, and the `-wal`/`-shm` sidecars in
`assets/databases/` stop existing. Leave the branch — it cost nothing and it
was describing a real property of the file at the time.

### The blob decoder needs a web path

`dart:io` does not exist on web, and this same table is the web's content
source. Nothing in `pubspec.yaml` covers the gap — no `archive`, no `drift`, and
`lib/` uses no codec today.

`DecompressionStream` (through JS interop) and `package:archive` both read
plain zlib. What separates them is testing: section 5 runs on the Dart VM, so it
can run `package:archive` over every blob and can never run
`DecompressionStream`. That favours `package:archive` — and its `ZLibDecoder` is
one call on every platform: `dart:io`'s zlib natively, its pure-Dart `Inflate`
on web. `ZLibDecoderWeb` forces the pure-Dart path, which is how section 5 runs
the web's decoder on the VM (step 5). Its speed once compiled to JS or wasm has
not been measured; step 11 does that.

### This work now gates the web move, rather than following it

The spike's own biggest open item for going static was the JSON fetch path —
"~27 conditional GETs and 3–4 MB per results page … **this is now the
least-understood piece, not SQLite**". This table deletes that path rather than
prototyping it. So in the README's order of operations, **step 2 (this
document) must land before step 4 (retire the server, make web static)**, or
step 4 builds a 285-file fetch path on web and then throws it away. Step 3
(move web onto Drift) comes between them for a simpler reason: it reads the
table step 2 builds.

### Three live bugs it found in code this work touches

All three confirmed present here. None is caused by the migration; two are in
the same build pipeline, one in the same datasource.

1. **`ORDER BY score` has no tiebreaker** —
   `lib/data/datasources/fts_local_datasource.dart:186` (and
   `server/lib/src/handlers/fts_handler.dart:93`). bm25 ties are common in this
   corpus: the first 5,000 hits for භගවා carry 622 distinct scores, largest tie
   group 69 rows. With `LIMIT`/`OFFSET` paging, rows can repeat or vanish as
   the user pages. Fix is `ORDER BY score, id`.

   **This one touches the safety net.** Group 9's goldens are *not* order-flaky
   — they address rows by `(file, page, entry, language)` and the test says why.
   But the escape hatch it documents, *"a row can drop out of the set with
   every snippet still byte-identical"*, is exactly what an unstable tiebreaker
   produces under overfetch + `_limitToGroups`. Adding `, id` is what stops
   that test firing spuriously — and the engine is about to change twice
   (Drift native, then wasm).
2. **Dictionary prefix lookup full-scans 175 MB on every word tap** —
   `lib/data/datasources/dictionary_local_datasource.dart:83,134,181` use
   `LIKE ? ESCAPE '\'`, which never uses `idx_word`. 133 ms natively; over OPFS
   it is the whole file through a JS callback. `buildDictionaryLikePattern`
   only ever builds a prefix, so the semantics survive
   `word >= :w AND word < :w || char(0x10FFFF)` — 0.4 ms.
3. **`idx_bjt_meta_language` earns nothing** — two distinct values over 457k
   rows. Its only demonstrated effect is the misplan above. Consider dropping
   it in the same pipeline pass.

### Smaller constraints, for whoever writes steps 5–8

- **`SQLITE_DQS 0` on web:** double-quoted *string literals* are an error
  there, and native won't catch it. New `bjt_content` SQL must use single
  quotes (identifier quoting is unaffected). Existing SQL is clean — the spike
  grepped every site in `lib/`, `packages/` and `server/`.
- **`enableMigrations: false`** when Drift opens these. `user_version` is 0
  (verified), so the migrator would otherwise write into the shipped DB.
- **No `ATTACH`** between this DB and `dict.db`. Drift's OPFS mode is chosen at
  runtime by browser capability, and one of the two modes stores exactly two
  files. They are already separate files by design; this just forecloses ever
  joining across them.
- **`snippet()`/`highlight()` return NULL, not an error**, on a contentless
  table. Nothing calls them, which is why the manual snippet path exists — but
  a silent NULL is what a future caller would get.
- **`bjt_suggestions` does not exist** (verified), so every autocomplete call
  throws. Not a mystery: `GENERATE_SUGGESTIONS: false` in the populate script's
  config. Either flip it and pay the size, or delete
  `_getSuggestionsFromEdition`. Unrelated to this work, but it is in the file
  step 6 opens.

### What it did not change

The speed numbers, the parity contract, per-entry being ruled out, and the
slice shape for step 6. The spike is about the engine under the table, not the
table. Its own caveat is worth carrying: it could not run the Dart layer at all
(pub.dev was blocked in that session), so Drift's worker negotiation, its
migration behaviour, and iOS/Firefox are unverified by execution — as is this
document's bench, which read with `File.readAsString` rather than through
`rootBundle` and sqflite's platform channel. Both sets of numbers are floors,
from different directions.

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
  pageNum INTEGER NOT NULL,        -- the *printed* page number, and not derivable
  blob BLOB NOT NULL,             -- zlib, level 9
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
- **`pageNum` is a column, not part of the blob, and it is not optional.** In the
  JSON it is a sibling of `pali`/`sinh`, not inside either, so a blob holding the
  page's substructure verbatim does not carry it — and `BJTDocumentParser`
  hard-casts it (`pageJson['pageNum'] as int`), so a page without one throws
  rather than degrades. It is user-visible: all three reader panes print it via
  `ReaderEntryBuilder.buildPageNumber`, and `BJTDocument.getPageByNumber` keys
  off it.

  It cannot be computed from `pageIndex`. Across the 285 content files only 7
  have a constant offset; `anya-vm.json` alone has 276 distinct ones. So it has
  to be stored.

  Into the blob is the one place it may **not** go: section 5 compares every key
  of the blob against every key of `pages[i][language]`, so an extra `pageNum`
  inside it is a shape divergence and fails. A column duplicates the value
  across the two language rows — 57,934 rows × a 1–2-byte varint, about 150 KB —
  which is cheaper than the join a sibling `bjt_page` table would put on every
  read.
- **Keep the stored format platform-neutral.** Node writes this table
  (`better-sqlite3`), Dart reads it. No Freezed models or app-specific types in the
  blob — just the page's JSON substructure.
- Decompression in Dart: `package:archive`'s `ZLibDecoder` — `dart:io`'s zlib
  natively, pure Dart on web, same call. Not in `pubspec.yaml` yet. See **The
  blob decoder needs a web path**.
- **~~Optional max-speed snippet path~~ — dropped.** The idea was a per-entry
  `text` column so a snippet needed no parse at all. The benchmark says the page
  fetch *is* 0.03 ms, so there is nothing left to win, and per-entry
  compression costs 1.67× per-page for it.

## Implementation Steps

1. **Lock the safety net first — DONE 2026-09-11.** The three gaps that let a
   garbled migration pass green are closed. Nothing new was scaffolded: each
   landed in the script or suite that already asked the neighbouring question.
   - **Corpus-wide parity** → section 5 of
     `static_site_generator/tool/verify_corpus_invariants.dart`. That file, not
     `plan_corpus.dart`: it is where the other four whole-corpus invariants
     live, it already prints PASS/FAIL and exits non-zero, and
     `test/corpus_tools_test.dart` already runs it. Reads the table with
     `sqlite3`, a `tool/`-only dev dependency pinned to 2.x so a checkout with
     no network can still run it. It walks every content file, every page, both
     languages, and names the first divergence per kind.

     **It arms itself.** The default target is the bundled
     `assets/databases/bjt-fts.db`, so the first run after step 5 populates
     `bjt_content` starts checking with no flag typed and no checklist item
     remembered — a trigger written in a doc holds only until someone skips the
     doc. Before then it reports **SKIPPED and does not vote**: a section that
     cannot run has not passed. Two states skip (no database; a database with no
     such table) and one fails (`--content-db` naming a path that is not there),
     because telling someone who typed a path that it was skipped is how the
     first version of this hid its own hole.

     The database is opened `immutable=1`, not merely `readOnly` — on a WAL
     database the latter still bumps the `-shm` sidecar's mtime. Nothing about
     the bundled asset or its sidecars is touched. The trade is that SQLite then
     ignores the `-wal`, so an un-checkpointed database is refused with the
     checkpoint command rather than read stale.

     **It is also where the blob format is pinned**, so step 5 writes to a
     contract rather than inventing one: one row per
     `(filename, pageIndex, language)`, holding the gzip- **or** zlib-framed
     bytes of that page's JSON substructure *verbatim* — the same object
     `pages[i]['pali']` decodes to, entries and footnotes and every other key.
     Not a remodelled one; Node writes and Dart reads, and anything app-shaped
     in the blob is a format two runtimes must agree about twice.

     The frame is sniffed from its magic number, and **gzip and zlib are the
     only two answers that pass**. Anything else fails even though it decodes:
     uncompressed JSON round-trips perfectly, so a lenient reader would report
     a clean run at 100% of plain JSON — the tool printing the number that says
     nothing was compressed while voting that all is well. A column holding TEXT
     rather than a BLOB is counted as its own failure too, rather than throwing
     on the cast and replacing a named finding with a stack trace.

     **Step 5 narrows the frame** to plain zlib — see there.

     Proven end-to-end before the real table exists, against throwaway DBs
     written by `better-sqlite3`: gzip and zlib rows both inflate; a wrong
     page's content, an entry that is a string, and an entry whose `text` is a
     number are each caught and named; an absent `footnotes` key is
     distinguished from an empty one; missing rows are counted, and a row naming
     no corpus file separately.
   - **Golden snippets** → Group 9 of
     `integration_test/search_flow_integration_test.dart`, reusing
     `search_test_helper.dart` unchanged. Five real queries; within each, rows
     pinned byte-for-byte and chosen to carry what compression can quietly
     eat — `**bold**`, `{n}` refs, embedded newlines, zero-width joiners — plus
     the whole-set invariant that no result carries an empty snippet, which is
     the hole that let `_loadFileJson` / `_extractEntryText` pass green with no
     coverage at all. Groups 1–8 were left alone: they pin result *counts* and
     BM25 *order*, which is a different question, not a subset of this one.
   - **`BJTDocumentParser`** → `test/data/datasources/bjt_document_parser_test.dart`
     over `test/fixtures/kn_jat_pages_0_1.json`: `kn-jat` pages 0–1, verbatim.
     Those two because between them they hold all five entry types, a `pageNum`
     that is not the page index, sections with and without footnotes, a
     non-numeric footnote label, a null `level`, and all three markers.

     One thing it does **not** cover, despite looking like it does: the
     segment-id test pins the counter running unbroken across both languages
     and both pages, but only *within one `parseDocument` call*. A per-page
     loader calling it once per page still produces an unbroken `0..n` each
     time. If step 6 reads page-at-a-time, segment-id continuity across a file
     needs its own check at whatever layer stitches the pages together.

   **Unrelated TODO, moved out 2026-09-14:** one entry point for every test path
   is its own plan now — [`test-all-and-release-all.md`](../test-all-and-release-all.md).
2. **Prove the speed win (primary goal) — DONE 2026-09-11. GO.** Snippets 13–586×,
   reader p50 45× with one slice in 1,411 a quarter-millisecond slower than
   today. Numbers and method in **What the measurements said**;
   `tools/bench_content_read.dart` is the throwaway that produced them.
3. **Measure the size bonus — DONE 2026-09-11.** 180 MB bundled against today's
   434 MB, built for real by `tools/bjt-content-spike.js` and verified entry for
   entry by section 5. Two things the estimate got wrong, both above: the table
   costs 85 MB rather than 42–70 (SQLite page waste, which `page_size` moves),
   and per-page compression is 4.2× rather than the 7× the whole-corpus figure
   suggested.
4. **Also measure the real release artifact — DONE 2026-09-11, with a caveat.**
   Today's JSON deflates to 46 MB, not the 70–110 estimated, so the **download
   rises** 92 → 114 MB while storage falls. Measured as deflate per file rather
   than out of a built APK: there is no Android SDK on this machine and iOS
   wants a signed build. Worth confirming against a real artifact on a machine
   that has one, but it will not change the direction.

   **Answered 2026-09-14:** accepted. Plain pages ship at 114 MB; a
   per-language compression sample would bring it back to 95 MB with reads as
   fast, and is kept for later — see **Compression sample — optional, later**.
5. Extend `tools/bjt-fts-populate.js` to populate `bjt_content` (one page per
   blob, plain zlib level 9, plus the `pageNum` column) alongside the existing
   `_fts` / `_meta` tables.

   **Two things that used to be part of this step are already done.** The
   script now ends in `finalizeDatabase` (`tools/db-finalize.js`) — `VACUUM
   INTO` at 8 KB pages,
   `ANALYZE`, and a header assert — so page size is inherited rather than
   chosen here, and nothing this step writes can reintroduce the WAL flag.
   Write rows in WAL mode as before; the finalize pass is what ships.

   **The contract is already written down and enforced** — see step 1: one row per
   `(filename, pageIndex, language)`, `language` spelled `pali` / `sinh`, the
   `blob` column a real BLOB, and the payload that page's JSON substructure
   verbatim — plus the `pageNum` column beside it, copied from the page.
   Uncompressed JSON is a *failure*, not a lenient pass: it round-trips clean
   and would otherwise read green at 100% of plain JSON.

   **One part of it narrows first: the frame.** Section 5 accepts gzip or
   zlib. Narrow it to zlib, the one frame the app's decoder reads — gzip passes
   here and fails in the app. A zlib header with the sample flag set fails
   too: no sample ships, so nothing could open it.

   **And it decodes every blob twice** — with `dart:io`'s zlib, and with
   `package:archive`'s pure-Dart decoder (`ZLibDecoderWeb`, checksum
   verified), which is the path the web build takes — failing where the two
   disagree. Nothing else runs the web path over the whole corpus, so it
   happens here rather than at step 11. `archive` joins `sqlite3` as a
   `tool/`-only dev dependency of `static_site_generator`; the app already
   locks the same version transitively.

   Almost nothing needs wiring up to check it. `verify_corpus_invariants.dart`
   looks in `assets/databases/bjt-fts.db` by default and reports SKIPPED while
   the table is absent, so the first run after this step arms it automatically —
   including the run inside
   `static_site_generator/test/corpus_tools_test.dart`. It opens the database
   `immutable=1`, touching neither the asset nor its WAL sidecars.

   **The exception is `pageNum`, and it has to be closed in this step.** Section
   5 compares blobs; the column sits beside them and nothing reads it. That is
   the one field of the four that is *not* derivable from anything else in the
   table, so a populate bug there is both the likeliest and the only invisible
   one — every other column is in the primary key, and a wrong key shows up as a
   missing or extra row. Extending section 5 to compare the column against
   `pages[i]['pageNum']` is a few lines in the loop that already has both sides
   in hand.

   **Leave no WAL frames behind.** Reading `immutable=1` means SQLite ignores a
   `-wal`, so the verifier refuses an un-checkpointed database rather than
   report stale parity. The script already closes in a `finally`, which
   checkpoints and removes the `-wal`; this bites only after a killed run or an
   open sqlite3 session. The refusal prints the remedy:
   `sqlite3 assets/databases/bjt-fts.db 'PRAGMA wal_checkpoint(TRUNCATE);'`

   **Back up the shipped database before the first run, and compare
   `bjt_meta` after.** The rebuild regenerates the search index too, not just
   the new table, and the shipped file's timestamp is earlier than the canon
   sync commit (`470d105`) on the same day — so it may predate the vendored
   JSON. If `bjt_meta` moves, the counts Groups 1–8 pin can move with it, for a
   reason unrelated to `bjt_content`. The file is untracked, so git cannot
   restore it.

   **Left for after this step:**
   - **Delete the step 2–4 throwaways**: `tools/bjt-content-spike.js`,
     `tools/bench_content_read.dart`, `tools/bjt-content-spike.db`, and the
     `.gitignore` block that names them. Their numbers are recorded in
     **What the measurements said**; nothing else reads them.
   - **`dict.db` is still WAL-flagged.** This step's rebuild fixes only
     `bjt-fts.db`. Run `npm run generate-dict` in `tools/` separately. Until
     then `validate-release.sh` fails on it, and the web build (step 11)
     cannot open it.
6. **Move the app to Drift, then add the content datasource on top.** Decided
   2026-09-13: both land in one branch, and no `sqflite` version of the
   datasource is written first. Two stages, so a failure points at one of them:

   1. **Swap the engine and change nothing else.** Three files import
      `sqflite` — `lib/main.dart` (desktop FFI setup),
      `fts_local_datasource.dart` and `dictionary_local_datasource.dart` — plus
      `test/data/datasources/fts_language_filter_sql_test.dart`. Move all four,
      `dict.db` included, so `sqflite` and `sqflite_common_ffi` leave
      `pubspec.yaml`. Same SQL, same results: the existing unit and integration
      suites pass with no expectation changed before stage 2 starts. Adopt
      Drift thin (`customSelect`) and follow **Smaller constraints** above.
      Land the `ORDER BY score, id` tiebreaker (bug 1 above) as its own change
      just before the swap, so a bm25 tie can't pass for an engine difference.
      Native Drift has never run in this repo — the spike could not run the
      Dart layer — so this stage is where it gets proven.
   2. **Add the content datasource** that reads + decompresses from
      `bjt_content`.

   Web keeps its server path in this branch and moves at step 11.

   Five things the measurements and the spike review turned up, all of which
   bite in stage 2 rather than in step 5:

   - **The half-open → page-span rule has no home, and needs one before
     stage 2.** Stage 2 must know which page rows to `SELECT` *before* it has a
     document, and the only implementation of that rule today is
     `DocumentSlice.of` (`lib/domain/entities/reader/document_slice.dart`),
     which takes a loaded `BJTDocument` — so it cannot serve the fetch, and the
     benchmark wrote its own copy twice rather than reuse it. The rule is
     subtle enough to be worth writing once: a `SliceRange.end` landing on entry
     0 means the slice stops *before* that page, anywhere else means it shares
     it. The two copies already disagree at the edges — `DocumentSlice.of`
     returns empty and drops `endEntry` when it clamps. Put a document-free form
     on `SliceRange`/`SliceIndex` in `wisdom_shared`, which already owns
     `rangeFor`, and have `DocumentSlice.of` consume it instead of re-deriving
     it.
   - **Fetch the whole span in one query**, not two statements per page:
     `WHERE filename = ? AND pageIndex BETWEEN ? AND ? ORDER BY pageIndex`.
     Measured at a further 5–10%.
   - **A missing row must throw, not be skipped.** `BJTDocumentParser._parsePage`
     hard-casts `pageNum`, `pali` and `sinh`, so a page assembled from a partial
     result set either crashes a layer further down or renders with one language
     silently absent. Assemble `{pageNum, pali, sinh}` per page and let an
     absent row fail at the fetch, where it can say which row.
   - **Segment-id continuity is not covered by the parser test** — see step 1.
     The counter runs unbroken *within one `parseDocument` call*, so a per-page
     loader calling it once per page still produces a clean `0..n` every time
     and the test passes anyway. Whatever stitches the pages together needs its
     own check.
   - **Decoder.** `package:archive`'s `ZLibDecoder` with `verify: true` — one
     call on every platform (`dart:io`'s zlib natively, pure Dart on web), and
     step 5 has already run both paths over every blob.
7. **Make an app update replace the copied databases.** Both
   `_initializeEdition` (`fts_local_datasource.dart`) and
   `dictionary_local_datasource.dart` copy the asset out of the bundle only
   when no copy exists, and nothing checks versions. So an update carrying a
   rebuilt database never reaches an existing install: it keeps its first copy
   for good. Every rebuild so far has had that gap, silently. This is the
   first where the old file cannot serve the new code — it has no
   `bjt_content`, so after step 8 reading and snippets break for every
   existing user. Must land before step 8 ships.

   To figure out:
   - **How the app tells its copy is stale** — something recorded beside the
     copy and compared with the bundled asset (a content hash, a build id).
     Not `user_version` without care: Drift's migrator writes it unless
     `enableMigrations: false` (see **Smaller constraints**).
   - **Replacing it safely** — close any open connection, copy to a temp
     file, then swap, so a launch killed mid-copy never leaves a half-written
     database.
   - **Memory** — `rootBundle.load` holds the whole asset in RAM before
     writing it (see `dict.db` under **Open Questions**). One copy helper for
     both databases, so the fix lands once.
   - **The web side of the same question** is the manifest + boot reconciler
     in [`db-auto-update-prestudy.md`](./db-auto-update-prestudy.md). Check
     whether mobile can share its versioning rather than invent a second one.
8. Repoint snippet path (now `_loadFileJson`/`_extractEntryText` in `_searchFullText`)
   and reader (`BJTDocumentLocalDataSourceImpl`) at the content datasource — see
   **Snippet-path teardown** below for the exact deletions.
9. **Stop shipping the JSON.** Remove `- assets/text/` from `pubspec.yaml` and
   keep the files in the repo — every build-time reader opens them from disk
   (see **Current Runtime Dependencies on JSON**), and so does `server/` until
   it is retired. Three things go with that line:
   - **The comment above `assets:`** says `text/` ships on native and the API
     serves it on web. Rewrite it to describe `databases/` alone.
   - **The web scripts' `assets/text` strip lines.** `scripts/web/deploy.sh`
     and `scripts/web/run_mac.sh` each `rm -rf build/web/assets/assets/text`,
     which does nothing once the files aren't bundled. Delete that line and
     keep the `databases` one beside it.
   - **Proof nothing still reads them.** Step 8's check covers only snippets.
     `grep -rn "assets/text" lib/` must find no loader (doc comments naming a
     file are fine), and a build must carry no `assets/text/` — on macOS, look
     under `the_wisdom_project.app/Contents/Frameworks/App.framework/Resources/flutter_assets/assets/`.
10. Verify offline reading + search snippets on a real device. Check first-launch
    DB copy time (`_initializeEdition` copies the asset DB to the documents dir;
    a bigger DB = bigger one-time copy + double on-disk during install), and
    that installing over an older build picks up the new database (step 7).
11. **Web now reads this DB client-side** (Drift wasm/OPFS) — see the top banner.
    The old `getWebOverrides()` → server route is being retired, not extended.
    Not part of step 6's branch: it needs the download-once path and the
    COOP/COEP headers first (README step 3).

    **Time the web decoder here.** Section 5 runs `package:archive`'s pure-Dart
    decoder on the Dart VM only, so time it and check its output once in a web build;
    if it is too slow there, swap just the unpacking call for
    `DecompressionStream` and keep the rest.

### Snippet-path teardown (step 8 detail)

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
- [ ] **Do not key the batched rows by `SearchResult.id`.** It is
      `editionId_filename_eind` with no language in it, so a Pali entry and its
      Sinhala twin share one id — real and common, e.g. `atta-dn-2-4` page 110
      entry 0 for "මහාසති". Key by
      `(filename, pageIndex, entryIndex, language)`.
- [ ] **Spell `language` the table's way, not the entity's.** That tuple exists
      in two vocabularies, and the seam between them is one line inside the loop
      being rewritten:

      | Where | Sinhala is |
      |---|---|
      | `bjt_content` rows, and `match.language` from FTS | `sinh` |
      | `SearchResult.language`, after the `normalizedLanguage` ternary | `sinhala` |

      The batched lookup runs **before** that normalize, so key it with
      `match.language` — already the table's spelling — and leave the normalize
      untouched where it is. Reach for `SearchResult.language` instead and every
      Sinhala lookup misses, silently, dropping those snippets to `''`.
      Group 9 addresses its goldens in the *other* vocabulary because they read
      finished `SearchResult`s; three of its fourteen rows are `'sinhala'`, and
      they are what goes red if this is got wrong.

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

- **~~Compression granularity~~ — decided 2026-09-14:** one page per blob,
  plain zlib; see **Blob size — decided**. The compression sample is optional
  and later. Nothing on this plan's critical path is open — the bullets below
  are real, but none blocks step 5.

- **`page_size` is a disk knob, not a download knob.** The 4/8/16/32 KB table
  sits next to the download discussion and reads as though a bigger page also
  shrinks the download. It does not. The 18.1 MB it moves is *slack* — mostly
  zero bytes — and an archive's deflate removes those for nothing. Raise it for
  on-device storage (which counts twice) and for web read I/O; do not count it
  against the download.

- **Delivery is an untouched axis.** Every figure here assumes the DB ships
  inside the APK/IPA. [`db-auto-update-prestudy.md`](./db-auto-update-prestudy.md)
  already designs a manifest + boot reconciler that downloads databases and
  reconciles them on launch — but only for web/OPFS. The same machinery on
  mobile, or its store-native equivalents (Play Asset Delivery, iOS On-Demand
  Resources), would take the install to a few megabytes and move the rest to a
  first-run fetch from R2, where egress is already free. It costs the *installs
  usable offline* property, which is why this is listed rather than proposed.
  Nobody has costed it.

- **`dict.db` — settled 2026-09-12: no size work, and here is why not.** It is
  in `pubspec.yaml` and ships in the APK, but appears in *none* of the headline
  figures above — "434 MB bundled / 529 MB on device (iOS) / 92 MB download"
  all exclude it. Including it, today is ~601 MB bundled, ~863 MB on device
  (iOS), ~120 MB downloaded.

  The download is fine and is not the target: the question asked was whether
  the *bundle* could come down, in one file, without getting slower, by enough
  to be worth a schema change and a regeneration — a bar set at 10 MB. Every
  lever clearing that bar costs download; every lever that leaves the download
  alone is under 3 MB. So nothing is done here.

  | lever | bundle | download |
  |---|---|---|
  | compress meanings | **saves ~70 MB** (166.6 → ~96) | 28.5 → ~50 MB |
  | drop `idx_word` via a clustered table | **costs 9.7 MB — the file gets bigger** | — |
  | deduplicate meanings | saves 2 MB | — |
  | 8 KiB pages | saves 2.6 MB — already shipped | — |
  | `dict_id` as INTEGER, drop `rank` | saves under 3 MB | — |

  **The ~28 MB download is the zip, not the database.** The APK stores the
  asset deflated — 174,686,208 → 29,907,287 bytes, **5.8×**. Anything done
  inside the database has to beat that, and nothing does:

  | compressing the 111.4 MB of meanings | ratio |
  |---|---|
  | whole file, one deflate stream — what the APK already does, free | **5.8×** |
  | per row + 32 KiB compression sample | 2.64× (42.2 MB) |
  | per row, plain deflate | 1.52× (73.4 MB) |
  | grouped by word | 1.50× — 463,337 distinct words, 1.29 entries each |

  Deflate over the whole file sees every `<b>` and `<br>` in the corpus; a
  196-byte row sees almost nothing. Compressing in the database also makes the
  bytes opaque to the zip. Net: disk 166.6 → ~96 MB, download **28.5 → ~50 MB**.
  Both numbers had to fall; one rises.

  Measured on the shipped file (166.6 MB, 596,835 rows; `dictionary` 145 MB +
  `idx_word` 20 MB by `dbstat`; meanings 111.4 MB, words 15.7 MB, mean 196 B).
  Why each lever was rejected, so none of them is re-derived:

  - **Shard DPD out.** Wins on both axes — DPD+DPDC are 463,458 rows and 73.6
    of the 111.4 MB; core-only is ~48 MB bundled, ~9 MB zipped. Rejected for
    the second file: most lookups want both dictionaries anyway.
  - **Compress the meanings.** The only lever above 10 MB, and the one that
    costs ~21.5 MB of download. Revisit only if the download stops mattering —
    the mechanism is measured and works (2.64× with a 32 KiB compression
    sample, round-trip verified).
  - **Clustered table** (`WITHOUT ROWID`, `PRIMARY KEY(word, dict_id, id)`).
    Drops `idx_word` entirely, so it looks like a free 20 MB. It is **not a
    saving — the file grows**, at both page sizes:

    | | 4 KiB | 8 KiB |
    |---|---|---|
    | today's schema | 166.6 MB | **164.0 MB** (shipped) |
    | clustered | 182.7 MB | 173.7 MB |
    | *of which overflow pages* | *8 → 37 MB* | *5 → 27 MB* |

    A `WITHOUT ROWID` table is an index b-tree, which caps inline payload near
    2 KB against a table page's 8 KB. 2,978 entries exceed that (max 69,879 B)
    and spill: overflow costs 22 MB where the dropped index saved 20 MB. The
    smallest of the four is what the pipeline already produces. Do not retry
    this — and note the sign, it has been misread once.
  - **Deduplicate meanings.** 586,993 distinct of 596,835 rows. 2 MB.
  - **8 KiB pages.** 166.6 → 164.0 MB. The pipeline sets it for the web read
    I/O, not the size.
  - **`dict_id` as INTEGER, drop the derivable `rank`.** Under 3 MB on disk,
    ~0 zipped.

  Two things are worth keeping, and neither is size work:

  1. **The lookup never uses its index.** `dictionary_local_datasource.dart:83`
     plans as `SCAN dictionary` — **41 ms against under 1 ms**, warm. `ESCAPE`
     is not the blocker; current SQLite handles it. The blocker is `LIKE` being
     case-insensitive by default against a BINARY `idx_word`. Prefer rewriting
     the predicate as `word >= ? AND word < ?`, which indexes unconditionally,
     over `PRAGMA case_sensitive_like=ON`, which changes behaviour globally. On
     web this is the whole 145 MB table per keystroke. Also spike §9c.
  2. **First launch allocates the file in RAM.**
     `dictionary_local_datasource.dart:40` loads all 166 MB into one `ByteData`
     before writing it out. `bjt-fts.db` needs the same copy, so this wants one
     shared streaming helper rather than a second copy of the bug — step 7.

  On Android `dict.db` costs ~28.5 + 166.6 ≈ 195 MB on the phone, not 333 MB:
  the APK keeps it deflated and only the first-run copy is full size. The same
  split, applied to the content table's headline, is under **Size — the bonus,
  on two axes**.

- **First-launch copy**: the content+FTS DB copies to the documents dir on first
  run and lives twice from then on — the 172 MB is why the iOS on-device figure
  is 344 MB and not 172. `dict.db` (166.6 MB) already copies to the same place, so the
  real first-run write is ~339 MB, up from ~262 MB today (the JSON is never
  copied). Every megabyte the table saves is saved twice — which is why
  `page_size` was taken at 8 KB. And it copies *only* on first run: an update
  never replaces it (step 7).
- **Reader rewrite risk**: this touches the reader (higher-risk code than
  search). Stage it: engine swap first (step 6), then the content table +
  snippet repoint, then the reader, and drop the assets last.
- **~~Footnotes / formatting markers~~ — answered.** The blob is the page's
  substructure verbatim, so footnotes and every marker come across by
  construction, and section 5 checked it entry for entry over the spike table:
  466,127 entries, 0 divergences. The one thing that did *not* come across was
  page metadata — `pageNum` is a sibling of the language sides, not inside them
  — which is why it is now a column. See the schema.

## Related

- [`README.md`](./README.md) — the parent plan: retiring the Dart content server.
- [`drift-fts5-wasm-spike-results.md`](./drift-fts5-wasm-spike-results.md) — the
  spike that cleared the FTS5 gate, and found the WAL flag and three live bugs.
- [`db-auto-update-prestudy.md`](./db-auto-update-prestudy.md) — how a rebuilt
  DB reaches a client that already has the old one (manifest + boot reconciler).
- `docs/general/how_search_works.md` — the search pipeline (Step 5 reads JSON).
- [`perf-fts-snippet-text-loading.md`](../../done/perf-fts-snippet-text-loading.md)
  — the shipped memo-cache fix this migration tears down.
