# Spike: Verify FTS5 works in the Drift WASM build (the one gate)

> **Status: DONE 2026-09-11 — PASSED.** The gate is cleared: FTS5 is compiled
> into the `sqlite3.wasm` Drift ships, and the real `bjt-fts.db` returns
> byte-identical rows through it. This page is the brief that was written
> *before* the spike ran; it is kept for what it asked, not as guidance.
>
> **Read [`drift-fts5-wasm-spike-results.md`](./drift-fts5-wasm-spike-results.md)
> instead.** It answers everything below and more, because the spike went
> further than this brief asked — and what it found that matters most is not in
> this page's pass criteria at all:
>
> - **The real blocker was never FTS5.** Both shipped databases are WAL-flagged,
>   and the wasm build (compiled `SQLITE_OMIT_WAL`) rejects such a file on the
>   first prepare with `SQLITE_NOTADB: file is not a database`. Fixed in the
>   build pipeline, 2026-09-11.
> - **"Secondary (deploy detail, not a gate)" below is wrong**, and is the one
>   part of this page that could still mislead — see the note on it.
> - It also found **three live performance bugs** in this repo, on every
>   platform, unrelated to the web move.
>
> **Part of:** retiring the Dart content server (see `README.md` and
> `reduce_mobile_bundle_size.md`).

## The narrow question this answers

Not "does Drift work?" (settled — production-grade, all platforms). The gate is
project-specific:

> Does **our real `bjt-fts.db`** — a **contentless** FTS5 index with the custom
> `unicode61 tokenchars` Sinhala charlist — return the **same rows** through the
> Drift **wasm** build (loaded into OPFS) as it does natively?

Why it's still open despite high-confidence research:

- Prebuilt `sqlite3.wasm` *should* ship `SQLITE_ENABLE_FTS5` (secondary sources; the
  literal build flag was not confirmed — the repo's build file 404'd).
- Standard `unicode61` *should* tokenize identically in wasm — but the whole search
  feature rides on it, so prove parity, don't assume.

## Pass criteria

For a set of real Sinhala queries, the **row ids returned in the browser (Drift
wasm/OPFS) match the rows returned natively** for the same query — same hits, same
order under `bm25`. Zero `no such module: fts5` / `unknown tokenizer` errors.

## Steps

1. Throwaway Flutter web target (or a plain `package:drift` wasm harness).
2. Add `drift` + `drift/wasm.dart`; drop `sqlite3.wasm` and the drift worker into `web/`.
3. Ship `assets/databases/bjt-fts.db`, load its bytes into **OPFS**, open read-only
   with `WasmDatabase`.
4. Run 3–5 real queries via `customSelect`:
   `SELECT rowid FROM bjt_fts WHERE bjt_fts MATCH ? ORDER BY bm25(bjt_fts)`
   — include a common term (long doclist) and a rare one. Use Pali-in-Sinhala-script
   terms (e.g. එවං), not romanized.
5. Compare the row ids to the native result for the same queries.
6. Note query timings if handy (informs UX, not a gate).

## If it fails

- **`no such module: fts5`** → the shipped wasm lacks FTS5. Use a `sqlite3.wasm`
  compiled with `-DSQLITE_ENABLE_FTS5` (the `sqlite3` package's own prebuilt, or a
  custom build) and re-test. Only a real blocker if no FTS5 wasm can be sourced.
- **Rows differ** → tokenizer parity issue. Check the `tokenize=` string the DB was
  built with is honoured and the Sinhala `tokenchars` survived.
- Neither is expected — the evidence points to a clean pass.

## ~~Secondary (deploy detail, not a gate)~~ — this was the wrong call

> The original text read: *"For full-speed OPFS, serve the web app with
> `Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy:
> require-corp`. Drift falls back (slower) without them."*
>
> **It is a hosting constraint, not a deploy detail.** Drift picks its storage
> mode at runtime from browser capability. The OPFS mode that does not need
> cross-origin isolation requires nested workers in a shared worker — **Firefox
> only**. On Chrome and Safari the only OPFS path needs `Atomics.wait`, hence
> COOP+COEP. So without the headers, on the primary target, the fallback is not
> "slower OPFS" — it is **IndexedDB holding 274 MB**, which is a different
> product.
>
> Consequences: the host must be able to set response headers (Cloudflare Pages
> can; GitHub Pages cannot), and `require-corp` breaks any cross-origin
> subresource lacking CORP — consider `credentialless` and self-hosted fonts.
> Measured, the headers are **not** a performance knob (447 vs 436 ms cold);
> they are the gate that decides whether OPFS is used at all.
