# `research_server` — the `/research` backend (AI Q&A)

A thin, **stateless** Python service that answers questions about the Pali Canon
with grounded citations, via Google's **Gemini File Search** (managed RAG). It is
the backend half of the AI Q&A feature; the Flutter app is the thin client.

- **What & why:** [`docs/todo/wisdom-project-rag-qa-design.md`](../docs/todo/wisdom-project-rag-qa-design.md)
- **How it lands in the app (clean architecture):** [`docs/todo/ai-qa-and-suttacentral-reference-resolver-plan.md`](../docs/todo/ai-qa-and-suttacentral-reference-resolver-plan.md)

This is a **separate deployable** (the Dart `server/` is unrelated — it proxies
web content). The two never talk; the app binds only to the `/research` JSON contract
below, so the backend's language is invisible to it. (Python — not Dart — because
Gemini File Search has no Dart SDK; see the plan doc §2.)

---

## Two modes

| Mode | Set | Needs | Returns |
|---|---|---|---|
| **stub** (default) | `RESEARCH_STUB=1` | only `fastapi`+`uvicorn` | a canned answer echoing your question |
| **live** | `RESEARCH_STUB=0` | `GEMINI_API_KEY` + `RESEARCH_STORE` + `google-genai` | a real grounded answer |

Stub mode is the **keyless bridge**: a real HTTP server you can point the Flutter
app at *today* to prove the round-trip, before any Gemini key or ingest exists.
The Gemini SDK is lazy-imported, so stub mode never needs it installed.

---

## Run locally (stub mode — no key)

```bash
cd research_server
python3 -m venv .venv && source .venv/bin/activate
pip install fastapi "uvicorn[standard]"          # stub needs only these
uvicorn app.main:app --reload --port 8081
```

Then:

```bash
curl localhost:8081/health
curl -X POST localhost:8081/research \
  -H 'Content-Type: application/json' \
  -d '{"question": "What does the Buddha say about saṁsāra?"}'
```

### Point the Flutter app at it — already wired (Step 3 ✅)

`lib/presentation/providers/research_provider.dart` already defaults
`researchBaseUrlProvider` to `http://localhost:8081` and selects
`ResearchRemoteDataSourceImpl`, so just run this server on :8081 and the app talks to
it — same contract, real network. No code change needed.

- **Override the URL:** `flutter run -d macos --dart-define=RESEARCH_BASE_URL=https://…`
- **Android emulator:** the host machine is `http://10.0.2.2:8081`.
- **Force the in-app stub back:** `--dart-define=RESEARCH_BASE_URL=` (blank).

---

## Go live (real answers)

```bash
pip install -r requirements.txt                  # adds google-genai

# 1) Ingest the corpus once (creates a File Search store, prints its name):
export GEMINI_API_KEY=...
export BILARA_DATA_DIR=/path/to/bilara-data       # published branch
python -m ingest.ingest                            # → "Set RESEARCH_STORE=fileSearchStores/…"

# 2) Run live:
export RESEARCH_STUB=0
export RESEARCH_STORE=fileSearchStores/tipitaka-en-xxxx
uvicorn app.main:app --port 8081
```

Validate ingest discovery first, **no key needed**:

```bash
python -m ingest.ingest --dry-run --limit 5        # prints uid + derived metadata
```

---

**Pilot a single section** — the `--filter` flag ingests only unit files whose
path contains a substring; ideal for a cheap **live** smoke test before the full
corpus:

```bash
python -m ingest.ingest --filter 'sn/sn15/' --display-name tipitaka-pilot-sn15
# → just the 20 SN 15 (Anamatagga) suttas, into their own store
```

> **Live-verified 2026-06-27** (`google-genai 2.10.0`, free tier): the ingest +
> `/research` round-trip works end-to-end — File Search `create`/`upload`/`documents.list`
> and `grounding_metadata` citation parsing all match the reference code, and the
> SN 15 pilot answers grounded saṁsāra questions correctly from the Flutter app.

## The `/research` contract (stable — protect this)

`POST /research`
```json
{
  "question": "string (Sinhala or English)",
  "history":  [{"role": "user|assistant", "content": "string"}],
  "filters":  {"basket": "vinaya"}
}
```
`history` and `filters` are optional (empty / absent in the prototype).

