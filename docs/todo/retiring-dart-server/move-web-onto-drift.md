# Move Web onto Drift

> **Status 2026-09-20: in progress on branch `feat/move-web-onto-drift`; steps
> 1–3 done.** This was step 11 of
> [`reduce-mobile-size-and-move-to-drift.md`](./reduce-mobile-size-and-move-to-drift.md),
> whose steps 1–9 are done: `bjt.db` holds the page text, and native reads both
> databases through Drift. It is step 3 of the [`README.md`](./README.md) order.
> Every question it raised is decided — see **Decided**. Checked on 2026-09-18
> against the Drift 2.35.0, sqlite3 3.5.2 and Flutter 3.44.1 tool sources, and
> the web half ran for the first time on 2026-09-20 (step 3).

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
- **Drift's web side now runs here** (step 3, 2026-09-20). Its workers, opening
  by storage mode and opening a file we wrote ourselves are all verified in
  Chrome against the real `bjt.db`; the spike could only reach the SQLite layer
  under it (spike §7).
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
- **Flutter's own server sends COOP/COEP** — verified on the wire 2026-09-20.
  Every `flutter run` web target reads `web_dev_config.yaml` at the project root
  (`flutter_tools` `devfs_config.dart`; it logs `[WebDevServer] Loaded
  configuration from web_dev_config.yaml`) and puts its headers on every
  response, `--release` included. That matters: Drift starts its worker from
  `drift_worker.js`, a file of its own. `flutter run` also has a
  `--web-header key=value` flag, hidden unless `--verbose`, and CLI headers
  **merge** with the file's rather than replacing them (`copyWith` in
  `devfs_config.dart`) — the file is still the choice, so no one has to
  remember flags.
  A hidden `--cross-origin-isolation` flag exists too, but in release and
  profile builds it covers `.html` only, and it sends `credentialless`. Both
  Flutter servers answer an unknown path with `index.html`, so reloading a deep
  link works.
- **Use `--web-hostname localhost`.** Cross-origin isolation needs a secure
  context, which `http://localhost` is; the default host is `any` (`0.0.0.0`).
- **The dev server answers HEAD with 404** but serves the same path on GET.
  `curl -I` against it proves nothing; use `curl -r 0-0 -D -`.
- **`-d chrome` copies the databases on every run.** It starts a throwaway
  Chrome profile and restores, then saves, `Default/` — where OPFS lives —
  through `.dart_tool/chrome-device` (`flutter_tools` `web/chrome.dart`).
  `-d web-server` plus your usual Chrome keeps them in place.
- **Chrome's mode lets go of a file when idle.** `opfsLocks` closes it when
  SQLite unlocks it, or 150 ms after the last request (sqlite3
  `async_opfs/worker.dart`, `_releaseImplicitLocks`; the 150 ms is
  `asyncIdleWaitTimeMs` in `sync_channel.dart`). Firefox's `opfsShared` would keep files open for the
  shared worker's life and store a third file, `meta` — moot with `opfsLocks`
  pinned. Practical consequence, hit in step 3: **deleting a folder straight
  after closing its database can still meet an open handle.** Wait, or delete
  only folders no tab has opened — which is what step 4's cleanup does anyway.
- **Chrome's OPFS is a plain file on disk**, so a run can be checked without the
  browser: the database shows up under
  `~/Library/Application Support/Google/Chrome/<profile>/File System/…` at
  exactly the source file's byte count (179,093,504 for `bjt.db`). To get back
  to a first visit, wipe it in Chrome: Settings → Privacy → Site data → the
  origin → Delete.
- **Drift already holds a lock per database:** `drift-db-<databaseName>`,
  exclusive, around every query (`navigator_locks_interceptor.dart`). Our lock
  names must not start with `drift-db-`.
- **Drift lists and deletes its own OPFS folders.** `WasmProbeResult` has
  `existingDatabases` (each folder under `drift_db/` holding a `database`
  file) and `deleteDatabase` (the worker swallows a failed delete).
  `WasmDatabase.open`, by contrast, picks a mode itself and keeps an existing
  database's storage — in a browser without the headers it creates an
  IndexedDB database under our name. `probe()` plus `open(mode, …)` avoids both.
- **`WasmProbeResult`'s field is `availableStorages`**, not
  `availableStorageImplementations`, and `existingDatabases` is a list of
  `(WebStorageApi, String)` records.
- **`probe.open(...)` returns a `DatabaseConnection`, which is a
  `QueryExecutor`** — `LocalDatabase` wraps it exactly as it wraps the native
  one. Web needs no new database class, only a new executor.
