# Move Web onto Drift

> **Status 2026-09-19: in progress on branch `feat/move-web-onto-drift`; steps
> 1–2 done.** This was step 11 of
> [`reduce-mobile-size-and-move-to-drift.md`](./reduce-mobile-size-and-move-to-drift.md),
> whose steps 1–9 are done: `bjt.db` holds the page text, and native reads both
> databases through Drift. It is step 3 of the [`README.md`](./README.md) order.
> Every question it raised is decided — see **Decided**. Checked on 2026-09-18
> against the Drift 2.35.0, sqlite3 3.5.2 and Flutter 3.44.1 tool sources.

## Goal

Flutter web reads `bjt.db` and `dict.db` in the browser, through Drift's wasm
build, the way native reads its copies. No Dart server.

**Done means:** the web app runs locally in Chrome with no server, and search,
the reader and the dictionary show what macOS shows. Hosting is not part of
this plan — it is [`web-release.md`](../web-strategy/web-release.md) §6.

## Where web stands (2026-09-18)

- `getWebOverrides()` (`platform_providers.dart`) swaps in three HTTP
  datasources — search, dictionary, reader — that call `/api/…` on the Dart
  server.
- `local_database_executor_web.dart` throws. Nothing opens a database in a
  browser.
- `bjtContentDataSourceProvider` is not overridden on web. Web never reaches it
  only because the server pre-fills `matchedText`
  (`text_search_repository_impl.dart`).
- `scripts/web/deploy.sh` and `run_mac.sh` delete
  `build/web/assets/assets/databases/` — `manifest.json` with it — and
  `run_mac.sh` serves the build through the Dart server.
- The update banner polls `/healthz`, which only the Dart server answers. Local
  builds leave it off (`VERSION_CHECK_ENABLED`).
- **Drift's web side has never run here.** The spike drove SQLite through its
  own harness; Drift's workers, its storage-mode choice and opening a file we
  wrote ourselves are unverified (spike §7). Step 3 starts there.
- Locked in `pubspec.lock`: Flutter 3.44.1, `drift` 2.35.0, `sqlite3` 3.5.2.
  `pubspec.yaml` does not hold them: it has `drift: ^2.35.0`, and `sqlite3`
  only comes in through Drift (3.6.0 is already in the pub cache).

## Decided (2026-09-18; cleanup 2026-09-19)

- **Chrome first**, Edge with it (same engine). Other browsers get a message
  for now. The check runs **before any download** and is by feature, not
  browser name: `WasmDatabase.probe()` must offer `opfsLocks`, and
  `createWritable` must exist. Firefox or Safari may pass it; only Chrome is
  tested here.
- **One storage mode everywhere: `opfsLocks`,** opened by name instead of
  taking Drift's pick. Chrome and Safari have only this OPFS mode, and Firefox
  has it beside `opfsShared`, so every browser that passes runs the same code.
  Naming the mode also means Drift can never fall back to IndexedDB with the
  whole library in it.
- **`bjt.db` first, then `dict.db` in the background.** On a first visit the
  download screen covers the whole app until `bjt.db` is installed. The tree
  (`tree.json`) could be browsed meanwhile, but every book in it opens text from
  `bjt.db` (chosen 2026-09-19). The dictionary waits for `dict.db` on its own.
- **Installing is not opening.** The first-visit screen drives the download;
  `LocalDatabase.open` on web only waits for a finished install and never
  downloads. A failed open is retried on the next query, so a download inside
  `open` would start 119 MB again on every search after a failure.
- **The version rides with the build.** Native reads the hash from the bundled
  `manifest.json` and compares it with the stamp beside its copy; a different
  hash means copy again. Web reads the same manifest and compares it with the
  stamp in its OPFS folder; a different hash means download again. The one
  difference: web puts each version in its own folder instead of over the old
  file. So a new database reaches the browser with a new web build, as it
  reaches a phone with a new app, and an old app never meets a new database.
  There is no live manifest on the CDN
  ([`db-auto-update-prestudy.md`](./db-auto-update-prestudy.md)).
