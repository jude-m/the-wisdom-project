# Bundled Database Copy — Test Proposal

Handover for a test-writing agent. Covers step 7 of
[`reduce-mobile-size-and-move-to-drift.md`](./reduce-mobile-size-and-move-to-drift.md):
how the app keeps its copy of `bjt.db` and `dict.db` current. Read step 7 first.

## What is under test

- **`local_database_executor_native.dart`** — `openLocalExecutor(dbName)`
  reads the hash for `dbName` from `assets/databases/manifest.json`, then works
  in a `databases/` folder it creates: under `getApplicationSupportDirectory()`
  on Android, under `getApplicationCacheDirectory()` everywhere else.
  - The copy is current when `<db>` exists **and** `<db>.sha256` holds that
    hash.
  - Otherwise it deletes the stamp, deletes the old copy, writes the asset
    straight to `<db>` in 8 MB pieces, and writes the stamp last.
  - If the copy or the stamp write throws, it deletes the partial copy and
    rethrows.
- **`database_manifest.dart`** — `databaseManifestEntry(dbName)` throws a `StateError`
  naming `npm run generate-<name>` when the manifest has no entry.
- **`local_database.dart`** — `LocalDatabase.open` shares one connection per
  file, so two first readers copy once, and a failed open is forgotten so the
  next one retries.

## Rules

- Don't change production code to make a test easier: no `@visibleForTesting`,
  no new parameters, no new seams. If one is truly missing, stop and ask.
- The only new dev dependencies allowed are `path_provider_platform_interface`
  and `plugin_platform_interface`. Don't import `package:sqlite3` — it is
  transitive, so `depend_on_referenced_packages` would complain.
- Sinhala text in Sinhala script (`ධම්ම`, not "dhamma").
- The app treats the hash as an opaque string. `"hash-a"` and `"hash-b"` are
  fine; nothing needs a real SHA-256.
- Run what you write, each file on its own.

## Files to write

| File | Holds | Run with |
| --- | --- | --- |
| `test/data/database/bundled_database_copy_test.dart` | 1–11 | `flutter test <file>` |
| `integration_test/bundled_database_copy_test.dart` | 12 | `flutter test <file> -d macos` |

Keep the integration file **out of `all_tests.dart`**: it closes the shared
connection and swaps the database file, which would disturb the files sharing
that app launch. It needs its own line in the integration row of
[`test-all-and-release-all.md`](../test-all-and-release-all.md), or nothing will
ever run it.

## Harness (unit tests)

- **Binding.** `TestWidgetsFlutterBinding.ensureInitialized()` at the top of
  `main()`, then plain `test()` cases. Not `testWidgets`: its fake clock stalls
  real file IO and Drift's background isolate.
- **The folder.** Set `PathProviderPlatform.instance` to a fake
  (`MockPlatformInterfaceMixin`) whose `getApplicationCachePath()` returns a
  fresh `Directory.systemTemp.createTemp()` per test, deleted in `tearDown`.
  Tests run on the host, so `Platform.isAndroid` is false and only the cache
  branch is reachable; the Android folder is a device check (14).
- **Assets.** `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
  .setMockMessageHandler('flutter/assets', …)`. The message is the asset key as
  UTF-8 (`utf8.decode(Uint8List.sublistView(message!))`). Serve the manifest and
  the database bytes from a map and count requests per key: a request for
  `assets/databases/bjt.db` means a copy happened. Returning `null` makes
  `rootBundle.load` throw — that is how scenario 9 fails an asset.
- **Clear the bundle cache in every `setUp`.** `rootBundle.loadString` caches
  the manifest and flutter_test never clears it, so without `rootBundle.clear()`
  a test reads an earlier test's manifest and results depend on test order. Call
  it again inside a test that changes the manifest mid-test (1, 2).
- **Fill assets with a pattern**, e.g. `i % 251`, not zeros: zeros hide a wrong
  offset in the piece loop.
- **A real SQLite file** is needed only where a connection opens (9, 11). Build
  it like `test/data/datasources/fts_language_filter_sql_test.dart` does, but on
  a file: `LocalDatabase(NativeDatabase(File(...)))`, one `customStatement`,
  `close()`, then read its bytes. Elsewhere the executor is lazy, so any bytes
  work and nothing needs closing.
