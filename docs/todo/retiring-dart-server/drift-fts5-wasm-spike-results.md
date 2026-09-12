# Spike results: FTS5 in the Drift WASM build

> **Copied verbatim into the repo 2026-09-11**, from the spike workspace outside
> it. The `spike-harness/` the last section describes did **not** come with it,
> nor did the two 99/175 MB databases it ran against — the commands under
> *Reproducing* only work in that workspace.
>
> One block was replaced rather than copied: §3's *Verify in CI* one-liner now
> points at the check as it was actually implemented here.
>
> What this changes in the plan is summarised in
> [`reduce_mobile_bundle_size.md`](./reduce_mobile_bundle_size.md) under **What
> the Drift/wasm spike changed**, where the repo-specific claims were also
> re-verified locally. Where the two disagree, the plan is the one being
> maintained.

**Verdict on the stated gate: PASS.** FTS5 is compiled into the binary Drift ships,
and our real `bjt-fts.db` returns byte-identical results through it.

**But the spike found a different, harder blocker that the plan didn't anticipate:
both DB files are flagged WAL, and the WASM build cannot open a WAL-flagged file at
all.** One-line fix, but it fails with a misleading error, so it is worth knowing before
you spend a week concluding Drift is broken.

Everything below was executed, not reasoned about, except where marked
*(source-read only)*.

---

## 1. The gate: does the shipped `sqlite3.wasm` have FTS5?

Yes, three independent ways:

| Evidence | Result |
|---|---|
| Build config `sqlite3_wasm_build/src/sqlite_cfg.h` | `#define SQLITE_ENABLE_FTS5 1` |
| Strings in the shipped binary | `fts5`×35, `fts5vocab`, `bm25`, `trigram`, `contentless`×14, `detail=none`, `unicode61`, `tokenchars` |
| Runtime, real DB | `SELECT count(*) … MATCH 'එවං'` → 26,925 |

The build file that 404'd for you is at
`simolus3/sqlite3.dart` → `sqlite3_wasm_build/src/sqlite_cfg.h` (it moved out of the
`sqlite3/` package into its own `sqlite3_wasm_build` package).

Also in that build: RTREE, math functions, DBSTAT, session/preupdate.
**Not** in it: FTS3/FTS4 (fully omitted), ICU, WAL, UTF-16, `sqlite3_deserialize`,
`load_extension`, compile-option diagnostics.

WASM SQLite version: **3.53.4** (2026-07-24), from release `sqlite3-3.5.2`.

> `PRAGMA compile_options` returns **zero rows** in this build
> (`SQLITE_OMIT_COMPILEOPTION_DIAGS`). Don't use it as your FTS5 check — probe with a
> real `MATCH` instead.

## 2. Tokenizer / result parity

Full query set run against the **real 99 MB `bjt-fts.db`**, comparing rowids of the
top 50, `bm25()` to 6 decimal places, the `bjt_meta` join, and the whole vocabulary
(892,673 terms) across **seven** engine configurations:

| Config | SQLite | Where |
|---|---|---|
| native, oldest available | 3.37.2 | your machine |
| native | 3.45.1 | cloud |
| Drift's `sqlite3.wasm` | 3.53.4 | Node |
| Drift's `sqlite3.wasm` (previous release) | 3.53.1 | Node |
| Drift's `sqlite3.wasm`, OPFS-backed | 3.53.4 | headless Chromium |
| same, DB rebuilt at 8 KiB pages | 3.53.4 | headless Chromium |
| same, after `VACUUM INTO` | 3.45.1 | cloud |

**All 15 queries × all 7 configs: identical.** Zero `no such module: fts5`, zero
tokenizer errors.

Query set: common term (එවං, 26,925 docs), highest-frequency term (ද, 73,683),
two rare terms (3 and 8 docs), phrase, AND, OR, NOT, `NEAR()`, prefix `බුද්ධ*`
(1,813 term expansions), two ANDed prefixes, digit token, Latin token, a
virama-internal cluster, a long compound.

I also created a **fresh** FTS5 table inside the browser using the exact `tokenize=`
string from your schema and indexed `එවං මෙ සුතං ඒකං සමයං භගවා`. It tokenised to
exactly `["එවං","ඒකං","භගවා","මෙ","සමයං","සුතං"]` and matched. So the Sinhala
`tokenchars` charlist is honoured for writes as well as reads — not just tolerated
when reading an index built elsewhere.

