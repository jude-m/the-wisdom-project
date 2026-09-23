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
npm ci
npm run dev          # wrangler dev on :8082 (stub mode by default)
npm run start:node   # same app on plain Node :8082
npm run bench        # CPU worst-case benchmark vs the 10ms budget
```

Dev port map: 8081 = Dart content server, **8082 = research server**.

Live mode locally: `./scripts/research_server/run.sh`, with
`RESEARCH_GEMINI_API_KEY` in `scripts/config/secrets.env`.

Deploy: `./scripts/research_server/deploy.sh`. It uploads
`RESEARCH_GEMINI_API_KEY` from `scripts/config/secrets.env` as the Worker's
`GEMINI_API_KEY`; `RESEARCH_STUB` and `RESEARCH_STORE` are vars in
`wrangler.jsonc`.

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
  `./scripts/research_server/run.sh --node`.
- Thinking-tier rungs can take ~170s; verify platform limits on long-await
  subrequests when first deploying to Workers.
