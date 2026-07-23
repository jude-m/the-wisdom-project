# SC Sync + Ingest — RAG Corpus Re-ingest Plan

> Status: **Plan / not started.** The read-only mirror is **not set up yet** (unlike
> the BJT one), and the ingest is mid-port from Python → Node — that ingest work is
> tracked in [`docs/todo/research/`](./research/), esp.
> [ingestion-node-rewrite-and-chunking-plan.md](./research/ingestion-node-rewrite-and-chunking-plan.md).
> Captured 2026-07-23.
> Scope: how the **research (RAG) corpus** stays in step with SuttaCentral, and the
> script that re-ingests it. Sibling of [bjt-sync-regen.md](./bjt-sync-regen.md) —
> **different source, different destination, different cadence.**

---

## 1. The problem in one line

The research feature answers from a **snapshot** of SuttaCentral's English
translations. SuttaCentral keeps revising those translations, so the snapshot drifts —
and, like the BJT copy, nothing currently records **which snapshot we ingested**.

---

## 2. How this differs from the BJT sync (read this first)

They look similar but are not the same job. Do not copy the BJT steps blindly.

| | **BJT sync** ([bjt-sync-regen.md](./bjt-sync-regen.md)) | **SC sync** (this doc) |
|---|---|---|
| Source repo | `pathnirvana/tipitaka.lk` | `suttacentral/bilara-data` (`published` branch) |
| What it feeds | the app's **vendored** `assets/text` (committed JSON) | a **cloud** Gemini File Search store (nothing committed) |
| "Copy" step | copy files into `assets/` | **upload / re-ingest** to a Gemini store |
| Rebuilds | FTS db + static HTML | the File Search store only |
| Rollback | git revert the assets | flip `RESEARCH_STORE` back to the old store |
| Cost of a refresh | local, cheap | Gemini API upload, quota-sensitive |

The key point: **there is no `assets/` copy here.** The corpus lives in a Gemini
File Search store in the cloud, and "sync" means re-uploading documents to it.

---

## 3. The two copies

| # | Where | What it is | Role |
|---|-------|-----------|------|
| 1 | GitHub `suttacentral/bilara-data`, `published` branch | Segment-aligned English translations, CC0. | Source of truth |
| 2 | Gemini **File Search store** (id in `research_server/wrangler.jsonc` → `RESEARCH_STORE`) | The ingested + chunked corpus the research Worker queries. | What the feature reads |

What we ingest (the globs — everything else in bilara-data is skipped):

```
translation/en/sujato/sutta/**/*-sujato.json      # Suttas (Bhikkhu Sujato)
translation/en/brahmali/vinaya/**/*-brahmali.json # Vinaya (Ajahn Brahmali)
```

Both CC0. The filename gives the **uid** (`sn15.3`, `mn10`, `pli-tv-bu-vb-np18`),
which becomes the document's `display_name` and rides into every citation — it is the
deep-link backbone. Basket/nikaya metadata is **derived from the uid at ingest**,
never annotated onto the JSON. (Commentary and Sujato's notes/introductions are
**out** — see [wisdom-project-rag-qa-design.md](./wisdom-project-rag-qa-design.md) §5.2.)

---

## 4. The read-only sync source (TODO — not created yet)

Mirror the BJT pattern, but **sparse** — bilara-data is large (every language), and we
need only two subtrees. This is exactly the case where blobless **+ sparse** pays off
(the opposite of BJT, where we kept everything).

```bash
cd Desktop/Dev
git clone --filter=blob:none --sparse \
  https://github.com/suttacentral/bilara-data.git bilara-data-readonly
cd bilara-data-readonly
git checkout published                       # the branch we ingest
git sparse-checkout set \
  translation/en/sujato/sutta \
  translation/en/brahmali/vinaya
# (add root/pli/ms/... later if/when Pali display is ingested — not v1)
```