Incidental: the index contains **zero** terms with ZWJ (U+200D) or ZWNJ (U+200C),
consistent with your locked rule to strip them at index and query time. That
stripping is Dart-side and platform-independent, but it's worth confirming the web
code path actually runs it.

---

## 3. The blocker the doc didn't anticipate: WAL header flag

Both files carry `write_version = read_version = 2` in the header (bytes 18/19),
meaning "this database was last used in WAL mode".

The WASM build is compiled `SQLITE_OMIT_WAL`. With that flag, SQLite's `lockBtree()`
rejects any file whose header says WAL. You get:

```
SQLITE_NOTADB (26): file is not a database
```

…on the **first prepare**, before any FTS5 code runs. Nothing about it points at WAL.
If you'd shipped as planned, this is the error you'd have gotten, and "file is not a
database" on a file that opens fine everywhere else is exactly the kind of thing that
burns days.

Confirmed both directions: the original file fails, the same file with the flag
cleared passes all 15 queries.

**Fix — add to the DB build pipeline, before publishing:**

```bash
sqlite3 bjt-fts.db "PRAGMA journal_mode=DELETE;"   # rewrites header bytes 18/19 -> 1
sqlite3 dict.db    "PRAGMA journal_mode=DELETE;"
```

or, better, since you want to rebuild anyway (see §5):

```bash
sqlite3 src.db "PRAGMA page_size=8192; VACUUM INTO 'out.db';"   # 0.4s, also -> non-WAL
```

**Verify in CI** — done, and not as a third copy of the rule. The check lives in
`assertShippableHeader` (`tools/db-finalize.js`), which both generators call before
swapping the rebuilt file into place, and again in `tools/validate-release.sh`, which
gates every database in `assets/databases/` without needing node. *(The one-liner
that stood here was a third spelling of the same two conditions; it is gone rather
than left to drift.)*

---

## 4. COOP/COEP is not a "deploy detail" — it's a hosting constraint

The doc has this as secondary, with Drift "falling back (slower)". That undersells it.
Drift picks a storage mode at runtime *(source-read: `drift/lib/src/web/wasm_setup/types.dart`)*:

