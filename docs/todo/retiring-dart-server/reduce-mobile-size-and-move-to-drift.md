# Faster Reads (and a Smaller App): Move Text into SQLite and the App onto Drift

> **Status 2026-09-18:** steps 1–9 done. `bjt.db` (renamed from
> `bjt-fts.db` at 7.1) carries `bjt_content` —
> one page per blob, **plain zlib** — and the app is on Drift: search, the
> dictionary, the reader and its snippets all read through it, with every
> suite green. A rebuilt database reaches the app's copy by a manifest hash
> and a stamp (step 7). **The JSON no longer ships** (step 9): 340 MiB off the
> macOS release bundle, 733 → 393 MiB, with the files kept in the repo for the
> build-time readers. **Next: step 11, web**, which is its own plan now:
> [`move-web-onto-drift.md`](../../done/retiring-dart-server/move-web-onto-drift.md). Two deletions
> from step 5 are deliberately still open: see **Left open after step 5**. A
> compression sample stays optional (**Compression sample — optional, later**).
>
> **No mobile release until
> [`first-mobile-release.md`](../mobile-release/first-mobile-release.md) is
> done.** It holds the real-device pass that was step 10, and everything else
> a phone release waits on.

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
>   media/audio store). The Flutter bundle and the static HTML are separate Pages
>   projects; only the heavy DBs live on R2. Details in
>   [`static-web-hosting.md`](../../decisions/static-web-hosting.md)
>   (Free-tier fit).
> - **~~Verify first (flag):~~ FTS5 in the Drift wasm build — PASSED 2026-09-11.**
>   `SQLITE_ENABLE_FTS5` is in the shipped binary, and the real `bjt-fts.db`
>   returns byte-identical rows through it — 15 queries × 7 engine
>   configurations, including the Sinhala `tokenchars` charlist honoured for
>   *writes* as well as reads. The spike found a different blocker instead (the
>   WAL header flag) and three live bugs in this repo: see **What the
>   Drift/wasm spike changed** below.
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
scripts: `tools/bjt-content-spike.js` built the real table into a copy of the
bundled DB, `tools/bench_content_read.dart` timed reads out of it.

**Both were deleted on 2026-09-20**, and neither was ever in git, so the
numbers below are the record, not the scripts. What was worth keeping out of
them moved into `tools/bjt-populate.js` at step 5 and into the datasource at
step 6, both noted where they land.

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

The FTS5-in-wasm spike passed its gate, and reviewed this repo on the way
past. Five of its findings land on the work below; each claim here was
re-verified locally against the shipped databases before being written down,
because a spike's numbers are its machine's.

### The build pipeline is now three steps, not one — and it was shipping a bug