- **One name per version:** `<db>-<first 16 hex of its SHA-256>`, written
  `bjt-<sha16>` below. It names the OPFS folder (`drift_db/bjt-<sha16>/`) and
  the file on R2 (`bjt-<sha16>.db.gz`). A file on R2 is never overwritten.
- **Old versions go when no tab uses them, before the new download.** Each tab
  holds a marker — a shared Web Lock — for every version it uses, for as long
  as it is open; the browser drops it when the tab closes or crashes. At start,
  a tab deletes another version's folder only if nobody holds its marker right
  now, and otherwise leaves it for a later start. Deleting first frees the old
  version's space before the new one arrives, as native does.

  The marker is needed because Chrome's mode closes a file 150 ms after its
  last query, so the browser lets one tab delete a file an idle old tab still
  reads. Chosen 2026-09-19 over "only when no other tab is open" (cleanup waits
  while two tabs stay open, and needs a lock-ordering trick) and "delete
  without checking" (an old tab open across an update fails until it is
  reloaded). Only other versions of `bjt` and `dict` are deleted: the set of
  databases is fixed — no splits, no renames — and nothing else in `drift_db/`
  is touched.
- **Local runs use Flutter's own server**, not a custom host:
  `flutter run -d web-server` with `web_dev_config.yaml`, opened in your usual
  Chrome. Not `-d chrome` — see **What the earlier docs don't have**.
- **`drift` and `sqlite3` are pinned exactly** in `pubspec.yaml`, with a comment
  naming `web/sqlite3.wasm` and `web/drift_worker.js`; a bump changes all four
  together.
- **This plan ends at "runs locally, no server".** Hosting goes to
  `web-release.md` §6.
- **The three remote datasources and `getWebOverrides()` are deleted**, not
  moved to `deprecated/`.
- **The databases live on R2**, as
  [`static-web-hosting.md`](../../decisions/static-web-hosting.md) already
  records; the app itself goes on a plain Pages project, like the static site.
  Each file is stored gzipped with `Content-Encoding: gzip`, so the browser
  un-gzips as it downloads. Setting any of it up is hosting, not this plan.

  **Why not pieces inside the app's Pages project**, the one alternative (each
  database gzipped and cut under Pages' 25 MiB per-file limit). The extra code
  is about the same either way; where it lives is not:

  | | R2 | pieces inside Pages |
  |---|---|---|
  | app code | one URL per database | a piece list, joined in order, each piece's size checked |
  | deploy | upload the database first, then deploy the app | one deploy |
  | one-time setup | per account: R2 on, a bucket, public access, a CORS rule | none |
  | a missing file | a real 404 | Pages answers with `index.html` and a 200, which the app must catch |
  | a tab open across a deploy | its version's file is still there, so its download finishes | old pieces vanish, so its download fails |

  Pieces put permanent workaround code into the app; R2 puts one-time setup in
  the console, and a wrong setup fails on the first test. R2 is also where the
  TTS audio is planned. Checked against Cloudflare's docs 2026-09-18: 25 MiB per
  Pages file; SPA fallback when there is no `404.html`; `r2.dev` is
  rate-limited and for development only; a production custom domain must be a
  zone in the bucket's account; wrangler uploads up to 315 MB. The setup, and
  what to confirm then, is in `web-release.md` §6.

## What the earlier docs don't have

- **Download size, measured 2026-09-18** (`gzip -6`): `bjt.db` 179 → 119 MB,
  `dict.db` 172 → 30 MB. About 149 MB on a first visit.
- **The web build already carries the manifest.** `manifest.json` is a Flutter
  asset, so a web build knows each database's SHA-256 with no extra file.
- **Flutter's own server sends COOP/COEP.** Flutter 3.44.1 has no
  `--web-header` flag, but every `flutter run` web target reads
  `web_dev_config.yaml` at the project root (`flutter_tools`
  `devfs_config.dart`) and puts its headers on every response. That matters:
  Drift starts its worker from `drift_worker.js`, a file of its own. A hidden
  `--cross-origin-isolation` flag exists too, but in release and profile builds
  it covers `.html` only, and it sends `credentialless`. Both Flutter servers
  answer an unknown path with `index.html`, so reloading a deep link works.
