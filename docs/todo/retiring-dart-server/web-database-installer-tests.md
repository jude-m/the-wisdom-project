# Web Database Installer — Test Proposal

Handover for a test-writing agent. Covers step 4 of
[`move-web-onto-drift.md`](./move-web-onto-drift.md): how the browser gets its
copy of `bjt.db` and `dict.db` and opens it. Read step 4 first. It is the web
twin of
[`bundled-database-copy-tests.md`](./bundled-database-copy-tests.md), and the
same rules apply.

## What is under test

- **`web_database_installer.dart`** — `WebDatabaseInstaller.instance`.
  - `_prepare()`, once per tab: reads both manifest entries, probes for
    `opfsLocks` **and** `FileSystemFileHandle.prototype.createWritable`, throws
    `DatabaseInstallFailure(unsupportedBrowser)` when either is missing and
    before anything is downloaded, asks for persistent storage, takes a shared
    `wisdom-db-in-use:<db>-<sha16>` lock per database for the tab's life, then
    deletes the versions of `bjt`/`dict` nothing holds.
  - `_install(db)`: under an exclusive `wisdom-db-download:<db>-<sha16>`,
    returns at once when `install.sha256` in the folder already holds the
    build's hash; otherwise streams the response into `database` and writes the
    stamp last. A byte count that does not match the manifest removes the
    folder and throws. Downloads run one at a time.
  - `open(db)` refuses a name outside `databases`, then waits for `_prepare()`
    and that database's install and opens `opfsLocks` with
    `enableMigrations: false`. A failed install throws on every `open` until
    `retry()`.
  - `retry()` forgets the failed installs and starts again, except an
    unsupported browser, which it leaves alone.
  - `status` / `changes` report `checking → installing → ready`, or `failed`
    with a `DatabaseInstallFailure` whose `kind` is what a first-visit screen
    branches on. Status is **per database**: `status` is `bjt.db`'s, and each
    change carries its own `database` and a `blocking` flag.
- **`local_database_executor_web.dart`** — `openLocalExecutor` starts the
  installer and returns `open(dbName)`; it never downloads by itself.
- **`database_install_status.dart`** — the status types, platform-neutral, and
  **`database_installation.dart`** — the conditional export the first-visit
  screen imports: `DatabaseInstallation` delegates to the installer on web and
  is always-ready on native.
- **`database_manifest.dart`** — `databaseManifestEntry` also requires an `int`
  `bytes`, and the two ways it can fail have two different `StateError`s: no
  entry names `npm run generate-<name>`, a missing byte count names the
  `node -e` manifest refresh instead.

## Rules

- Don't change production code to make a test easier: no `@visibleForTesting`,
  no new parameters, no new seams. If one is truly missing, stop and ask.
- Sinhala text in Sinhala script (`ධම්ම`, not "dhamma").
- The hash is an opaque string to the app, but the folder name takes its first
  16 characters, so fixtures need 16+ characters of lowercase hex.
- Run what you write, each file on its own.

## The hard part: this code only exists on web

`openLocalExecutor` is behind a conditional export, and the installer imports
`dart:js_interop` and `package:web`. `flutter test` runs on the Dart VM and
cannot load either, so **none of this is reachable from `test/`**. That is the
first thing to settle, and it is why this proposal does not list files to write
the way the native one does.

Three options, in the order worth trying:

1. **`flutter test --platform chrome`** — a separate invocation from the normal
   suite, over a `test/web/` folder that the VM run excludes. It gets real
   OPFS, real Web Locks and real `fetch`, so the interesting behaviour is
   testable rather than mocked. Check first whether a headless Chrome under
   `flutter test` is cross-origin-isolated; `opfsLocks` needs `Atomics.wait`,
   and without the COOP/COEP headers the probe will not offer it. If it is
   not, this option is dead and says so loudly.
2. **Test only what is platform-free.** `databaseManifestEntry`'s validation
   and the folder-name rule are plain Dart. Small, but real, and they run in
   the normal suite.
3. **Leave it to the browser checks in step 8** and write nothing. Honest, and
   the option to pick if 1 fails — say so in the plan rather than leaving the
   gap silent.

## What a browser test should cover

Numbered so a later doc can cite them.

1. A first visit writes `drift_db/<db>-<sha16>/database` at exactly the
   manifest's `bytes`, and `install.sha256` beside it holding the full hash.
2. The stamp is written **after** the database: a run that dies mid-download
   leaves the folder without a stamp, and the next start downloads again.
3. A second start with the stamp present downloads nothing.
4. A byte count that does not match the manifest removes the folder and throws
   a `DatabaseInstallFailure(download)` — not a database that opens and then
   fails deep inside SQLite.
5. A folder named `bjt-<other 16 hex>` that no tab holds is deleted at the next
   start; the current one and anything not matching `(bjt|dict)-[0-9a-f]{16}`
   are left alone. (Verified by hand 2026-09-20 — worth keeping.)
6. A version another context holds the shared `wisdom-db-in-use:` lock for is
   **not** deleted. Two contexts are needed; a worker is the cheap second one.
7. Two `open` calls for one database download it once.
8. After a failed install, `open` throws at once rather than downloading
   again; after `retry()` it waits for the new attempt.
9. `status`/`changes` walk `checking → installing → ready`, `received` never
   exceeds `total`, and the last `installing` reports the whole file rather
   than stopping a part-megabyte short.
10. A failed `dict.db` leaves `status` (`bjt.db`'s) `ready`: only a change with
    `blocking` true covers the app.

## Already verified by hand

Chrome 2026-09-20, headless, release build, against the real databases —
covered here so a test does not have to prove them twice, but not a substitute
for 1–10:

- First visit installed `bjt.db` (179,093,504 bytes) then `dict.db`
  (171,941,888 bytes), both at exactly the manifest counts, and the reader,
  search and the dictionary all read from them.
- A reload downloaded nothing.
- A planted `bjt-0000000000000000` was deleted at the next start while both
  current folders survived.
