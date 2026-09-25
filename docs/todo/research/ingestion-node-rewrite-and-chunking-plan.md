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
  store**, then flip `RESEARCH_STORE` in `wrangler.jsonc`. Rolling back is
  flipping back, with a key from the old store's project (below).

## Where we are (2026-09-25)

- **Done:** the research server is TypeScript on Cloudflare Workers, live on
  dev (personal Cloudflare account, CORS `localhost:8080` only since
  2026-09-25), reading the pilot store — SN 15 only
  (`tipitakapilotsn15-…`), made by the Python ingest with default chunking.
- **Not done:** the ingest job itself is still Python (the port below).
- **Ops Google account:** `wisdom-research` project and its key exist; no
  store yet. Likely needs the paid tier for a full-corpus ingest — check
  Gemini pricing and store-size limits first.
- **Ops Cloudflare account:** exists, keys in `secrets.env`; no Worker
  deployed there yet (`deploy.sh --prod` still refuses).
- **Next:** full-corpus ingest into one new store in the ops project, then
  move research to the ops accounts and retire the personal ones. Dev and prod
  Workers share that one store — both read `RESEARCH_STORE` from the same
  `wrangler.jsonc`.

## New home: the ops Google account

- The new store is made with the `wisdom-research` key. The key goes into
  `secrets.env` (`RESEARCH_GEMINI_API_KEY`) only at the switch.
- A store belongs to the project that made it, and so does a key. The switch
  is therefore one deploy: `RESEARCH_STORE` and the key together.
  `scripts/research_server/deploy.sh` refuses a key that can't open the store
  (`check_research_store` in `scripts/lib/common.sh`).
- The old store and the Worker's current key live in the old personal
  project. The key's value is lost, so a rollback needs a fresh key made
  there — keep that project until step 6.

## Port plan

New: `research_server/ingest/ingest.ts`, run via `npm run ingest` (tsx or
`npm run build` + node). Same `GEMINI_API_KEY` env var, fed from
`RESEARCH_GEMINI_API_KEY` in `scripts/config/secrets.env`; `@google/genai` JS SDK
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
2. With the `wisdom-research` key, create the new store (name it for the
   chunking, e.g. `...-c200`) and ingest SN 15.
3. Together, point `RESEARCH_STORE` at the new store (committed) and put the
   key in `secrets.env` (not committed); deploy with
   `scripts/research_server/deploy.sh --dev` (it must print `Secrets uploaded
   with this deploy: GEMINI_API_KEY`); run the two standard live probes
   (fast + thinking, the SN 15 catalogue question) and compare `body=`
   KB and `cpu=` in the tail — expect a large drop; verify answer quality
   didn't regress (all 20 suttas still enumerated in thinking mode).
4. Once 3 passes, ingest the full corpus into the same store (re-runs skip
   uids already there).
5. Move research to the ops Cloudflare account: a dev and a prod Worker, both
   reading the same store. Make `deploy.sh --dev` and `--prod` target them,
   repoint `RESEARCH_BASE_URL` in `scripts/config/targets.env` and the app's
   `--dart-define`, and probe both.
6. Retire the personal accounts' research pieces: delete the personal
   `wisdom-research` Worker, and the old personal Google project (the old
   store and the old key go with it). Delete `deprecated/research_server/` —
   **repo is Python-free**.
7. Update the knowledge doc's CPU map with the new measured `body=`/CPU numbers.

## Risks

- **Retrieval quality shift**: smaller chunks retrieve more precisely but carry
  less context per chunk; the generate model sees less surrounding text. The
  step-3 probe comparison is the gate — if quality drops, retry at 300–500
  tokens before giving up on small chunks.
- **Snippet titles**: `splitHeading` peels the sutta heading Gemini puts at the
  top of a chunk; with small chunks most chunks won't start with a heading —
  already handled (`title: null`), but eyeball citation cards after re-ingest.
