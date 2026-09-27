# Research ingestion: ops store, chunking, full corpus

**Goal:** research reads a File Search store in the ops Google project, built
from the latest SuttaCentral texts, with a chunk size we chose on evidence.
The ingest is the Python script, brought back from `deprecated/` to
`tools/research_ingest/`. The personal Google project is gone.

**Node port dropped (2026-09-28):** the repo keeps other Python
(`docs/profiling/`, `tools/mahamevnawa_map/`), so a port would retire no
toolchain.

Three phases, each ending in a live switch of the one Worker:

| Phase | Ingest with | Store (display name) | Texts | Chunking |
|---|---|---|---|---|
| A | Python, unchanged, from `deprecated/` | `tipitaka-pilot-sn6` | SN 6 + DN 16, June snapshot | Google default |
| B | Python in `tools/research_ingest/` + chunk flags | `tipitaka-pilot-sn6-c200` | same as A | 200 / 20 overlap |
| C | same as B | `tipitaka-en-c200` | whole corpus, **latest** snapshot | what B settled |

A and B hold the same texts in the same project, so the only difference
between their probe results is the chunk size.

## Where we are (2026-09-28)

- **Worker:** ops Cloudflare account, `research.sammaditthi.net`, every build
  calls it. `RESEARCH_STORE` still names the personal SN 15 pilot store.
- **Ops Google project** `wisdom-research`: its key is in
  `scripts/config/secrets.env` as `RESEARCH_GEMINI_API_KEY`. Verified: it
  sees no stores, so it is not the personal project's key. No store yet.
- **The Worker has no key.** The old personal key was deleted on purpose
  (`wrangler secret delete`, 2026-09-28): `/health` says
  `key_configured:false` and every research call fails until step A3. There
  is no rollback to the SN 15 store.
- **Personal Google project:** nothing needs it any more. The user deletes it
  in the Google dashboard whenever convenient; the SN 15 store goes with it.
- **Python ingest works as-is:** `deprecated/research_server/.venv`
  (google-genai 2.10.0) and a bilara-data checkout in
  `deprecated/research_server/bilara-data` — shallow, blobless, sparse on the
  two translation trees, `published` @ `9b1a954` (2026-06-15). Dry runs done:
  `--filter sn/sn6/` → 15 uids, `--filter dn/dn16_` → 1.

## Why smaller chunks

A chunk is the piece File Search stores as one vector and hands back as one
retrieved text. Its size is set at upload only: changing it later means
re-uploading every document. That's why it's decided before the full ingest.

- **The old note was wrong.** It said default chunking produced "100k+ char
  chunks" behind heavy payloads. The SN 15 store holds 20,265 bytes in all,
  and its longest sutta is 3.4k chars (measured 2026-09-28), so no SN 15
  chunk can be big. Whatever drove July's 3–14 ms CPU and large `body=`, it
  wasn't chunk size. The 100k+ figure is the bench's worst case (DN 16).
- **Where size will matter:** the full corpus has long texts: 153 over 12k
  chars, 34 over 50k, the longest (`pli-tv-kd1`) 234k (measured 2026-09-28,
  June snapshot). Google doesn't document the default chunk size.
- **What smaller chunks should buy on long texts:** sharper retrieval (one
  vector per passage, not a blend of a whole section); citations and snippets
  that land on the passage; less text into the model (tokens, latency) and
  back in the payload (Worker CPU, 10 ms budget).
- **What they can cost:** less context per chunk, so weaker answers.

So it's a hypothesis, and A vs B tests it. DN 16 is in the pilot as the long
text; SN 6.15 tells the same event briefly, so probe P3 pulls both.

## Probes

Four questions reused in every phase. One call each: the Gemini key is free
tier, so don't loop.

| | Mode | Question | Expect |
|---|---|---|---|
| P1 | thinking | List every sutta in the Brahma Saṁyutta (SN 6), one line each. | all 15 |
| P2 | fast | What did Brahmā Sahampati ask of the Buddha after his awakening? | SN 6.1 |
| P3 | fast | What were the Buddha's last words? | DN 16 + SN 6.15 |
| P4 | fast, `"filters":{"basket":"vinaya"}` | Can a monk accept money? | Vinaya uids (C only) |