- **`-d chrome` copies the databases on every run.** It starts a throwaway
  Chrome profile and restores, then saves, `Default/` — where OPFS lives —
  through `.dart_tool/chrome-device` (`flutter_tools` `web/chrome.dart`).
  `-d web-server` plus your usual Chrome keeps them in place.
- **Chrome's mode lets go of a file when idle.** `opfsLocks` closes it when
  SQLite unlocks it, or 150 ms after the last request (sqlite3
  `async_opfs/worker.dart`, `_releaseImplicitLocks`; the 150 ms is
  `asyncIdleWaitTimeMs` in `sync_channel.dart`). Firefox's `opfsShared` would keep files open for the
  shared worker's life and store a third file, `meta` — moot with `opfsLocks`
  pinned.
- **Drift already holds a lock per database:** `drift-db-<databaseName>`,
  exclusive, around every query (`navigator_locks_interceptor.dart`). Our lock
  names must not start with `drift-db-`.
- **Drift lists and deletes its own OPFS folders.** `WasmProbeResult` has
  `existingDatabases` (each folder under `drift_db/` holding a `database`
  file) and `deleteDatabase` (the worker swallows a failed delete).
  `WasmDatabase.open`, by contrast, picks a mode itself and keeps an existing
  database's storage — in a browser without the headers it creates an
  IndexedDB database under our name. `probe()` plus `open(mode, …)` avoids both.
- **Flutter 3.44's `flutter_service_worker.js` only unregisters itself.**
  Nothing caches the databases.

## Steps

All steps are on branch `feat/move-web-onto-drift`, step 1 included (chosen
2026-09-19 over landing it on main first).

1. **~~Fix the dictionary query~~ — done 2026-09-19.** The prefix lookup was
   `word LIKE ? ESCAPE '\'`, which never uses `idx_word`: the whole table read
   per word tap, over OPFS on web (spike §9c). Now prefix is
   `word >= ? AND word < ?` (the word, and the word followed by U+10FFFF) and
   exact is `word = ?`, built by `appendDictionaryWordMatch`, which replaced
   `buildDictionaryLikePattern` in `wisdom_shared` at all six call sites — the
   app's datasource and `server/`'s `dictionary_handler.dart`, three each.
   Same rows as `LIKE` for 907 sampled prefixes, now through `idx_word`:
   `බුද්ධ` 63 ms → under 1 ms natively. `LIKE` ignored ASCII case and the
   range does not, which changes nothing: no headword has an uppercase letter.

   The order needed a tiebreaker. `rank` is the same across a whole
   dictionary, so ties inside one followed the query plan: load order under the
   full scan, word order under the index — the first 50 differed for 267 of
   485 sampled prefixes. `dictionaryOrderBy` in `wisdom_shared` now ends
   `word, id`: alphabetical on purpose, chosen over `id` alone, which gives
   back load order exactly. The dictionary and search-flow integration tests
   pass; they check counts, not order.
2. **~~Rename `BundledDatabase` to `LocalDatabase`~~ — done 2026-09-19.** On
   web only the manifest is bundled, so "bundled" was the wrong word.
   `bundled_database.dart` is now `local_database.dart`, the executor files
   `local_database_executor*` (`openBundledExecutor` → `openLocalExecutor`), and
   `bundled_database_manifest.dart` is `database_manifest.dart`
   (`bundledDatabaseSha256` → `databaseSha256`). The native/web file split
   stays instead of passing an executor in: each platform has one way to open.
   Native behaviour is unchanged — the copy's path and stamp don't use these
   names — and the web file still throws until steps 3–4.
   [`bundled-database-copy-tests.md`](./bundled-database-copy-tests.md) took the
   new names for the code it tests; its own name and its test files' names
   stay, as they test the native copy out of the bundle. `flutter build web`
   compiles; the unit suite and the search-flow and dictionary integration
   tests pass.
