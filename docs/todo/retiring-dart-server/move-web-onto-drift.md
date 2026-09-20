# Move Web onto Drift

> **Status 2026-09-20: in progress on branch `feat/move-web-onto-drift`; steps
> 1–5 done.** This was step 11 of
> [`reduce-mobile-size-and-move-to-drift.md`](./reduce-mobile-size-and-move-to-drift.md),
> whose steps 1–9 are done: `bjt.db` holds the page text, and native reads both
> databases through Drift. It is step 3 of the [`README.md`](./README.md) order.
> Every question it raised is decided — see **Decided**. Checked on 2026-09-18
> against the Drift 2.35.0, sqlite3 3.5.2 and Flutter 3.44.1 tool sources. The
> app itself first ran on web without a server on 2026-09-20 (step 5).

## Goal

Flutter web reads `bjt.db` and `dict.db` in the browser, through Drift's wasm
build, the way native reads its copies. No Dart server.

**Done means:** the web app runs locally in Chrome with no server, and search,
the reader and the dictionary show what macOS shows. Hosting is not part of
this plan — it is [`web-release.md`](../web-strategy/web-release.md) §6.

## Where web stands (2026-09-20, after step 5)

- **There is no web-only datasource left.** `getWebOverrides()` and the three
  remote datasources are deleted; every platform reads the same local
  datasources. `main.dart` runs the manifest check on web too.
- `local_database_executor_web.dart` opens the browser's own copy through
  `WebDatabaseInstaller`, which downloads it on the first visit. Anything
  outside `lib/data/database/` reaches it through `DatabaseInstallation`, a
  conditional export with a do-nothing native side (step 4's notes).
- `scripts/web/run_mac.sh` serves the app with `flutter run -d web-server`;
  `server/` and the three `scripts/web/` files that only ran or deployed it
  are in `deprecated/`.
- The update banner polls `/healthz`, which nothing answers now. Local builds
  leave it off (`VERSION_CHECK_ENABLED`); making it a static file is
  [`test-all-and-release-all.md`](../test-all-and-release-all.md)'s.
- Locked in `pubspec.lock`: Flutter 3.44.1, `drift` 2.35.0, `sqlite3` 3.5.2.
  `pubspec.yaml` does not pin them yet (step 7): it has `drift: ^2.35.0`, and
  `sqlite3` only comes in through Drift. `web: ^1.1.0` is direct since step 4.

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
  together — and check the fifth thing with them: the installer walks OPFS
  itself, so it mirrors drift's own folder name (`driftOpfsRoot`, `drift_db`,
  which the package does not export) as a `const`.
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
- **The dev server answers `/main.dart.js` with `index.html` until the compile
  finishes.** `flutter run -d web-server` serves `index.html` as soon as it is
  listening, minutes before `--release` has written `main.dart.js`; the
  fallback then hands the bootstrap an HTML file and Chrome says only
  "Refused to execute script … MIME type ('text/html')". Wait for
  `Compiling lib/main.dart for the Web...` to finish, not for the port to
  answer.
- **Headless Chrome runs all of this**, which is how step 5 was verified:
  `--headless=new` with a throwaway `--user-data-dir` is a genuine first visit
  (its OPFS goes with the folder), `--enable-logging=stderr --v=1` puts the
  app's `debugPrint` in the log as `CONSOLE:` lines, and
  `--remote-debugging-port` lets a script click, type and screenshot. Two
  traps: **virtual time starves the real OPFS I/O**, and Chrome's own
  `--screenshot` flag runs the page on it — with that flag the app paints its
  shell and then a spinner for ever, and not one `[db]` line is logged, because
  the install never starts. Take the picture on real time instead, over CDP
  (`Page.captureScreenshot`) once the page has had its seconds. The second trap
  is milder: `--disable-gpu` falls back to CPU rendering, which is slower but
  paints correctly.
