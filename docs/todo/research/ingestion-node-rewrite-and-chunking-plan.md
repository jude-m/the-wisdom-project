# Ingestion: Node rewrite + chunking config (retire Python)

**Goal:** port `deprecated/research_server/ingest/ingest.py` to TypeScript/Node
inside `research_server/`, re-ingest with an explicit chunking config, and
delete the last Python from the repo.

## Why now

- The ingest job is the **only living Python** left (the Python server itself
  is already retired). Porting it removes a whole toolchain from the project.
- We have to re-upload the corpus anyway to fix chunking (below), and
  re-ingesting is the port's natural end-to-end test.

## Chunking findings (2026-07-18, live measurements)

- Live per-request CPU on Workers is dominated by **parsing Gemini's response
  payload**, not by our snippet/citation post-processing (measured: 21-citation
  answers at 3 ms and 14 ms CPU; a zero-citation failure at 8 ms — the payload
  weight is the variable, our build cost is 0.2–0.4 ms). One request has
  already spiked past the 10 ms free-plan budget (14 ms, survived on
  Cloudflare's spike tolerance).
- The payload weight is `chunks returned × chunk size`. The chunk **count** is
  a fixed internal default with **no query-time knob** (top-k/rank_limit is an
  open feature request — google-gemini/cookbook#1048). Chunk **size** is the
  only lever, and it is **ingest-time only**.
- Our Python ingest passed **no `chunking_config`**, so the store uses default
  chunking — which produced the huge chunks (100k+ chars observed) behind the
  heavy payloads.
- The knob: `chunking_config.white_space_config.max_tokens_per_chunk` +
  `max_overlap_tokens` on `upload_to_file_search_store`. Community guidance:
  ~200 tokens/chunk, ~20 overlap for precise retrieval; docs cap is 500.
- Changing chunking = **re-uploading every document**. Upload into a **new
  store**, then flip `RESEARCH_STORE` in `wrangler.jsonc` — instant rollback by
  flipping back.

## Port plan

New: `research_server/ingest/ingest.ts`, run via `npm run ingest` (tsx or
`npm run build` + node). Same `GEMINI_API_KEY` env var; `@google/genai` JS SDK
(the JS twin of the Python SDK — same File Search surface).

Keep the Python script's behaviour 1:1, it is all still right:

1. **Discover** bilara-data files → per-sutta text (uid from filename).
2. **`--dry-run`**: list uids + derived metadata, no SDK, no key, no upload.
3. **Dedupe**: list existing store docs by `display_name`, skip already-present
   uids (safe re-runs).
4. **Upload** with `display_name: uid` (rides into citations as the chunk
   title — the server depends on this), `custom_metadata` derived from uid
   (basket etc. — powers the basket filter), and **new:** the
   `chunking_config` above.
5. Throttle + retry-after-sleep on failures, summary line at the end.

## Steps

1. Write `ingest.ts` (port, plus `chunking_config`); `--dry-run` against local
   bilara-data must list the same uids as the Python script.
2. Create new store (name it for the chunking, e.g. `...-c200`), ingest SN 15.
3. Point `RESEARCH_STORE` at the new store, deploy, run the two standard live
   probes (fast + thinking, the SN 15 catalogue question) and compare `body=`
   KB and `cpu=` in the tail — expect a large drop; verify answer quality
   didn't regress (all 20 suttas still enumerated in thinking mode).
4. Retire the old store (keep until 3 passes), delete
   `deprecated/research_server/` — **repo is Python-free**.
5. Update the knowledge doc's CPU map with the new measured `body=`/CPU numbers.

## Risks

- **Retrieval quality shift**: smaller chunks retrieve more precisely but carry
  less context per chunk; the generate model sees less surrounding text. The
  step-3 probe comparison is the gate — if quality drops, retry at 300–500
  tokens before giving up on small chunks.
- **Snippet titles**: `splitHeading` peels the sutta heading Gemini puts at the
  top of a chunk; with small chunks most chunks won't start with a heading —
  already handled (`title: null`), but eyeball citation cards after re-ingest.
