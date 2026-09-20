# First Mobile Release

> **Status 2026-09-18: not started.** Android and iOS have not been built since
> the app moved to Drift. Nothing ships to a phone until sections 1–4 are done.
> This Mac has no Android SDK and no iOS signing, so all of it needs another
> machine, or this one set up.

Background: [`reduce-mobile-size-and-move-to-drift.md`](../retiring-dart-server/reduce-mobile-size-and-move-to-drift.md).
Section 2 was its step 10.

## 1. Build both apps

- The first Android and iOS builds since Drift. They are also the first to
  fetch `package:sqlite3`'s native binaries.
- **Signing.** Android release builds still use the debug key
  (`android/app/build.gradle`). iOS needs a signed export.
- **Store upload** isn't scripted: the mobile `deploy.sh` scripts are
  placeholders in [`test-all-and-release-all.md`](../test-all-and-release-all.md).

## 2. Check on a real device

On both platforms:
- Reading and search snippets work with no network.
- Time the first-launch copy. `openLocalExecutor` copies each bundled
  database into `databases/`, so the file lives twice on disk from then on.
- Install over an older build. The database must copy again (plan step 7).

On Android only:
- Time the first search after install on a low-end phone. The engine inflates
  the whole asset on the UI thread.
- Clear the app's cache. Nothing may copy again, because on Android the copy
  lives in the files folder, not the cache.
- Auto Backup must leave `files/databases/` out:
  `adb shell bmgr backupnow <package>` succeeds.

**Full phone.** Fill the device's storage, then search. The partial copy must be
gone afterwards (`adb shell run-as <package> ls files/databases`), and the app
must stay usable. The failed-copy path has never run: a full disk can't be
reproduced on the Mac.

## 3. Decide from what section 2 shows

- **What search shows on a full phone.** Today a failed copy reaches the screen
  as "no results", like any database that won't open. Should it say "free up
  space" instead?
- **Whether a failed copy keeps retrying.** Every search retries: the debounce
  is 300 ms, and a failed open is forgotten so the next search opens again. On
  Android each try unpacks the whole asset again. Should it stop until the app
  restarts?
- **`noCompress` for `.db` on Android.** It skips the inflate but costs about
  190 MB installed: deflate takes `bjt.db` from 170 to 113 MB and `dict.db`
  from 163 to 28 MB (measured 2026-09-17). Decide once the first search has
  been timed.

## 4. Measure the real artifacts

Every size figure so far is either a macOS bundle or a per-file deflate
estimate. None came out of an APK or IPA.
- Download and installed size from a real APK and IPA. Compare them with the
  plan's estimates in **Size — the bonus, on two axes** and its step 4, where
  the download rose from 92 to 114 MB. `flutter build apk --analyze-size` gives
  the Android breakdown.
- Optional: time a search and a reader open on the phone. The speed-up was
  measured on the two code paths (plan step 2), never in the running app.

## Later: not costed

- **Download the databases instead of bundling them.** Every figure assumes the
  databases ship inside the APK/IPA. Two ways would take the install to a few
  megabytes, with a first-run fetch from R2, where egress is free:
  - the web's installer
    ([`move-web-onto-drift.md`](../retiring-dart-server/move-web-onto-drift.md)):
    the build's manifest names each database, fetched once from R2
  - the store-native options, Play Asset Delivery and iOS On-Demand Resources

  Either way, a fresh install no longer works offline, which is why this is
  listed, not proposed.
