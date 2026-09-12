# Retiring the Dart content server

Goal: delete the always-on Dart `shelf` content server. All read-only canon data
(content + FTS + dict) moves **client-side into SQLite via Drift** — native FFI on
mobile/desktop, **wasm + OPFS** in the browser — so Flutter web ships fully static.
The research (RAG) server stays as the one scale-to-zero backend; notes → Firestore.
**Net: zero always-on infrastructure.** (Decided 2026-07-16 in a design study.)

## In this folder

- **`reduce_mobile_bundle_size.md`** — the content-DB plan (JSON → contentless FTS +
  per-page compressed text, same file). Now the keystone; the top banner carries the
  decisions, and **What the Drift/wasm spike changed** carries what moved after the
  spike. The only open question on its critical path is blob granularity.
- **`drift-fts5-wasm-spike-results.md`** — what the spike found. Read this one.
- **`db-auto-update-prestudy.md`** — the follow-on design brief: how a rebuilt DB
  reaches a client that already has the old one. Manifest + a boot reconciler, where
  the update path, eviction recovery and first install are one function.
- **`drift-fts5-wasm-spike.md`** — ~~the ONE gate~~ **PASSED 2026-09-11**. The brief
  as written before the spike ran, kept for what it asked. One section of it is
  actively wrong and marked so.

## Order of operations

1. ~~**Spike** — de-risk FTS5-in-wasm.~~ **DONE 2026-09-11, passed.** FTS5 is in the
   shipped wasm and our index returns byte-identical rows through it. The blocker it
   found instead — both DBs WAL-flagged, which that build rejects outright — is fixed
   in `tools/db-finalize.js`, which both database generators now end in.
2. **Migrate FTS + dict to Drift** (native + web) — one engine, prove parity on every client.
3. **Build the content DB** and fold it onto the same Drift path.
4. **Retire** `server/` and the web remote datasources; make Flutter web static.
   The static HTML site + Flutter bundle share one **Cloudflare Pages** project;
   the canon DBs (~180 MB content+FTS, ~175 MB `dict.db`) exceed Pages' 25 MiB
   per-file limit, so they're hosted on **R2** and downloaded once into OPFS — see
   [`reduce_mobile_bundle_size.md`](./reduce_mobile_bundle_size.md) (delivery bullet)
   and [`static-web-hosting.md`](../../decisions/static-web-hosting.md)
   (Free-tier fit).

> **3 before 4, and that is new.** Without the content DB, going static means serving
> the 285 `assets/text/*.json` files to the browser — ~27 conditional GETs and 3–4 MB
> per results page, and never offline. Step 3 deletes that path; doing 4 first means
> building it and then throwing it away. (The spike called that fetch path "the
> least-understood piece" of going static. The answer is not to prototype it.)
>
> Step 2 is also where the host decision lands: without COOP+COEP, Drift on Chrome
> does not fall back to "slower OPFS", it falls back to IndexedDB holding ~274 MB.

## Related (outside this folder)

- `../serverless-deployment-decision.md` — hinge now dissolved (banner at top).
- `../../done/client-server-architecture-for-web.md` — the server being retired.