3. **Prove Drift on web, throwaway.** In a release build with the headers:
   fetch `bjt.db` into `drift_db/bjt-<sha16>/database` with `createWritable()` —
   no locks, no stamp, no progress — open it with `probe()` and
   `open(opfsLocks, …, enableMigrations: false)`, then run one search and one
   page read. This settles the two web files, the headers, and opening a file
   we wrote. Time two things there: the pure-Dart zlib decoder (if it is slow,
   swap just the unpacking call for `DecompressionStream`), and SHA-256 over the
   whole download (step 4 keeps it only if it is cheap).
4. **The web installer** (data layer, web only). Each start:

   ```
   probe = WasmDatabase.probe(...)
   no opfsLocks, or no createWritable → unsupported message; nothing downloaded
   for db in manifest: hold shared "wisdom-db-in-use:<db>-<sha16>" for the tab's life
   for old in probe.existingDatabases        // bjt-/dict- + 16 hex, not this build's
     take exclusive "wisdom-db-in-use:<old>", only if free right now:
       free  → probe.deleteDatabase(old)
       held  → skip: an old tab still reads it; a later start deletes it
       error → skip
   install bjt.db, then dict.db, each under exclusive "wisdom-db-download:<db>-<sha16>":
     stamp holds the hash → installed
     otherwise stream the download into `database` (createWritable), counting bytes;
       count == manifest bytes → write the stamp
   probe.open(opfsLocks, "<db>-<sha16>", enableMigrations: false)
   ```

   - The download lock stops two tabs downloading the same file.
     `createWritable()` commits on close, so a cut download leaves no half
     file, and the stamp goes last — native's rule: no stamp, not finished.
     Fetch with `cache: 'no-store'`, so Chrome keeps no second copy.
   - No `initializeDatabase`: it loads the whole file into memory.
   - `manifest.json` gains `bytes` per database (`tools/db-finalize.js`), for
     the size check and the progress bar.
   - `navigator.storage.persist()` on each start until it returns true: Chrome
     decides from how much the site is used, at the time of asking, so a
     first-visit false can become true later.
   - `LocalDatabase.open` on web waits for that database's install, and fails at
     once if the install has failed, so a search shows an error, not a spinner.
     After "try again" it waits for the new attempt. Its doc comment describes
     the native copy only, so it changes here.