- **Chrome's OPFS files are easy to count.** Each is a numbered file under
  `<profile>/Default/File System/000/t/00/`, at the database's own byte count,
  with its 64-byte `install.sha256` beside it — so `ls -l` alone says which
  versions are installed and whether an old one really went.

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
4. **~~The web installer~~ — done 2026-09-20.**
   `local_database_executor_web.dart` now starts `WebDatabaseInstaller`
   (`lib/data/database/web_database_installer.dart`) and returns its
   `open(dbName)`; the installer holds everything the pseudocode described —
   the feature check before any download, a shared
   `wisdom-db-in-use:<db>-<sha16>` per database for the tab's life, deleting
   the versions nothing holds, then the streamed download under an exclusive
   `wisdom-db-download:<db>-<sha16>`, byte count checked, stamp last. One
   download at a time. `LocalDatabase` was not touched: `probe.open` returns a
   `DatabaseConnection`, which is a `QueryExecutor`.

   The parts worth knowing that the pseudocode did not say:

   - The stamp is `install.sha256` **inside** the version folder, beside
     drift's `database`. Drift lists a folder as an existing database as soon
     as it holds a `database` file, so a cut download would look installed
     without it; it ignores the extra file, and `deleteDatabase` removes the
     folder whole.
   - Nothing starts the download at app start yet — `openLocalExecutor` does,
     on the first read. That is step 6's job, and until then a first visit sits
     on a spinner while ~350 MB arrives.
   - `databaseSha256` became `databaseManifestEntry`, returning
     `({String sha256, int bytes})`. `tools/db-finalize.js` writes `bytes`;
     `writeManifestEntry` is exported so the manifest can be refreshed without
     rebuilding a database, which is how the two existing entries got theirs.
     `manifest.json` is gitignored, so **a checkout without `bytes` fails the
     startup check until the databases are rebuilt or the manifest refreshed.**
     The field stays required on every platform even though only web reads it —
     one manifest, one shape — so the two failures carry two different
     messages: no entry at all names `npm run generate-<name>`, a hash without
     a byte count names the `node -e` refresh, which is the smaller repair.
   - `web: ^1.1.0` is a direct dependency now.
   - `DATABASE_BASE_URL` (empty by default) picks the URL: the app's own asset
     copy locally, `<base>/<db>-<sha16>.db.gz` when set. Empty also means
     `flutter build web` bundles both databases, because they are declared
     assets — stripping them is the deploy's job
     ([`web-release.md`](../web-strategy/web-release.md) §6), and nothing does
     it today.
   - **Status is per database, and the screen reads it through a
     platform-neutral name** (both settled 2026-09-20, when steps 4 and 5 were
     reviewed; step 6 depends on them):
     - `DatabaseInstallStatus` (in `database_install_status.dart`, with
       `DatabaseInstallPhase`, `DatabaseInstallFailure` and
       `DatabaseInstallFailureKind` — `unsupportedBrowser` / `outOfSpace` /
       `download` / `other`) carries the database it is about and a
       **`blocking`** flag, true only for `databases.first`. So `dict.db`
       failing cannot read as the app failing: the reader and search are in
       `bjt.db`, which is the whole point of installing it first. The installer
       keeps one status per database; `status` hands out the blocking one, and
       `changes` carries every change, tagged.
     - `DatabaseInstallation` (`database_installation.dart`) is the conditional
       export — the same split as `local_database_executor.dart` — with
       `status`, `changes`, `start()` and `retry()`. The web file delegates to
       `WebDatabaseInstaller`, the native file is always ready and does
       nothing. **`main.dart`, the provider and the screen import that, never
       `web_database_installer.dart`.** It has no caller yet; step 6 is its
       first.

