# Research ingestion: ops store, chunking, full corpus

**Done 2026-10-01**, phases A–C. Re-syncs from SuttaCentral:
`docs/todo/sc-sync-ingest.md`.

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
| C | same as B | `tipitaka-en` | whole corpus, **latest** snapshot | Google default |

A and B hold the same texts in the same project, so the only difference
between their probe results is the chunk size.

## Where we are (2026-10-01, done)

- **Worker:** ops Cloudflare account, `research.sammaditthi.net`, every build
  calls it. Worker version `88b38439` answers from `tipitaka-en`.
- **Ops Google project** `wisdom-research`: its key is in
  `scripts/config/secrets.env` as `RESEARCH_GEMINI_API_KEY`. One store,
  C's `tipitaka-en` = `fileSearchStores/tipitakaen-j02s31fl1p4q`, the
  full corpus (all six collections). The A and B pilot stores are deleted.
- **Personal Google project:** deleted by the user, with its SN 15 store.
- **Ingest:** `scripts/research_server/ingest.sh` runs
  `tools/research_ingest/ingest.py` (its own venv, google-genai 2.25.0).
  bilara-data is at `~/Desktop/Dev/bilara-data-readonly` — shallow,
  blobless, sparse on the two translation trees, `published` @ `ce5b98f`
  (2026-09-28).
- **Git:** work happens on `main` directly; `feat/research-ingestion` is
  merged.
- **Decided for C:** Google's default chunking, the free tier, and the
  ingest in batches.

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
doesn't stay in the shell). JSON, because CPU time is only in the JSON
event. It prints no "Connected" line: give it ~10 s before the first probe.

```sh
bash -c '. scripts/lib/common.sh && use_cloudflare prod \
  && cd research_server && "$WRANGLER" tail --format json' \
  > "$TMPDIR/research-tail.json"
```

…and each probe in another, a few seconds apart (the zone rate limit is
6 requests / 10 s). `"mode":"thinking"` for a thinking probe:

```sh
curl -sS https://research.sammaditthi.net/research \
  -H 'content-type: application/json' \
  -d '{"question":"What were the Buddha'\''s last words?","history":[],"mode":"fast"}'
```

Record per probe, in the handover notes: `cpuTime` and `wallTime` from the
event; `model=`, `rung=`, `citations=` and `body=` from its `research[…]`
log line; and whether the answer is right. (`cpu=` and `build=` print only
under Node, never on Workers.)

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

The gate runs every probe in **thinking** mode: fast mode on 3.1-flash-lite
didn't search (A4 notes), so a fast probe showed nothing about chunk size
(3.5-flash-lite does search: B5). Before the
switch, rerun P2 and P3 in thinking mode on the A store, as their baseline
(2 calls). Then wait for indexing (A2), switch and deploy as in A3 (no
README change; the commit carries this doc too), probe P1–P3 in thinking
mode (3 calls), compare.

- **Pass:** `body=` and `cpuTime` drop, most on P3; P1 still lists all 15; the
  answers are as good; citation cards read well (mid-sutta chunks give
  `title: null` — already handled, but look at them).
- **Quality drops:** re-ingest into a new store at 300, then 500, and
  compare again.
- **No gain at all:** use default chunking in C (leave the flags out).

**B5. Re-run the gate on the new model ladder.** Done 2026-09-28. The
ladders changed after B4, so B4's figures came from other models. The
thinking run 503'd on every rung, so the gate moved to **fast** mode:
P1–P3 on the A store, then on c200 (6 calls, all on 3.5-flash-lite).
Numbers in the handover notes.

