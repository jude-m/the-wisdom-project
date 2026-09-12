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

**Bonus: size — on device only.** Once the text is in the DB (compressed), the
`assets/text/*.json` files no longer ship: on-device storage falls by a third.
The *download* rises, because the JSON compresses inside the APK/IPA and a
pre-compressed blob cannot. Measured both ways below.

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

So compression is essentially free for speed. It is not free in the archive:
the blob size chosen for compression is also the unit the reader fetches, and
is also what the user downloads, because nothing can compress it again. Those
three are one knob.

## TL;DR

Move the text out of 285 JSON files and into a **compressed, per-page content
table** in the existing SQLite DB, then drop `assets/text/` from the bundle.
The JSON files stay in the repo — the FTS build script and the static site
generator both read them from the filesystem, not the app bundle — so the database
still builds and the HTML site still generates. They just aren't shipped.

```
TODAY (shipped):  95 MB FTS index  +  339 MB JSON  = 434 MB bundled
PROPOSED:         95 MB FTS index  +  85 MB table  = 180 MB bundled
```

Measured, not projected — see **What the measurements said** below. On-device
that is 529 MB today against 360 MB (the DB is copied out of the bundle on
first launch, so its size counts twice and the JSON's counts once).

**The download goes the other way**, which the framing above hides: an APK/IPA
is a zip, today's JSON deflates inside it to 46 MB, and a pre-compressed blob
cannot be compressed again. On the download axis this migration is a
regression, and the fix — if it is worth having — is the blob granularity, not
the plan.

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
Per-page blobs give up a third of the ratio, because each one starts
compressing from nothing. See the granularity curve below, where per document
is the real floor.

Two things shrink it when it moves into a table:

1. **Packaging disappears** — `type`/`level` become compact typed columns; no
   braces/quotes/field-names/indentation repeated per entry.
2. **Text compresses** — 7× as one stream, but only **4.2× per page**, which is
   the number that applies because the blobs are per page.

So the table costs 85 MB on disk while 339 MB of JSON vanishes entirely.

## Why This Is the Only Option That Wins on All Three Axes

Download and on-device storage moved apart once both were measured, so they get
a column each. Today's JSON is enormous on disk and cheap in the archive; a
compressed blob is the reverse.

| Approach | Download | On device | Read speed | Offline | Effort |
|----------|----------|-----------|-----------|---------|--------|
| Today | 92 MB | 529 MB | parses whole files | ✅ | — |
| Per-search memo cache only | same | same | snippets fixed; reader same | ✅ | tiny |
| Gzip the JSON assets | ~same | ↓↓ | same (still parses) | ✅ | low |
| **Compressed content table, drop JSON** ⭐ | 114 MB | 360 MB | ✅ per-page fetch | ✅ | medium–high |
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

### Size — the bonus, which is two numbers and they disagree

| | Today | Proposed |
|---|-------|----------|
| Bundled | 94.8 MB DB + 339.2 MB JSON = **434 MB** | 180.0 MB DB = **180 MB** |
| On device after first launch | + the DB's copy = **529 MB** | + the DB's copy = **360 MB** |
| **Download** (deflated, as an APK/IPA carries it) | 45.5 + 46.5 = **92 MB** | **114 MB** |

On-device storage falls by a third. **The download rises by 22 MB**, and that
is not a rounding error in the estimate — it is structural. The JSON is
enormous and highly compressible, so the archive already gets it down to 46 MB;
a per-page gzip blob is incompressible, so whatever it costs is paid twice, on
disk and on the wire. The 2026-06 estimate of "~70–110 MB" for the JSON's
download impact was high by half.

(Measured by deflating each file the way a zip stores an entry. A real APK
would confirm it, but there is no Android SDK on this machine, and iOS needs a
signed build; the arithmetic an archive does is the same either way.)

**That regression is mobile-only, and reads backwards on web.** The row above
is an APK/IPA — an archive that deflates the JSON for free. The web has no
archive. Today's plan for it (spike §8b) is to serve the same 285 JSON files
and let the client do what the server does, which costs, *per results page*,
~27 conditional GETs and 3–4 MB transferred to parse ~34 MB of JSON in the tab
— repeated, unbounded, and never offline. The content table replaces all of it
with bytes already downloaded:

| | Web, serving JSON | Web, content table |
|---|---|---|
| One-time | 47.6 MB (FTS, gzipped) | 47.6 + ~67 MB blobs ≈ **115 MB** |
| Per results page | ~27 GETs, 3–4 MB, 34 MB parsed | one row fetch |
| Offline | ✗ | ✓ |

So on web this migration is not a download regression at all: it converts an
unbounded per-use cost into a bounded one-time one, and it is the only thing
here that makes web offline possible. The "download rises" framing above is
true of the phone and false of the browser, and both surfaces read this table.

### Where the 85 MB goes, and the knob that moves it

The blobs are 67.2 MB. The other 18.1 MB is SQLite leaving space on the floor:
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

### The granularity curve — now load-bearing

The doc used to file this as an open question worth revisiting. The download
finding promotes it: blob size *is* the download.

| pages per blob | 1 | 2 | 4 | 8 | 16 | 32 | whole doc |
|---|---|---|---|---|---|---|---|
| compressed | 67.2 | 57.6 | 50.9 | 46.3 | 43.6 | 42.2 | **41.0 MB** |

The right-hand end is the floor — a single stream over the whole corpus does no
better, for the reason given above.

Per entry is worse than per page by 1.67×, which rules it out — including the
"optional max-speed snippet path" in the schema below. The curve is steep at
the near end and flat past 8: four pages a blob recovers 16 MB, eight recovers
21 MB, and everything after that is single digits.

Eight pages a blob would put the download at roughly today's 92 MB and the
bundle near 150 MB — better than today on **both** axes — at the cost of
decoding ~8 pages where a slice needs 3. Since the median slice is 2% of its
file, that is a real cost; `dn-1`'s 34-page slice says it is not a large one.

**This is a decision, not a finding, and it is not made.** Per page is what the
contract in `verify_corpus_invariants.dart` pins today, and changing it means
changing that contract (`pageIndex` → a chunk key) before step 5 writes to it.

**The web adds a second beneficiary and a second cost, both to the same knob.**
The blobs are the web download too, and there they are not competing against an
APK's deflate — nothing recompresses them on either side, so 67.2 → 46.3 MB at
eight pages a blob is a straight 21 MB off a one-time download on a connection
the user is waiting on. Against that, a web read is dearer than the 0.03 ms
measured natively: OPFS goes through a JS callback, and on Chrome through
`Atomics.wait` to a second worker, so decoding eight pages to use three costs
more there than here. Both halves of that trade are web-side and neither is
measured — but they push the same way the mobile argument does, and nothing
found so far argues for staying at one page.

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

### The blob decoder has a web requirement the schema section doesn't state

The schema below says compression is `dart:io` `GZipCodec`/`ZLibCodec`, to be
verified "on all shipped **native** platforms". But the banner makes this same
table the **web** content source, and `dart:io` does not exist there. Nothing
in `pubspec.yaml` covers the gap — no `archive`, no `drift`, and `lib/` uses no
codec today.

The *format* is fine: gzip and zlib are both decodable on web, and the contract
`verify_corpus_invariants.dart` pins needs no change. It is the *decoder* in
steps 6–7 that needs a web-capable path — `package:archive`, or
`DecompressionStream` through JS interop. Decide it when step 6 picks an API,
not after.

### This work now gates the web move, rather than following it

The spike's own biggest open item for going static was the JSON fetch path —
"~27 conditional GETs and 3–4 MB per results page … **this is now the
least-understood piece, not SQLite**". This table deletes that path rather than
prototyping it. So in the README's order of operations, **step 3 (this
document) must land before step 4 (retire the server, make web static)**, or
step 4 builds a 285-file fetch path on web and then throws it away. The order
as written is already right; the dependency was not stated, and now is.

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

