# research_server

TypeScript rewrite of the `/research` backend, targeting Cloudflare Workers
(free plan, 10ms CPU/request) but runnable on any Node host — the core is
Web-standard `fetch`/`Request`/`Response` only.

The retired Python prototype lives in `deprecated/research_server/` (reference
only; its `ingest/` job still handles File Search store uploads).

## Endpoints

- `POST /research` — `{question, history, filters?, mode}` →
  `{answer, lang, citations}`. Errors: `{"error": {code, message, retriable}}`.
- `GET /health`, `GET /` — liveness / mode.

## Run

```sh
npm install
npm run dev          # wrangler dev on :8082 (stub mode by default)
npm run start:node   # same app on plain Node :8082
npm run bench        # CPU worst-case benchmark vs the 10ms budget
```

Dev port map: 8081 = Dart content server, **8082 = research server**.

Live mode locally: copy `.dev.vars.example` → `.dev.vars` and fill
`GEMINI_API_KEY` + `RESEARCH_STORE` (values are in the old server's `.env`).

Deploy: `wrangler deploy`, then `wrangler secret put GEMINI_API_KEY` and set
`RESEARCH_STUB=0` + `RESEARCH_STORE` in `wrangler.jsonc` vars.

## Design notes

- Model ladders (fast: flash-lite tier; thinking: full-flash tier) fall through
  on 429/503/timeout only — see `src/config.ts` for models and caps.
- The whole request (rewrite + answer, all rungs) runs under one per-mode
  deadline (55s fast / 290s thinking), just inside the app's HTTP timeouts —
  past it no new rung starts, since the client has already hung up.
- CPU budget: snippet building is the only real cost. Snippets are built once
  per displayed source (deduped by uid), the body scan is bounded
  (12k chars / 24 matches), and word folding is memoised across requests.
- One log line per request; extra `warn` lines only when a ladder rung fails.
  On Node the line also carries debug CPU timers — `cpu=` (whole handler,
  includes Node-side TLS/JIT that Workers doesn't bill) and `build=` (the
  post-processing that scales, i.e. snippets). Workers hides the CPU clock
  from scripts, so there the field is absent — read per-request CPU from the
  dashboard invocation logs instead. Live-on-Node run:
  `set -a; source .dev.vars; set +a; RESEARCH_STUB=0 npm run start:node`.
- Thinking-tier rungs can take ~170s; verify platform limits on long-await
  subrequests when first deploying to Workers.
