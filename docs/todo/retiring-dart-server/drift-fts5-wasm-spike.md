# Spike: Verify FTS5 works in the Drift WASM build (the one gate)

> **Status:** TODO — the single technical gate before committing to Drift +
> client-side SQLite on web. ~30 min, throwaway code.
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

## Secondary (deploy detail, not a gate)

For full-speed OPFS, serve the web app with `Cross-Origin-Opener-Policy: same-origin`
+ `Cross-Origin-Embedder-Policy: require-corp`. Drift falls back (slower) without them.
Watch: `require-corp` can block cross-origin assets that lack CORP headers.
