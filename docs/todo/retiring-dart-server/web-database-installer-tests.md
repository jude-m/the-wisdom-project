# Web Database Installer — Test Proposal

Handover for a test-writing agent. Covers step 4 of
[`move-web-onto-drift.md`](../../done/retiring-dart-server/move-web-onto-drift.md): how the browser gets its
copy of `bjt.db` and `dict.db` and opens it. Read step 4 first. It is the web
twin of
[`bundled-database-copy-tests.md`](./bundled-database-copy-tests.md), and the
same rules apply.

## What is under test

- **`web_database_installer.dart`** — `WebDatabaseInstaller.instance`.
  - **All or nothing.** `start()` installs every database, then opens both
    through `LocalDatabase.open` and loads `tree.json` and `sc-to-bjt.json`
    into `rootBundle`, and only then reports `ready`. A reload whose stamps all
    match reports `ready` before the probe and skips the opening and loading.
  - `_prepare()`, once per install: probes for `opfsLocks` **and**
    `FileSystemFileHandle.prototype.createWritable`, and when either is
    missing throws before anything is downloaded — `download` if the drift
    worker did not start, `outOfSpace` if the storage estimate is short of the
    manifest's bytes, `unsupportedBrowser` otherwise. Then it asks for
    persistent storage, takes a shared
    `wisdom-db-in-use:<db>-<sha16>` lock per database for the tab's life (once,
    even across retries), then deletes the versions of `bjt`/`dict` nothing
    holds.
  - `_install()`: after `_prepare()`, downloads each database whose stamp is
    missing, one at a time, each under an exclusive
    `wisdom-db-download:<db>-<sha16>`. Inside the lock it returns at once when
    `install.sha256` already holds the build's hash (another tab finished
    it); otherwise it streams the response into `database` and writes the
    stamp last. A byte count that does not match the manifest removes the
    folder and throws.
  - `open(db)` refuses a name outside `databases`, then waits for `_install()`
    and opens `opfsLocks` with `enableMigrations: false`. A failed install
    throws on every `open` until `retry()`.
  - `retry()` starts again from the top, except for an unsupported browser,
    which it leaves alone. It never takes the reload shortcut.
  - `status` starts at `checking`, which only `retry()` sends again; `changes`
    reports `installing → ready`, or `failed` with a `DatabaseInstallFailure`
    whose `kind` is what a first-visit screen branches on. **One status for the whole install:** `received` and `total`
    count bytes over every database this start downloads.
- **`local_database_executor_web.dart`** — `openLocalExecutor` returns the
  installer's `open(dbName)`. `open` starts the downloads itself when nothing
  has yet; only `start()` (the gate) reports `ready` or `failed`, and opens
  and fetches.
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
- The installer's private names — `drift_db`, `install.sha256`, the
  `wisdom-db-in-use:` and `wisdom-db-download:` prefixes, the
  `<db>-<first 16 hex>` folder rule — are copied into the tests as literals,
  not exported.
- Run what you write. The four browser files run **in order** (below); each
  checks its own precondition and fails loudly if it is not met.

## Where it runs: `flutter drive` in Chrome, one page load per file

The installer imports `dart:js_interop` and `package:web`, so nothing of it is
reachable from `flutter test` on the VM.