5. **~~Wiring~~ — done 2026-09-20.** `getWebOverrides()`,
   `platform_providers.dart` and the three remote datasources are gone, with
   `FTSMatch.matchedText`, the search repository's pre-filled guard and
   `FTSMatch.toJson` (whose only callers were the remotes). `contentDataSource`
   is non-nullable. The comments naming the server were fixed in
   `document_provider.dart`, `bjt_document_datasource.dart`,
   `bjt_document_parser.dart`, `multi_pane_reader_widget.dart`,
   `edition.dart` and `deep_link_listener.dart`. `main.dart`'s manifest check
   runs on web.

   **The suggestions path is gone**: `getSuggestions` from the domain
   interface, `TextSearchRepositoryImpl`, `CachingTextSearchRepository` and
   `FTSDataSource`, `FTSSuggestion`, both methods in
   `fts_local_datasource.dart`, the test group, and the word counting,
   `extractWords`, `createSuggestionsTable` and `saveSuggestions` in
   `tools/bjt-populate.js` with its three config settings.
   `{edition}_suggestions` in `multi_edition_architecture.md` became
   `{edition}_content`, and `reduce-mobile-size-and-move-to-drift.md`'s open
   note says where it went. `tools/bjt-fts-populate-obsolete.js` keeps its copy
   — it is a record.

   **`server/` was not edited. It moved to `deprecated/server/`** (decided
   2026-09-20, bringing forward
   [`test-all-and-release-all.md`](../test-all-and-release-all.md) step 4).
   With it went `scripts/web/deploy.sh`, `run_win.bat` and `restart_win.bat`,
   to `deprecated/scripts-web/` — all three existed only to deploy or run the
   Dart server. Its `pubspec.yaml` path to `wisdom_shared` was repointed so the
   package still resolves if it is ever revived.

   `test/data/repositories/text_search_repository_impl_test.dart` takes a
   `MockBJTContentDataSource` stubbed to return no page sides instead of
   `contentDataSource: null`, so `BJTContentDataSource` joined
   `test/helpers/mocks.dart`. The unit suite is 636 tests, from 639.

6. **First-visit screen,** full screen, driven by `DatabaseInstallation`
   through a provider: progress, the unsupported-browser message, "try again"
   after a failed download, "not enough space" (a private window may refuse
   351 MB), and `dict.db` starting once `bjt.db` is done. It covers the app
   only while a **blocking** status is unready, so a failed dictionary leaves
   the reader and search alone — see step 4's notes for the surface. A deep
   link opened on a first visit still lands after the download
   (`deep_link_listener.dart` reads `Uri.base` after the first frame).
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
   - **~~The download URL~~ — built in step 4**, and both halves of the rule
     are in `WebDatabaseInstaller`. The local one is confirmed end to end: a
     first visit installed both databases from
     `assets/assets/databases/<db>.db` at the manifest's byte counts.
   - **~~`run_mac.sh`~~ — rewritten 2026-09-20**, bringing forward
     [`test-all-and-release-all.md`](../test-all-and-release-all.md) step 4. It
     is now `flutter run -d web-server` with `--web-hostname localhost`
     (secure context) and `--no-web-resources-cdn` (until step 8 settles
     CanvasKit); `--debug|--profile|--release`, `--port` and `--clean` survive,
     `--skip-build` does not — `flutter run` always builds. Nothing deletes
     the databases from a build any more, because there is no `build/web` to
     clean: the dev server serves the assets itself.