- **No Pass.** P3, the only like-for-like pair, had the same body (5KB)
  on both stores and no CPU gain. P1 missed suttas on both, and more on
  c200 (10 of 15, against A's 14). CPU at this size is noise.
- **Default chunks are already small.** `body=` is Gemini's raw response,
  and A's P3 came back at 5KB with a DN 16 chunk in it: the default
  doesn't hand back whole long suttas.
- **Decision: Google's default in C** (leave the flags out), by the
  "No gain" rule above; the user picked it 2026-09-28. The gain c200 was
  meant to bring doesn't show, and on a list question it covers fewer
  suttas. 300 or 500 would cost another ingest, 2 deploys and ~6 calls for
  a gain that may not exist.

## Phase C — latest SuttaCentral, full corpus

**C1. Limits and cost.** Decided 2026-09-28: **free tier, no billing.**

- **Cost:** on the free tier File Search is free: indexing, storage and
  query embeddings.
- **Size:** the free cap is 1 GB per project, counted as about 3× the
  text. The corpus is 13.8 MB, about 3.4M tokens (measured 2026-09-28, June
  snapshot), so it fits.
- **Speed is the limit.** Google no longer publishes free-tier limits. A
  third-party measurement (2026-09-02) gives the embedding model 100
  requests a minute and 1,000 a day. Unknown whether indexing counts
  against that: A's, B's and C4's uploads didn't show on the usage page.
  Hence the batches in C4.
- **Why not paid:** the whole corpus would cost about $0.51, but paid needs
  a $5 prepay, and the card can't be removed without closing the billing
  account.
- **Billing comes back before release,** for the live feature. On the free
  tier each thinking model allows about 20 requests a day (same
  measurement), and Google may use users' questions to improve its
  products.
- **Embedding model:** Google's default, `gemini-embedding-001`, as in A
  and B. It's fixed per store. `gemini-embedding-2` has no documented gain
  on English text, and Sinhala questions are translated to English before
  the search.

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

**C4. Full ingest into a fresh store, in batches**: `tipitaka-en`, on
Google's default chunking (no chunk flags). Not the pilot store: its SN 6 +
DN 16 came from the June snapshot, and a resumed run skips uids already
present, so they'd stay stale.

One collection per run, smallest first. Counts are from C3 (`ce5b98f`). The
six collections cover every file once.

| Batch | `--collection` | Documents |
|---|---|---|
| 1 | `dn` | 34 |
| 2 | `mn` | 152 |
| 3 | `vinaya` | 422 |
| 4 | `kn` | 755 |
| 5 | `an` | 1,408 |
| 6 | `sn` | 1,819 |

Batch 1 created the store (`--display-name tipitaka-en`); every later batch
adds to it. From the repo root, with the batch's collection:

```sh
./scripts/research_server/ingest.sh \
  --store fileSearchStores/tipitakaen-j02s31fl1p4q --collection sn
```

It waits **15 s before each upload** (`--pace`; batch 3 used 20), prints a
line per upload (`[13:05:12] #1/733 cp17`), stops at the first 429, and
stops if listing the store fails (going on would upload every document a
second time).

- **Stop rule:** a 429 stops the run. Re-run the same command the next day
  (quota resets at midnight Pacific); it skips what's already in. No 429
  so far, even at 1,229 uploads in one Pacific day (batch 5), so uploads
  have no 1,000-a-day cap.
- Other failures (network errors, a 503) are logged and skipped; a re-run
  uploads just those. They left nothing behind in the store.
- An upload can hang waiting for Google's reply: the SDK sets no timeout.
  Ctrl+C and re-run. The hung upload may still land (batch 6's did, 15
  min later), so check by name after the re-run.
- Batch with `--collection`, never `--limit`: `--limit` cuts the list before
  the skip, so every run picks the same first N.
- `skipped` counts only files in the collection, so a new batch shows
  `0 skipped`.
- AI Studio → Usage shows nothing for uploads (A, B and C4 alike), so it
  can't tell whether indexing spends the embedding quota. A 429, or
  documents left failed in A2's check, are the only signals.
- Re-run until `0 failed`. Done when active = the dry-run count and nothing
  is pending or failed (A2's check). A document that failed indexing still
  has its name in the store, so a re-run would skip it: delete it first.
- After a batch that had failures, also check by name: list the store's
  documents and compare their display names with the dry-run uids of the
  batches so far — no duplicates, none missing, none extra, all
  `STATE_ACTIVE`. A one-off script (`ingest.discover` +
  `ingest.load_unit` for the expected side, `documents.list` for the
  store).

**C5. Switch + probe.** `RESEARCH_STORE` in `wrangler.jsonc` →
`tipitaka-en`, with the store's source on the line above it
(`// bilara-data published@ce5b98f (2026-09-28), chunks default`): done
2026-09-29, mid-C4; committed in `493e1f8`. Deployed and probed
2026-10-01: done (see the handover notes).

**C6. Clean up.** Done 2026-10-01: `deprecated/research_server/` (the
retired FastAPI server) deleted; the user deleted the personal Google
project.

**C7. Docs.** Done 2026-10-01: the knowledge doc
(`docs/knowledge/research-server-from-question-to-cited-answer.md`) and
`docs/todo/sc-sync-ingest.md` updated; this doc moved to
`docs/done/research/`.

## Separate job, not a blocker

After C, most citations won't open in the reader: the concordance maps
SN 15 only. Growing it is its own job —
`docs/todo/suttacentral-bjt-concordance-findings.md`.

## Risks

- **`thinkingLevel` on a new rung:** the pipeline sends it to every
  `gemini-3*` model, and one that rejects it (400) fails fast instead of
  falling back. 3.6/3.7/3.8 don't reject it (3.6 answered C5's P1).
- **Snippet titles:** `splitHeading` reads the heading off the chunk's first
  line; small chunks mostly have none (`title: null`). Look at the cards.

## Handover notes

Newest last. Each step adds: date, store names/ids, numbers, surprises.

- **2026-09-28** — Ops key in `secrets.env`, verified (sees no stores). The
  Worker's old key deleted; `/health` → `key_configured:false`. Dry runs:
  SN 6 → 15 uids, DN 16 → 1. Plan rewritten to phases A–C; Node port
  dropped, the Python ingest stays. Next: A1.
- **2026-09-28, A1–A2** — Store `tipitaka-pilot-sn6` (ops project; deleted
  2026-09-29). SN 6: 15
  uploaded, DN 16: 1 uploaded, 0 failed. Indexed by the first check: 16
  active, none pending or failed, 162,106 bytes, `gemini-embedding-001`.
  No surprises.
- **2026-09-28, A3** — Committed on branch `feat/research-ingestion`
  (`9ddf045`); `main` fast-forwarded to it, because the deploy only
  releases from `main`. Deployed: the store check passed, `GEMINI_API_KEY`
  uploaded, `/health` live with a key. Worker version `d192fb5a`. Research
  is live again.
- **2026-09-28, A4 baseline** — All three answers right.

  | | model (rung) | citations | cpu | body | time |
  |---|---|---|---|---|---|
  | P1 thinking | gemini-3-flash-preview (2) | 17 | not captured | 12KB | 87.7s |
  | P2 fast | gemini-3.1-flash-lite (1) | 1 | 6 ms | 2KB | 4.4s |
  | P3 fast | gemini-3.1-flash-lite (1) | 2 | 5 ms | 1KB | 3.5s |

  Surprises:
  - **Fast mode didn't search.** P2 and P3 came back with no grounding
    chunks: every citation was built from a ref the model wrote in the
    text (`title: null`, `snippet: null`), and `body=` is tiny because no
    chunk text came back. Chunk size can't show up in a probe that
    retrieves nothing, so P3 as it stands can't carry the B4 gate.
  - **P1 did search:** 5 of its 17 citations came from grounding chunks
    (sn6.3, sn6.10, sn6.14, sn6.15, dn16), each with a snippet; the other
    12 came from refs in the text. Rung 1 (gemini-3.5-flash) returned 503
    after 37.8s.
  - **`cpu=` and `build=` never print on Workers** (`cpuMs()` is null
    there). CPU time is only in the tail's JSON event (`cpuTime`), so
    P2/P3 used `--format json`; P1 ran under `--format pretty` and has no
    CPU figure.
- **2026-09-28, B1–B3** — bilara-data moved intact to
  `~/Desktop/Dev/bilara-data-readonly` (`published` @ `9b1a954`). Script in
  `tools/research_ingest/`, wrapper `scripts/research_server/ingest.sh`.
  pip installed google-genai **2.25.0**, not 2.10; the chunk fields are
  unchanged there, and the SDK sends them as `chunkingConfig`. Dry runs
  through the wrapper: SN 6 → 15, DN 16 → 1.
  `research_server/bench/bench.ts` pointed at the old bilara-data path; it
  now has the script's default (bench passes, 6.96 ms worst case).
  Decided for B4: every gate probe in thinking mode, with a thinking
  baseline for P2/P3 first; the tail uses `--format json`.
  Review fix: the script passes `GEMINI_API_KEY` to the SDK explicitly and
  stops if it's empty, because the SDK prefers `GOOGLE_API_KEY` (another
  project's key could win). Branch merged to `main`; work continues on
  `main` directly.
- **2026-09-28, B4 baseline (thinking, A store)** — Both answers right.
  3 calls: P3's rung 1 (gemini-3.5-flash) returned 503 after 25.1s.

  | | model (rung) | citations | cpu | body | time |
  |---|---|---|---|---|---|
  | P2 thinking | gemini-3.5-flash (1) | 0 | 7 ms | 3KB | 37.1s |
  | P3 thinking | gemini-3-flash-preview (2) | 2 | 10 ms | 13KB | 58.4s |

  Surprises:
  - **P2 retrieved no grounding chunks** even in thinking mode, and wrote
    its refs as raw uids (`[sn6.1]`). `REF_IN_PROSE` only matches the
    `SN 6.1` form, so it got 0 citations and the answer shows `[sn6.1]` as
    plain text. Outside B4; not fixed.
  - **P3 searched:** dn16 and sn6.15 both came from grounding chunks, with
    snippets. dn16 already had `title: null` under default chunking, so
    Google's default split DN 16 mid-sutta. 10 ms CPU is the Worker's
    budget.
- **2026-09-28, B4 upload** — Store `tipitaka-pilot-sn6-c200` (ops
  project; deleted 2026-09-29), chunks 200 / 20 overlap on both runs. SN 6: 15 uploaded, DN 16: 1
  uploaded, 0 failed. Indexed by the first check: 16 active, none pending
  or failed, 162,106 bytes (source bytes, same as A). The documents API
  doesn't show a document's chunk config, so only the probes can confirm
  it took. `RESEARCH_STORE` switched to it.
- **2026-09-28, B4 probes (thinking, c200 store)** — Deployed from
  `a2a73ac`, Worker version `ecfc580b`. All three answers right; P1 lists
  all 15.

  | | model (rung) | citations | cpu | body | time |
  |---|---|---|---|---|---|
  | P1 thinking | gemini-3-flash-preview (2) | 16 | 14 ms | 11KB | 115.4s |
  | P2 thinking | gemini-3.5-flash (1) | 1 | 12 ms | 8KB | 32.4s |
  | P3 thinking | gemini-3-flash-preview (2) | 2 | 8 ms | 11KB | 51.5s |

  Against A (default chunking):
  - **P3**, the only like-for-like pair (same model, both searched):
    body 13KB → 11KB, CPU 10 → 8 ms. Same two citations, same snippets.
  - **P1:** body 12KB → 11KB; A has no CPU figure. 5 grounding chunks
    either way (c200: sn6.1, sn6.3, sn6.8, sn6.10, sn6.15).
  - **P2** doesn't compare: A's run didn't search, this one did (sn6.1,
    mid-sutta chunk, `title: null`, snippet on the passage).
  - Cards read well. The only `title: null` cards are mid-sutta chunks and
    show the ref. P1's snippets highlight "one" and "each" from the
    question: that's query-term matching, not chunk size.
  - One sample each, and a couple of ms of CPU is within run-to-run noise.
    By the rules it's a Pass: body and CPU drop, most on P3, and quality
    holds. But the gain is small.

  Calls: 8 attempts. P1's first try failed with a 502: rung 1 503 (29.4s),
  rung 2 503 (13.7s), rung 3 `gemini-2.5-flash` **404: "no longer
  available to new users"**. The ops project is new, so the thinking
  ladder's last rung (`research_server/src/config.ts`) is dead there.
  The fast ladder's `gemini-2.5-flash-lite` wasn't tested. The 404 logs as
  `unhandled` and returns `retriable: true`. P1's retry worked on rung 2.
  Rung 1 (gemini-3.5-flash) 503'd on 4 of today's 6 thinking requests,
  after 24–35s each.