| Mode | Needs | Reality |
|---|---|---|
| `opfsShared` | shared worker spawning a **nested** dedicated worker | **Firefox only.** Chrome ([crbug 1088481](https://crbug.com/1088481)) and Safari don't support nested workers in shared workers |
| `opfsLocks` | `Atomics.wait` → **cross-origin isolation** → COOP+COEP | the only OPFS path on Chrome and Safari |
| `sharedIndexedDb` / `unsafeIndexedDb` | — | what you actually get on Chrome without the headers |
| `inMemory` | — | nothing persists |

So on your primary target (desktop Chrome), **without COOP+COEP you don't get "slower
OPFS", you get IndexedDB** — a block-emulated filesystem holding 274 MB. I did not
benchmark that path, but it is not the same product.

Consequences for "move to a static site":

- **The host must let you set response headers.** GitHub Pages cannot. Cloudflare
  Pages / Netlify / Vercel can (`_headers`). Rule this in before committing.
- `Cross-Origin-Embedder-Policy: require-corp` will break any cross-origin subresource
  without CORP headers — Google Fonts, CDN assets, analytics, embedded media. Consider
  `COEP: credentialless` and self-hosting fonts.

Measured, for what it's worth: cross-origin isolation made **no difference** to raw
query time in my harness (447 ms vs 436 ms cold; 3.6 ms vs 2.6 ms rare-term). The
headers aren't a performance knob — they're the gate that decides whether Drift uses
OPFS at all on Chrome.

> Worth knowing: my harness reached OPFS through a `FileSystemSyncAccessHandle` in a
> plain dedicated worker, which needs **no** cross-origin isolation. That's what
> `package:sqlite3`'s `SimpleOpfsFileSystem` does. The COI requirement comes from
> Drift's multi-tab locking layer, not from OPFS. If you ever decide multi-tab safety
> isn't worth the header constraint, dropping to `package:sqlite3` directly buys you
> that — at the cost of the single cross-platform API you said you want.

---

## 5. Numbers

### Memory — good news, with one trap

Querying the 99 MB DB over OPFS, **total WASM heap stayed at 18.4 MB**. SQLite reads
pages on demand through the VFS; the file is never materialised. Across the full
15-query run: 44,881 `read()` calls, 184 MB read.

**The trap:** Drift's own seeding API is
`initializeDatabase: FutureOr<Uint8List?> Function()?`, and it does
`file.xWrite(response, 0)` — one shot, whole file in memory
*(source-read: `drift/lib/src/web/wasm_setup/shared.dart`)*. For your two DBs that's a
**274 MB Dart typed-data allocation** in the tab. Plausible on desktop, a tab kill on
a phone.

**Avoid it by pre-seeding OPFS yourself.** Drift only calls the initializer if the
file is absent:

```dart
if (initializer != null && vfs.xAccess('/database', 0) == 0) { ... }
```

So: stream the download straight into OPFS at the path Drift uses —
`drift_db/<databaseName>/database` (constant `driftOpfsRoot = 'drift_db'`,
`pathForOpfs(name) => 'drift_db/$name'`, file `/database`) — then call
`WasmDatabase.open(databaseName: name)` with **no** `initializeDatabase`. It finds the
file and opens it.

I ran exactly this layout in Chromium: wrote the real 99 MB `bjt-fts.db` plus a
175 MB stand-in for `dict.db` into `drift_db/*/database` via streamed sync access
handles (peak buffer 2 MB), then queried through Drift's WASM binary. Works, 274 MB
used. (`dict.db` itself was too large to move into the test environment, so its size
— not its content — was reproduced.)

*(I could not execute the Dart side — pub.dev and storage.googleapis.com are blocked
by this session's egress policy, so no Dart SDK. The path constants and the
`xAccess` guard are read from Drift's source at `main`, c63d744.)*

### Query latency (headless Chromium, OPFS, 4 KiB pages)

| | first query in session | warm (best of 3) |
|---|---|---|
| එවං (26,925 docs) | 450–500 ms | 25 ms |
| ද (73,683 docs) | 155 ms | 53 ms |
| `බුද්ධ*` prefix (1,813 expansions) | 40 ms | 20 ms |
| rare term (3 docs) | 2.4 ms | <1 ms |

Two things move the needle, and one doesn't:

- **`PRAGMA cache_size` does nothing.** Only ~5 MB is touched for a top-50 query; the
  default 16 MB cache already covers it. Don't bother tuning.
- **8 KiB page size halves the I/O** — 1,384 → 703 `read()` calls, and first-query
  time 505 ms → 325 ms. Free: `PRAGMA page_size=8192; VACUUM INTO 'out.db'`. Parity
  re-verified on the 8 KiB build. **Recommended.**
- **`SELECT count(*) … MATCH` is the expensive part** — it scores every hit. In the
  full run, 7 top-50 queries cost 1,384 reads; adding `count(*)` for all 15 pushed it
  to 44,881. If the UI shows "N results" for a common term, that's most of your
  latency. Consider `LIMIT`-capped counts ("500+") or dropping exact counts.

### Download and storage

| | on disk | gzip -6 | ratio |
|---|---|---|---|
| `bjt-fts.db` | 99.4 MB | **47.6 MB** | 47.9% |
| `dict.db` | 174.7 MB | **30.3 MB** | 17.4% |
| total | **274 MB** | **78 MB** | |

(Decimal MB throughout. `xz -3` gets `bjt-fts.db` to 41 MB but browsers won't decode it
transparently, so gzip/brotli is the practical ceiling.)

78 MB over the wire is very acceptable. 274 MB resident is the number to worry about —
`Content-Encoding: gzip` is transparent to `fetch`, so you write the *uncompressed*
bytes to OPFS.

Streaming write throughput in-container: 99 MB in ~0.8 s, 175 MB in ~1.1–1.6 s. Real
cost is the network.

`dict.db` is the bigger, softer target. Text by source:

| dict_id | rows | text |
|---|---|---|
| DPD | 423,154 | 78.3 MB |
| CR | 29,669 | 21.1 MB |
| PTS | 16,245 | 6.7 MB |
| PN | 9,965 | 5.7 MB |
| other 6 | 117,802 | 5.1 MB |

DPD alone is two thirds of the content. Splitting per `dict_id` into separately
downloadable files, with DPD opt-in, would cut the mandatory download to roughly a
third. (Also: 117 MB of text sits in a 175 MB file — the rest is `idx_word` plus page
overhead.)

**Eviction.** `navigator.storage.persist()` returned **false** in a fresh profile
(quota there was only ~500 MB, but that reflects the test container's small disk —
Chrome's real quota is a share of free disk, so quota itself is unlikely to bite on
desktop).
Chrome grants persistence based on engagement/installation signals, so a first-time
visitor's 266 MB is best-effort storage that can be evicted under pressure. Design for
it: call `persist()` and check the result, keep a manifest with version + size +
hash, detect a missing/short OPFS file on boot and re-download rather than failing.
On iOS Safari (your best-effort tier) this is materially worse — tighter per-origin
quota and eviction after ~7 days without interaction.

---

## 6. Other things the doc doesn't mention

**`SQLITE_DQS 0`.** Double-quoted *string literals* are an error in the WASM build:

```
SELECT 1 FROM bjt_meta WHERE language = "pali"   -- FAILS on web
  → no such column: "pali" - should this be a string literal in single-quotes?
SELECT 1 FROM bjt_meta WHERE language = 'pali'   -- fine
SELECT "language" FROM bjt_meta                  -- fine (identifier quoting is unaffected)
```

Most native builds (including the one your Dart server links) allow DQS, so this is a
**web-only breakage that native tests won't catch**. I grepped every SQL site in
`lib/`, `packages/` and `server/`: **your code is clean** — all string literals are
single-quoted or bound as `?`. Nothing to do here.

**Contentless FTS5 returns NULL, not an error.** On `bjt_fts`, `snippet()`,
`highlight()` and `SELECT text` all return `NULL` silently. `bjt-fts.db` is a pure
index; `bjt_meta` only holds `filename`/`eind`/`nodeKey` pointers. Where the text
actually comes from is answered in §8 — the codebase settles it, and the answer is
benign. (Your code never calls `snippet()`/`highlight()`, so nothing breaks here.)

**You can't `ATTACH` the two DBs together — on some browsers.**
`SimpleOpfsFileSystem` (the `opfsShared` mode) stores **exactly two files**,
`/database` and `/database-journal`, by design. `async_opfs` (`opfsLocks`) does
support arbitrary paths. Since the mode is chosen at runtime by browser capability,
an ATTACH-based cross-DB query would work on Chrome-with-COI and break on Firefox.
**Treat them as two independent Drift connections** (two databaseNames, two workers).

**Pass `enableMigrations: false`.** Your DBs have `user_version = 0`. If Drift's
migrator runs against a prebuilt read-only DB it will try to create its own schema and
bump `user_version` — writing into the file you shipped. `WasmDatabase.open` takes
`enableMigrations`; use it, and query with `customSelect`.

**Also absent from the web build, in case you rely on any of it:**
`sqlite3_deserialize` (you cannot hand SQLite a byte array — everything goes through
the VFS), `mmap` (`PRAGMA mmap_size` = 0), UTF-16, `load_extension`.
`PRAGMA journal_mode=wal` doesn't error — it silently returns `delete`.

**Minor upstream oddity.** In `sqlite3_wasm_build/src/helpers.c`,
`dartvfs_sectorSize()` calls `xDeviceCharacteristics()` — the `xSectorSize` import is
declared in `bridge.h` but never wired up (it's absent from the binary's import list).
SQLite clamps sector size into a safe range so there's no correctness risk for a
read-only workload, but it's a real copy-paste bug worth an upstream issue.

---

## 7. What this spike did *not* cover

The SQLite/FTS5/WASM/OPFS layer was **executed** against the real binary and the real
database. The Dart layer above it was **not run** — pub.dev and
storage.googleapis.com are blocked by this session's egress policy, so no Dart or
Flutter SDK was reachable. Specifically unverified by execution:

- `WasmDatabase.open()`'s worker negotiation and storage-mode selection in a real browser
- Drift's own migration/`user_version` behaviour against a prebuilt DB
- the IndexedDB fallback path's performance
- iOS Safari and Firefox (Chromium only here)

(Your app's real call sites were reviewed after the fact — see §8 onward.)

A ~30-minute Flutter web target on your machine would close the rest, and it now has a
much shorter checklist to run: clear the WAL flag, pre-seed OPFS, set the headers,
`enableMigrations: false`.

---


# Part 2 — reviewed against the actual repo

Source reviewed: your local `lib/` (identical to GitHub `main` for both data sources
that matter — 40 other files differ, none of them these) plus `server/`,
`packages/wisdom_shared/` and the asset manifest from `main` @ `dc432fc`.

The migration is more work than the doc assumes, and the repo review turned up three
performance problems that are **already live today**, independent of the web move.
Those are worth more to you than anything in Part 1.

---

## 8. The three things Part 1 couldn't know

### 8a. The app is on `sqflite`, not Drift

`pubspec.yaml`: `sqflite: ^2.3.0` + `sqflite_common_ffi: ^2.4.0+2`. Drift appears
nowhere in the codebase. So "move to Drift" is a rewrite of
`FTSDataSourceImpl` and `DictionaryDataSourceImpl`, not a config change.

The good news: every query is already a raw SQL string passed to `db.rawQuery(sql,
args)`. Drift's `customSelect(sql, variables:)` is close to a 1:1 port — you're not
adopting the ORM, codegen or table classes, just its OPFS/worker plumbing. Budget it
as a mechanical port of two files, plus the storage-mode and header work in §4.

Worth pricing against the alternative: `sqflite_common_ffi_web` keeps the `sqflite`
API on web and runs the same `sqlite3.wasm` underneath, so the diff is far smaller.
It's IndexedDB-backed rather than OPFS, which given §4 is roughly what Drift would
fall back to on Chrome without COOP/COEP anyway. Everything in §3 and §6 applies
identically either way — the WAL flag doesn't care which Dart package opens the file.

One thing already in your code that Part 1 flagged as a Drift trap: both local data
sources do `rootBundle.load(assetPath)` → `data.buffer.asUint8List()` →
`writeAsBytes`. That's the same whole-file-in-memory pattern as Drift's
`initializeDatabase`, and it's shipping on mobile today for a 99 MB and a 175 MB file.
On web, stream it (§5).

### 8b. Where the text comes from — answered, and it's fine

`FtsHandler._loadTextForMatch` (server) reads `assets/text/<filename>.json`, splits
`eind` on `-` into `[pageIndex, entryIndex]`, indexes `pages[pageIndex]`, and picks the
`pali`/`sinh` branch. Those JSON files are already Flutter assets shipped to mobile, so
for the static site you serve the same 285 files and let the web client do what the
server does. **No new content pipeline needed.** That closes the biggest open item from
Part 1.

The cost is real but manageable:

| | |
|---|---|
| `assets/text` | 285 files, **356 MB** raw (median 1.02 MB, max 4.04 MB) |
| gzip ratio, measured on 3 files | **7–12%** — so ~0.05–0.11 MB on the wire per file |
| distinct JSON files touched by one page of 50 results | **median 27** (range 11–34) |
| → per search results page, uncached | ~34 MB raw ≈ **3–4 MB transferred**, over 27 requests |

So a search page costs ~27 conditional GETs and a few MB, plus parsing ~34 MB of JSON
in the tab. The Dart server hides this today (local disk + its `_jsonCache`). On a CDN
with `immutable` caching it's acceptable, but it's the thing to prototype next — it's
now the least-understood part of the plan, not the SQLite layer.

Also needed on first load: `assets/data/tree.json`, 4.2 MB.

### 8c. `bjt_suggestions` does not exist

Both `FTSDataSourceImpl._getSuggestionsFromEdition` and the server's `_suggestions`
query `${editionId}_suggestions`. There is no `bjt_suggestions` table in the shipped
`bjt-fts.db` — `DatabaseManager._logDiagnostics` even logs "bjt_suggestions: not
available". Every autocomplete call throws today. Either build the table into the DB
(and add its size to the download budget) or delete the code path.

---

## 9. Three live performance bugs, found while testing your real queries

These are in the app now, on every platform. The web move surfaced them; it didn't
cause them.

### 9a. A missing `ANALYZE` costs 12 seconds on the scope+language query

Your search with a scope filter *and* the පාළි/සිංහල toggle produces this, via
`ScopeFilterSql`:

```sql
SELECT COUNT(*) FROM bjt_fts t JOIN bjt_meta m ON t.rowid = m.id
WHERE bjt_fts MATCH ? AND (m.filename LIKE ?) AND m.language = ?
```

`bjt-fts.db` has **no `sqlite_stat1`**, so the planner is guessing. It sees
`idx_bjt_meta_language` and drives the join from the meta side — running a *separate*
FTS5 MATCH for each of the 232,057 `pali` rows:

```
SEARCH m USING INDEX idx_bjt_meta_language (language=?)
SCAN t VIRTUAL TABLE INDEX 0:=M1          ← the '=' means one MATCH per row
```

Measured, same DB, same query (`බුද්ධ*`, `dn-%`, `pali`, 128 hits):

| SQLite | plan | time |
|---|---|---|
| 3.37.2 | bad | **9,239 ms** |
| 3.45.1 | bad | **12,315 ms** |
| 3.53.4 (the WASM build) | good | 77 ms |
| 3.45.1, **after `ANALYZE`** | good | **10 ms** |

`ANALYZE` costs **8 KB** and flips the plan on every version. Two-line fix in the DB
build:

```bash
sqlite3 out.db "ANALYZE;"
```

Note which versions lose. `sqflite` on Android uses the **system** SQLite, whose
version tracks the OS — so users on older Androids may be sitting on the 9-second path
right now. The web build dodging it is luck, not a guarantee.

Consider also dropping `idx_bjt_meta_language` outright: two distinct values over
457k rows (`456977 228489` in the stats) means it can never be selective, and its only
demonstrated effect is to mislead the planner.

### 9b. `ORDER BY score` has no tiebreaker, and you paginate with OFFSET

`FTSDataSourceImpl._searchInEdition` ends `ORDER BY score LIMIT ? OFFSET ?`. bm25 ties
are not rare here — for `භගවා`, the first 5,000 hits carry only **622 distinct
scores**, and the largest tie group is **69 rows**. Order within a tie group is
whatever the plan happens to produce, so as the user pages, rows can repeat or vanish.
It also means Part 1's "identical order" result only holds because my harness added
`, rowid`; your actual ORDER BY is not deterministic across engines either.

Fix: `ORDER BY score, id`.

### 9c. Dictionary lookup full-scans a 175 MB table on every word tap

`DictionaryDataSourceImpl.lookupWord` / `searchDefinitions`:

```sql
... FROM dictionary WHERE word LIKE ? ESCAPE '\' ORDER BY is_exact ASC, rank DESC LIMIT ?
```

`EXPLAIN QUERY PLAN` on the real `dict.db`, prefix `බුද්ධ%`, 936 matching rows:

| form | plan | time |
|---|---|---|
| `LIKE ? ESCAPE '\'` (yours, full row fetch) | `SCAN dictionary` | **133 ms** |
| same without `ESCAPE` | `SCAN dictionary` | 45 ms |
| `LIKE` on the covering index only | `SCAN ... USING COVERING INDEX` | 29–36 ms |
| `GLOB 'බුද්ධ*'` | `SEARCH ... USING COVERING INDEX idx_word` | **0.4 ms** |
| `word >= ? AND word < ?` | `SEARCH ... USING COVERING INDEX idx_word` | **0.4 ms** |
| `word = ?` (your exactMatch path) | `SEARCH ... (word=?)` | **0.0 ms** |

`idx_word` exists and is never used by the prefix path. Natively that's 133 ms and
nobody notices. Over OPFS it means reading essentially the **whole 175 MB file through
a JS callback per lookup** — and the dictionary opens on every word tap. After the WAL
flag, this is the biggest web risk in the codebase.

The rewrite keeps the same semantics, since `buildDictionaryLikePattern` is only ever
building a prefix:

```sql
-- prefix (exactMatch = false)
WHERE word >= :w AND word < :w || char(0x10FFFF)
-- exact  (exactMatch = true)
WHERE word = :w
```

`countDefinitions` has the same issue in milder form (covering-index scan, 39 ms) and
takes the same fix.

---

## 10. Your real queries, browser vs native

The app's exact SQL — the CTE with the `bjt_meta` join, and the separate `COUNT(*)` —
run through Drift's `sqlite3.wasm` over OPFS in Chromium against the real DB (8 KiB
pages), against the same SQL natively on 3.45.1. `total` is count + search, which is
what one search actually costs you.

| query (as `buildFtsQuery` emits it) | no filter | scope=sp | native | ratio |
|---|---|---|---|---|
| `බුද්ධ*` — **the default single-word path** | **809 ms** | 626 ms | 36 ms | **22×** |
| `ධම්*` — shorter prefix | **1,317 ms** | 1,724 ms | 61 ms | **22–28×** |
| `ද*` — one-character worst case (233,803 hits) | **2,217 ms** | 3,071 ms | 503 ms | 4–6× |
| `NEAR(එවං* මෙ* සුතං*, 1)` — **the default multi-word path** | 191 ms | 160 ms | 57 ms | 3× |
| `බුද්ධ* ධම්ම*` — anywhere-in-text, prefix | 450 ms | 340 ms | 37 ms | 12× |
| `NEAR(භගවා* එකං*, 10)` — proximity, prefix | 55 ms | 51 ms | 7 ms | 8× |
| `"එවං මෙ සුතං"` — exact phrase | **7 ms** | 8 ms | 3 ms | 3× |
| `බුද්ධ ධම්ම` — anywhere, exact tokens | **2 ms** | 1 ms | 1 ms | 3× |
| `NEAR(භගවා එකං, 10)` — proximity, exact | **5 ms** | 5 ms | 3 ms | 2× |
| `භගවා` — exact single token | 200 ms | 141 ms | 13 ms | 15× |

The pattern is stark: **everything with a `*` is slow, everything without one is
instant.** And `isExactMatch` defaults to `false`, so the prefix path *is* the product.

Three consequences:

1. **Prefix matching is the whole cost.** A one-character query (`ද*`) is a 2–3 second
   stall for 233,803 hits nobody will read. Requiring 3+ characters before enabling
   the `*`, or offering exact-first with "search prefixes" as an opt-in, converts the
   common case from ~800 ms to ~5 ms.
2. **You run the MATCH twice.** `countFullTextMatches` and `searchFullText` each
   execute the same FTS query; on `බුද්ධ*` with scope that's 455 ms of pure count.
   Dropping the exact count (show "500+") or capping it with a subquery `LIMIT` is the
   cheapest single win available.
3. **These numbers are a floor, not a ceiling.** My harness reads OPFS through a
   `FileSystemSyncAccessHandle` in one dedicated worker — Drift's `opfsShared` shape.
   Chrome gets `opfsLocks`, which routes every read through `Atomics.wait` to a second
   worker. Expect Chrome to be slower than this table, not faster. 42,490 reads and
   348 MB were pulled through the VFS across these 30 queries.

---

## Recommended sequence

**Blocking, before any of this can work:**

1. DB build: `PRAGMA page_size=8192; VACUUM INTO 'out.db';` then `ANALYZE;`. Add a CI
   assert on header bytes 18/19. Clears the WAL flag (§3), halves I/O (§5), and fixes
   the 12-second query (§9a).
2. Confirm the static host can set COOP/COEP (§4). It constrains the host choice —
   GitHub Pages can't.
3. Rewrite the dictionary prefix predicate to a range or `GLOB` (§9c). A full scan of
   175 MB over OPFS on every word tap is not shippable.

**Cheap wins worth doing regardless of the migration:**

4. `ORDER BY score, id` (§9b).
5. Gate prefix search behind a minimum query length; drop or cap the separate count
   query (§10).
6. Drop `idx_bjt_meta_language` (§9a).
7. Build `bjt_suggestions` or delete the dead autocomplete path (§8c).

**Then the migration itself:**

8. Pre-seed OPFS at `drift_db/<name>/database` by streaming; don't use
   `initializeDatabase` (§5). Two DBs = two connections, no ATTACH (§6).
   `enableMigrations: false` (§6).
9. Split `dict.db` by `dict_id`, make DPD opt-in — two thirds of the 175 MB (§5).
10. Manifest + integrity check + re-download-on-eviction; call `persist()` and handle
    `false` (§5).
11. Prototype the `assets/text` JSON fetch path — ~27 files and 3–4 MB per results
    page (§8b). This is now the least-understood piece, not SQLite.

## Reproducing

`spike-harness/` in this folder is self-contained:

```bash
node run-wasm.mjs sqlite3.wasm bjt-fts.delete.db wasm.json   # real binary, Node
python3 native.py bjt-fts.db native.json                     # native baseline
python3 compare.py native.json wasm.json                     # strict diff
node serve.mjs . 8099 coi & node browser.mjs 8099 out.json   # Chromium + OPFS
node perf.mjs 8099                                           # page-size / cache matrix
node appsql.mjs                                              # YOUR SQL, browser vs native
node probes.mjs                                              # build-capability probes
```

`sqlite3-host.mjs` implements the 31 `dart` imports the binary needs (a VFS bridge),
which is what lets the exact shipped `sqlite3.wasm` run without a Dart runtime.
`app-queries.json` + `web/app.mjs` reproduce the CTE and COUNT that
`FTSDataSourceImpl` builds, so you can re-run §10 after any change.