House rules, same as the BJT mirror: **pull only, never commit, never add a remote.**
Point the ingest's `bilara_dir` config at this folder.

> Placement note: the old Python setup expected a checkout inside
> `research_server/bilara-data/` (see its `.gitignore`). For consistency with the BJT
> mirror, prefer `Desktop/Dev/bilara-data-readonly` and set `bilara_dir` to it. Pick
> one; don't keep two checkouts.

---

## 5. What the script must do (the steps)

### Step 0 — Heartbeat: "did SuttaCentral change?" (no download)

```bash
git ls-remote https://github.com/suttacentral/bilara-data.git published
```

One SHA. Compare to the receipt (Step 5). Same → nothing to do. Different → continue.

### Step 1 — Refresh the mirror

```bash
cd Desktop/Dev/bilara-data-readonly
git pull
```

### Step 2 — Review what changed **inside our globs only**

Most of bilara-data churn is other languages/translators we don't ingest. Filter to
what actually affects us:

```bash
git diff <old-sha>..<new-sha> -- \
  translation/en/sujato/sutta translation/en/brahmali/vinaya
```

If nothing under those two paths changed, **stop** — the corpus is unaffected even
though the repo moved.

### Step 3 — Re-ingest into a NEW store (never mutate the live one)

Run the ingest (being ported to `research_server/ingest/ingest.ts`, `npm run ingest` —
see [research/ingestion-node-rewrite-and-chunking-plan.md](./research/ingestion-node-rewrite-and-chunking-plan.md)):

- Upload into a **new** File Search store, leaving the current one untouched.
- Keep the **chunking config explicit** (`max_tokens_per_chunk` ~200, overlap ~20) —
  default chunking produced the huge 100k-char chunks behind the heavy payloads.
- This is **quota-sensitive** (Gemini upload) — always a deliberate, prompted action,
  **never automatic**. (See [feedback: quota-conscious probing].)

### Step 4 — Flip the pointer (instant, reversible)

Point the Worker at the new store, then deploy:

```
research_server/wrangler.jsonc  →  RESEARCH_STORE = <new store id>
```

Rollback = flip `RESEARCH_STORE` back to the old id and redeploy. Keep the previous
store around until the new one is verified.

### Step 5 — Write the provenance receipt

Record which snapshot is live:

```
bilara_sha    : <new-sha>       # bilara-data published commit
ingested_on   : <date>
store_id      : <new store id>
chunk_config  : max_tokens=200, overlap=20
```

Same idea as the BJT receipt — turns Step 0 into a one-line compare, and tells us
exactly which SuttaCentral snapshot any given store id represents.

---

## 6. What exists vs. what is TODO

| Piece | State |
|-------|-------|
| Read-only bilara-data mirror | ⬜ TODO — not created (Step 4 above) |
| Ingest job (Python → Node port) | 🔶 In progress — see ingestion-node-rewrite plan |
| Explicit chunking config | ⬜ TODO — part of the port / re-ingest |
| Heartbeat check (Step 0) | ⬜ TODO |
| New-store + flip flow (Steps 3–4) | ⬜ TODO |
| Provenance receipt (Step 5) | ⬜ TODO |

---

## 7. Open questions

- **Also affects the concordance.** bilara-data seeds the SuttaCentral side of the
  SC↔BJT concordance (see [suttacentral-bjt-concordance-findings.md](./suttacentral-bjt-concordance-findings.md)).
  A bilara-data update could shift SC enumeration, so a re-sync may need a concordance
  re-check too — not just a re-ingest.
- **Mirror location** — `Desktop/Dev/bilara-data-readonly` vs. inside `research_server/`
  (§4 note). Decide one.
- **Detecting "meaningful" change** — Sujato revises wording often; do we re-ingest on
  any diff in-globs, or only when segment **ids** change (which is what breaks
  citations/deep-links)? Probably: always safe to re-ingest, but urgent only on id
  changes.
