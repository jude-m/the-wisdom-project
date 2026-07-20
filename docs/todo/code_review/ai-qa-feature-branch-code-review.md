# AI Q&A (`feat/ai-qa`) — Code Review Findings

> **Status:** Review captured 2026-06-30. Read-only audit of the `feat/ai-qa`
> branch (5 commits, ~4.4k lines): the Python `/ask` RAG backend (`ask_server/`),
> the Flutter Q&A vertical, and the SuttaCentral→BJT resolver + search-by-reference.
> **Reviewed against:**
> [`ai-qa-and-suttacentral-reference-resolver-plan.md`](../ai-qa-and-suttacentral-reference-resolver-plan.md),
> [`wisdom-project-rag-qa-design.md`](../wisdom-project-rag-qa-design.md),
> [`suttacentral-bjt-concordance-findings.md`](../suttacentral-bjt-concordance-findings.md).
> **No code was changed** — this is the findings log.
> **Follow-up plans:**
> Findings **#1, #2, #4, #5, #6** (the error-handling cluster) were consolidated,
> with all decisions **settled**, into
> [`../ask/ask-error-handling-gold-standard-plan.md`](../ask/ask-error-handling-gold-standard-plan.md).
> Finding **#8** (the generic rollout to other datasources) is
> [`../refactor/generic-server-call-and-error-handling-standard.md`](../refactor/generic-server-call-and-error-handling-standard.md).

> **✅ UPDATE (2026-07-02) — the error-handling cluster is now IMPLEMENTED** on
> `feat/ai-qa` per the gold-standard plan. Findings **#1, #2, #4, #5, #6** are
> resolved (see the per-finding "Resolved" notes below). **Still open:** #3
> (capability gate), #7 (ref casing), #8 (generic rollout — its own refactor
> doc), #9 (concordance repository bypass), #10 (nits).
> **What shipped:**
> - **Server** (`ask_server/app/`): new `errors.py` (`AskError` + `classify_upstream`
>   + safe messages); `main.py` returns a structured `{"error":{code,message,retriable}}`
>   envelope with the right status (429/503/422/502/401/400) and never leaks raw
>   exception text; `pipeline.py` gained a shared model-ladder helper reused by the
>   rewrite call, plus an empty-answer → 422 `cannot_answer` guard.
> - **Client** (`lib/`): `ApiClient` + typed `ApiException` family
>   (`data/datasources/api_client.dart`); `mapAskError` reading `error.code`
>   (`data/repositories/ask_error_mapper.dart`); `Failure.apiFailure` +
>   `ApiErrorType` (verbatim message, no double prefix); the `X-App-Token` header
>   wired via `askAppTokenProvider`; the dialog now shows a per-type localised
>   message + a Retry affordance (retriable types only) and is fully ARB'd
>   (en/si), with the stale "stub" copy removed.

---

## 0. Verdict

High-quality, well-documented work. The clean-architecture mapping is faithful,
the stub-first swap is real, the resolver is correctly pure, and the
"SQLite stays off the ask path" discipline holds. The findings are mostly about
**error handling and the production-readiness layer the plan itself flagged as
cross-cutting** — i.e. the "before it's public" work, not architectural breakage.

---

## 1. What's done well (keep)

- **Architecture (Q1/Q2/Q9):** entity → datasource → repository → provider →
  widget mirrors the `search`/`dictionary` verticals. There is no
  `lib/data/models/` dir — the project puts `fromJson` directly on Freezed domain
  entities (e.g. `recent_search.dart`), so the Ask entities carrying `fromJson`
  is **consistent with the codebase**, not a deviation. The plan's separate
  `ask_response_model.dart` was correctly dropped in favour of the real convention.
- **Resolver (Q3):** pure, injected map, in `wisdom_shared`, table-testable. The
  `sn15.3 → sn-2-3-1-3` correction is reflected in the seed. Search-by-reference
  reuses the existing `nodeKey`→open-in-tab path, is excluded from the tab bar
  (`search_results_panel.dart:489-491`), and got proper ARB keys.
- **Cost (Q4):** send-button disabled while in-flight; ladder leads with cheap
  `flash-lite`; rewrite skipped for English-without-history; snippet slicing is
  pure (no extra Gemini call); SQLite untouched on the ask path.