Run the tail in one terminal (repo root; a child bash, so the prod token
doesn't stay in the shell):

```sh
bash -c '. scripts/lib/common.sh && use_cloudflare prod \
  && cd research_server && "$WRANGLER" tail --format pretty'
```

…and each probe in another, a few seconds apart (the zone rate limit is
6 requests / 10 s):

```sh
curl -sS https://research.sammaditthi.net/research \
  -H 'content-type: application/json' \
  -d '{"question":"What were the Buddha'\''s last words?","history":[],"mode":"fast"}'
```

Record per probe, in the handover notes: `citations=`, `cpu=`, `build=`,
`body=` from the tail line, and whether the answer is right.

Citations outside SN 15 show no "open in reader" link: the SC→BJT
concordance (`assets/data/sc-to-bjt.json`) covers SN 15 only. Expected, not
a bug — see "Separate job" below.

## Phase A — ops store, Python as-is

**A1. Ingest** (network to `generativelanguage.googleapis.com`). From
`deprecated/research_server/`, in a subshell so the key doesn't linger:

```sh
(
  export GEMINI_API_KEY=$(sed -n 's/^RESEARCH_GEMINI_API_KEY=//p' ../../scripts/config/secrets.env)
  .venv/bin/python -m ingest.ingest --bilara-dir bilara-data \
    --display-name tipitaka-pilot-sn6 --filter sn/sn6/
  # prints "created store: fileSearchStores/<id>" — use it below
  .venv/bin/python -m ingest.ingest --bilara-dir bilara-data \
    --store fileSearchStores/<id> --filter dn/dn16_
)
```

Expect `15 uploaded` then `1 uploaded`, `0 failed`.

**A2. Wait for indexing.** Uploads return before indexing ends. From the
repo root:

```sh
key=$(sed -n 's/^RESEARCH_GEMINI_API_KEY=//p' scripts/config/secrets.env)
printf 'x-goog-api-key: %s\n' "$key" | curl -sS -H @- \
  https://generativelanguage.googleapis.com/v1beta/fileSearchStores/<id>
```

Ready when `activeDocumentsCount` is 16 and no pending/failed counts show.

**A3. Switch.** On `main`, one commit:
- `research_server/wrangler.jsonc`: `RESEARCH_STORE` → the new store.
- `scripts/research_server/README.md`, "Good to know": the Google side is now
  the ops `wisdom-research` project.

Then `./scripts/research_server/deploy.sh --prod`. It checks the key opens
the store before uploading. It must print `Secrets uploaded with this deploy:
GEMINI_API_KEY` and end `OK: …/health is live, with a key.`

**A4. Probe** P1–P3 (3 calls). This is the baseline for B.

## Phase B — bring the Python back + chunking gate

**B1. Move bilara-data out of `deprecated/`**, so deleting that folder can't
take it: `mv deprecated/research_server/bilara-data
~/Desktop/Dev/bilara-data-readonly` (sibling of `tipitaka.lk-readonly`; the
checkout moves intact).

**B2. Bring the script back** to `tools/research_ingest/`, next to the
repo's other Python tool:

- `git mv deprecated/research_server/ingest/ingest.py
  tools/research_ingest/ingest.py`. Run it as a file (`python ingest.py`),
  so `__init__.py` stays behind.
- `tools/research_ingest/requirements.txt`: `google-genai>=2.10` only.
  `tools/research_ingest/.gitignore`: `.venv/`, `__pycache__/`.
- Venv, once, by hand: `python3 -m venv tools/research_ingest/.venv &&
  tools/research_ingest/.venv/bin/pip install -r
  tools/research_ingest/requirements.txt`.
- Script changes — nothing else moves:
  - `--chunk-tokens N` and `--overlap-tokens N`. Left out = Google's default
    (A's behaviour). Given = `chunking_config.white_space_config`
    (`max_tokens_per_chunk`, `max_overlap_tokens`) in the upload config.
    Check the field names against google-genai 2.10.
  - Default `--bilara-dir`: `BILARA_DATA_DIR`, else
    `~/Desktop/Dev/bilara-data-readonly`.
  - Usage docstring: the new path and invocation.
- **Wrapper** `scripts/research_server/ingest.sh [args…]`: loads the key with
  `secret RESEARCH_GEMINI_API_KEY` (common.sh), exports it as
  `GEMINI_API_KEY`, and runs `tools/research_ingest/.venv/bin/python
  tools/research_ingest/ingest.py "$@"`. One line for it in
  `scripts/research_server/README.md`.

**B3. Sanity dry run:** `ingest.sh --dry-run --filter sn/sn6/` → the same
15 uids; `--filter dn/dn16_` → 1.

**B4. Chunked pilot + gate.** Pass the chunk flags on both runs: each upload
carries its own config.

```sh
./scripts/research_server/ingest.sh --display-name tipitaka-pilot-sn6-c200 \
  --chunk-tokens 200 --overlap-tokens 20 --filter sn/sn6/
./scripts/research_server/ingest.sh --store fileSearchStores/<id> \
  --chunk-tokens 200 --overlap-tokens 20 --filter dn/dn16_
```

Wait for indexing (A2), switch and deploy as in A3 (no README change), probe
P1–P3, compare with A4.

- **Pass:** `body=` and `cpu=` drop, most on P3; P1 still lists all 15; the
  answers are as good; citation cards read well (mid-sutta chunks give
  `title: null` — already handled, but look at them).
- **Quality drops:** re-ingest into a new store at 300, then 500, and
  compare again.
- **No gain at all:** use default chunking in C (leave the flags out).

## Phase C — latest SuttaCentral, full corpus

**C1. Limits and cost.** Read the current Gemini File Search pricing and
free-tier limits: indexing spends the embedding model's quota, and stores
have a size cap per tier. The corpus is 13.45M chars, about 3.4M tokens
(measured 2026-09-28, June snapshot). Decide: free tier over several days
(the ingest resumes) or paid. Turning on billing for `wisdom-research` is
the user's dashboard step — and on paid, Google also drops the datacenter
geo-block.

**C2. Update SuttaCentral to the latest `published`.**

```sh
cd ~/Desktop/Dev/bilara-data-readonly
git fetch --depth 1 origin published
git reset --hard FETCH_HEAD
git log -1 --format='%h %cd'
```

The checkout is shallow, blobless and sparse, so this stays small. Record
the sha and date in the handover notes. This checkout is the read-only
mirror `docs/todo/sc-sync-ingest.md` asks for.

**C3. What changed.** In the checkout, list what moved inside our two trees
since the June snapshot:

```sh
git diff --name-status 9b1a954 HEAD -- \
  translation/en/sujato/sutta translation/en/brahmali/vinaya
```

Note added / removed files in the handover notes, then run a full
`ingest.sh --dry-run` and note any `(empty)` files.

**C4. Full ingest into a fresh store** `tipitaka-en-c200`, with the chunk
flags B4 settled. Not the pilot store: its SN 6 + DN 16 came from the June
snapshot, and a resumed run skips uids already present, so they'd stay
stale. Re-run until `0 failed`. Done when active = the dry-run count and
nothing is pending or failed (A2's check).

**C5. Switch + probe.** `RESEARCH_STORE` → the new store, with a comment on
the line above it:
`// bilara-data published@<sha> (<date>), chunks <tokens>/<overlap>` — the
store's source, kept beside its id. Deploy, probe P1–P4 (4 calls).

**C6. Clean up.**
- Delete both pilot stores: `DELETE v1beta/fileSearchStores/<id>?force=true`,
  key in the header as in A2.
- Delete `deprecated/research_server/` — the ingest left it in B2; what's
  left is the retired FastAPI server.
- User: delete the personal Google project, if not done already.

**C7. Docs.**
- `docs/knowledge/research-server-from-question-to-cited-answer.md`: new
  `body=` / CPU numbers in the CPU map; drop the chunk-size claim if B
  disproved it.
- `docs/todo/sc-sync-ingest.md`: the mirror exists, the source is recorded
  beside `RESEARCH_STORE`, the ingest is `scripts/research_server/ingest.sh`.
- Move this doc to `docs/done/research/`.

## Separate job, not a blocker

After C, most citations won't open in the reader: the concordance maps
SN 15 only. Growing it is its own job —
`docs/todo/suttacentral-bjt-concordance-findings.md`.

## Risks

- **Research is down** from 2026-09-28 until A3.
- **Retrieval quality** with small chunks: the B4 gate.
- **Free-tier daily cap mid-ingest:** the run resumes, but an upload that
  failed may still have spent quota.
- **Snippet titles:** `splitHeading` reads the heading off the chunk's first
  line; small chunks mostly have none (`title: null`). Look at the cards.

## Handover notes

Newest last. Each step adds: date, store names/ids, numbers, surprises.

- **2026-09-28** — Ops key in `secrets.env`, verified (sees no stores). The
  Worker's old key deleted; `/health` → `key_configured:false`. Dry runs:
  SN 6 → 15 uids, DN 16 → 1. Plan rewritten to phases A–C; Node port
  dropped, the Python ingest stays. Next: A1.
- **2026-09-28, A1–A2** — Store `tipitaka-pilot-sn6` =
  `fileSearchStores/tipitakapilotsn6-f0aqkxv2244r` (ops project). SN 6: 15
  uploaded, DN 16: 1 uploaded, 0 failed. Indexed by the first check: 16
  active, none pending or failed, 162,106 bytes, `gemini-embedding-001`.
  No surprises.
- **2026-09-28, A3 (edits only)** — `RESEARCH_STORE` switched and the README
  bullet updated, left uncommitted on the user's instruction. The deploy
  refuses a dirty tree, so it waits for the user's commit.
