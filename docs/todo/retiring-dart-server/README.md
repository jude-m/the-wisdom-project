# Retiring the Dart content server

Goal: delete the always-on Dart `shelf` content server. All read-only canon data
(content + FTS + dict) moves **client-side into SQLite via Drift** — native FFI on
mobile/desktop, **wasm + OPFS** in the browser — so Flutter web ships fully static.
The research (RAG) server stays as the one scale-to-zero backend; notes → Firestore.
**Net: zero always-on infrastructure.** (Decided 2026-07-16 in a design study.)

## In this folder

- **`reduce-mobile-size-and-move-to-drift.md`** — the content-DB plan (JSON →
  contentless FTS + per-page compressed text, same file) and the app's move to
  Drift. Now the keystone; the top banner carries the decisions and the current
  step, and **What the Drift/wasm spike changed** carries what moved after the
  spike.
- **`move-web-onto-drift.md`** — web reads the same databases in the browser, with
  no server. Was step 11 of the content-DB plan. It also carries how a rebuilt
  database reaches a browser that already has the old one: the version rides with
  the web build, so update, eviction recovery and first install are one path.

## Order of operations

1. ~~**Spike** — de-risk FTS5-in-wasm.~~ **DONE 2026-09-11, passed.** FTS5 is in the
   shipped wasm and our index returns byte-identical rows through it. The blocker it
   found instead — both DBs WAL-flagged, which that build rejects outright — is fixed
   in `tools/db-finalize.js`, which both database generators now end in.
2. **Build the content DB and move the app onto Drift — one branch, native only.**
   Decided 2026-09-13: FTS, dict and the new content table leave `sqflite`
   together — engine swap first, content table on top. Steps 5–9 of
   [`reduce-mobile-size-and-move-to-drift.md`](./reduce-mobile-size-and-move-to-drift.md),
   all done 2026-09-18: the app is on Drift and ships no JSON. The device
   pass that was step 10 is in
   [`first-mobile-release.md`](../mobile-release/first-mobile-release.md).
3. **Move web onto Drift** (wasm + OPFS) — the same datasources, reading a database
   downloaded once rather than bundled:
   [`move-web-onto-drift.md`](./move-web-onto-drift.md).
4. **Host Flutter web statically** —
   [`web-release.md`](../web-strategy/web-release.md) §6. Step 3 already deletes
   the web remote datasources, and moved `server/` — with the three
   `scripts/web/` files that only existed to run or deploy it — to
   `deprecated/` (2026-09-20).
   The static HTML site and the Flutter bundle are separate **Cloudflare Pages**
   projects (one per surface); the canon DBs (~180 MB content+FTS, ~175 MB
   `dict.db`) exceed Pages' 25 MiB per-file limit, so they're hosted on **R2** and
   downloaded once into OPFS — see
   [`static-web-hosting.md`](../../decisions/static-web-hosting.md) (Free-tier fit).

> **2 before 4, and that is new.** Without the content DB, going static means serving
> the 285 `assets/text/*.json` files to the browser — ~27 conditional GETs and 3–4 MB
> per results page, and never offline. Step 2 deletes that path; doing 4 first means
> building it and then throwing it away. (The spike called that fetch path "the
> least-understood piece" of going static. The answer is not to prototype it.)
> Step 3 sits between them for a simpler reason: it reads the table step 2 builds.
>
> Step 3 is also where COOP+COEP become required: without them Drift on Chrome
> does not fall back to "slower OPFS", it falls back to IndexedDB holding the whole
> library. Step 3 sends them locally (`web_dev_config.yaml`) and shows a message
> instead of running without them; hosting sends them from `_headers`
> (`web-release.md` §6).

## Related (outside this folder)

- `../serverless-deployment-decision.md` — hinge now dissolved (banner at top).
- `../../done/client-server-architecture-for-web.md` — the server being retired.
