# Retiring the Dart content server

Goal: delete the always-on Dart `shelf` content server. All read-only canon data
(content + FTS + dict) moves **client-side into SQLite via Drift** — native FFI on
mobile/desktop, **wasm + OPFS** in the browser — so Flutter web ships fully static.
The research (RAG) server stays as the one scale-to-zero backend; notes → Firestore.
**Net: zero always-on infrastructure.** (Decided 2026-07-16 in a design study.)

## In this folder

- **`reduce_mobile_bundle_size.md`** — the content-DB plan (JSON → contentless FTS +
  per-page compressed text, same file). Now the keystone; the top banner carries the
  decisions.
- **`drift-fts5-wasm-spike.md`** — the ONE gate to clear before committing: prove our
  FTS5 index + tokenizer return identical rows through the Drift wasm build.

## Order of operations

1. **Spike** (`drift-fts5-wasm-spike.md`) — de-risk FTS5-in-wasm.
2. **Migrate FTS + dict to Drift** (native + web) — one engine, prove parity on every client.
3. **Build the content DB** and fold it onto the same Drift path.
4. **Retire** `server/` and the web remote datasources; make Flutter web static.
   The static HTML site + Flutter bundle share one **Cloudflare Pages** project;
   the canon DBs (~140–165 MB content+FTS, ~167 MB `dict.db`) exceed Pages' 25 MiB
   per-file limit, so they're hosted on **R2** and downloaded once into OPFS — see
   [`reduce_mobile_bundle_size.md`](./reduce_mobile_bundle_size.md) (delivery bullet)
   and [`../web-strategy/static-web-hosting.md`](../web-strategy/static-web-hosting.md)
   (Free-tier fit).

## Related (outside this folder)

- `../serverless-deployment-decision.md` — hinge now dissolved (banner at top).
- `../../done/client-server-architecture-for-web.md` — the server being retired.