Response
```json
{
  "answer": "string (same language as question)",
  "lang":   "si | en",
  "citations": [
    {"uid": "sn15.3", "ref": "SN 15.3", "title": "Linked Discourses Chapter One Tears",
     "kind": "canon",
     "snippet": "…short preview span around the match…", "deeplink": null}
  ]
}
```

`title` is the sutta heading (collection name + chapter + name) with just the
number dropped — it's already shown as `ref` — so the app can show a consistent
bold heading per source; `null` when a chunk carried no heading. `snippet` is a short window sliced around the query terms over the
body only (FTS-`snippet()`-style), not the full chunk — tune its length with
`RESEARCH_SNIPPET_CHARS` (default 220). The deep link opens the full text. See
`docs/done/research/source-snippet-shortening-plan.md`.

`deeplink` is `null` until the SuttaCentral→BJT resolver lands (plan Part D).
`kind` is always `"canon"` for now; `"note"` is reserved (design §5.2) so adding
Sujato's notes later needs no contract change.

Other endpoints: `GET /health` (mode + model), `GET /` (banner).

---

## Layout

```
app/
  main.py        FastAPI app: /research, /health, CORS, optional token gate
  config.py      env-driven Settings (12-factor)
  contracts.py   pydantic models = the wire contract above
  lang.py        Sinhala-vs-English detection (Unicode block) — pure
  refs.py        uid <-> display-ref + known-uid linkifier guard — pure
  pipeline.py    LIVE path: detect → rewrite → file_search generation → citations
  stub.py        canned answer for stub mode
ingest/
  ingest.py      both bilara-data trees → File Search store (idempotent, resumable)
Dockerfile       Cloud Run / container image
requirements.txt fastapi + uvicorn (+ google-genai for live/ingest)
```

---

## Deploy (Cloud Run sketch)

```bash
gcloud run deploy wisdom-research --source . \
  --set-env-vars RESEARCH_STUB=0,RESEARCH_STORE=fileSearchStores/tipitaka-en-xxxx \
  --set-secrets GEMINI_API_KEY=gemini-api-key:latest \
  --allow-unauthenticated
```

It scales to zero (≈ $0 idle). **Before exposing publicly**, set `RESEARCH_APP_TOKEN`
(callers then send `X-App-Token`) and/or put rate-limiting at the edge — `/research`
spends Gemini quota (plan, cross-cutting #2). Tighten `RESEARCH_CORS_ORIGINS` to the
app's origin.

---

## Notes & seams (deliberately deferred)

- **Fan-out / retrieval breadth** (design §5.9b) — `pipeline._search_queries`
  returns one query today; decompose thematic questions there later.
- **Deep-links** — `pipeline._deeplink_for` returns `null`; the resolver
  (plan Part B/D) fills it.
- **FTS4 hybrid, multi-turn history, metadata filters beyond `basket`** — v1.1.
- **Model tiers** — the app's Fast/Thinking switch (`ResearchRequest.mode`)
  routes to one of two fallback ladders (`config.FAST_MODELS` / `THINKING_MODELS`,
  via `Settings.models_for_mode`): FAST (`gemini-3.1-flash-lite` →
  `gemini-2.5-flash-lite`) and THINKING (`gemini-3.5-flash` →
  `gemini-3-flash-preview` → `gemini-2.5-flash`), all free-tier +
  File-Search-capable, each falling to the next rung on a 429 (rate limit) or 503
  (high demand) (`pipeline._is_retryable`). The query rewrite always uses the fast
  tier. Override a whole tier with `RESEARCH_FAST_MODELS` /
  `RESEARCH_THINKING_MODELS` (CSV, highest priority first); `GET /health` echoes
  both tiers.
- **Verified 2026-06-28** (`google-genai 2.10.0`): the ladder models support the
  File Search tool and have a free tier; `create`/`upload`/`documents.list` and
  `grounding_metadata` shapes work as written. **Still to verify at scale**
  (design Appendix A): the `metadata_filter` (basket) syntax and per-tier
  file-count / storage caps.