Both generators ended in `VACUUM`. They now end in `finalizeDatabase`
(`tools/db-finalize.js`, shared by `bjt-populate.js` and
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

> **`dict.db` is still WAL-flagged** (header bytes 18/19 = 2/2, checked
> 2026-09-15). Step 5's rebuild fixed `bjt-fts.db`; `dict.db` has not been
> rebuilt. Run `npm run generate-dict` in `tools/`, or the repair one-liner
> `validate-release.sh` prints. The databases are untracked, so no commit
> carries the fix.

One consequence worth noting: once both generators end in `VACUUM INTO`, the
un-checkpointed-WAL branch in `verify_corpus_invariants.dart` becomes
unreachable for our own builds, and the `-wal`/`-shm` sidecars in
`assets/databases/` stop existing. Leave the branch — it cost nothing and it
was describing a real property of the file at the time.

### The blob decoder needs a web path

`dart:io` does not exist on web, and this same table is the web's content
source. `archive` and `drift` are in `pubspec.yaml` since step 6, and
`_decode` in `bjt_content_local_datasource.dart` is the one decode call.

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

1. **~~`ORDER BY score` has no tiebreaker~~ — fixed 2026-09-16, step 6.** bm25
   ties are common in this corpus: the first 5,000 hits for භගවා carry 622
   distinct scores, largest tie group 69 rows, so `LIMIT`/`OFFSET` paging could
   repeat or drop a row. `fts_local_datasource.dart` and
   `server/lib/src/handlers/fts_handler.dart` now both end
   `ORDER BY score, id`. Every suite passed with no expectation changed.

   It mattered to the safety net: Group 9's escape hatch, *"a row can drop out
   of the set with every snippet still byte-identical"*, is what an unstable
   tie produces under overfetch + `_limitToGroups`, and the engine then changed
   under it.
2. **~~Dictionary prefix lookup full-scans 175 MB on every word tap~~ — fixed
   2026-09-19, step 1 of [`move-web-onto-drift.md`](../../done/retiring-dart-server/move-web-onto-drift.md).**
   The three queries in `lib/data/datasources/dictionary_local_datasource.dart`
   used `LIKE ? ESCAPE '\'`, which never uses `idx_word`: 133 ms natively, and
   over OPFS the whole file through a JS callback. They are now
   `word >= :w AND word < :w || char(0x10FFFF)` — 0.4 ms — with the same rows,
   and the ORDER BY ends `word, id` so ties inside a dictionary no longer
   follow the query plan.
3. **`idx_bjt_meta_language` earns nothing** — two distinct values over 457k
   rows. Its only demonstrated effect is the misplan above. Consider dropping
   it in the same pipeline pass.

### Smaller constraints, for whoever writes steps 5–8

- **`SQLITE_DQS=0` on native too, now:** double-quoted *string literals* are
  an error. Under sqflite that was web-only; the SQLite `package:sqlite3`
  bundles natively is compiled the same way, so native tests catch it as well.
  Use single quotes (identifier quoting is unaffected). Existing SQL is clean.
- **`enableMigrations: false`** when Drift opens these. `user_version` is 0
  (verified), so the migrator would otherwise write into the shipped DB.
  Native passes it (`local_database_executor_native.dart`); web must too.
- **No `ATTACH`** between this DB and `dict.db`. Drift's OPFS mode is chosen at
  runtime by browser capability, and one of the two modes stores exactly two
  files. They are already separate files by design; this just forecloses ever
  joining across them.
- **`snippet()`/`highlight()` return NULL, not an error**, on a contentless
  table. Nothing calls them, which is why the manual snippet path exists — but
  a silent NULL is what a future caller would get.
- **`bjt_suggestions` does not exist** (verified), so every autocomplete call
  throws. Not a mystery: `GENERATE_SUGGESTIONS: false` in the populate script's
  config. **Settled 2026-09-20:** no screen calls `getSuggestions`, so the
  whole path went — the repositories, the datasources, `FTSSuggestion` and the
  populate script's word counting — in step 5 of
  [`move-web-onto-drift.md`](../../done/retiring-dart-server/move-web-onto-drift.md).

### What it did not change

The speed numbers, the parity contract, per-entry being ruled out, and the
slice shape for step 6. The spike is about the engine under the table, not the
table. Its own caveat has been half answered: it could not run the Dart layer at
all (pub.dev was blocked in that session), and Drift's worker negotiation and
its migration behaviour against a prebuilt file were then verified in Chrome on
2026-09-20 (`move-web-onto-drift.md` step 3). iOS and Firefox remain unverified,
as does this document's bench, which read with `File.readAsString` rather than
through `rootBundle` and sqflite's platform channel. Both sets of numbers are
floors, from different directions.

## Current Runtime Dependencies on JSON

Two code paths read `assets/text/{filename}.json` via `rootBundle`. **Both
moved to the content table at step 8**, which is what let step 9 drop the
assets:

1. **Search snippets** — `_searchFullText` in
   `lib/data/repositories/text_search_repository_impl.dart`. Was a per-match
   `_loadTextForMatch`, then the 2026-06-19 memo-cache quick win
   (`_loadFileJson` + `_extractEntryText` + `_fileJsonCache`), now one batched
   `loadPageSides`.
2. **Reader** — `BJTDocumentLocalDataSourceImpl.loadDocument` in
   `lib/data/datasources/bjt_document_local_datasource.dart` →
   `BJTDocumentParser`. Was the whole document; now the unit's pages.

Note: snippet **behavior/UX stays the same** — only its data source changes
(from JSON file → content table). It gets faster, not different.

Three other consumers read the same JSON from the filesystem rather than the
bundle, so none was affected by dropping the asset declaration — and they are why
the files stay in the repo:

- `tools/bjt-populate.js` (`fs.readFileSync`) — builds the FTS index.
- `static_site_generator/lib/data/corpus_reader.dart` — builds the public HTML site.
- `server/lib/src/handlers/fts_handler.dart` (`_loadTextForMatch` /
  `_loadJsonFile` / `_jsonCache`) — the one that is **not** build-time: it serves
  snippets to web at runtime, off the server's own filesystem. It is **not** being
  repointed at `bjt_content`; the whole `server/` tree is being deleted (see
  [`README.md`](./README.md)), and the JSON has to outlive it.

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
  natively, pure Dart on web, same call. A direct dependency since step 6. See
  **The blob decoder needs a web path**.
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
     `assets/databases/bjt.db`, so the first run after step 5 populates
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

     **It is also where the blob format is pinned**, so step 5 wrote to a
     contract rather than inventing one: one row per
     `(filename, pageIndex, language)`, with that page's `pageNum` in its own
     column and a **plain zlib** blob of that page's JSON substructure
     *verbatim* — the same object `pages[i]['pali']` decodes to, entries and
     footnotes and every other key. Not a remodelled one; Node writes and Dart
     reads, and anything app-shaped in the blob is a format two runtimes must
     agree about twice.

     The frame is sniffed from its header, and **plain zlib is the only answer
     that passes**. Everything else fails even where it decodes: gzip reads
     natively but comes back empty on web, a sample-flagged zlib header needs a
     sample the app doesn't have, and uncompressed JSON round-trips perfectly,
     so a lenient reader would report a clean run at 100% of plain JSON — the
     tool printing the number that says nothing was compressed while voting
     that all is well. Every blob is decoded by `dart:io` and by the web
     build's pure-Dart decoder, and fails where the two differ. A column
     holding TEXT rather than a BLOB is counted as its own failure too, rather
     than throwing on the cast and replacing a named finding with a stack
     trace.

     Proven end-to-end before the real table existed, against throwaway DBs
     written by `better-sqlite3`: a wrong page's content, an entry that is a
     string, and an entry whose `text` is a number are each caught and named;
     an absent `footnotes` key is distinguished from an empty one; missing rows
     are counted, and a row naming no corpus file separately. Step 5 proved the
     frame, `pageNum` and decoder checks the same way.
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
     time. **Resolved at step 8, without a new check:** the reader now parses
     one span at a time, so ids are per-document by design, and nothing reads
     `Entry.segmentId` — the note lives on the counter, and alignment work
     will derive ids from absolute coordinates instead.

   **Unrelated TODO, moved out 2026-09-14:** one entry point for every test path
   is its own plan now — [`test-all-and-release-all.md`](../test-all-and-release-all.md).
2. **Prove the speed win (primary goal) — DONE 2026-09-11. GO.** Snippets 13–586×,
   reader p50 45× with one slice in 1,411 a quarter-millisecond slower than
   today. Numbers and method in **What the measurements said**;
   `tools/bench_content_read.dart` was the throwaway that produced them.
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
   wants a signed build. Confirming it against a real artifact is section 4
   of [`first-mobile-release.md`](../mobile-release/first-mobile-release.md);
   it will not change the direction.

   **Answered 2026-09-14:** accepted. Plain pages ship at 114 MB; a
   per-language compression sample would bring it back to 95 MB with reads as
   fast, and is kept for later — see **Compression sample — optional, later**.
5. **Populate `bjt_content` — DONE 2026-09-15.** `tools/bjt-populate.js`
   (`createContentTable` + the page loop in `populateData`) writes one row per
   `(filename, pageIndex, language)`: that page's language side,
   `JSON.stringify`'d verbatim and `zlib.deflateSync`'d at level 9, with
   `pageNum` in its own column. The rows go in the same per-file transaction as
   the `_fts` / `_meta` rows. Writes stay in WAL mode; `finalizeDatabase` is
   what ships.

   **Section 5 was tightened before the real run:**
   - **Plain zlib only.** gzip now fails: it reads natively but comes back as
     empty bytes from the web decoder. A zlib header with the sample flag
     (FDICT) set fails too, shown as frame `zlib+sample`.
   - **Every blob is decoded twice**, with `dart:io`'s zlib and with
     `package:archive`'s `ZLibDecoderWeb` (`verify: true`, the web build's
     path), and fails where the bytes differ. `archive: ^4.0.9` is now a
     `tool/`-only dev dependency of `static_site_generator`, the version the
     app already locks.
   - **`pageNum` is compared** against `pages[i]['pageNum']` on every row. A
     table with no such column selects NULL in its place and fails each row by
     name.

   **Proved on a table built to fail.** A throwaway DB with one good row and
   five bad ones: gzip and `zlib+sample` were named as frames; a sample-flagged
   stream and a corrupted checksum as inflate failures (`Filter error, bad
   data`); a wrong `pageNum`; and a stream with two trailing bytes as a
   **decoder disagreement** (see step 6, Decoder). The good row was in none.
   The step 2–4 spike table now fails every row on frame and `pageNum` while
   its entries still match.

   **Result on the real build:**

   | | |
   |---|---|
   | rows | 57,934 over 285 files; none missing, none extra |
   | entries compared | 466,127; zero divergences of any kind |
   | frames | every blob `78 DA` (zlib, level 9) |
   | blobs | 66.5 MB, 23.3% of the JSON they hold; largest 3.7 KB |
   | `bjt_content` on disk | 74.9 MB + 1.4 MB primary-key index |
   | `bjt-fts.db` | 94.8 → **170.8 MB** (the plan said 172) |
   | header | 8 KB pages, bytes 18/19 = 1/1, `sqlite_stat1` written, no sidecars |
   | build / verify time | 25 s / 31 s |

   **The search index did not move.** `bjt_meta` hashes the same before and
   after (456,977 rows; SHA-256 over every column in `id` order), and two
   `MATCH` counts agree (`භගවා` 11,459, `බුද්ධ*` 16,537). So the old file
   matched the vendored JSON despite its older timestamp, and the counts
   Groups 1–8 pin have no reason to move. The integration suites were not run.

   Nothing else needs wiring: `static_site_generator/test/corpus_tools_test.dart`
   runs the verifier with no flag, so it enforces section 5 from now on.

   **Recap for whoever starts step 6** — what step 5 leaves you:
   - **The table.** `bjt_content(filename, pageIndex, language, pageNum,
     blob)`, keyed on `(filename, pageIndex, language)`, inside
     `assets/databases/bjt.db`. `filename` is the JSON name without
     `.json` (`an-1`), the same key `bjt_meta` uses. Every page has both a
     `pali` and a `sinh` row, so a missing row really is a fault.
   - **The blob** inflates to exactly `pages[i]['pali']` or `['sinh']` from the
     JSON. `pageNum` is the printed page number, not `pageIndex + 1`: take it
     from the column.
   - **Nothing in the app reads the table yet.** Snippets and the reader still
     load `assets/text/*.json` until step 8.
   - **Rebuild and check:** `npm run generate-bjt` in `tools/`, then
     `dart run tool/verify_corpus_invariants.dart` in `static_site_generator/`.
     Section 5 already proves the table matches the JSON entry for entry, so if
     step 8 shows a page differently from today, suspect the datasource, not
     the data.
   - **Suites:** green before and after the swap (step 6), though macOS read
     a January copy of the index, not this build (see step 7).
     `all_tests.dart` can flake when files share the database; re-run a
     failing file alone before blaming a change.
   - **The decoder traps** are under **Decoder** in step 6.

   **~~Left open after step 5~~ — cleared 2026-09-20.** The step 2–4
   throwaways (`tools/bjt-content-spike.js`, `tools/bench_content_read.dart`,
   `tools/bjt-content-spike.db`), the pre-rebuild backup
   `tools/bjt-fts.pre-step5.db`, the obsolete `tools/bjt-fts4.db` and the
   `.gitignore` block that named the scripts are all deleted — 407 MB of
   database and two scripts, none of them ever in git. Their numbers stay in
   **What the measurements said**.