- **Backend hygiene:** 12-factor config, lazy `genai` import (stub needs no SDK),
  idempotent/resumable ingest, transient-only retry with fail-fast on 4xx, full
  tracebacks logged server-side, `.env` gitignored, no secrets committed.

---

## 2. Findings (by severity)

| # | Severity | Area | One-line | Status |
|---|---|---|---|---|
| 1 | **High** | Error handling | All failures collapse to one generic message; user can't tell quota/offline/timeout apart; double-prefix message bug | ✅ Resolved |
| 2 | **High** | Security | App-token gate is half-wired — the client can't send `X-App-Token`, so enabling it 401s the app | ✅ Resolved |
| 3 | **High** | Capability gate | The Ask button always shows, even with no usable backend configured | Open |
| 4 | Medium | i18n | Q&A dialog hardcodes English; violates the ARB rule; stale "this is a stub" copy | ✅ Resolved |
| 5 | Medium | Robustness | The rewrite step has no fallback ladder — one 429 there fails the whole Sinhala request | ✅ Resolved |
| 6 | Medium | Security | Backend returns raw exception text to the client (info disclosure) | ✅ Resolved |
| 7 | Low | Consistency | Display-ref casing diverges server vs client (`DHP 155` vs `Dhp 155`); duplicated abbreviation lists | Open |
| 8 | Low | Reuse (Q6) | Four remote datasources hand-roll the same HTTP+status+decode; no generic client — **see the refactor doc** | Partial — `ApiClient` landed for ask; rollout pending |
| 9 | Low | Consistency | Concordance load bypasses the repository + `Either` convention | Open |
| 10 | Low | Nits | Unbounded `google-genai` pin; unused `ChatMessage.fromJson`; complex pure snippet code untested | Open |

---

### Finding 1 — All failures collapse into one generic message (High)

`AskRepositoryImpl` catches *everything* into one `Failure.dataLoadFailure` with a
fixed string (`lib/data/repositories/ask_repository_impl.dart:32-45`). The layers
below build *specific* signals that are then discarded:

- Datasource throws `TimeoutException('The answer took longer than 120s…')`
  (`lib/data/datasources/ask_remote_datasource.dart:53-57`) and
  `Exception('ask failed (502): <body>')`, where the body carries the backend's
  `"ask backend error: RESOURCE_EXHAUSTED…"`.
- Backend distinguishes 400/401/502/503 (`ask_server/app/main.py:70-97`).

So **quota-exhausted (429→502) shows identical text to Wi-Fi-off.** Plan
cross-cutting #1 ("needs a connection") and #2 (rate-limit) never surface.

**Double-prefix bug:** `Failure.userMessage` prepends `"Failed to load data: "`
(`lib/domain/entities/failure.dart:41`); the dialog renders `failure.userMessage`
(`lib/presentation/providers/ask_provider.dart:83`). The user sees:
*"Failed to load data: Could not get an answer right now. Please try again."*

**Recommendation:** classify failures into distinct types (offline, timeout,
rate-limited/quota, server-busy, not-authorised, cannot-answer, generic) with
distinct messages, and add a verbatim-message `Failure` variant so the
`"Failed to load data: "` prefix stops doubling up.
**→ Fully specced & decided** in the gold-standard plan:
[`../ask/ask-error-handling-gold-standard-plan.md`](../ask/ask-error-handling-gold-standard-plan.md)
(7-variant matrix, server status classifier, `Failure.apiFailure` + `ApiErrorType`).
The generic rollout to other datasources is the
[refactor doc](../refactor/generic-server-call-and-error-handling-standard.md).

**✅ Resolved (2026-07-02):** the server now classifies each failure into the
right status + a structured envelope; the client maps it via `mapAskError` into
`Failure.apiFailure(type:…)` and shows one of 7 per-type messages with the right
retry/rephrase/none affordance. The double-prefix bug is gone — `apiFailure`
returns its message **verbatim** (no `"Failed to load data: "`).

---

### Finding 2 — App-token security gate is half-wired (High)

