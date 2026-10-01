# SC Sync + Ingest — RAG Corpus Re-ingest Plan

> Status: **Plan. The pieces exist; the re-sync itself doesn't.** The read-only
> mirror, the ingest (`scripts/research_server/ingest.sh`) and the receipt beside
> `RESEARCH_STORE` came from the first full ingest, done 2026-10-01 in
> [research-ingestion-ops-chunking-full-corpus.md](../done/research/research-ingestion-ops-chunking-full-corpus.md).
> Left: the heartbeat (Step 0) and a re-sync run. Captured 2026-07-23.
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

## 4. The read-only sync source

`~/Desktop/Dev/bilara-data-readonly`, set up 2026-09-28: branch `published`, shallow,
blobless, and sparse on the two trees we ingest — bilara-data holds every language,
and we need two subtrees. The ingest reads it by default (`--bilara-dir` /
`BILARA_DATA_DIR` override). To recreate it:

```bash
cd ~/Desktop/Dev
git clone --depth 1 --filter=blob:none --sparse --branch published \
  https://github.com/suttacentral/bilara-data.git bilara-data-readonly
cd bilara-data-readonly
git sparse-checkout set \
  translation/en/sujato/sutta \
  translation/en/brahmali/vinaya
# (add root/pli/ms/... later if/when Pali display is ingested — not v1)
```

House rules, same as the BJT mirror: **fetch only, never commit, never add a remote.**

---

## 5. What the script must do (the steps)

### Step 0 — Heartbeat: "did SuttaCentral change?" (no download)

```bash
git ls-remote https://github.com/suttacentral/bilara-data.git published
```

One SHA. Compare to the receipt (Step 5). Same → nothing to do. Different → continue.

### Step 1 — Refresh the mirror

```bash
cd ~/Desktop/Dev/bilara-data-readonly
git fetch --depth 1 origin published
git reset --hard FETCH_HEAD
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

Run the ingest (`scripts/research_server/ingest.sh` —
see [research-ingestion-ops-chunking-full-corpus.md](../done/research/research-ingestion-ops-chunking-full-corpus.md)):

- Upload into a **new** File Search store, leaving the current one untouched:
  `--display-name <name>` creates it and prints its id; then `--store <id>
  --collection <c>`, one collection per run, as in the ingestion plan's C4.
- Chunking: Google's default, no chunk flags (`chunks default` in the receipt).
- Check the store by name after the last run (C4: no duplicates, none missing).
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

Record which snapshot is live, on the line above `RESEARCH_STORE` in
`research_server/wrangler.jsonc`, in the same commit as the switch:

```
// bilara-data published@ce5b98f (2026-09-28), chunks default
"RESEARCH_STORE": "fileSearchStores/tipitakaen-j02s31fl1p4q",
```

Same idea as the BJT receipt — turns Step 0 into a one-line compare, and tells us
exactly which SuttaCentral snapshot any given store id represents.

---

## 6. What exists vs. what is TODO

| Piece | State |
|-------|-------|
| Read-only bilara-data mirror | ✅ `~/Desktop/Dev/bilara-data-readonly` (§4) |
| Ingest job (Python, `tools/research_ingest/`) | ✅ via `scripts/research_server/ingest.sh` |
| Chunking config | ✅ Google's default (ingestion plan, B5) |
| Heartbeat check (Step 0) | ⬜ TODO |
| New-store + flip flow (Steps 3–4) | 🔶 done by hand once (ingestion plan C4–C5) |
| Provenance receipt (Step 5) | ✅ the comment above `RESEARCH_STORE` |

---

## 7. Open questions

- **Also affects the concordance.** bilara-data seeds the SuttaCentral side of the
  SC↔BJT concordance (see [suttacentral-bjt-concordance-findings.md](./suttacentral-bjt-concordance-findings.md)).
  A bilara-data update could shift SC enumeration, so a re-sync may need a concordance
  re-check too — not just a re-ingest.
- **Detecting "meaningful" change** — Sujato revises wording often; do we re-ingest on
  any diff in-globs, or only when segment **ids** change (which is what breaks
  citations/deep-links)? Probably: always safe to re-ingest, but urgent only on id
  changes.
