# Ask — Error-Handling Gold Standard (Plan)

> **Status:** Plan, 2026-06-30. The AI Q&A path (`/ask` backend ⇄ Flutter client)
> becomes the **reference implementation** for error handling; every other feature
> later follows it. The *generic/systemic* version (other datasources, shared
> `Failure` category, non-HTTP sources) is handed over to
> [`../refactor/generic-server-call-and-error-handling-standard.md`](../refactor/generic-server-call-and-error-handling-standard.md).
> **Source review:** [`../code_review/ai-qa-feature-branch-code-review.md`](../code_review/ai-qa-feature-branch-code-review.md)
> (Findings #1, #2, #4, #5, #6).

---

## 0. The problem (agreed)

When an ask request fails, **the app cannot tell the user *why*** — offline,
quota-exhausted, timeout, server-warming-up, and not-authorised all produce the
**same** sentence. The information exists at every layer but is **flattened on the
way up**: the backend knows the status, the datasource has it as a raw string, the
repository's blanket `catch` collapses it to one generic `Failure`, and the UI has
nothing left to differentiate.

**Goal:** every failure the ask path can produce is (a) given a *meaningful* shape
by the backend, (b) carried *intact* to the UI, and (c) shown as a message whose
**user action is correct** — *and no more variants than make sense* (many causes
collapse to one message when the user would do the same thing).

---

## 1. The two halves of "gold standard"

```
   Gemini ── error ──▶ ask_server ── meaningful HTTP status + clean error body ──▶ ApiClient
                       (classify, don't leak)        │                            (typed exception)
                                                      ▼
                                              Flutter client ── Failure(type) ──▶ dialog (right message + action)
```

- **Server half:** stop collapsing every live-mode failure into `502 "ask backend
  error: <raw exc>"`. Classify upstream/config errors into the *right* status code
  and return a **structured, safe error body** (no raw exception text — Finding #6).
- **Client half:** read that status/body into a **typed error**, map it to a
  `Failure` with an explicit `type`, and render a per-type message + action. No
  string-sniffing of exception types.

---

## 2. Intensive scenario check (every path, end to end)

Walking the full path: **client guard → network → HTTP status → response body →
backend-internal (Gemini rewrite + generate)**. "Variant" is the *user-facing*
bucket; note how many raw causes collapse into each.

### 2a. Transport — client never gets a usable response

| Scenario | Signal (today) | Retry? | Variant | Notes |
|---|---|---|---|---|
| No internet | `SocketException` / web `ClientException` | user retry | **offline** | |
| Service unreachable (conn refused, DNS, wrong base URL, cold backend) | `SocketException` / `ClientException` | user retry | **offline** | Often indistinguishable from "no internet" at runtime → same message |
| Wrong host / path (404 from a non-`/ask` host) | `404` | build fix | **offline** | Treated as "can't reach service" |
| Client timeout (>120 s) | `TimeoutException` | retry | **timeout** | 120 s ceiling sized for slow flash models |
| Gateway timeout | `504` | retry | **timeout** | Cloud Run / LB request cap |

### 2b. Auth / config — not user-fixable

| Scenario | Signal | Retry? | Variant | Notes |
|---|---|---|---|---|
| Missing/invalid app token | `401` | no | **notAuthorised** | Only when `ASK_APP_TOKEN` set + client wired (Finding #2) |
| Forbidden (edge IAM) | `403` | no | **notAuthorised** | Don't promise "try again" |

### 2c. Rate / capacity — retry later

| Scenario | Signal (today → **gold**) | Retry? | Variant | Notes |
|---|---|---|---|---|
| Edge rate limit | `429` | later | **rateLimited** | From Cloud Run / API gateway (plan cross-cutting #2) |
| **Gemini quota exhausted, all rungs** | `502` → **`429`** | later | **rateLimited** | *Today this is buried in a 502.* Map `RESOURCE_EXHAUSTED` → 429 + `Retry-After` |
| Store not configured (`ASK_STORE` unset) | `503` | shortly | **serviceBusy** | Already 503 — keep |
| Cold start / scaling | `503` | shortly | **serviceBusy** | Platform-level |
| **Gemini UNAVAILABLE, all rungs** | `502` → **`503`** | shortly | **serviceBusy** | Map `UNAVAILABLE` → 503 |

### 2d. Bad question / can't answer — *rephrase*, not retry

| Scenario | Signal (today → **gold**) | Retry? | Variant | Notes |
|---|---|---|---|---|
| Empty question | client guard; backend `400` | — | *(prevented)* | Send disabled; no message needed |
| Gemini safety block / no candidates | `502` → **`422`** | rephrase | **cannotAnswer** | Detect `finish_reason=SAFETY`/empty candidates |
| Empty answer text on `200` | `200` blank → **`422`** | rephrase | **cannotAnswer** | Guard `answer==""` → return 422 `cannot_answer`, never a blank `200` bubble |
| Prompt too long / upstream `400` | `502` → **`422`** | rephrase | **cannotAnswer** | Upstream (Gemini) 400 is user-actionable → `cannot_answer`, **not** our API 400 |

> **The two 422s / two 400s — disambiguate by `code`, not bare status.**
> `422` is used by *both* our deliberate `cannot_answer` **and** FastAPI's default
> Pydantic body-validation error (shape `{"detail":[…]}`, not our envelope). `400`
> means *our* "empty question" (client-prevented). So the client must key on the
> structured `error.code` (§3.2): `cannot_answer` → **cannotAnswer**; a 422/400 with
> **no** `error.code` envelope → **serverError** (a client-side bug that shouldn't
> occur). Never branch on the raw status alone for these two.

### 2e. Server fault — generic retry

| Scenario | Signal (today → **gold**) | Retry? | Variant | Notes |
|---|---|---|---|---|
| Gemini SDK / unexpected error (all rungs) | `502` raw exc → **`502` clean body** | retry | **serverError** | Finding #6: no raw exception in the body |
| Unhandled framework `500` | `500` | retry | **serverError** | |
| Malformed / contract-mismatch JSON on `200` | `FormatException` / `fromJson` throws | retry | **serverError** | Log as *parse* internally; same user message |
| Pydantic `422` (client sent bad body) | `422` | no (bug) | **serverError** | Shouldn't happen with a correct client |

### 2f. Not errors (handle, don't alarm)

| Scenario | Handling |
|---|---|
| `200`, answer present, **citations empty** | Valid (honest absence). Show answer, omit "Sources". *Already handled.* |
| `200`, partial-coverage answer | The model's own "coverage may be partial" line; no special UI. |

### The variant set (the messages that "make sense") — **7**

Each has a *distinct user action*; ~18 raw causes above collapse into these 7:

| `type` | Message (draft — goes through ARB) | Action implied | Retry UI? |
|---|---|---|---|
| **offline** | "Can't reach the answer service. Check your connection and try again." | check connection | retry |
| **timeout** | "That took too long — the model may be busy. Please try again." | retry now | retry |
| **rateLimited** | "You've reached the question limit for now. Please try again later." | wait | retry (later) |
| **serviceBusy** | "The answer service is busy or starting up. Please try again shortly." | retry shortly | retry |
| **notAuthorised** | "This version of the app can't use the answer service." | none (build issue) | **no retry** |
| **cannotAnswer** | "I couldn't answer that. Try rephrasing your question." | rephrase | edit, not retry |
| **serverError** | "Something went wrong. Please try again." | retry | retry |

> **"Only when it makes sense":** we track more *codes* internally (for logs /
> telemetry) than we show *messages*. `parse`, generic `502`, and `500` all map to
> **serverError** because the user does the same thing (retry). We keep
> **notAuthorised** separate precisely because promising "try again" there would be
> a lie.

---

## 3. Server-side changes (`ask_server`)

1. **Error classifier.** Replace the blanket `except Exception → 502 raw exc`
   (`app/main.py:88-97`) with a mapping from upstream/config errors to status:
   - `RESOURCE_EXHAUSTED` / 429 (ladder exhausted) → **429** (+ `Retry-After`)
   - `UNAVAILABLE` / 503 (ladder exhausted) → **503**
   - safety-blocked / empty candidates / upstream 400 → **422** (cannotAnswer)
   - `ASK_STORE` unset → **503** *(already)*
   - everything else → **502**
2. **Structured, safe error body** (Finding #6) — a small envelope the client can
   read without parsing prose:
   ```json
   { "error": { "code": "rate_limited", "message": "<user-safe>", "retriable": true } }
   ```
   Keep the full traceback in `log.exception` only. `code` is the precise signal;
   HTTP status is the coarse one — the client uses `code` when present, else status.
   The `code` strings map 1:1 onto the client `ApiErrorType` (§4.7):

   | HTTP | `code` | → client `type` |
   |---|---|---|
   | 429 | `rate_limited` | rateLimited |
   | 503 | `service_unavailable` | serviceBusy |
   | 401/403 | `not_authorised` | notAuthorised |
   | 422 | `cannot_answer` | cannotAnswer |
   | 400 | `bad_request` | serverError *(client bug — shouldn't happen)* |
   | 502/500 | `server_error` | serverError |

   (`offline` / `timeout` have no server `code` — they're client-side transport
   states, never a server reply.)
3. **Rewrite gets the ladder (Finding #5).** Extract `_generate`'s retry loop into a
   shared helper and reuse it for `_rewrite`, so a throttled rewrite model classifies
   like a generation failure (or — preferred — *retire the rewrite for single-shot*
   pending the validation gate; see review Finding #5).
4. **Empty-answer guard.** If `resp.text` is empty on success (blank generation or a
   safety block with no candidates), respond **422** with `code: "cannot_answer"` —
   never a `200` with a blank `answer`. *(Decision #2: cannotAnswer is a non-200
   error, not a `200`+flag — keeps the rule "errors are non-200".)*

> The success `/ask` contract (design §7) is **unchanged**. The error envelope is
> **additive** — a new shape only on non-200 — so it doesn't touch the reversibility
> anchor.

---

## 4. Client-side changes (Flutter, ask only)

1. **`ApiClient` (ask-scoped)** — typed transport from the refactor doc, used by
   `AskRemoteDataSourceImpl` only. Adds the **app-token header** (Finding #2) and
   the 120 s timeout in one place.
2. **Typed errors** — `ApiNetworkException` / `ApiTimeoutException` /
   `ApiStatusException(code, body)`, plus reading the structured `error.code`.
3. **`mapAskError(e) → Failure`** — produces a `Failure` carrying an explicit
   `type` (the 7 above). One pure, table-testable function.
4. **Dialog rendering** — message per `type`; a **Retry** affordance for retriable
   types; **no retry** wording for `notAuthorised`; for `cannotAnswer`, keep the
   user's question in the box to edit. (Today the dialog just shows a red line —
   `ask_chat_dialog.dart:114-124`.)
5. **i18n (Finding #4)** — all 7 messages are new ARB keys in `app_en.arb` /
   `app_si.arb`; the rest of the dialog strings get localised in the same pass.
6. **Verbatim-message `Failure` variant** *(decided — see §4.7)* — the 7 messages
   are already user-ready, so they must **not** get the `"Failed to load data: "`
   prefix `Failure.userMessage` adds today.

### 4.7 The `Failure` variant + error-type enum *(decided)*

Add **one** new, *general* (not ask-specific) variant to the existing `Failure`
union (`lib/domain/entities/failure.dart`). It carries a machine-readable `type`
**and** returns its message **verbatim** — settling both the prefix decision (#1)
and "how does the UI know which type" in one move. It is general because the 7
types describe any remote call, so Stage 2 of the refactor doc reuses it unchanged.
Do **not** make an ask-only failure — that violates the one-`Failure` rule.

```dart
/// Machine-readable category of a remote-call failure. Drives the message AND the
/// UI affordance (retry vs rephrase vs none). More causes than types — see §2.
enum ApiErrorType {
  offline,        // couldn't reach the service
  timeout,        // took too long
  rateLimited,    // 429 / Gemini quota exhausted
  serviceBusy,    // 503 / cold start / upstream UNAVAILABLE
  notAuthorised,  // 401 / 403 — not user-fixable
  cannotAnswer,   // 422 — safety block / empty answer → rephrase
  serverError,    // 502 / 500 / parse mismatch → retry
}

// In the Failure union:
const factory Failure.apiFailure({
  required String message,     // already user-ready — shown as-is
  required ApiErrorType type,
  Object? error,               // original cause, for logs only
}) = ApiFailure;

// In `String get userMessage` (the when/switch):
//   apiFailure: (message, _, __) => message,   // VERBATIM — no prefix
```

`mapAskError` (§4.3) is the only thing that constructs `apiFailure`; the dialog
(§4.4) switches on `type` for the retry/rephrase affordance and shows `userMessage`
as the text.

---

## 5. Forward-compatibility: **Fast vs Thinking** mode (separate task, but connected)

A planned dropdown lets the user pick **Fast** (lite models) vs **Thinking** (flash
models). Already captured as design §14 ("model-family selector"). It touches this
plan in three real ways — design for them now even though it ships later:

1. **The ladder splits into two families.** Today `config.DEFAULT_MODELS` is one
   ladder mixing lite + flash. Fast = the lite sub-ladder, Thinking = the flash
   sub-ladder; an optional `mode` (or `tier`) field on the `/ask` request selects
   which. **Additive to the contract.**
2. **Fallback must stay *within* the chosen family.** This is the error-handling
   link: on a `429`, "Fast" must **not** silently fall back to a slow flash model —
   that betrays the user's choice and changes cost/latency. It should exhaust the
   *lite* rungs, then return **rateLimited** for that family. (Note: the **current
   mixed ladder already has this latent surprise** — a lite-429 silently jumps to a
   ~45 s flash model. The dropdown is the reason to make fallback family-scoped.)
3. **Mode-aware messages.** Once modes exist, **rateLimited** / **serviceBusy** can
   gain a smarter action: *"Fast mode is busy — try Thinking mode, or wait."* So the
   error body should **echo the failed `mode`**, and the `Failure.type` design should
   leave room for an optional `mode` payload. The 7-variant set doesn't change; two
   of them just get a richer suggested action.

Also: **timeout** is far likelier in Thinking mode (flash ~35–45 s) than Fast
(lite ~7 s), so a future mode-aware client timeout (shorter for Fast) is a natural,
non-breaking refinement.

**Net:** keep the request `mode`-ready (optional field), make server fallback
family-scoped, and let `Failure.type` carry an optional `mode` — none of which
blocks shipping the error work now.

---

## 6. Stages (ask only)

1. **Server classifier + error envelope** (§3.1–3.2) — biggest correctness win;
   the client can stay generic until it lands.
2. **Client `ApiClient` + typed errors + `mapAskError` + app-token** (§4.1–4.3,
   Findings #1/#2).
3. **Dialog: per-type messages, Retry affordance, i18n** (§4.4–4.5, Finding #4).
4. **Rewrite ladder / retire** (§3.3, Finding #5) + **empty-answer guard** (§3.4).
5. **(When the dropdown lands)** family-scoped fallback + `mode` echo (§5).

---

## 7. Decisions (settled) & remaining implementer calls

**Settled (build to these):**

- ✅ **`userMessage` prefix → verbatim `Failure` variant.** Add
  `Failure.apiFailure` whose `userMessage` returns the message as-is; no
  `"Failed to load data: "` prefix. General, not ask-only. (§4.7)
- ✅ **Error category → one `ApiErrorType` enum** on that variant (the 7 types),
  not a `Failure` per datasource. (§4.7)
- ✅ **cannotAnswer transport → HTTP 422** (`code: "cannot_answer"`), *not* a
  `200`+flag. Keeps "errors are non-200". (§3.4)

**Left to the implementer (sensible defaults given):**

- **`Retry-After` header:** *Default v1 = ignore it* — allow immediate manual
  retry; the backend may still emit the header on 429/503 for later use. Honour it
  (disable retry until it elapses) only if cheap.
- **`ApiFailure` name/home:** `apiFailure` matches `ApiClient`/`ApiException` from
  the refactor doc; bikeshed freely, but keep it *general* and in the shared
  `Failure` union.
- **Rewrite (§3.3):** ladder-retrofit vs retire-for-single-shot is gated on the
  design's §12 validation result — pick when that lands; either satisfies Finding #5.