**Not `flutter test --platform chrome`** (decided 2026-09-24, from the Flutter
tool's source, not run). It has a hidden `--cross-origin-isolation` flag, but
it adds the headers to `.html` responses only
(`flutter_tools/lib/src/test/flutter_web_platform.dart`). The installer loads
`drift_worker.js` relative to the page, so the worker would have to be copied
under `test/` and would arrive without COEP, which Chrome refuses inside an
isolated page. And it would test a different page from the one that ships.

**`flutter drive`**, through `scripts/app/web/test_chrome.sh`, serves the real
app with `web_dev_config.yaml`'s headers and already passes the suite. Each run
is one page load, so one fresh `WebDatabaseInstaller`; OPFS lives in the fixed
Chrome profile and survives to the next run. So a file is **a visit**, and the
files in order are a visitor's life: first visit, reload, update, bad network.

### Four test-side tricks, no production seams

1. **OPFS by hand.** Wipe `drift_db`, plant folders, read sizes and stamps,
   through `navigator.storage.getDirectory()`.
2. **A `window.fetch` wrapper.** Counts requests for `*.db` and, when a test
   asks, answers with a short body or a stream that errors part-way; everything
   else goes to the real `fetch`. The installer looks `window.fetch` up at call
   time, so it gets the wrapper.
3. **The test holds the lock.** Web Locks belong to the origin, not the tab, so
   a shared `wisdom-db-in-use:<folder>` taken by the test page blocks the
   delete exactly as another tab would. No worker needed.
4. **One asset fails.** On web `rootBundle` still sends over `flutter/assets`
   on the test binding's messenger, so a mock handler can return `null` for
   `tree.json` and pass every other key to `delegate.send`.

```dart
/// Wraps window.fetch: records database downloads, and can fake one answer.
class FetchSpy {
  final List<String> dbUrls = [];
  web.Response? Function(String url)? fake; // null → the real network
  late final JSFunction _real;

  void install() {
    _real = globalContext['fetch']! as JSFunction;
    globalContext['fetch'] = ((JSAny input, [JSAny? init]) {
      final url = input.isA<JSString>() ? (input as JSString).toDart : '';
      if (url.endsWith('.db')) {
        dbUrls.add(url);
        final answer = fake?.call(url);
        if (answer != null) return Future.value(answer).toJS;
      }
      return _real.callAsFunction(web.window, input, init);
    }).toJS;
  }
}
```

A sketch — the test writer checks it compiles.

### Harness

- Pump `ProviderScope(child: MaterialApp(home: DatabaseInstallGate(child:
  Text(<sentinel>))))` with the app's localization delegates — the gate is
  under test, not `AppShell`. The sentinel showing is "the gate lifted".
- Subscribe to `WebDatabaseInstaller.instance.changes` **before** pumping: it
  is broadcast and does not replay.
- Never `pumpAndSettle` while the screen is up — the progress bar keeps it
  busy. Poll with `pump(250 ms)` against a deadline, like
  `waitForSearchResults` in `search_test_helper.dart`.
- Read the button text from `AppLocalizations`, not a literal.
- On a first visit `ready` already proves both files open as SQLite:
  `LocalDatabase` connects with `SELECT 1`, and SQLite reads the header and
  schema to prepare even that (checked 2026-09-24 — random bytes fail with
  "file is not a database"). A real query only adds that it is *our* database.

## Files to write

| Order | File | The visit | Items |
| --- | --- | --- | --- |
| 1 | `integration_test/web_installer_first_visit_test.dart` | first visit | 1, 2, 5, 9 |
| 2 | `integration_test/web_installer_reload_test.dart` | the same browser, next visit | 3 |
| 3 | `integration_test/web_installer_update_test.dart` | a new build changed `dict.db` | 5, 6, 7, 10 |
| 4 | `integration_test/web_installer_failures_test.dart` | bad network, then good | 2, 4, 8, 11 |
| — | `test/data/database/database_manifest_test.dart` | VM, normal suite | 12 |

Shared helpers (the tricks above, the poll loop) in
`integration_test/web_installer_helpers.dart`.

The four browser files are web-only and **stay out of `all_tests.dart`**: they
wipe OPFS, and they would not compile for macOS. They share the suite's Chrome
profile — file 4 ends with a clean, current install, and anything a failed run
leaves the installer heals at the next start.

**1 — first visit.** Wipe OPFS, then plant `bjt-<current>/database` holding
1 MB of junk and no stamp, `bjt-0000000000000000/` with a stamp, and
`notes-x/`. Show the gate and wait for the sentinel. Then: both databases at
exactly the manifest's bytes with the full hash in the stamp — the junk
replaced, not appended to (1, 2); the old version gone and `notes-x/` kept
(5); each database fetched once; the status walk (9); one real query on each.

**2 — reload.** Precondition: both stamps present. The first status sent is
`ready`, with no `installing` at all (the screen never flashes), and nothing is
fetched (3). One real query on each — `open` still waits for the probe.

**3 — update.** Precondition as 2. Delete `dict-<current>`; plant
`dict-aaaaaaaaaaaaaaaa` (the test holds it in use, and waits for the grant) and
`dict-bbbbbbbbbbbbbbbb`. Before pumping, start two `open('dict.db')` calls
without awaiting them. Then: `dict.db` fetched once, `bjt.db` never and its
file untouched (7, 10); every `total` is `dict.db`'s bytes and no `ready`
before it is in (10); `aaaa` kept, `bbbb` deleted (5, 6). Release the lock at
the end.

**4 — failures.** Wipe OPFS, then in one page:

1. `bjt.db` answers 1,000 bytes: `failed`, kind `download`, "Try again" shown,
   no `bjt-<current>` folder (4). `open('bjt.db')` throws at once with no new
   fetch (8).
2. The stream errors after 2 MB. Tap "Try again", then call `open('bjt.db')`:
   it waits for this attempt (8). It fails again and leaves no stamp (2).
   Don't assert the kind yet: today it is `other`, and it should be
   `download` — the fix is banked in
   [`web-release.md`](../web-strategy/web-release.md) §6.
3. Real network, `tree.json` failing: both databases install, then `failed`
   naming `tree.json`.
4. `tree.json` back. Tap "Try again": `tree.json` is asked for again, nothing
   is re-downloaded, the sentinel shows (11).

Steps 2 and 4 automate the two "try again" checks done by hand in step 8 of
[`move-web-onto-drift.md`](../../done/retiring-dart-server/move-web-onto-drift.md).

**12 — the manifest (VM).** `databaseManifestEntry`: a good entry; no entry, or
one whose `sha256` is not a string (`StateError` naming
`npm run generate-bjt`); a hash with no byte count
(naming `writeManifestEntry`); a failed manifest load that succeeds on the next
call (the cache was evicted). Harness as in
[`bundled-database-copy-tests.md`](./bundled-database-copy-tests.md) — mock
`flutter/assets`, `rootBundle.clear()` in every `setUp`. That doc's item 8
tests the same function; it should point here rather than test it twice.

## Running them

- **`scripts/app/test.sh`** gets an `installer · Chrome` step after
  `integration · Chrome`, left out by `--quick` and guarded until the files
  exist, the way `database_copy` is. It calls
  `./scripts/app/web/test_chrome.sh <file>` once per file, in the order above.
  It needs a line in
  [`test-all-and-release-all.md`](../test-all-and-release-all.md) too.
- Each file is its own build, and files 1, 3 and 4 download for real.

## What the tests should cover

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
   **not** deleted. The test page holding the lock is that context.
7. Two `open` calls for one database download it once.
8. After a failed install, `open` throws at once rather than downloading
   again; after `retry()` it waits for the new attempt.
9. `status` starts at `checking` (a first visit never sends it — only `retry()`
   does), `changes` then walk `installing → ready`, `received` never
   exceeds `total`, and the last `installing` reports every byte rather than
   stopping a part-megabyte short.
10. With `bjt.db` stamped and `dict.db` not, `total` is `dict.db`'s bytes
    alone, and `status` is not `ready` until `dict.db` is in.
11. A failure after the downloads (a `tree.json` fetch that fails) leaves
    `status` `failed`, and `retry()` fetches it again rather than reporting
    `ready` off the stamps.
12. `databaseManifestEntry` fails with the message that names the right
    repair, and a failed manifest load does not stick.

## Already verified by hand

These stay by hand: each needs a browser setting, another browser, a second
tab or a killed process. All are recorded in step 8 of
[`move-web-onto-drift.md`](../../done/retiring-dart-server/move-web-onto-drift.md):
out of space (DevTools quota), an unsupported browser, a
`drift_worker.js` that does not load (never reproduced), a hard kill
mid-download (leaks the partial; recorded, not fixed), a private window, and
two tabs on a first visit downloading once.

Chrome 2026-09-20, headless, release build, against the real databases —
covered here so a test does not have to prove them twice, but not a substitute
for 1–11:

- First visit installed `bjt.db` (179,093,504 bytes) then `dict.db`
  (171,941,888 bytes), both at exactly the manifest counts, and the reader,
  search and the dictionary all read from them.
- A reload downloaded nothing.
- A planted `bjt-0000000000000000` was deleted at the next start while both
  current folders survived.