### Smaller constraints, for whoever writes steps 5–7

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
- Compression in Dart: `dart:io` `GZipCodec`/`ZLibCodec` on native — **but the
  decoder must also work on web**, where `dart:io` does not exist and this same
  table is the content source. `package:archive` or `DecompressionStream` via
  JS interop; neither is in `pubspec.yaml` yet. The stored format needs no
  change for this — gzip and zlib both decode there.
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

   **Unrelated TODO, parked here so it is not lost:** consolidate every test
   path behind one entry point — a master switch that fires unit
   (`flutter test`), integration (`flutter test integration_test/all_tests.dart
   -d macos`), `static_site_generator` (`dart test`, its `corpus` tag and the
   `tool/` scripts) and `packages/wisdom_shared`, taking optional parameters to
   run a subset instead of remembering four commands.
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

   **This is the one result that should be read before step 5 starts.** The plan
   is still worth doing — storage is what a scripture app on a retreat runs out
   of, and speed was the primary goal — but "Bonus: size" is no longer true
   without qualification, and the blob granularity is what decides whether it
   becomes true. See the granularity curve.
5. Extend `tools/bjt-fts-populate.js` to populate `bjt_content` (compress per
   page) alongside the existing `_fts` / `_meta` tables.

   **Two things that used to be part of this step are already done.** The
   script now ends in `finalizeDatabase` (`tools/db-finalize.js`) — `VACUUM
   INTO` at 8 KB pages,
   `ANALYZE`, and a header assert — so page size is inherited rather than
   chosen here, and nothing this step writes can reintroduce the WAL flag.
   Write rows in WAL mode as before; the finalize pass is what ships.

   **The contract is already written down and enforced** — see step 1: one row per
   `(filename, pageIndex, language)`, `language` spelled `pali` / `sinh`, the
   `blob` column a real BLOB, the bytes gzip- or zlib-framed, and the payload
   that page's JSON substructure verbatim — plus the `pageNum` column beside it,
   copied from the page. Uncompressed JSON is a *failure*, not a
   lenient pass: it round-trips clean and would otherwise read green at 100% of
   plain JSON.

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
6. Add a local content datasource that reads + decompresses from `bjt_content`.
   Four things the benchmark and the spike review turned up, all of which bite
   here rather than in step 5:

   - **The half-open → page-span rule has no home, and needs one before this
     step.** Step 6 must know which page rows to `SELECT` *before* it has a
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

- **Compression granularity — measured, and now a decision.** Per entry is out
  (1.67× worse than per page). Per page costs 22 MB of download that eight pages
  a blob would not — on mobile *and* on the web's one-time fetch. Curve and
  trade-off above; changing it means changing the contract section 5 pins, so it
  is decided *before* step 5, not after. **The only open question left on this
  plan's critical path.**
- **The web decoder** — `dart:io` is not available there and nothing in
  `pubspec.yaml` replaces it yet. Format is settled; the API is not. Decide in
  step 6. See the spike section.
- **First-launch copy**: the content+FTS DB copies to the documents dir on first
  run and lives twice from then on — the 180 MB is why the on-device figure is
  360 MB and not 180. `dict.db` (175 MB) already copies to the same place, so the
  real first-run write is ~355 MB. Still well under today's, but it means every
  megabyte the table saves is saved twice — which is why `page_size` was taken
  at 8 KB, and half the argument for a coarser blob.
- **Reader rewrite risk**: this touches the reader (higher-risk code than
  search). Stage it: land the content table + snippet repoint first, reader
  second, drop the assets last.
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