README (`ask_server/README.md:167`) and `main.py:38-47` say "set `ASK_APP_TOKEN`
before exposing publicly; callers send `X-App-Token`." But
`AskRemoteDataSourceImpl` sends only `Content-Type`
(`lib/data/datasources/ask_remote_datasource.dart:43`) — there is **no
`X-App-Token` anywhere in `lib/`**. Enabling the gate makes the live app 401 on
every question. The only built-in abuse protection for the money endpoint is
unusable with the actual client.

**Recommendation:** add an optional `ASK_APP_TOKEN` `--dart-define` → provider →
header. This is delivered by the shared `ApiClient` in the refactor doc.

**✅ Resolved (2026-07-02):** `askAppTokenProvider` reads
`--dart-define=ASK_APP_TOKEN`; when set, the `ApiClient` sends it as the
`X-App-Token` header on every `/ask` call, matching the backend gate. Unset →
no header (open local dev). A rejected token now returns the `not_authorised`
envelope → **notAuthorised** type (no retry).

---

### Finding 3 — Capability gate missing (High)

Plan cross-cutting #1: "a flag hides the entry-point button when no backend is
configured." `AskButton` is added unconditionally
(`lib/presentation/screens/reader_screen.dart:143`) and the default base URL is
hardcoded `http://localhost:8081` (`lib/presentation/providers/ask_provider.dart:18-23`).
For a shipped release:

- No `--dart-define` → button points at localhost → every question fails.
- Empty dart-define → silently serves **canned stub answers** (looks fake).

**Recommendation:** gate the button on a configured non-localhost backend (or an
explicit `kAskEnabled` flag).

---

### Finding 4 — i18n not applied to the Q&A dialog (Medium)

`ask_chat_dialog.dart` and `ask_button.dart` hardcode English ('Ask the Canon',
'New chat', 'Thinking…', 'Sources', 'Send', 'Close', the hint, the empty-state).
Plan A.6 + cross-cutting #5 + `CLAUDE.md` require ARB. `TODO(i18n)` markers exist,
but the plan now marks the feature **LIVE**, so the "stub stage" excuse has
expired. The empty-state copy *"(This is a stub — answers are canned…)"*
(`ask_chat_dialog.dart:177`) is now **stale**.

**Recommendation:** move all dialog strings into `app_en.arb` / `app_si.arb`
(search-by-reference already did this correctly); fix the stale stub copy.

**✅ Resolved (2026-07-02):** every dialog + button string is now an ARB key
(en/si) — title, New chat, Close, empty state, hint, Thinking…, Sources, Send,
Retry, and the 7 error messages. The stale "this is a stub" empty-state copy is
gone. The `TODO(i18n)` markers were removed.

---

### Finding 5 — Rewrite step has no fallback ladder (Medium)

`_generate` walks the model ladder and retries transient 429/503
(`ask_server/app/pipeline.py:130-145`). But `_rewrite` makes a one-shot
`generate_content` on `cfg.rewrite_model` with no retry
(`pipeline.py:81-84`). Every Sinhala question hits rewrite **first**, so a
throttled rewrite model fails before generation begins — asymmetric robustness.

**The reliability is backwards.** English-without-history skips rewrite entirely
(`pipeline.py:66`, early return), so English never touches the fragile call. Only
**Sinhala** — the primary audience — always goes through it. The resilient path
(generation) protects the case that's already safe; the fragile path guards the
case that matters most. A few minutes of the rewrite model being throttled = every
Sinhala question fails, even though generation would have happily fallen back.

**Two-part recommendation:**
1. **First decide whether the rewrite is needed at all.** In the prototype it does
   *only* translation (no history yet). The design's validation gate (§12) should
   measure Sinhala locator-recall **raw vs translated**; if raw retrieval is good
   enough for single-shot questions, **delete the rewrite call** and this finding
   disappears entirely (no second call ⇒ no fragile call). The rewrite earns a
   permanent place only once multi-turn lands, where it does pronoun-resolution
   (not translation) and cannot be skipped.