- **2026-09-28, model ladders** — Google now lists 3.6/3.7/3.8-flash and
  3.5-flash-lite for the ops project. New ladders, newest first, nothing
  removed: thinking = 3.8-flash, 3.7-flash, 3.6-flash, 3.5-flash,
  3-flash-preview, 2.5-flash; fast = 3.5-flash-lite, 3.1-flash-lite,
  2.5-flash-lite. `gemini-2.5-flash` is still listed but 404s for this
  project, so it's kept as the last rung (the user's call). The 404's
  `unhandled` / `retriable: true` is unchanged. Deployed from `f2707a5`,
  Worker version `7d026bed`; `/health` lists the new ladders. Next: B5.
- **2026-09-28, B5 first try (stopped, no answers)** — Worker `7d026bed`,
  c200 store. 9 calls, every rung failed, stopped for the day.

  | | rungs (time to fail) | total | cpu |
  |---|---|---|---|
  | P1 thinking | 3.8-flash 503 (3.7s), 3.7-flash 503 (4.5s), 3.6-flash **429** (4.8s), 3.5-flash 503 (4.8s), 3-flash-preview 503 (46.0s), 2.5-flash 404 | 502 in 64.0s | 10 ms |
  | P1 fast | 3.5-flash-lite 503 (3.0s), 3.1-flash-lite 503 (2.8s), 2.5-flash-lite **404** | 502 in 5.9s | 13 ms |

  After the thinking failure the user moved the gate to **fast** mode.

  Surprises:
  - **Both ladders end in a dead model.** `gemini-2.5-flash-lite` also
    returns 404 "no longer available to new users" for this project, so the
    fast ladder has two live rungs. Both 404s log `unhandled` /
    `retriable: true`.
  - **3.6-flash's first ever call got a 429** (quota), not a 503. Cause
    unknown.
  - **No 400 from 3.7/3.8:** they 503'd, so `thinkingLevel: LOW` wasn't
    rejected up front. 3.6 is still unknown.
  - The busy rungs now fail in 3–5s (B4: 24–35s), so the ladder falls
    through fast, but a busy spell spends every rung: 6 calls per thinking
    question, 3 per fast one.
  - Whether 3.5-flash-lite searches the store in fast mode is still open.

  Next: B5 again as **6 probes in fast mode**, P1–P3 on each store, 1 min
  apart, stopping at the first failure:
  1. Commit `RESEARCH_STORE` → the A store, deploy, fresh tail, P1–P3.
  2. `git revert` that commit (back to the c200 store), deploy, fresh
     tail, P1–P3.
  3. Compare A with c200 per probe: model, grounding chunks, citations,
     cpu, body.

  The switch is a commit because `deploy.sh` only releases a clean,
  committed tree. Cost: 6 calls, +1 per 503 (worst case 18), 2 prod
  deploys, 2 commits on `main`. Then C.