6. **Move the app to Drift, then add the content datasource on top — DONE
   2026-09-16.** One branch, two stages, and no `sqflite` version of the
   datasource was ever written. Web keeps its server path and moves at step 11.

   **Tiebreaker first, on its own:** `ORDER BY score, id` (bug 1). Suites
   green, no expectation changed.

   **Stage 1 — the engine swap.** `sqflite` and `sqflite_common_ffi` left
   `pubspec.yaml` for `drift`; `package:sqlite3` bundles one SQLite build on
   every native platform.
   - `lib/data/database/bundled_database.dart`: **`BundledDatabase`**, a
     table-less `GeneratedDatabase` whose `rawQuery(sql, args)` wraps
     `customSelect`, so every query kept its text. Its statics `open` and
     `closeShared` keep one connection per file for the whole app — what
     sqflite's one instance per path gave. FTS and page text share a
     connection, and two first-launch readers can't copy the same asset at
     once. The static can't be named `close`: Drift's instance `close()`
     already is.
   - `bundled_database_executor_native.dart`: the copy-if-absent both
     datasources used to repeat, now written once, then
     `NativeDatabase.createInBackground(file, enableMigrations: false)`. Its
     `_web.dart` twin throws, and the conditional export keeps `dart:ffi` out
     of the web build.
   - `main.dart` lost the desktop FFI setup; `lib/core/utils/platform_utils*`,
     used only for it, is deleted.
   - `fts_language_filter_sql_test.dart` runs on an in-memory `BundledDatabase`.

   Unit and every integration file, each run alone on macOS, were green at
   three checkpoints — before any change, after the tiebreaker, after the
   swap — with no expectation changed and no Drift warning or SQLite error in
   any log. `flutter build web --release` still builds. **Not run: Android and
   iOS** (no SDK or signing here) — see
   [`first-mobile-release.md`](../mobile-release/first-mobile-release.md).

   **Stage 2 — the content datasource.**
   - **The page-span rule has one home:** `SliceRange.pageSpan` returns a
     `SlicePageSpan(firstPage, lastPage?, endEntry?)` in `wisdom_shared`, from
     coordinates alone. `DocumentSlice.of` consumes it and keeps only the
     clamping a loaded document needs.
   - **`BJTContentDataSource`** and `BJTContentLocalDataSourceImpl`
     (`lib/data/datasources/bjt_content_*`), on the FTS index's connection:
     - `loadPages(fileId, firstPage:, lastPage:)` — the span in one query, each
       page shaped like an item of the JSON's `pages` list
       (`{pageNum, pali, sinh}`), so `BJTDocumentParser` reads it unchanged. A
       page missing a language throws a `StateError` naming the row.
     - `loadPageSides(keys)` — the snippet batch, keyed by `ContentPageKey`
       `(fileId, pageIndex, language)` in the table's spelling. It joins
       against a `VALUES` list, so each key is one primary-key seek; the
       row-value `IN` planned as two IN lists, filename × page. A missing or
       corrupt row is left out and costs only its own snippet.
     - Both queries `CAST(blob AS BLOB)`. A value stored as TEXT is otherwise
       read as a string inside SQLite and fails the whole query before the row
       can be named.
   - `archive` is a direct dependency. **No provider and no caller yet** —
     step 8 wires it.

   **Verified by a throwaway probe**, outside the repo, through the real
   datasource, Drift and a copy of the real `bjt-fts.db`. Every page of every
   content file equals its JSON and parses to an identical `BJTDocument`,
   segment ids included: 0 mismatches, 11 s. Also: bounded, open-ended,
   one-page and empty spans; batched sides across 40 files with a missing key
   left out; a page past the end, an unknown file and a deleted language row
   each throwing with the row named; and seven broken blobs — empty, cut
   short, bad checksum, changed byte, gzip header, plain JSON, stored as TEXT —
   each becoming a `FormatException` naming the row, and left out of
   `loadPageSides` while the other language survives. The TEXT case failed
   first; it is what added the `CAST`.
   **Decoder — the record behind `_decode`.** `package:archive`'s
   `ZLibDecoder` with `verify: true`: `dart:io`'s zlib natively, pure Dart on
   web, and step 5 ran both over every blob. **A bad blob fails differently on
   each, and neither always throws** (probed 2026-09-15):

   | Broken blob | Native (`dart:io`) | Web (pure Dart) |
   |---|---|---|
   | bad checksum | throws `FormatException` | empty bytes |
   | a byte changed mid-stream | throws `FormatException` | throws `RangeError` or empty bytes, by position (one tried to allocate ~24 GB and ran out of memory) |
   | cut short | part of the page, no error | throws `RangeError` |
   | trailing bytes | whole page, no error | empty bytes |
   | gzip frame | whole page, no error | empty bytes |

   So an empty-bytes check alone misses a cut-short blob on native. `_decode`
   decodes and parses in one `try` — part of a page is never a whole JSON
   object — and turns every failure, `Error` included, into one
   `FormatException` naming the row. No real blob does any of this today:
   section 5 would fail.

   **Recap for whoever starts step 8** — all of it done there: snippets read
   `loadPageSides` keyed with `match.language`, the reader reads `loadPages`
   over `SliceRange.pageSpan`, and the segment-id counter still restarts per
   parse (step 8 records why that is safe today).

   **Left open after step 6** — raised by the review, none of them a bug
   (2026-09-16); nothing in step 7 waits on them:
   - **The declared SDK floor is stale.** `pubspec.yaml` still says
     `sdk: '>=3.5.2 <4.0.0'`, while `pubspec.lock` already resolved to
     `>=3.12.0` — drift and `package:sqlite3` both need a recent Dart, so the
     declared floor could not resolve anyway. Raise it **in its own commit,
     with a `dart format` pass**: a floor past 3.7 switches the formatter to
     tall style and rewrites most of the repo, which would bury this one.
   - **`dontWarnAboutMultipleDatabases` is set per connection**, in
     `BundledDatabase._connect`, rather than once. The assignment is global and
     idempotent, so it costs nothing; the comment beside it says why silencing
     it for every class is safe here.
   - **`DictionaryDataSourceImpl.close()` guards on `_database != null`** where
     `_initialized` beside it says the same thing.
   - **`_log` is hand-copied into five datasources.** A shared two-line helper
     earns its place at five, but it touches files this branch otherwise leaves
     alone — the user's call, like the step 5 deletions above.