- **`package:web` and `package:crypto` are transitive today.** Anything in
  `lib/` that reaches OPFS, `fetch` or SHA-256 needs `web` (and `crypto`, if a
  hash survives step 4) added to `pubspec.yaml`, or the
  `depend_on_referenced_packages` lint fails `flutter analyze`.
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
   names — and the web file still throws until step 4 (step 3 proved the web
   path outside it, in a throwaway entrypoint).
   [`bundled-database-copy-tests.md`](./bundled-database-copy-tests.md) took the
   new names for the code it tests; its own name and its test files' names
   stay, as they test the native copy out of the bundle. `flutter build web`
   compiles; the unit suite and the search-flow and dictionary integration
   tests pass.
3. **~~Prove Drift on web, throwaway~~ — done 2026-09-20. It works.** In Chrome,
   in a release build with the headers, the probe `lib/dev/web_drift_probe.dart`
   streamed `bjt.db` into `drift_db/bjt-<sha16>/database` with
   `createWritable()`, opened it with `probe()` and
   `open(opfsLocks, …, enableMigrations: false)`, and ran one search and one
   page read. `crossOriginIsolated` was true, `availableStorages` offered
   `opfsLocks`, and the only missing feature was
   `dedicatedWorkersInSharedWorkers` — the Chrome bug
   ([crbug 1088481](https://crbug.com/1088481)) that rules out `opfsShared`
   and nothing else. Results were identical to macOS: `MATCH
   'එවං*'` 27,850 rows, the same top-5 ids under `ORDER BY score, id`, `dn-1`
   148 content rows, its page 0 pali 1,629 chars of JSON over 9 entries. The
   SHA-256 of the bytes that landed in OPFS matched `manifest.json`.
   The probe copied those two queries out of `fts_local_datasource.dart` and
   `bjt_content_local_datasource.dart` rather than calling them, so the app's
   own path — providers, repositories, widgets — is still step 8's to check.
   `flutter analyze` clean, the unit suite passes, no app code touched.

   **Measured, 2026-09-20, Chrome release, served from localhost:**

   | | |
   |---|---|
   | zlib inflate, 148 real page blobs (168,707 → 786,417 bytes) | 19–26 ms, i.e. **132–176 µs per blob** |
   | SHA-256 over the 179 MB | **2,141 ms**, 74% of the 2,888 ms download-and-write |
   | OPFS streaming write of 179 MB, hashing subtracted | ~750 ms |
   | top-50 search | 165–448 ms cold, 102–122 ms warm |
   | `count(*)` after that search | 10–22 ms — see step 8, this is a warm number |

   **So: the zlib decoder stays as it is.** `DecompressionStream` would buy
   nothing at 176 µs a page and would cost a web-only branch. **And a
   per-download SHA-256 is real CPU**, on the main isolate, so step 4 keeps the
   byte count.

   The probe lives until the end of step 4 — the installer is written against
   it — then goes. Two things learnt from running it, worth keeping if it is
   ever rebuilt: its report has to be **on the page** (with `-d web-server` the
   output goes to the browser, not the terminal), and it needs a button that
   **deletes the OPFS copy and downloads again**, because a reload otherwise
   finds the database already installed and the download timings are never
   taken.

   ```bash
   flutter run -d web-server --release --no-web-resources-cdn \
     --web-hostname localhost --web-port 8099 -t lib/dev/web_drift_probe.dart
   ```

   Then open that URL in your usual Chrome.
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
   - **The size check stays a byte count, not a hash.** Step 3 measured SHA-256
     over `bjt.db` at 2,141 ms of main-isolate CPU (`package:crypto`, chunked);
     `dict.db` would cost about as much again. The browser's
     `crypto.subtle.digest` is faster but takes one buffer, which is the 179 MB
     allocation this design exists to avoid. That 2,141 ms was measured against
     localhost, where nothing hides it; on a real connection most of it would
     overlap with the transfer, but it is still main-isolate CPU.
   - `manifest.json` gains `bytes` per database (`tools/db-finalize.js`), for
     the size check and the progress bar.
   - **Reuse the probe's shapes** (`lib/dev/web_drift_probe.dart`, deleted at
     the end of this step). The OPFS walk:

     ```
     navigator.storage.getDirectory()
       → getDirectoryHandle('drift_db', create: true)
       → getDirectoryHandle('<db>-<sha16>', create: true)
       → getFileHandle('database', create: true)
       → createWritable()
     ```

     and the read loop, `ReadableStreamDefaultReader(response.body)` writing
     each `JSUint8Array` straight to the sink. Writing the JS chunk
     unconverted is what keeps the peak small. The probe's URIs are
     root-relative — `sqlite3Uri: Uri.parse('sqlite3.wasm')`,
     `driftWorkerUri: Uri.parse('drift_worker.js')` — because Flutter copies
     `web/` to the build root.
   - **Add `web` to `pubspec.yaml`** — it is transitive today, and `lib/` code
     importing it trips the `depend_on_referenced_packages` lint.
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
7. **Web files and scripts.** The first two arrived with step 3 (2026-09-20).
   - **~~`web/sqlite3.wasm` and `web/drift_worker.js`~~ — added.** Neither
     needed a download: `drift` 2.35.0 ships the prebuilt worker at its package
     root (`~/.pub-cache/hosted/pub.dev/drift-2.35.0/drift_worker.js`), and the
     same package's DevTools build carries a matching wasm at
     `extension/devtools/build/sqlite3.wasm` — SQLite 3.53.4 with FTS5, the
     fingerprint the spike recorded for the `sqlite3-3.5.2` release (`fts5`×35,
     `fts5vocab`, `bm25`, `trigram`, `unicode61`). **Known limit:** that is
     drift's DevTools copy, not the official release asset, and it was not
     compared byte for byte. If that ever matters, replace both from the GitHub
     releases — nothing else changes. Still to do here: `pubspec.yaml` pins
     `drift: 2.35.0` and adds `sqlite3: 3.5.2` as a direct dependency.
   - **~~`web_dev_config.yaml` at the repo root~~ — added**, and verified on the
     wire: every response carries both headers, `--release` included. The
     headers must sit under `server:`, or `flutter run` stops with an error:

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
     `<base>/<db>-<sha16>.db.gz` on R2. The local half is confirmed — the dev
     server answers that path with the whole file (`content-length:
     179093504`, `application/octet-stream`, and a
     `cross-origin-resource-policy: cross-origin` it adds itself).
   - `run_mac.sh` stops deleting the databases from the build. Its serving
     moves off the Dart server to `flutter run -d web-server` in
     [`test-all-and-release-all.md`](../test-all-and-release-all.md) step 4; if
     this plan lands first, that change happens here. It wants
     `--web-hostname localhost` (secure context) and, until the CanvasKit
     question in step 8 is settled, `--no-web-resources-cdn`.
8. **Verify in Chrome.**
   - Search, the reader and the dictionary against macOS, including the Group 9
     snippet queries by hand. **Compare what is stored, not a re-serialised
     copy:** step 3's one mismatch was a baseline built by re-encoding a page's
     JSON in Python, whose separator spacing added 55 characters.
   - A reload downloads nothing — the probe already showed a second load
     finding `(opfs, bjt-<sha16>)` in `existingDatabases` and skipping, so this
     is a re-check, not an unknown. After a new database, the old folder goes at
     the next start with no old tab open, and stays while one is. A tab closed
     mid-download starts clean next time. Two tabs on a first visit download
     once.
   - A dropped connection mid-download offers "try again"; a private window
     works or says there isn't enough space.
   - A deep link on a first visit opens after the download.
   - **Still open: Flutter's CanvasKit from Google's CDN under
     `require-corp`.** Step 3 dodged it with `--no-web-resources-cdn` rather
     than answering it, so the CDN path is untested. Try without the flag; if
     it fails, keep the flag — the canvaskit files are already in
     `flutter/bin/cache/flutter_web_sdk/canvaskit`, so it costs bundle size and
     nothing else. Whatever this settles applies to the deployed build too
     ([`web-release.md`](../web-strategy/web-release.md) §6).
   - Measure prefix search (the spike had `බුද්ධ*` at ~800 ms count + search,
     §10). Measure only. Use **`බුද්ධ*` and `ද*`**, the spike's own terms, for a
     like-for-like: step 3 timed `එවං*` (27,850 hits) at 165–448 ms cold and
     102–122 ms warm for the top 50, which is the first number from the
     `opfsLocks` mode we actually ship, but a different term — so it neither
     confirms nor contradicts §10's warning that `opfsLocks` would come out
     slower than that harness.
   - **Measure `count(*)` cold**, in its own session before any ranked query.
     Step 3's 10–22 ms was warm — the ranked query had already pulled those
     pages in — and the spike (§5) puts counting as the expensive half.
   - Time the dictionary's slow case: a one-letter prefix with a dictionary
     filter. The count then reads `dict_id` from the table, not just the
     index. If it is slow, replace `idx_word` with `(word, dict_id)`.
   - `flutter analyze` clean; the native suites still pass.
   - Delete `lib/dev/web_drift_probe.dart` — due at the end of step 4; check it
     has actually gone.
   - **Then the two reference docs can go.** `drift-fts5-wasm-spike-results.md`
     and `db-auto-update-prestudy.md` survived the 2026-09-20 cleanup — which
     took the spike brief, its two scripts and 407 MB of databases — only
     because this plan still cites them: the spike at §5 and §10 for the
     numbers step 8 replaces, at §7, §8c and §9c for what it found, and the
     prestudy under **Decided** for the version rule. Sweep those citations,
     and the ones in `web-release.md`,
     `reduce-mobile-size-and-move-to-drift.md` and `README.md`, first.

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