8. **Verify in Chrome.** Some of this was done on 2026-09-20 while verifying
   step 5, in **headless** Chrome (release build, `-d web-server`, driven over
   the DevTools protocol). Headless is not the browser a reader uses, so the
   ticks below say what was seen, not that the item is closed.

   Already seen, headless:
   - A first visit through the deep link `/tipitaka/dn-1-1` installed `bjt.db`
     (179,093,504 bytes) and then `dict.db` (171,941,888 bytes), both exactly
     the manifest's counts, and the reader painted the sutta in parallel
     Pali/Sinhala. So a deep link on a first visit does land.
   - A reload downloaded nothing.
   - A search for `එවං` returned full-text hits with snippets out of
     `bjt_content` and definitions out of `dict.db`.
   - A planted `drift_db/bjt-0000000000000000/database` was deleted at the next
     start; both current folders survived.
   - No errors in the console on any run. `storage.persist()` returned false,
     which is what headless does.

   Seen again on 2026-09-20 after the review fixes, headless, release build,
   served from `build/web` with the two headers:

   - A first visit installed both databases in order and at exactly the
     manifest's counts, and `ls -l` in the throwaway profile showed the four
     files: 179,093,504 and 171,941,888 bytes, each with a 64-byte stamp.
   - A reload downloaded nothing (`already installed as bjt-<sha16>`).
   - **A new version replaces the old one and frees its space first.** With the
     build's manifest given a different hash for `bjt.db`, the next start
     deleted `bjt-d3f2cd05cf3343b7`, then downloaded — and the profile held
     341 MB, not 520 MB, so the delete was real and not just logged. `dict.db`
     was left alone.
   - The reader painted `dn-1` in parallel Pali/Sinhala out of the downloaded
     `bjt.db`.

   Still to do, and the reason this step is open:
   - **All of the above again in a real Chrome**, by eye.
   - Search, the reader and the dictionary against macOS, including the Group 9
     snippet queries by hand. **Compare what is stored, not a re-serialised
     copy:** step 3's one mismatch was a baseline built by re-encoding a page's
     JSON in Python, whose separator spacing added 55 characters.
   - A tab closed mid-download starts clean next time. Two tabs on a first
     visit download once. A version an **open second tab** holds is kept —
     only the "nothing holds it" half has been seen.
   - A dropped connection mid-download offers "try again"; a private window
     works or says there isn't enough space.
   - **Still open: Flutter's CanvasKit from Google's CDN under
     `require-corp`.** Step 3 dodged it with `--no-web-resources-cdn` rather
     than answering it, so the CDN path is untested. Try without the flag; if
     it fails, keep the flag — the canvaskit files are already in
     `flutter/bin/cache/flutter_web_sdk/canvaskit`, so it costs bundle size and
     nothing else. Whatever this settles applies to the deployed build too
     ([`web-release.md`](../web-strategy/web-release.md) §6) and to
     `run_mac.sh`.
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
   - `flutter analyze` clean; the native suites still pass. (Both true at the
     end of step 5, and again after the review fixes: 636 unit tests, plus the
     search-flow and two dictionary integration files.)
   - ~~Delete `lib/dev/web_drift_probe.dart`~~ — gone 2026-09-20, once step 5
     had been verified.
   - **Then the two reference docs can go.** `drift-fts5-wasm-spike-results.md`
     and `db-auto-update-prestudy.md` survived the 2026-09-20 cleanup — which
     took the spike brief, its two scripts and 407 MB of databases — only
     because this plan still cites them: the spike at §5 and §10 for the
     numbers this step replaces, at §7 and §9c for what it found, and the
     prestudy under **Decided** for the version rule. Sweep those citations,
     and the ones in `web-release.md`,
     `reduce-mobile-size-and-move-to-drift.md` and `README.md`, first.

**Tests:** not written by this work, the 2026-09-20 review fixes included. The
proposal for the test agent is
[`web-database-installer-tests.md`](./web-database-installer-tests.md) —
read its "The hard part" section first: none of the installer is reachable
from `flutter test` on the VM, so what can be tested at all is the first
question. Three existing tests changed with the code:
`dictionary_sql_helpers_test.dart` in `wisdom_shared` (step 1),
`test/data/datasources/fts_language_filter_sql_test.dart` (step 2) and
`test/data/repositories/text_search_repository_impl_test.dart` (step 5).

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
- **One place that knows a database's name.** Three know today:
  `WebDatabaseInstaller.databases`, `FTSDataSourceImpl._dbNameFor`
  (`'$editionId.db'`) and `DictionaryLocalDataSource._dbName`. A new edition
  means a new `{editionId}.db`
  ([`multi_edition_architecture.md`](../multi_edition_architecture.md)), which
  on web also has to be installed and published; `open()` says so rather than
  throwing a null check, and unifying the three is multi-edition work.
- **`dictionary_sql_helpers.dart` back into the app** once `server/` is gone;
  the app is then its only user.