7. **Make a rebuilt database reach the app's copy — DONE 2026-09-17.**
   `openBundledExecutor`
   (`lib/data/database/bundled_database_executor_native.dart`), which both
   databases open through, used to copy the asset out of the bundle only when
   no copy existed. So a rebuilt database never reached a device that already
   had a copy, and after step 8 an old copy, with no `bjt_content`, would
   break reading and snippets.

   **It had already happened on the dev Mac.** The macOS app's copy was a
   `bjt-fts.db` made on 15 Jan 2026, and every macOS run until this step read
   it, step 6's green suites included. Checked 2026-09-17: its `bjt_meta` rows
   (456,977) and both `MATCH` counts (`භගවා` 11,459, `බුද්ධ*` 16,537) equal
   today's `bjt.db`. It lacked `bjt_content`, and one other count differed:
   see the suites below.

   **Nothing has been released**, so no install holds an old copy. No code
   deals with old file names or old copies; the dev Mac's were deleted by hand.

   **What was built:**
   - **Fingerprint: a manifest.** `finalizeDatabase` (`tools/db-finalize.js`)
     ends by writing the finished file's SHA-256 into
     `assets/databases/manifest.json`:
     `{"bjt.db": {"sha256": "…"}, "dict.db": {"sha256": "…"}}`. It updates only
     that file's entry, keys sorted. Gitignored like the databases, so the two
     always travel together, and listed in `pubspec.yaml`, so a checkout that
     never ran a generator fails at build time, as a missing database already
     does. The builds are not byte-identical, so every rebuild changes the
     hash and costs one recopy. Accepted.
   - **A stamp beside the copy.** `openBundledExecutor` gets the manifest's
     hash for `dbName` from `bundledDatabaseSha256`
     (`bundled_database_manifest.dart`, plain Dart, so web needs no twin),
     which throws a `StateError` naming the `npm run generate-…` command if
     the entry is missing. The copy is current when `bjt.db` exists **and**
     `bjt.db.sha256` holds that hash; both are checked because the OS can
     delete one file of the pair. Otherwise it deletes the stamp, then the old
     copy, writes the asset straight to `bjt.db`, and writes the stamp last.
     The stamp is the only mark of a finished copy, so a launch killed at any
     point copies again next time. The stamp goes first because it can already
     hold this hash, when only the copy was deleted. Deleting the old copy
     first means an update needs room for one copy, not two, and no temp file
     is left behind. A copy that throws — a phone that fills up, say — deletes
     its partial file before rethrowing, since nothing else would: Android
     never clears the files folder. This runs inside
     `BundledDatabase._connect`, once per file per launch, before a connection
     exists, so nothing is deleted under an open database.
   - **A full phone is still a bad place to be:** every search retries the
     copy. What it should do instead is decided on a device, in
     [`first-mobile-release.md`](../mobile-release/first-mobile-release.md).
   - **Where: a `databases/` folder** the code creates, in a place that
     depends on the platform:
     - **Android: the files folder**, `getApplicationSupportDirectory()`.
       Android clears the cache folder whenever the phone needs space, and
       cleaner apps clear it too. A recopy there is the costly kind: the asset
       is compressed in the APK, and the engine inflates all of it on the UI
       thread (see the `main.dart` change below). The files folder is backed
       up, so `android/app/src/main/res/xml/backup_rules.xml` (Android 11 and
       lower) and `data_extraction_rules.xml` (12 and higher) leave
       `databases/` out. Over Auto Backup's 25 MB limit, Android would skip
       the app's whole backup, settings included.
     - **Everywhere else: the cache folder**, `getApplicationCacheDirectory()`.
       It is left out of iCloud backups and stays out of a Windows or Linux
       user's own Documents folder. If the OS clears it, the next open copies
       from the app package again, with no download and no extra code. The
       asset isn't compressed on these platforms, so that costs about 0.7 s per
       file on the dev Mac. The sandboxed macOS app's folder is
       `~/Library/Containers/lk.tipitaka.theWisdomProject/Data/Library/Caches/lk.tipitaka.theWisdomProject/databases/`.
   - **Memory: written in 8 MB pieces**, through a `RandomAccessFile`, each
     piece a `Uint8List.sublistView`. `rootBundle.load` still loads the whole
     asset; avoiding that needs native code per platform, which isn't planned.
     A whole `Uint8List` given to `writeAsBytes`, or to
     `writeFrom(whole, start, end)`, goes to dart:io's IO thread as it is; a
     partial view is copied into a buffer its own size
     (`_ensureFastAndSerializableByteData`, `dart:io` `common.dart`).
     **Measured on macOS** (`ProcessInfo.maxRss` around the `bjt.db` copy,
     2026-09-17): one `writeAsBytes` raised the peak 342 MB; 8 MB pieces
     raised it 211 MB and 230 MB in two runs. So the pieces remove about one
     extra copy of the file.
   - **No sidecar handling.** The copies are only read and use a rollback
     journal (header bytes 18/19 = 1), so SQLite never creates `-wal`, `-shm`
     or `-journal` for them. None existed after the suites ran.
   - **Web uses the same fingerprint.**
     [`move-web-onto-drift.md`](../../done/retiring-dart-server/move-web-onto-drift.md) reads this manifest
     in the browser; the hash names each version's OPFS folder and its file on
     R2. No web code now.
   - **Nothing checks the manifest against the files yet.** The app trusts
     it, so a database changed outside `finalizeDatabase` (copied in by hand,
     repaired with `sqlite3`, or left half-written by a failed generator run)
     would leave existing installs on their old copy. The check belongs to
     `scripts/app/test.sh`'s "shipped databases" row in
     [`test-all-and-release-all.md`](../test-all-and-release-all.md).
   - **`validate-release.sh` is not taught the manifest.** It is being
     retired ([`test-all-and-release-all.md`](../test-all-and-release-all.md));
     one comment line there says the omission is deliberate.

   **Done by hand first:** deleted the old copies in
   `~/Library/Containers/lk.tipitaka.theWisdomProject/Data/Documents/`
   (`bjt-fts.db`, `dict-fts.db`, `dict.db`, each with `-wal`/`-shm`; about
   500 MB), then rebuilt both databases (`npm run generate-bjt`, then
   `npm run generate-dict`) so the manifest has both entries. The `dict.db`
   rebuild cleared its WAL flag (bytes 18/19 now 1/1) and took it from
   174.7 MB to 164.0 MB.

   **Checked on macOS**, launching with
   `integration_test/search_language_toggle_test.dart` (it opens both
   databases), with temporary log lines since removed:
   - Rebuilding `dict.db` changed only its manifest entry, and the next launch
     copied only `dict.db`.
   - With `bjt.db`'s manifest entry removed, the open failed with
     `Bad state: assets/databases/manifest.json has no entry for bjt.db. Rebuild the database: cd tools && npm run generate-bjt`.
     The search repository turns that into a `Failure`, so the screen shows no
     results rather than the message, as for any database that fails to open.
     Not changed here.
   - Suites: unit 638 passed. Integration 77 passed, 1 failed, and it failed
     alone too: `B2 Pagination` in `search_flow_integration_test.dart` pinned
     `Viewing 50 out of 29769 results` for `මහා`. The real `bjt.db` has 29,770
     `MATCH 'මහා*'` rows, and so does the July backup
     `tools/bjt-fts.pre-step5.db`; the pin was taken against the January copy
     (test added 2026-02-20). The user approved moving the pin to 29770; the
     file then passed (32/32). No `-wal`, `-shm` or `-journal` in the cache
     folder afterwards. `flutter analyze` is clean.

   **Checked again after a review the same day** changed the copy (delete
   first, delete the partial file if it throws), the folder, and where the
   manifest reader lives. A throwaway probe ran in the macOS app, reading the
   copy's modified time:
   - The first open created `databases/` and copied. Both copies and both
     stamps match the assets (`shasum`).
   - A reopen copied nothing.
   - A stale stamp, a deleted copy with its stamp kept, and a deleted stamp
     with its copy kept each copied again and ended with a matching stamp.
   - Every open answered a query, and the folder held only the two copies and
     their stamps.
   - The copies from before the change, in the cache folder itself, were
     deleted by hand.
   - With the folder deleted first, `search_language_toggle_test.dart` passed
     on macOS (1/1) and left both copies matching the assets. The other
     suites were not run again.
   - **Not exercised:** the failed-copy path. Filling the disk isn't
     reproducible here; the full-phone check in
     [`first-mobile-release.md`](../mobile-release/first-mobile-release.md)
     covers it.
   - **Android is unchecked:** this Mac has no Android SDK. The same doc
     covers the files folder and the backup rules.

   **Also changed: the startup check in `main.dart`.** It checked `bjt.db` was
   bundled with `rootBundle.load('assets/databases/bjt.db')`. It now calls
   `bundledDatabaseSha256('bjt.db')`. A build missing the database or the
   manifest file already fails to build, so the check catches a manifest with
   no `bjt.db` entry. The error screen now shows the caught error, which names
   the command to run, instead of showing no search results. Checked in the
   real macOS app.
   - **The memory saving is Android's, not macOS's.** Measured on macOS
     (debug, `maxRss` just after the check): 251 MB before, 248 and 252 MB
     after. The engine maps a large asset from disk without copying it
     (`platform_message_response_dart.cc`), so the old load read nothing. On
     Android the asset sits compressed in the APK (no `noCompress`), and
     `AAsset_getBuffer` inflates the whole file into memory
     (`apk_asset_provider.cc`) on every launch, on the UI thread. Read from
     the engine source, not measured: Android has not been built since the
     move to Drift. The copy still pays that once per install or database
     update. Whether `noCompress` for `.db` is worth its installed size is
     decided in [`first-mobile-release.md`](../mobile-release/first-mobile-release.md).

   **7.1 — Rename `bjt-fts.db` to `bjt.db` — DONE 2026-09-16, in its own
   commit.** The file stopped being a search index at step 5: it holds
   `bjt_content` beside `bjt_fts` and `bjt_meta`, and `dict.db` has no suffix
   either. No behaviour changed.
   - **Names:** `_dbNameFor` is `'$editionId.db'`; the content datasource's
     `_dbName` is `bjt.db`. The generator is `tools/bjt-populate.js`, run with
     `npm run generate-bjt` — the pair `dict-populate.js` / `generate-dict`
     already set. **Table names did not move**: they are `{editionId}_*`,
     independent of the file name.
   - **Live references moved** in `lib/`, `pubspec.yaml`, `server/`,
     `tools/`, `scripts/bjt-sync-regen/`, the static site generator's tools,
     test and `UPSTREAM_DEFECTS.md`, `.agent/`, and the live docs.
   - **Records kept the old name**: `docs/done/`, `docs/decisions/` (except
     one pointer to the generator, now by function name), dated measurements
     in this plan, the FTS4 file in `performance_test_queries.md`,
     `tools/bjt-fts-populate-obsolete.js`, and the untracked
     `tools/bjt-fts*.db` leftovers.
   - **`bjt_suggestions` does not exist** (this step's text said it did). It
     was not in the step-5 backup either — see the spike's §8c.

   **Checked:** the rebuilt `bjt.db` has the same size (170.80 MB), rows
   (456,977 meta, 57,934 content) and `MATCH` counts (`භගවා` 11,459,
   `බුද්ධ*` 16,537) as step 5; the bytes differ, the build is not
   byte-deterministic. `verify_corpus_invariants.dart` with no flag found
   `bjt.db` and passed section 5 (466,127 entries, 0 divergences).
   `flutter analyze` is clean. `validate-release.sh`'s database checks pass
   for `bjt.db` and fail only on `dict.db`'s WAL flag (**Left open after
   step 5**).