5. **Wiring.** Delete `getWebOverrides()`, the three remote datasources,
   `FTSMatch.matchedText` (only the server filled it) and the search
   repository's pre-filled-`matchedText` guard; its content datasource stops
   being nullable. Fix the comments that name the remote datasources:
   `bjtContentDataSourceProvider`, `bjt_document_datasource.dart` and
   `bjt_document_parser.dart`. Two more say the JSON ships with the app, which
   it has not since `da67891`: the no-retry comment in
   `multi_pane_reader_widget.dart` (its "on web the user can refresh" half goes
   with the server) and `EditionType.local`'s example in `edition.dart`.
   `main.dart`'s startup check runs on web too.

   **The suggestions path goes too** (decided 2026-09-19: the feature is not
   used). `bjt_suggestions` is not in `bjt.db` and no screen calls
   `getSuggestions`, so every call would throw (spike §8c); the server's copy
   also pastes `editionIds` into the table name. Delete:
   - `getSuggestions` in `TextSearchRepository`, `TextSearchRepositoryImpl`,
     `CachingTextSearchRepository` (and its class comment's line on it) and
     `FTSDataSource`; `FTSSuggestion`; `getSuggestions` and
     `_getSuggestionsFromEdition` in `fts_local_datasource.dart`. The remote
     one goes with its file.
   - The `getSuggestions` group in `text_search_repository_impl_test.dart`;
     regenerate `mocks.mocks.dart`.
   - `server/`: the `/suggestions` route and `_suggestions` in
     `fts_handler.dart` (and its class comment), the `bjt_suggestions` check in
     `database_manager.dart`.
   - `tools/bjt-populate.js`: the `bjt_suggestions` header line, the three
     suggestion settings, `extractWords`, the word counting,
     `createSuggestionsTable`, `saveSuggestions`; its line in
     `tools/README.md`. The flag is already off, so `bjt.db` does not change.
   - Docs: `{edition}_suggestions` in `multi_edition_architecture.md`; the
     open `bjt_suggestions` note in `reduce-mobile-size-and-move-to-drift.md`
     becomes done. Records stay: `docs/done/`, the spike results,
     `bjt-fts-populate-obsolete.js`.
6. **First-visit screen,** full screen, driven by the installer through a
   provider: progress, the unsupported-browser message, "try again" after a failed
   download, "not enough space" (a private window may refuse 351 MB), and
   `dict.db` starting once `bjt.db` is done. A deep link opened on a first
   visit still lands after the download (`deep_link_listener.dart` reads
   `Uri.base` after the first frame).
7. **Web files and scripts.**
   - `web/sqlite3.wasm` and `web/drift_worker.js` from the `sqlite3` 3.5.2 and
     `drift` 2.35.0 releases. `pubspec.yaml` pins `drift: 2.35.0` and adds
     `sqlite3: 3.5.2` as a direct dependency.
   - `web_dev_config.yaml` at the repo root. The headers must sit under
     `server:`, or `flutter run` stops with an error:

     ```yaml
     server:
       headers:
         - name: Cross-Origin-Opener-Policy
           value: same-origin
         - name: Cross-Origin-Embedder-Policy
           value: require-corp
     ```
   - The download URL: locally the app's own `assets/assets/databases/<db>.db`,
     uncompressed; with a `DATABASE_BASE_URL` build setting,
     `<base>/<db>-<sha16>.db.gz` on R2.
   - `run_mac.sh` stops deleting the databases from the build. Its serving
     moves off the Dart server to `flutter run -d web-server` in
     [`test-all-and-release-all.md`](../test-all-and-release-all.md) step 4; if
     this plan lands first, that change happens here.
8. **Verify in Chrome.**
   - Search, the reader and the dictionary against macOS, including the Group 9
     snippet queries by hand.
   - A reload downloads nothing. After a new database, the old folder goes at
     the next start with no old tab open, and stays while one is. A tab closed
     mid-download starts clean next time. Two tabs on a first visit download
     once.
   - A dropped connection mid-download offers "try again"; a private window
     works or says there isn't enough space.
   - A deep link on a first visit opens after the download.
   - Flutter's CanvasKit loads from Google's CDN, which must allow it under
     `require-corp`. If it doesn't, build with `--no-web-resources-cdn`.
   - Measure prefix search (the spike had `බුද්ධ*` at ~800 ms). Measure only.
   - Time the dictionary's slow case: a one-letter prefix with a dictionary
     filter. The count then reads `dict_id` from the table, not just the
     index. If it is slow, replace `idx_word` with `(word, dict_id)`.
   - `flutter analyze` clean; the native suites still pass.

**Tests:** not written by this work. A test proposal for the test agent, like
[`bundled-database-copy-tests.md`](./bundled-database-copy-tests.md). Three
existing tests change with the code: `dictionary_sql_helpers_test.dart` in
`wisdom_shared` (step 1 replaced its helper; done),
`test/data/datasources/fts_language_filter_sql_test.dart`, which builds a
`LocalDatabase` (step 2; done), and
`test/data/repositories/text_search_repository_impl_test.dart`, which passes
`contentDataSource: null` and has a `getSuggestions` group (step 5).

## Not in this plan

- **Hosting** — the Pages project, `_headers`, R2. What web Drift needs from it
  is listed in [`web-release.md`](../web-strategy/web-release.md) §6; it waits
  on the production account.
- **The update banner** — `/healthz` becomes a static version file, planned in
  [`test-all-and-release-all.md`](../test-all-and-release-all.md).
- **Offline on web.** The databases are stored locally, but the app itself
  still needs a service worker to load with no connection.
- **Faster prefix search.**
- **Firefox and Safari** — they may pass the check and run the same code;
  tested later.
- **One dictionary query, not two.** `lookupWord` and `searchDefinitions` run
  the same SQL except `OFFSET`, in the app and in `server/`; `lookupWord`
  could call `searchDefinitions`.
- **`dictionary_sql_helpers.dart` back into the app** once `server/` is gone;
  the app is then its only user.
