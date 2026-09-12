# DB auto-update mechanism — pre-study / design brief

**Context:** follow-on to the *Retiring the Dart server* spike (`drift-fts5-wasm-spike-results.md`).
That spike established that the client downloads `bjt-fts.db` and the `dict.db` shards once
and stores them in OPFS. This brief answers the next question: **when a new version of a DB
ships (say `dict.db` two months later), how does the client pick it up seamlessly, without the
user re-downloading everything by hand?**

Verdict up front: **doable, no user-facing permissions, and it reuses code the spike already
requires.** The update path and the eviction-recovery path are literally the same function.

This is a design brief, not an implementation. It fixes the shape and names the traps so the
developer starts from the right place. Items marked **VERIFY** are web-platform behaviours that
shift over time and must be confirmed against current browser support at implementation time —
do not take them as settled.

---

## 1. The one premise to correct first

There is **no reliable "check once a month while the app is closed"** on the web. There is no
cron. The only thing resembling it is the **Periodic Background Sync API**, which is
Chromium-only, requires the app to be installed as a PWA, and fires at the browser's discretion —
never on Safari or Firefox, and not on a guaranteed schedule even where it exists.

So the model is **check on open, not on a schedule.** And the check is cheap enough that the
"once a month" throttle is not worth building: the manifest is ~1 KB, fetching it on every launch
costs nothing, and a download only happens when the version actually differs.

> **Decision: check the manifest on every boot. Download only on a version diff. No throttle.**
> A throttle would only save a trivial request while adding state you have to keep correct.

---

## 2. Storage category and permissions — nothing to solve

The DB files live in **OPFS (Origin Private File System)** — `navigator.storage.getDirectory()`.
This is browser-managed storage, the same bucket as IndexedDB and Cache Storage. Treating these
files as **cache/temp, not user-owned downloads, is the correct mental model.**

Every operation — fetch bytes, write into OPFS, delete the old file, move staged → live — happens
**silently, with zero permission prompts.** The user is never asked, sees no "file downloaded"
indicator, and cannot browse to these files in their OS file manager.

The distinction worth being precise about: there are two filesystem APIs on the web and only one
prompts.

| API | Prompts? | Use it here? |
|---|---|---|
| **OPFS** (`navigator.storage.getDirectory()`) | Never | **Yes** — this is the sandbox |
| **File System Access** (`showSaveFilePicker`, `showDirectoryPicker`) | Yes — shows a picker, touches the real filesystem | **No** — that's the *deliberate download* case, not ours |

**The consequence of the cache category — internalise this:** cache is **evictable.** The browser
may wipe the origin's storage under disk pressure, and the user can clear it via "Clear browsing
data / site data." This is not a flaw in the plan; it is exactly *why* the reconcile-on-boot
design below is mandatory rather than optional (see §6–7).

`navigator.storage.persist()` asks the browser to mark storage durable so it resists casual
eviction. On Chrome it's granted silently on engagement heuristics (returns true/false, no
dialog). **VERIFY** current Firefox/Safari behaviour — historically Firefox prompted, engines have
been converging toward silent grants. Either way, `persist()` returning `false` is **not fatal** —
it drops to best-effort storage, which the reconciler already handles.

---

## 3. CDN layout: manifest + version-stamped immutable files

```
/manifest.json                    ← mutable;   Cache-Control: no-cache
/db/bjt-fts.2026-09-01.db.gz      ← immutable; Cache-Control: public, max-age=31536000, immutable
/db/dict-core.2026-09-01.db.gz    ← immutable
/db/dict-dpd.2026-07-15.db.gz     ← immutable; independent version per shard
```

`manifest.json` lists, per DB/shard: current version, on-the-wire size, decompressed size, and
hash. Sketch:

```json
{
  "schemaVersion": 1,
  "databases": {
    "bjt-fts":   { "version": "2026-09-01", "url": "/db/bjt-fts.2026-09-01.db.gz",
                   "bytesGz": 47600000, "bytesRaw": 99400000, "sha256": "..." },
    "dict-core": { "version": "2026-09-01", "url": "/db/dict-core.2026-09-01.db.gz", ... },
    "dict-dpd":  { "version": "2026-07-15", "url": "/db/dict-dpd.2026-07-15.db.gz", ... }
  }
}
```

Why this shape:

- **The version is in the URL and the file is served `immutable`,** so browser and CDN caches are
  trivially correct — you never fight cache invalidation. Only `manifest.json` is ever revalidated.
- **Version each shard independently** (the per-`dict_id` split from spike §8). A month where only
  DPD changed then re-downloads only DPD (~30 MB gz), not the whole 274 MB. On flaky mobile this
  also raises the odds a non-resumable download completes.

---

## 4. The core constraint: you cannot overwrite an open DB

Drift holds each DB through a `FileSystemSyncAccessHandle` in its worker, and the user is hitting
`dict.db` on every word tap. Renaming over an open handle, or swapping mid-session, races
in-flight queries.

> **Decision: download-in-background, swap-on-next-boot.** The staged file is applied while Drift
> is closed, at the next launch. For a monthly dictionary refresh the one-launch delay is
> invisible, and it removes the open-handle problem entirely — no "please restart" nag, no
> mid-session disruption.