- **2026-09-28, B5 second try (6 fast probes)** — A store: switch
  `6b67f1f`, Worker `12b40acc`. c200: revert `3c29b9d`, Worker `529a474d`
  (live now). 6 calls, all 200 on rung 1 (`gemini-3.5-flash-lite`), no
  503s. "Chunks" = suttas that came back as grounding chunks (citations
  are deduped by uid, so the raw chunk count isn't logged).

  | | store | chunks | citations | cpu | body | time | answer |
  |---|---|---|---|---|---|---|---|
  | P1 | A | 14 (sn6.1–6.14) | 15 | 10 ms | 28KB | 14.7s | 14 of 15, no SN 6.15 |
  | P1 | c200 | 10 (sn6.1–6.8, 6.10, 6.11) | 11 | 6 ms | 20KB | 15.0s | 10 of 15, says coverage "may be partial" |
  | P2 | A | 0 | 1 | 7 ms | 2KB | 4.2s | right (SN 6.1) |
  | P2 | c200 | 2 (sn6.1, sn6.2, `title: null`) | 2 | 6 ms | 10KB | 20.2s | right (SN 6.1, + SN 6.2) |
  | P3 | A | 2 (dn16, sn6.15) | 2 | 4 ms | 5KB | 3.4s | right |
  | P3 | c200 | 2 (same, same snippets) | 2 | 8 ms | 5KB | 7.4s | right |

  Surprises:
  - **Fast mode searches now.** 3.5-flash-lite retrieved on 5 of 6 probes
    (A4's 3.1-flash-lite: 0 of 2). Only A's P2 didn't search.
  - **P1 fails on both stores.** Thinking mode listed all 15 (B4); the
    fast model lists only what came back, and c200 brought back fewer
    suttas. A guess, not measured: if the retriever returns a fixed number
    of chunks, small chunks cover fewer suttas.
  - **CPU is noise at this size.** P3 had the same body on both stores and
    still went 4 → 8 ms, so P1's 10 → 6 ms can't be credited to chunk
    size. The first try's failures used 10–13 ms with no chunks at all.
  - **P2 doesn't compare, again:** A didn't search, c200 did. Whether the
    model searches is its choice, made before any chunk comes back.
  - **Default chunks are already small.** A's P3 came back at 5KB with a
    DN 16 chunk in it (`body=` is Gemini's raw response).
  - c200 was slower on P2 and P3 (one sample each).

  Verdict: no Pass in fast mode. P3, the only like-for-like pair, shows
  the same body and no CPU gain; P1 got worse on c200. With B4's weak
  pass, chunk size shows no clear gain. Recommendation: Google's default
  in C. The user picks.
- **2026-09-28, C1** — Free tier, no billing (see C1). Measured on the June
  snapshot: 4,589 documents, 13.8 MB of text. The embedding model stays
  `gemini-embedding-001`. C4 runs in six batches, one per collection.
  Chunking: Google's default (the user's pick). Next: C2.
- **2026-09-28, C2 (half) + C3's diff** — Fetched `published` @ `ce5b98f`
  (2026-09-28). The checkout's files are still June's: auto mode blocked
  `git reset --hard`, so the user runs it (no local edits to lose; only
  untracked `.DS_Store`).

  747 commits since June, 71 of them in our two trees.
  `git diff --name-status 9b1a954 ce5b98f`: 1 added (`kn/ja/ja534`), 0
  removed, 4,355 modified. Most of the modified count is `91ddece` "align
  segment id 2.", which adds empty segments to line up with the Pali root.
  The ingest drops empty segments, so it changes nothing we upload.

  On the uploaded text (measured on a scratch copy of `ce5b98f`, not the
  checkout): 2,704 documents identical, 15 whitespace only, 1,871 with new
  wording (median 3 words), plus ja534 = 4,590. The wording comes from:
  - Sujato revising the suttas, e.g. MN 6:19.1 moves "in this very life"
    from after "freedom by wisdom" to after "with my own insight".
  - Brahmali revising the Vinaya, mostly the nuns' rules.
  - `aba21d6` "remove title numbers": 342 Vinaya rule headings lost their
    number ("10. Exchanging…" → "Exchanging…").

  **Surprise:** `splitHeading` (`research_server/src/snippet.ts:137`)
  keeps a title only if the heading line holds the ref's number. So after
  C, 342 of the 344 Vinaya documents that had a card title in June show
  `title: null` (the card shows the uid). Suttas: 0 lost. Not a blocker for
  C; a small follow-up in `splitHeading`, the user's call.

  Next:
  1. User: `git -C ~/Desktop/Dev/bilara-data-readonly reset --hard ce5b98f`,
     then `git -C ~/Desktop/Dev/bilara-data-readonly log -1 --format='%h %cd'`
     → `ce5b98f`.
  2. C3's dry run: `./scripts/research_server/ingest.sh --dry-run`. Expect
     `discovered 4590 unit files`; note any `(empty)`.
  3. C4 batch 1 (`--display-name tipitaka-en --filter sutta/dn/`), then
     check AI Studio → Usage to see whether indexing counts against the
     embedding quota.
- **2026-09-28, C2 + C3** — The user ran the reset; the checkout is at
  `ce5b98f` (2026-09-28), no local edits. Full dry run: `discovered 4590
  unit files`, 0 `(empty)`. Per batch: dn 34, mn 152, vinaya 422, kn 755
  (+ja534), an 1,408, sn 1,819 = 4,590; each file matches exactly one
  filter. Rechecked the Vinaya headings offline (June vs Sept blobs): 381
  held a rule number in June, 39 now, so 342 lost it, as the C2 note says.
  Next: C4 batch 1.
- **2026-09-28, C4 batch 1 (DN)** — Store `tipitaka-en` =
  `fileSearchStores/tipitakaen-j02s31fl1p4q` (ops project), created
  13:29 UTC. 34 uploaded, 0 skipped, 0 failed, no 429. A2's check right
  after: 34 active, none pending or failed, 1,141,641 bytes,
  `gemini-embedding-001`. 37 calls in all (create, list, 34 uploads, one
  check).

  Paced at 15 s before each upload by a one-off launcher that ran
  `ingest.py`'s `main()` and stopped at the first 429. The script has no
  pause option; the plain command uploads back to back.

  The script's closing line says to set `RESEARCH_STORE` now. Not yet:
  that's C5, after all six batches.

  AI Studio → Usage shows nothing, as after A and B, so it can't answer
  whether indexing spends the embedding quota. Next: batch 2 (`sutta/mn/`,
  152).
- **2026-09-28, C4 batch 2 (MN)** — 152 uploaded, 0 skipped, 0 failed, no
  429. Paced at 15 s per upload by the same kind of one-off launcher (see
  C4). The user ran it in their own terminal because auto mode's
  classifier was down. Account check: the key lists exactly the three ops
  stores (A, B, `tipitaka-en`), so it's the ops project. A2's check: 186
  active, none pending or failed, 3,035,426 bytes, `gemini-embedding-001`.
  AI Studio → Usage still shows nothing.

  Today's uploads: 186. If the reported 1,000 a day counts indexing, batch
  3 (422 → 608 total) still fits today and batch 4 (755) doesn't. Next:
  batch 3 (`vinaya/`, 422), at 20 s per upload.
- **2026-09-29, C4 batch 3 (Vinaya)** — Paced at 20 s. First run: 411
  uploaded, 11 failed, no 429. The failures were network errors (one
  "Server disconnected", ten "[Errno 60] Operation timed out"): 6 spread
  through the monks' rules, 5 at the very end (`pli-tv-pvr4`, `pvr6`–`9`).
  None of the 11 reached the store (597 active after). The re-run: 11
  uploaded, 411 skipped, 0 failed.

  Check by name (the new C4 bullet): 608 documents, 608 distinct uids, 0
  duplicates, 0 missing, 0 extra, all active. A2's check: 608 active,
  7,818,985 bytes. So a timed-out upload leaves nothing behind, and a
  re-run is enough.

  Uploads so far: 608, all on 2026-09-28 Pacific time. If the reported
  1,000 a day counts indexing, batch 4 (755 → 1,363) won't fit in one
  Pacific day: start it after midnight Pacific (07:00 UTC). Next: batch 4
  (`sutta/kn/`, 755), at 15 s per upload (the user's call, 2026-09-29), by
  the launcher now written out in C4.
- **2026-09-29, C4 batch 4 (KN), first part** — Started after midnight
  Pacific. The first try pasted the launcher and the terminal dropped part
  of a line (`client.file_search_stores.documents` arrived as `clienents`):
  a NameError at the listing, before any upload. The second ran 26 uploads
  in about 7 minutes, then was stopped by hand (Ctrl+C) because the
  launcher printed nothing and looked stuck. `cp17` failed on a network
  error ("Server disconnected"); `cp33` was cut off mid-upload.

  Check by name: 632 documents = 608 + 24 KN (`cp1`–`cp32` less `cp17`),
  0 duplicates, all active. Neither `cp17` nor `cp33` reached the store.

  The launcher is retired: `ingest.py` now has `--collection`, `--pace`
  (default 15 s), a line per upload, a stop at the first 429, and a stop
  when listing the store fails. `ingest.sh` runs it under `caffeinate -i`.
  Next: finish batch 4 with the command in C4.
- **2026-09-29, pilot stores deleted, C5 switch in config** — Mid-batch 4,
  the user's call: nothing is live, and `tipitaka-en` already holds far
  more than the pilots. Deleted A (`tipitaka-pilot-sn6`) and B
  (`tipitaka-pilot-sn6-c200`), 16 documents each; the ops project now
  lists only `tipitaka-en`. `RESEARCH_STORE` → `tipitaka-en` in
  `wrangler.jsonc`, not yet deployed, so the Worker fails until then.
  `--store` stays explicit (left out, a run creates a new store); the
  command is in `ingest.sh`'s usage.
- **2026-09-29, C4 batch 4 (KN), done** — The new `ingest.sh
  --collection kn`: 731 uploaded, 24 skipped, 0 failed, no 429. Check by
  name (DN + MN + Vinaya + KN): 1,363 documents, 1,363 distinct uids, 0
  duplicates, 0 missing, 0 extra, all active. A2's check: 1,363 active,
  none pending or failed, 8,759,164 bytes.

  Uploads on 2026-09-29 Pacific: 757 (26 + 731), still no 429, so whether
  a 1,000-a-day limit exists is still open. Batch 5 (1,408) is over 1,000
  either way: start it after midnight Pacific (07:00 UTC); if it stops at
  a 429, re-run the next day. Next: batch 5 (`--collection an`), and the
  user's commit + deploy (C5).
- **2026-09-30, C4 batch 5 (AN), done** — `ingest.sh --collection an`:
  1,407 uploaded, 0 skipped, 1 failed (`an9.60`: 503 Service Unavailable),
  no 429. The re-run: 1 uploaded, 1,407 skipped, 0 failed. Check by name
  (DN + MN + Vinaya + KN + AN): 2,771 documents, 2,771 distinct uids, 0
  duplicates, 0 missing, 0 extra, all active. A2's check: 2,771 active,
  none pending or failed, 11,489,917 bytes.

  Uploads per Pacific day, from the documents' `create_time`: 2026-09-28
  608, 2026-09-29 934, 2026-09-30 1,229. Batch 5 started at 05:55 UTC,
  before midnight Pacific, so 179 of its uploads fell on 09-29. No 429 on
  any day, so the 1,000-a-day limit doesn't cap uploads: batch 6 (1,819)
  can start any time. Next: batch 6 (`--collection sn`), check by name,
  then C5's probes.
- **2026-10-01, C4 batch 6 (SN), done; C4 done** — `ingest.sh
  --collection sn`. The first run reached #1743 (`sn56.85`); the next
  upload, `sn56.86`, hung waiting for Google's reply and the user stopped
  it with Ctrl+C. It landed anyway, 15 min after it was sent, and the
  re-run skipped it. `sn35.58` was missing after the first run (its error
  line wasn't kept). The re-run: 4,514 uids already in the store, 76
  uploaded (`sn35.58` and the rest from `sn56.87`), 1,743 skipped, 0
  failed. Check by name (all six collections): 4,590 documents, 4,590
  distinct uids, 0 duplicates, 0 missing, 0 extra, all active. A2's
  check: 4,590 active, none pending or failed, 13,795,093 bytes.

  Uploads per Pacific day, from `create_time`: 2026-09-28 608, 2026-09-29
  934, 2026-09-30 3,048. No 429 on any day. Next: C5, the user's deploy,
  then probes P1–P4.
- **2026-10-01, C5 done** — The user deployed: Worker `88b38439`, store
  `tipitaka-en`. Probes P1–P4, 1–2 min apart, with a JSON tail. 6 Gemini
  calls (P1's first two rungs 503'd), all four 200.

  | | mode | model (rung) | citations | cpu | body | time | answer |
  |---|---|---|---|---|---|---|---|
  | P1 | thinking | 3.6-flash (3; 3.8 and 3.7 503'd) | 5 (sn6.1–6.3, 6.10, `sn6`) | 9 ms | 10KB | 43.9s | 4 of 15, says coverage is partial |
  | P2 | fast | 3.5-flash-lite (1) | 0 | 2 ms | 2KB | 4.9s | right in substance; names `pli-tv-kd1` in plain text, no card |
  | P3 | fast | 3.5-flash-lite (1) | 2 (dn16, sn6.15) | 2 ms | 5KB | 3.9s | right |
  | P4 | fast, basket `vinaya` | 3.5-flash-lite (1) | 1 (pli-tv-bu-vb-np18) | 8 ms | 9KB | 8.6s | right (NP 18) |

  Surprises:
  - **P1 is now a weak spot.** The pilot stores held only SN 6 and DN 16,
    so every chunk came from SN 6 (B4: all 15). In the full corpus the
    retriever returns a few chunks, so a "list every sutta" question only
    sees part of the chapter. A limit of retrieval, not of the ingest.
  - **`sn6` is a citation with no title or snippet:** the model cited the
    chapter, which isn't a document in the store.
  - **P2 didn't search** (body 2KB, as A's P2 in B5) and named the Vinaya
    telling of the same story (`pli-tv-kd1`) from memory, outside a cite
    marker, so the user gets no card.
  - **3.6-flash takes `thinkingLevel`:** the open risk is closed.
  - **Snippet titles:** 5 of 8 cards have one; chunks that start
    mid-document have no heading (`dn16`, `np18`).
  - CPU 2–9 ms on every probe, so the full corpus costs no more CPU than
    the pilots did.

  Next: C6, C7.
- **2026-10-01, C6 done, C7 in part** — Deleted `deprecated/research_server/`
  (16 tracked files, plus its old `.env` and venv; the `.env` held only the
  personal key and an empty app token). `research_server/README.md` pointed
  at it; it now points at `ingest.sh`. The user deleted the personal Google
  project. C7: `sc-sync-ingest.md` updated (mirror, ingest, chunking and
  receipt exist; the heartbeat doesn't). Next: the knowledge doc, then
  move this doc.
- **2026-10-01, C7 done; plan done** — The knowledge doc: the log-line
  example is a real C5 line (`body=5KB`); the "one chunk can be 100k+
  chars" claim is gone (live bodies are 2–28KB); the CPU map gains the live
  whole-request figure (2–9ms), and parsing is no longer called the driver
  (B5's failed calls used 10–13ms with no chunks). This doc moved to
  `docs/done/research/`.