2. **If kept:** extract the ladder/retry loop from `_generate` into a shared helper
   and reuse it for the rewrite call. Do **not** silently fall back to the raw
   Sinhala query — against an English corpus it retrieves poorly; surface a clear
   "service busy" error (Finding #1) instead.

**✅ Resolved (2026-07-02):** took option 2 (the validation gate hasn't landed,
so retire-for-single-shot is deferred). `pipeline._call_with_ladder` is the
shared helper; `_generate` and `_rewrite` both use it. The rewrite ladder leads
with `rewrite_model`, then falls through to the generation rungs on transient
errors. Exhausting the ladder raises (→ classified into rateLimited/serviceBusy)
rather than silently degrading to the raw Sinhala query.

---

### Finding 6 — Backend leaks raw exception text to the client (Medium)

`main.py:95-97` returns `detail=f"ask backend error: {exc}"`. The SDK exception
can carry store names, model ids, internal request detail. It is already logged
server-side; the client only needs a generic 502.

**Recommendation:** return a generic client detail; keep the traceback in logs.

**✅ Resolved (2026-07-02):** `main.py` no longer puts `{exc}` in the response.
The full traceback stays in `log.exception`; the client receives only a generic,
user-safe `message` in the envelope (`errors.SERVER_ERROR_MSG` et al.). No store
names, model ids, or SDK internals cross the wire.

---

### Finding 7 — Display-ref casing diverges, abbreviation lists duplicated (Low)

Python `ref_from_uid` upper-cases the whole nikāya (`ask_server/app/refs.py:41`)
→ `"DHP 155"`; Dart `displayRef` proper-cases via a map
(`packages/wisdom_shared/lib/src/refs/suttacentral_ref_resolver.dart:55-70`) →
`"Dhp 155"`. The server's `ref` is what renders in citations, so Khuddaka
citations show the wrong case. The two abbreviation sets also diverge (Python
`NIKAYAS` has `KN` but not `vv/pv/cp/bv`; Dart `knownBooks` the reverse).

**Recommendation:** give the Python side a proper-case map mirroring Dart; align
the two abbreviation lists (or document why they differ).

---

### Finding 8 — No generic HTTP client; four datasources repeat the pattern (Low) — your Q6

`ask`, `fts`, `dictionary`, `bjt_document` remote datasources each hand-roll
`http.Client` + baseUrl + a status-throw + `jsonDecode`. Three predate this
branch, so the ask datasource correctly followed the existing pattern — this is a
**repo-wide cleanup, not a branch defect**.

→ Full scope, stages, the one-`Failure`-for-all-sources standard, and benefit
analysis live in
[`../refactor/generic-server-call-and-error-handling-standard.md`](../refactor/generic-server-call-and-error-handling-standard.md).

**Partial (2026-07-02):** the shared `ApiClient` + typed `ApiException` family
now exist (`lib/data/datasources/api_client.dart`) and the ask datasource is
migrated to them (Stage 1 = the gold-standard pilot). The `fts` / `dictionary` /
`bjt_document` datasources are **not** migrated yet — that's Stage 2 in the
refactor doc.

---

### Finding 9 — Concordance load bypasses repository + `Either` (Low)

`suttaCentralRefResolverProvider` calls the datasource `.load()` directly and
swallows errors via `valueOrNull`
(`lib/presentation/providers/reference_search_provider.dart:21-25, 45`). Elsewhere
data flows through repositories returning `Either<Failure,T>`. For a tiny
best-effort asset that degrades gracefully this is acceptable — flag it as a
conscious choice.

---

### Finding 10 — Nits (Low)

- `ask_server/requirements.txt` pins `google-genai>=1.0` (unbounded) while the
  code was verified against `2.10.0` and itself flags `grounding_metadata`/filter
  shapes as version-sensitive — add an upper bound like the fastapi/uvicorn pins.
- `ChatMessage.fromJson` / `.g.dart` is generated but unused (only `toHistoryJson`
  is sent). Harmless dead code.
- `_to_citations` / `make_snippet` are the most complex pure code on the branch —
  the first place to add a unit test when tests are requested.

---

## 3. Suggested priority order

1. ~~Error differentiation + double-prefix message (**#1**)~~ — ✅ done.
2. Capability gate (**#3**) + ~~app-token wiring (**#2**)~~ — #2 ✅ done; **#3 still
   open** (the last "can't ship public" item).
3. ~~Dialog i18n (**#4**)~~ — ✅ done.
4. ~~Rewrite fallback / removal (**#5**) + exception leak (**#6**)~~ — ✅ done.
5. Casing (#7), shared-client rollout (#8 Stage 2 — see refactor doc), concordance
   repository (#9), nits (#10) when convenient.