- **Connections are static.** Call `LocalDatabase.closeShared` for both names
  in `tearDown`.

## Scenarios, most critical first

### P1 — App update (a new build ships a new database)

The copies survive an app update, and only the stamp check replaces them. A bug
here means old text in a new app, silently.

1. **Changed database is replaced.** Start with a copy and stamp from `hash-a`;
   the manifest now says `hash-b`, with different bytes. After open: the file
   holds the new bytes, the stamp says `hash-b`, and the folder holds only the
   copy and its stamp. Run it once more with the stamp holding garbage — same
   path, one more assertion.
2. **Only the changed one is replaced.** `dict.db` changes and `bjt.db` does
   not: no asset request for `bjt.db`, and `dict.db` is replaced.
3. **Nothing changed.** No asset request for either database.

### P1 — Fresh install

4. **No copy yet, no `databases/` folder.** The folder is created, the copy is
   byte-identical to the asset, and the stamp matches.
5. **Piece boundaries.** Assets of exactly 8 MiB and 8 MiB + 1 copy
   byte-identical. Those two catch both off-by-ones the loop can make.

### P2 — Partial states the OS or a kill can leave

6. **The copy was deleted, its stamp kept.** It copies again and ends with both.
7. **The stamp was deleted, the copy kept and larger than the asset.** It copies
   again, and the result is exactly the asset's bytes — not the asset followed
   by the old tail.

### P2 — Errors

8. **No entry in the manifest**, or an entry with no string `sha256`:
   `StateError` naming `npm run generate-bjt` (or `generate-dict`), and no
   `databases/` folder created — the hash is read before anything touches disk.
9. **The asset request fails.** Start with no copy and a stamp holding the
   current hash (the OS deleted only the copy). The open throws, and afterwards
   neither a stamp nor a partial copy is left. Then, through
   `LocalDatabase.open`, a later open with the asset served succeeds — the
   retry path.
10. **The stamp can't be written.** Put a *folder* at `<db>.sha256` before
    opening. The copy runs, the stamp write throws, and no `<db>` is left: the
    cleanup gave the space back. (The real case is a disk filling mid-write,
    which can't be faked without a brittle fake `File`.)

### P3 — Sharing

11. **Two opens, one copy.** Two `LocalDatabase.open('bjt.db')` calls, the
    second started before the first completes, return the same instance and make
    one asset request.

### Integration (macOS, real app and real assets)

12. **Stale copy replaced end to end.** In its own file: call
    `LocalDatabase.closeShared('bjt.db')`, write garbage to `bjt.db` and
    `"stale"` to `bjt.db.sha256` in `getApplicationCacheDirectory()`'s
    `databases/` folder (create it), pump the search app, and search `ධම්ම`.
    Expect full-text results above zero, and the stamp to equal the `bjt.db`
    entry in the bundled manifest. The copy ends correct, so later runs aren't
    affected.

## Covered elsewhere — don't test twice

13. **The manifest must match the shipped files.** A database changed outside
    `tools/db-finalize.js` leaves the manifest stale, and existing installs
    silently keep their old copy. That check belongs to `scripts/app/test.sh`'s
    "shipped databases" row in
    [`test-all-and-release-all.md`](../test-all-and-release-all.md).
14. **Devices ([`first-mobile-release.md`](../mobile-release/first-mobile-release.md)).** Installing over an older build; on Android,
    clear-cache versus clear-storage, `adb shell bmgr backupnow <package>`, and
    the full-phone case.

## Not worth a test

- **The `main.dart` error screen.** `main()` calls `runApp` directly, so testing
  it would mean restructuring production code. Checked by hand in the real macOS
  app on 2026-09-17.
- **`-wal`/`-shm` files.** The copies are read-only and use a rollback journal;
  none appeared after the suites ran.
- **`tools/db-finalize.js` under `node:test`.** Everything it could get wrong
  shows up in 13, which needs no new test runner in `tools/`.
- **The Android folder branch.** Unreachable from host tests; covered by 14.
