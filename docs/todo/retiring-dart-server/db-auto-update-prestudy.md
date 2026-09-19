# Database updates on the web — pre-study

**Context:** follow-on to the *Retiring the Dart server* spike
(`drift-fts5-wasm-spike-results.md`), which settled that the browser downloads
`bjt.db` and `dict.db` once and keeps them in OPFS. The question here: **when a
rebuilt database ships, how does a browser that already holds the old one pick it
up, without the user doing anything?**

> **Answered 2026-09-18: the database version rides with the web build.** The
> build's `manifest.json` names each database's SHA-256; the browser installs that
> version into a folder of its own, and deletes an old version once no tab uses
> it. The design is in [`move-web-onto-drift.md`](./move-web-onto-drift.md). This
> brief keeps what the study found that still holds.

---

## 1. No schedule on the web — check on open

There is **no reliable "check once a month while the app is closed"** on the web.
The only thing resembling it, the **Periodic Background Sync API**, is
Chromium-only, needs the app installed as a PWA, and fires at the browser's
discretion — never on Safari or Firefox, and not on a schedule even where it
exists. So the check happens when the app opens. With the version in the build,
it is a comparison against the build's `manifest.json`, fetched from the app's
own host like any asset: no request to R2.

## 2. Storage category and permissions — nothing to solve

The databases live in **OPFS (Origin Private File System)** —
`navigator.storage.getDirectory()`. This is browser-managed storage, the same
bucket as IndexedDB and Cache Storage. Treating these files as **cache, not
user-owned downloads, is the right mental model.**

Every operation — fetch, write into OPFS, delete an old version — happens
**silently, with zero permission prompts.** The user is never asked, sees no
"file downloaded" indicator, and cannot browse to these files in their OS file
manager. Only one of the two filesystem APIs prompts:

| API | Prompts? | Use it here? |
|---|---|---|
| **OPFS** (`navigator.storage.getDirectory()`) | Never | **Yes** — this is the sandbox |
| **File System Access** (`showSaveFilePicker`, `showDirectoryPicker`) | Yes — shows a picker, touches the real filesystem | **No** — that's the *deliberate download* case, not ours |

**Cache is evictable.** The browser may wipe the origin's storage under disk
pressure, and the user can clear it via "Clear browsing data / site data."
`navigator.storage.persist()` asks the browser to resist that. Chrome answers
from site engagement at the time of asking, with no dialog, so the app asks on
each start until it gets `true`. A `false` is not fatal: storage stays
best-effort, and §5 covers an eviction.

## 3. One file per version on R2, named by its hash

```
bjt-<first 16 hex of SHA-256>.db.gz     ← Cache-Control: public, max-age=31536000, immutable
dict-<first 16 hex of SHA-256>.db.gz    ← the same
```

A database's version **is its SHA-256**: the one `tools/db-finalize.js` computes
over the finished, uncompressed file, the same fingerprint native compares
(`assets/databases/manifest.json`). There is no separate version to bump.

- **The hash is in the name and a file is never overwritten,** so browser and
  CDN caches are trivially correct, and a tab still on an old build finishes
  downloading its own version after a deploy.
- **The same name is the OPFS folder** (`drift_db/bjt-<sha16>/`), so nothing is
  ever replaced in place.
- **No shards.** The set of databases is fixed (decided 2026-09-19).

## 4. You cannot delete a database a tab is reading

Chrome's OPFS mode (`opfsLocks`) closes a file 150 ms after its last query, so
the browser does not stop another tab deleting a file that an idle old tab still
reads — its next search would fail. Hence a new version goes into a new folder,
and an old folder is deleted only when no tab holds its in-use Web Lock
([`move-web-onto-drift.md`](./move-web-onto-drift.md) step 4).

## 5. Update == eviction recovery == first install

The most useful property: **one path covers all three.** "There's a newer
version," "the browser evicted the storage" and "first-ever visit" are all *no
finished folder for this build's version → install it.* Build it once.

## 6. Integrity — keep it cheap

- **Byte length against the manifest** — catches a cut download, the common
  failure.
- **`createWritable()` commits on close**, and a stamp written last marks an
  install finished; a folder without one is installed again.
- **Full SHA-256 is optional.** A file's name comes from its hash and HTTPS
  covers the transfer. `SubtleCrypto` does not stream, so hashing would be pure
  Dart on the UI thread over 351 MB — measured before it is kept
  (`move-web-onto-drift.md` step 3).

## 7. Verify at implementation time

- **`navigator.storage.persist()`** on each target engine (silent or a prompt).
- **iOS Safari eviction** (~7 days without interaction) and its tighter
  per-origin quota — the best-effort tier. §5 makes it survivable, not invisible.
- **Periodic Background Sync** — assume unavailable; nothing depends on it.