(Same-session apply is possible — close the dict connection, swap, reopen — but it's more code and
more failure surface for no real benefit here. Default to boot-swap.)

---

## 5. Download-to-staging (during the session)

Reuse the streaming writer the spike already needs for initial pre-seed (spike §6): stream the
`fetch` body, decompress, write into OPFS in chunks (~2 MB peak buffer — do **not** buffer the
whole 175 MB). Note `Content-Encoding: gzip` is transparent to `fetch`, so you write the
*uncompressed* bytes to OPFS.

Write to a **staging path**, never over the live file. Verify it (§7). Set a "pending swap" flag.
Do not touch the live file. That's the whole in-session job.

---

## 6. The reconciler (on boot, before Drift opens anything)

One function, `reconcile()`, run **before Drift opens any DB**, under a **Web Lock**
(`navigator.locks.request(...)`) so two tabs can't both do it.

For each DB in the manifest, decide from three questions — *present? correct size? matching
version?*:

1. **Verified staged file matching the manifest version exists** → delete live, move staged → live,
   record new version. → *this is the update landing.*
2. **Live file missing / short / wrong version, no staged file** → mark for download (happens in
   §5 once the app is interactive). → *this is eviction recovery **and** first install.*
3. **Live file present and matches manifest** → nothing to do.

Then open Drift on files that are now guaranteed correct.

```
boot
 └─ navigator.locks.request("db-reconcile", async () => {
      manifest = await fetch("/manifest.json")   // ~1 KB, no-cache
      for each db:
        if stagedVerified(db):   swap(db)        // delete live, move staged→live
        elif liveBad(db):        markForDownload(db)
        // else: ok
    })
 └─ Drift.open(...)   // on known-good files
 └─ (interactive) → download any marked DBs into staging → verify → set pending-swap
      → applied on next boot
```

---

## 7. Integrity and crash-safety — non-negotiable

**Crash-safe swap.** Staging + atomic move, **never** download-over-live. Delete the old file
**only after** the move succeeds. A swap interrupted halfway must leave *either* the intact old
file *or* a verified staged file — never a half-written live one.

**Transient disk.** During a swap you briefly hold old + new for the DB being replaced (~350 MB
for DPD). The per-shard split keeps this bounded — another reason it pays off.

**Integrity gate — keep it cheap:**

- **Byte-length vs manifest** — catches truncation, the common failure.
- **`PRAGMA quick_check`** when the staged DB first opens — catches structural corruption cheaply.
- **Full SHA-256** is optional belt-and-suspenders. `SubtleCrypto` does **not** stream, so don't
  hash 175 MB of decompressed bytes in one buffer — either hash the ~30 MB *compressed* artifact,
  or use a streaming WASM hasher during the write pass.

---

## 8. Update path == eviction-recovery path == first install

The single most useful property of this design: **one reconciler covers all three.** "There's a
newer version," "iOS evicted the file after ~7 days of no interaction," and "first-ever visit"
are all just *"OPFS doesn't match the manifest → make it match."* Build it once, keyed on
(present? correct size? matching version?). This is the same requirement as spike §11.11
(manifest + integrity check + re-download-on-eviction) — this brief is that item, fleshed out.

---

## 9. The developer must VERIFY (web-platform, shifts over time)

- **OPFS `FileSystemHandle.move()` / rename support** across Chrome, Safari, Firefox. If not
  universal, the fallback for the swap is copy-via-stream then delete — one extra full-size pass
  during the (Drift-closed) boot window. Since the swap runs while Drift is closed, raw OPFS APIs
  are free to use either way.
- **`navigator.storage.persist()` behaviour** (silent vs prompt) on each target engine.
- **Periodic Background Sync** — assume unavailable; the design does not depend on it. Only
  revisit if you later ship an installed PWA and want opportunistic pre-fetch as a bonus.
- **iOS Safari eviction window** (~7 days without interaction) and its tighter per-origin quota —
  the best-effort tier. The reconciler makes this survivable, not invisible.

Confirm these against current MDN / caniuse at implementation time rather than trusting any
figure here — this brief predates your build.

---

## 10. Scope and first steps

**In scope for this work:** manifest schema, CDN cache headers, the `reconcile()` boot pass under
a Web Lock, streaming download-to-staging, crash-safe atomic swap, the byte-length + `quick_check`
gate, `persist()` + handling `false`.

**Explicitly out of scope / deferred:** background scheduling (there is none), same-session apply,
delta/patch downloads (ship whole versioned files — the per-shard split already bounds payloads).

**Prototype first, in this order:**

1. Manifest + one versioned immutable file on the real host; confirm cache headers behave
   (ties into the COOP/COEP host decision, spike §3 — same "can this host set headers" question).
2. Streaming download-to-staging reusing the §6 pre-seed writer; verify ~2 MB peak buffer holds.
3. The crash-safe swap + `reconcile()` boot pass — this is the heart of it, and the part with the
   real failure modes. Test: kill the tab mid-swap, mid-download, mid-verify; confirm you always
   boot into either old-good or new-good, never broken.

**Ties back to the spike doc:** this is sequence items §11.10 (split `dict.db` by `dict_id`) and
§11.11 (manifest + integrity + re-download-on-eviction), specified. It assumes the OPFS layout and
streaming writer from §6 already exist.
