# Next-Gen Research Server — Open Items

> **Status: OPEN (2026-07-16). Read when the full File Search store lands** — most
> items are parked on it. Nothing here is a bug: Thinking mode works end-to-end
> (169.9s, answer rendered in the app).

## Measurements (SN 15 seed store)

| Run | Time | Citations |
|---|---|---|
| Thinking, uncapped | 289.4s | 21 |
| Thinking, `thinking_level=LOW` | 169.9s | 21 |
| Fast | 9.1s | 6 |

The cap cut deliberation by 41% and changed retrieval not at all.

## Two facts worth not re-deriving

- **A client timeout does not save quota.** The 289s call the app abandoned at 120s
  still moved RPD 3/20 → 4/20 — Gemini had already run and charged for it.
- **21 citations = the entire seed store** (all of SN 15), not broad retrieval. So
  reading isn't the cost; SN 15 suttas are short. Likeliest cause is free-tier
  queueing — the same model 503'd twice that day. No knob fixes that.

## Open items

### 1. `top_k` — parked until the real store
Unset for both modes; Fast and Thinking send identical search config. Tuning "best 8
of 21" says nothing about "best 8 of thousands". When the store is real, set via
`file_search["top_k"]` in `pipeline._generate` for: **predictability** (Google picks
the default today and can change it silently), **readability** (21 citations is a lot
to put before a reader), **latency**. Re-measure — don't assume it helps.

### 2. Latency — streaming, not another knob
If ~170s still bothers with the real store, stream the answer. `_linkify_prose_refs`,
`_inject_citation_tokens` and `_to_citations` all assume a finished string, so it's a
real change to the answer path, not a flag.

### 3. Reasoning-cap values are untuned
`config.THINKING_LEVEL="LOW"` / `THINKING_BUDGET_TOKENS=4096` were chosen to fit the
client timeout, not for quality. `None` lifts the cap. Both budget *deliberation
time* — not model capability.

**MEDIUM has never actually been measured.** A 2026-07-16 attempt looked slow and was
rolled back, but the log showed both runs 503'd off *both* Gemini 3 rungs and were
answered by `gemini-2.5-flash` — which takes `thinking_budget`, not `thinking_level`.
No MEDIUM answer was ever generated; the slowness was item 5, not the cap. **Lesson:
check which rung answered before attributing a timing.** Known: uncapped 289s, LOW
170s. LOW vs MEDIUM quality remains uncompared, which is the question that matters.

### 4. Thinking knob is keyed on model-name prefixes
`pipeline._thinking_config`: `gemini-3.x` → `thinking_level`, `gemini-2.5` →
`thinking_budget`, unknown → `None` (uncapped but working). **Update when a new model
family joins a tier.** The SDK validates both shapes for any model, so a wrong knob is
a 400 — which fails fast and takes the whole tier down.

### 5. Per-rung ceiling — BUILT 2026-07-16, value unverified
`config.RUNG_TIMEOUT_SECONDS = 210`, applied via `http_options` to every model call;
`_is_retryable` now treats timeouts as retryable so a cut rung falls through instead
of killing the request. **Failing rungs were the dominant cost, not thinking:**

```
gemini-3.5-flash        503 after   4.0s  → fall through
gemini-3-flash-preview  503 after 369.7s  → fall through   ← the cost
gemini-2.5-flash        OK  in     6.5s
DONE in 380.2s
```

**Why 210s and not lower** — successes (6.5 / 7.2 / 169.9 / 289.4s) and refusals
(4.0 / 74.3 / 74.9 / 369.7s) *overlap*: a slow rung that will answer looks exactly
like one that will refuse. Anything under ~170s would kill `gemini-3.5-flash`'s real
answer every time and silently demote Thinking to the bottom rung. (An earlier note
here claimed a 60s cap would turn 380s into ~130s — **wrong**, for that reason.)

**Still open:** 210s is reasoned from four data points, never observed firing in
anger. It is **coupled to `THINKING_LEVEL`** (item 3) — it must exceed the slowest
legitimate answer, so lifting the cap means raising this too. Worst case is 210s ×
rungs, which can still exceed the client ceiling (item 6); a total request deadline
would bound that properly if it becomes a problem.

Not for quota: a timeout does not refund a call Gemini has already run.

### 6. Client timeouts chosen, not measured
`_timeoutFor`: Fast 60s, Thinking 4 min. The Thinking backstop catches a *wedged*
request, not a slow one. Also: `researchErrorTimeout` says "Please try again" — that
retry costs ~5% of the daily quota and fails identically.

### 7. Cloud Run may set the dropped `RESEARCH_MODEL`
Removed (it front-pinned the fast model onto both tiers). If the deploy still sets it,
it's now silently ignored. Confirm; consider a startup warning.

### 8. No tests
`research_server/` has no `tests/`. Two pure-function tests worth having:
`Settings.models_for_mode("thinking")` (would have caught the tier-leak bug) and
`pipeline._thinking_config` (item 4 rots silently).

### 9. Smaller
- Request tag missing from `main.py`'s final `log.exception` (the ContextVar unwinds first).
- Rewrite ladder is FAST-tier only; revisit if flash-lite 429s appear in the logs.
- `_search_queries` is still the single-query fan-out seam (§5.9b) — pairs with item 1.