8. **Both readers of the JSON now read the table — DONE 2026-09-18**, committed
   as `d9965fd`. Snippets and the reader in one change, on the user's
   instruction to keep them together. Nothing in `lib/` loads
   `assets/text/*.json` any more, which is what step 9 waited on.

   **The snippet path.** `_fileJsonCache`, `_loadFileJson` and
   `_extractEntryText` are gone from `text_search_repository_impl.dart`, with
   the `dart:convert` and `flutter/services.dart` imports they were the last
   users of. In their place `_searchFullText` collects one
   `Set<ContentPageKey>` before the loop and makes a single `loadPageSides`
   call, then `_entryTextFrom` picks each entry out of the returned rows.
   - **Both language sides of a hit's page are asked for**, not just the
     matched one: the old loader fell back to the other language when the
     matched side carried no text at that entry, and the goldens pin what that
     produced. Doubling the keys costs nothing — a results page asks for about
     100 primary-key seeks.
   - **The keys are built from `match.language`**, before the
     `normalizedLanguage` ternary, so they are spelled the table's way
     (`sinh`). The `SearchResult.id` trap was avoided by not keying on it at
     all: `_entryTextFrom` takes `(fileId, pageIndex, entryIndex, language)`.
   - **A failed batch costs the snippets only.** `loadPageSides` already
     leaves out single corrupt rows; the call is also wrapped, because the
     JSON loader caught its own failures per file and "a missing snippet never
     fails the search" is the invariant that path documents. A database that
     will not open now loses the previews, not the results.
   - **Web is unchanged.** `_contentDataSource` is nullable and the server
     pre-fills `matchedText`, so the guard that skipped the file read skips the
     batch. `LRUCache` stays — `caching_text_search_repository.dart` and
     `cache_config.dart` use it.

   **The reader loads its unit's pages, not its file.** This is where the
   measured 45× comes from, and it needed the three decisions below.
   `BJTDocumentLocalDataSourceImpl` now holds a `BJTContentDataSource` and
   parses `{'pages': rows}`; the span travels
   `bjtDocumentProvider` → use case → repository → datasource as
   `(firstPage, lastPage)`.
   - **`BJTDocument.firstPageIndex`** (default 0) is the index of `pages.first`
     in the file. `DocumentSlice.of` and `getPageByIndex` translate through it
     instead of indexing `pages` directly, so **one slicing path serves both
     surfaces**: the reader's document holds its span, the web server's holds
     the whole file at 0, and neither needs to know which it got. `pageCount`
     now means the loaded span, so `lastPageIndex` was added beside it.
   - **A span past the file's last page stops there.** `loadPages` keeps
     `_whole` strict for a hole *inside* the span and truncates only the tail,
     matching the clamp `DocumentSlice.of` has always done. An empty result
     costs one `SELECT 1 … LIMIT 1`: no rows for the file at all is a tree
     pointing at content that does not exist, and throws with the name, while
     a span starting past a real file's end comes back empty and renders
     nothing.
   - **`close()` was left alone.** Still nothing calls it at runtime, so the
     shared connection needs no ref-counting — as the step 6 note said, settle
     it when a caller appears.
   - **The provider key is a record**, `({fileId, firstPage, lastPage})`, so
     two tabs on the same unit share one load and two units in one file do not
     collide. Same reason the repository's own cache key gained the span.
     `requestFor(unit)` builds it in one place; the reader, in-page search
     (which reads a *specific* tab's document, not the active one) and the
     citation preview all go through it.
   - **The citation preview got faster for free.** It quoted three entries out
     of a whole decoded file; `requestForPage` fetches the one page it shows.
   - **`loadPageSides` is still one statement.** Three bind variables per key
     against SQLite's 32,766 caps a batch near 10,900, and a results page asks
     for about 100. Unchanged.

   **Segment ids are per-parse, and now that means per-span.** The parser's
   counter starts at 0 on every `parseDocument`, so a unit's ids no longer
   count from the top of its file. Nothing reads `Entry.segmentId` — only
   `bjt_document_parser_test.dart` pins it — so this breaks nothing today, and
   the note step 1 asked for is on the counter itself: cross-edition alignment
   will have to derive ids from the absolute page and entry rather than trust
   these.

   **Checked on macOS, 2026-09-18.** `dart analyze` clean, `dart format`
   clean. **638 unit tests pass, unchanged, and no test file was edited** —
   the regenerated mockito mock fills `firstPage: 0` by default, so the
   repository's existing stubs still match its new signature.

   **Every integration file passed, each run alone — 78/78**, against step 7's
   77-pass-1-fail (that failure was the `මහා` count pin, since corrected):

   | | |
   |---|---|
   | `search_flow_integration_test.dart` | 32 — **including all five Group 9 snippet goldens** |
   | `in_page_search_test.dart` | 8 |
   | `sutta_step_navigation_test.dart` | 13 |
   | `breadcrumb_navigation_test.dart` | 8 |
   | `layout_switch_test.dart`, `scroll_restoration_test.dart`, `dictionary_editable_word_test.dart` | 4 each |
   | `dictionary_filter_flow_test.dart` | 2 |
   | `language_independence_test.dart`, `search_tab_highlight_test.dart`, `search_language_toggle_test.dart` | 1 each |

   Group 9 is the one that matters: it pins snippet rows byte-for-byte,
   including `**bold**`, `{n}` refs, embedded newlines and zero-width joiners,
   and three of its fourteen rows are Sinhala — the rows that go red if the
   `sinh`/`sinhala` seam is got wrong. Group 2's highlighting check passed too,
   so the markers survive the round trip.

   **One run hung and it was not this change:** an `in_page_search_test` launch
   sat at 0% CPU after `Failed to foreground app; open returned 1`. Re-run
   alone it passed 8/8 in 2:22. Worth knowing before blaming a diff — it looks
   exactly like the shared-database flake, and is neither.

   **Not exercised, reasoned instead:** a missing or corrupt row degrading to
   an empty snippet. `loadPageSides` leaves bad rows out (step 6 probed all
   seven corruptions) and the call site's `?? ''` is unchanged, but no test
   feeds the app a broken row.

   **The speed win is inherited, not re-measured.** Step 2 timed the two paths
   directly (snippets 13–586×, reader p50 45×); this step wired them up and
   proved the *text* is identical, not that the app got faster. Nobody has
   timed a search or a reader open in the real app before and after. If that
   number is wanted, take it on a device — an optional item in
   [`first-mobile-release.md`](../mobile-release/first-mobile-release.md).

   **Recap for whoever starts step 9:** its first check already passes —
   `grep -rn "assets/text" lib/` now finds nothing at all, the last doc comment
   naming the JSON having moved to `bjt_content`'s vocabulary. What remains is
   `pubspec.yaml`, the comment above `assets:`, the two web scripts' strip
   lines, and a built artifact that must carry no `assets/text/`.
9. **Stop shipping the JSON — DONE 2026-09-18.** `- assets/text/` is out of
   `pubspec.yaml`, and the 285 files stay in the repo: `tools/bjt-populate.js`
   and `static_site_generator/lib/data/corpus_reader.dart` open them from disk
   (see **Current Runtime Dependencies on JSON**), and so does `server/` until
   it is retired. The comment above `assets:` now describes `databases/` alone,
   and the dead `rm -rf build/web/assets/assets/text` line is gone from both
   `scripts/web/deploy.sh` and `scripts/web/run_mac.sh` — the `databases` line
   beside it stays. Three files changed; no Dart was touched.

   **The number this plan exists for.** macOS release `.app`, both builds from
   this same tree so the only variable is the pubspec line:

   | | before | after |
   |---|---|---|
   | `the_wisdom_project.app` (`du -sh`) | **733 MiB** | **393 MiB** |
   | as `flutter build` reports it | 767.9 MB | 412.1 MB |
   | `flutter_assets/assets/text` | 340 MiB, 285 files | **absent** |
   | `flutter_assets/assets/databases` | 335 MiB | 335 MiB |

   **340 MiB comes off, 46% of the app**, and the delta is exactly `assets/text`
   — nothing else moved. What remains is mostly the two databases: `bjt.db`
   171 MiB + `dict.db` 164 MiB.

   **This is not the mobile figure.** It is a macOS bundle, it includes
   `dict.db`, and steps 3–4 costed the APK/IPA with `dict.db` excluded, so it
   neither confirms nor replaces them. In particular the **download** still
   rises (92 → 114 MB, step 4): a pre-compressed blob cannot deflate again.
   Nothing here was measured out of a real APK or IPA; that is in
   [`first-mobile-release.md`](../mobile-release/first-mobile-release.md).

   **How absence was proved**, three ways, since a size drop alone would not
   show it:
   - `grep -rn "assets/text" lib/` finds nothing at all — step 8's precondition,
     re-verified before the edit.
   - `AssetManifest.bin` in the built app carries **zero** `assets/text` entries,
     so `rootBundle` cannot resolve one even if a caller reappeared.
   - A `flutter clean` build has no `assets/text` directory at all, and `find`
     over the whole `.app` turns up no JSON under any `text` path.

   **Checked on macOS, 2026-09-18, with the JSON no longer in the bundle.** No
   Dart changed at this step, so nothing was re-analyzed; what matters here is
   runtime, and only the app-launching suites can see an asset that stopped
   shipping. **638 unit tests pass**, and **every integration file passed, each
   run alone — 78/78**, both identical to step 8's counts:

   | | |
   |---|---|
   | `search_flow_integration_test.dart` | 32 — **including all five Group 9 snippet goldens** |
   | `sutta_step_navigation_test.dart` | 13 |
   | `in_page_search_test.dart`, `breadcrumb_navigation_test.dart` | 8 each |
   | `layout_switch_test.dart`, `scroll_restoration_test.dart`, `dictionary_editable_word_test.dart` | 4 each |
   | `dictionary_filter_flow_test.dart` | 2 |
   | `language_independence_test.dart`, `search_tab_highlight_test.dart`, `search_language_toggle_test.dart` | 1 each |

   Group 9 is again the one that carries the argument: it pins snippet rows
   byte-for-byte, and it passed against a bundle with no JSON in it. The same
   goes for the reader — `sutta_step_navigation` walks real suttas. So the text
   the app shows now provably comes from `bjt_content`. `in_page_search` did not
   hang this run.

   **An incremental rebuild leaves an empty `assets/text/` directory behind.**
   The 285 files go, the directory does not. It is stale build residue, 0 bytes,
   and a clean build never produces it — worth knowing before reading it as a
   failure. The first `flutter build macos` after the edit also died once on
   `Failed to copy Flutter framework`; it built on an unchanged retry.
10. **The real-device pass — moved 2026-09-18** to
    [`first-mobile-release.md`](../mobile-release/first-mobile-release.md),
    with everything else a mobile release waits on.
11. **Web onto Drift — moved 2026-09-18** to
    [`move-web-onto-drift.md`](../../done/retiring-dart-server/move-web-onto-drift.md), its own plan.

### What the snippet path lost at step 8

The interim memo-cache fix
([`perf-fts-snippet-text-loading.md`](../../done/perf-fts-snippet-text-loading.md),
shipped 2026-06-19) was deliberately isolated, so repointing it was a two-method
deletion rather than a rewrite: `_fileJsonCache`, `_loadFileJson` and
`_extractEntryText` went, the call-site shape (`matchedText ?? <load> ?? ''`,
grouped before the loop) stayed, and only the loader was replaced. What
replaced it, and the two vocabulary traps it had to get right, are in step 8.

**Server — nothing to port.** `server/lib/src/handlers/fts_handler.dart` has its own
`_loadTextForMatch` / `_loadJsonFile` / `_jsonCache`, but the whole `server/` tree is
being deleted (see [`README.md`](./README.md)) — web reads the same DB client-side
through Drift. It goes with the server; do not repoint it at `bjt_content`.

**Became moot at step 8 — don't build:**
- Top-10 #2 Phase 3 (decode off the UI isolate) — a row lookup never janks.
- Track B #4 (windowed payload) — windowing is now a substring on the fetched
  row, decoupled from any file parse.

## Open Questions / Risks

- **~~Compression granularity~~ — decided 2026-09-14:** one page per blob,
  plain zlib; see **Blob size — decided**. The compression sample is optional
  and later. Nothing on this plan's critical path is open — the bullets below
  are real, but none blocks step 6.

- **`page_size` is a disk knob, not a download knob.** The 4/8/16/32 KB table
  sits next to the download discussion and reads as though a bigger page also
  shrinks the download. It does not. The 18.1 MB it moves is *slack* — mostly
  zero bytes — and an archive's deflate removes those for nothing. Raise it for
  on-device storage (which counts twice) and for web read I/O; do not count it
  against the download.

- **Delivery is an untouched axis.** Every figure here assumes the DB ships
  inside the APK/IPA. Downloading it instead is listed, not costed, under
  **Later** in [`first-mobile-release.md`](../mobile-release/first-mobile-release.md).

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

  1. **~~The lookup never uses its index~~ — fixed 2026-09-19** (step 1 of
     `move-web-onto-drift.md`). `lookupWord` in
     `dictionary_local_datasource.dart` planned as `SCAN dictionary` — **41 ms against under 1 ms**, warm. `ESCAPE`
     was not the blocker; current SQLite handles it. The blocker was `LIKE` being
     case-insensitive by default against a BINARY `idx_word`. The predicate is
     now `word >= ? AND word < ?`, which indexes unconditionally, rather than
     `PRAGMA case_sensitive_like=ON`, which changes behaviour globally. Also
     spike §9c.
  2. **First launch allocates the file in RAM.** `openLocalExecutor` loads
     all 166 MB into one `ByteData` before writing it out, and does the same
     for `bjt.db`. Step 7 writes it in 8 MB pieces, which removed a second
     copy (peak +342 MB → +211 MB for `bjt.db`); the load itself stays whole.

  On Android `dict.db` costs ~28.5 + 166.6 ≈ 195 MB on the phone, not 333 MB:
  the APK keeps it deflated and only the first-run copy is full size. The same
  split, applied to the content table's headline, is under **Size — the bonus,
  on two axes**.

- **First-launch copy**: the content+FTS DB copies out of the package on first
  run and lives twice from then on — the 172 MB is why the iOS on-device figure
  is 344 MB and not 172. `dict.db` (166.6 MB) already copies to the same place, so the
  real first-run write is ~339 MB, up from ~262 MB today (the JSON is never
  copied). Every megabyte the table saves is saved twice — which is why
  `page_size` was taken at 8 KB. After step 7 it copies again whenever the
  bundled database's hash changes or, outside Android, the OS clears the cache
  folder.
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
- [`move-web-onto-drift.md`](../../done/retiring-dart-server/move-web-onto-drift.md) — step 11 as its own
  plan: web reads these databases in the browser, and how a rebuilt DB reaches
  a browser that already has the old one (answered: with the build).
- `docs/general/how_search_works.md` — the search pipeline (Step 5 reads JSON).
- [`perf-fts-snippet-text-loading.md`](../../done/perf-fts-snippet-text-loading.md)
  — the shipped memo-cache fix this migration tears down.
