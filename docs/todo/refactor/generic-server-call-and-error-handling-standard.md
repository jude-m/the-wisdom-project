# Refactor — Generic Server-Call Client & Error-Handling Standard

> **Status:** Proposal / **handover**, 2026-06-30. Spun out of the `feat/ai-qa`
> code review
> ([`../code_review/ai-qa-feature-branch-code-review.md`](../code_review/ai-qa-feature-branch-code-review.md),
> Findings #1/#2/#8). **No code changed yet.**
> **Scope split:** the **ask** path is being built first as the *gold standard* and
> has its own plan —
> [`../ask/ask-error-handling-gold-standard-plan.md`](../ask/ask-error-handling-gold-standard-plan.md).
> **This doc is the general standard + the handover** for rolling that same pattern
> out to the other three datasources (`fts`, `dictionary`, `bjt_document`) and to
> future non-HTTP sources. Pick it up once the ask pilot has proven the shape.
> **Companion concern:** the app-token header (review Finding #2) and the
> error-message differentiation (review Finding #1) are delivered first by the ask
> plan, then generalised here.

---

## 0. TL;DR

Today four remote datasources (`ask`, `fts`, `dictionary`, `bjt_document`) each
hand-roll the same thing: an `http.Client`, a base URL, a status-code check, and
a `jsonDecode`. There is **no shared transport** and **no typed error model** —
so error *categorisation* happens late and fragilely, by sniffing exception type
names and message strings in `statusVariantForError()`
(`lib/presentation/widgets/common/status_message_view.dart:236`).

This refactor introduces:

1. **`ApiClient`** — one thin JSON-over-HTTP transport (headers, timeout, auth,
   status → typed exceptions).
2. **`ApiException` family** — typed transport errors (`network`, `timeout`,
   `status`) instead of bare `Exception('… (502)')`.
3. **`mapApiException()`** — one shared mapper: typed exception → the **existing,
   generic** `Failure` union, with correct, distinct user messages.

Rolled out in **stages**, ask-first, so nothing working is disturbed.

**The headline rule:**
> Transport throws *typed technical* exceptions; the repository maps them to the
> *one shared domain* `Failure`; only `Failure.userMessage` produces user copy.
> Status codes never leak above the repository; user strings never appear below it.

---

## 1. The architectural question this settles: one `Failure`, or one per source?

**You already have the right thing — keep using it.** `Failure`
(`lib/domain/entities/failure.dart`) is a sealed union —
`dataLoadFailure` / `dataParseFailure` / `notFoundFailure` /
`invalidOperationFailure` / `unexpectedFailure` — and it is **already the shared
error currency for every repository** (search, dictionary, documents, reader,
tree), not just web. That is exactly correct. The answer to "should we have a
Failure type for all errors — db, future image retrieval, not only web?" is
**yes, the single generic `Failure` — and we already do.**

The mistake to avoid is the opposite one: **do not create a `Failure` subtype per
datasource** (`AskFailure`, `DbFailure`, `ImageFailure`…). That fragments the
domain and forces every UI to know which datasource it came from.

The correct shape is three layers with a clear division of labour:

```
                     SPECIFIC + TECHNICAL                 SHARED + SEMANTIC
   ┌─────────────┐   throws                  ┌───────────┐  returns            ┌──────────────┐
   │  Transport  │ ───────────────────────▶ │ Repository │ ──────────────────▶ │ Domain / UI  │
   │ (datasource)│   ApiException            │  (mapper)  │   Failure           │  Failure only│
   └─────────────┘   DbException             └───────────┘                      └──────────────┘
                     ImageException
```

- **Exceptions are a data-layer implementation detail** — *specific* to the
  mechanism. HTTP throws `ApiException`; SQLite would throw a `DbException`; image
  fetch an `ImageException`. They carry technical facts (status code, SQL error,
  HTTP body). They are **not** domain types and never reach the UI.
- **`Failure` is a domain concept** — *semantic*, source-agnostic. "Not found" is
  the same idea whether it came from a 404, a missing SQLite row, or an absent
  asset. The UI renders `Failure`; it must not care which datasource produced it.
- **The repository is the single mapping seam.** Each *source family* gets one
  small mapper (`mapApiException`, later `mapDbException`), and **they all target
  the same `Failure` union.** One mapper per transport, one shared destination.

### When do we add a *new* `Failure` variant?

Driven by **one test only: does the UI need to render this case differently?**
Not by "a new datasource appeared."

- Offline vs rate-limited vs server-busy *do* render differently ("check your
  connection" vs "you've hit today's limit" vs "starting up, retry") → they
  deserve to be **distinguishable**. Today they are all squashed into
  `dataLoadFailure` and separated only by message string, and the *presentation*
  re-derives "offline" by **sniffing type names** in `statusVariantForError`
  (`status_message_view.dart:236-277`). That works but is brittle.
- A db read error vs a web read error that the UI renders **identically** → same
  variant, no new type needed.

So variants are **per user-meaningful outcome, never per datasource.** The
cleanup (Stage 3) is to let the `Failure` carry the category explicitly so the UI
stops string-sniffing — see §4.

> **Rule of thumb:** *new datasource → new exception type + a new mapper. New
> user-visible outcome → maybe a new `Failure` variant. Never a `Failure` per
> datasource.*

---

## 2. The components

### 2.1 `ApiClient` (transport)

`lib/data/datasources/api_client.dart` — framework-free, so it can later move to
`wisdom_shared`.

```dart
/// Thin JSON-over-HTTP transport. Centralises base URL, timeout, the optional
/// app-token header, status-code handling, and JSON decoding so datasources stay
/// tiny and consistent.
class ApiClient {
  final http.Client _client;
  final String _baseUrl;
  final String? _appToken;          // review Finding #2: one home for X-App-Token
  final Duration _timeout;

  ApiClient({
    required String baseUrl,
    String? appToken,
    Duration timeout = const Duration(seconds: 120),
    http.Client? client,
  })  : _baseUrl = baseUrl,
        _appToken = appToken,
        _timeout = timeout,
        _client = client ?? http.Client();

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) =>
      _send(() => _client.post(
            Uri.parse('$_baseUrl$path'),
            headers: _headers,
            body: jsonEncode(body),
          ));

  Future<Map<String, dynamic>> getJson(String path, {Map<String, String>? query}) =>
      _send(() => _client.get(Uri.parse('$_baseUrl$path').replace(queryParameters: query),
            headers: _headers));

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_appToken != null) 'X-App-Token': _appToken!,
      };

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() call) async {
    final http.Response res;
    try {
      res = await call().timeout(_timeout);
    } on TimeoutException {
      throw ApiTimeoutException(_timeout);
    } catch (e) {
      throw ApiNetworkException(e);   // SocketException, refused, DNS, web XHR, …
    }
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw ApiStatusException(res.statusCode, res.body);
  }
}
```

### 2.2 `ApiException` family (the transport↔repository contract)

```dart
sealed class ApiException implements Exception {}

class ApiNetworkException extends ApiException {     // could not reach the server
  final Object cause;
  ApiNetworkException(this.cause);
}

class ApiTimeoutException extends ApiException {      // server too slow
  final Duration limit;
  ApiTimeoutException(this.limit);
}

class ApiStatusException extends ApiException {       // server replied non-200
  final int statusCode;
  final String body;
  ApiStatusException(this.statusCode, this.body);

  bool get isRateLimited => statusCode == 429;
  bool get isUnavailable => statusCode == 503;
  bool get isUnauthorized => statusCode == 401;
}
```

### 2.3 `mapApiException()` (the seam — review Finding #1)

```dart
Failure mapApiException(Object e) {
  if (e is ApiNetworkException) {
    return const Failure.dataLoadFailure(
        message: 'No connection. Check your internet and try again.');
  }
  if (e is ApiTimeoutException) {
    return Failure.dataLoadFailure(
        message: 'The answer took too long (${e.limit.inSeconds}s). '
            'The model may be busy — please try again.');
  }
  if (e is ApiStatusException) {
    if (e.isRateLimited) {
      return const Failure.dataLoadFailure(
          message: "You've reached today's question limit. Please try later.");
    }
    if (e.isUnavailable) {
      return const Failure.dataLoadFailure(
          message: 'The answer service is starting up. Please try again shortly.');
    }
    if (e.isUnauthorized) {
      return const Failure.invalidOperationFailure(
          message: 'This app build is not authorised to use the answer service.');
    }
    return const Failure.unexpectedFailure(
        message: 'The answer service had a problem. Please try again.');
  }
  return const Failure.unexpectedFailure(
      message: 'Something went wrong. Please try again.');
}
```

With this, a datasource is just JSON↔entity and a repository is one line:
`try { return Right(await _ds.ask(...)); } catch (e, s) { log(...); return Left(mapApiException(e)); }`.

---

## 3. Stages (each independently shippable)

### Stage 0 — Foundation (no behaviour change)
Add `api_client.dart` (the `ApiClient` + `ApiException` family + `mapApiException`).
Nothing consumes it yet. Pure addition, zero risk.

### Stage 1 — Adopt in the ask feature only → **the gold-standard pilot**
**Owned by [`../ask/ask-error-handling-gold-standard-plan.md`](../ask/ask-error-handling-gold-standard-plan.md).**
That plan goes deeper than this generic doc (full scenario matrix, a 7-variant
message set, the server-side status classifier, the Fast/Thinking-mode forward
compat). In short: `AskRemoteDataSourceImpl` takes an injected `ApiClient`,
`AskRepositoryImpl` replaces its blanket `catch` with the mapper, the app-token is
wired (Finding #2), and the user gets differentiated copy (Finding #1) — all on the
newest, least-coupled path, **working features untouched.** This Stage is the
template the remaining stages copy.

### Stage 2 — Migrate the three existing datasources *(handover starts here)*
`fts`, `dictionary`, `bjt_document` each collapse to JSON↔entity mappers over
`ApiClient`. Mechanical; do one per PR, verify, move on. All four then share one
timeout policy, offline detection, and error vocabulary.

### Stage 3 — Make `Failure` carry its category; retire the string-sniffing
Today `statusVariantForError` (`status_message_view.dart:236`) decides
offline-vs-error by matching `'SocketException'` / `'ClientException'` / message
substrings on the *unwrapped* cause. Once errors flow through `mapApiException`,
the `Failure` can name its own category (e.g. a small `kind` enum:
`offline | timeout | rateLimited | unavailable | server | parse | notFound |
unexpected`), and the presentation reads that directly. Removes the brittle
type/string matching. Optional and last, because it touches shared UI.

### Stage 4 (future) — Extend the pattern to non-HTTP sources
When local-DB or image errors need richer UI treatment, add `DbException` /
`ImageException` + `mapDbException` / `mapImageException` — **targeting the same
`Failure` union** (§1). Don't fork `Failure`.

---

## 4. Benefits

- **Correct, distinct error messages** (the user can tell offline from quota from
  timeout) — review Findings #1 across *all* server calls, not just ask.
- **One home for cross-cutting transport concerns:** timeout, auth header
  (Finding #2), retry policy, logging, base-URL handling.
- **Less code, less drift:** four near-identical `_checkResponse` + decode blocks
  collapse to one.
- **Robust categorisation:** typed exceptions replace `statusVariantForError`'s
  type-name/string sniffing (Stage 3).
- **Testability:** `mapApiException` is a pure function — table-test it. `ApiClient`
  takes an injected `http.Client` — mock it.
- **Clean-architecture reinforcement:** status codes stop leaking above the
  repository; user strings stop appearing below it.

---

## 5. Non-goals / risks

- **Not a networking framework.** No interceptors, no retry-by-default, no
  caching. Just transport + typed errors. (Per-feature retry, e.g. the ask model
  ladder, stays server-side.)
- **Don't migrate all four at once.** Stage 2 per-datasource keeps regression
  surface small; the existing three already work.
- **`Failure.userMessage` prefix is a blocker for clean copy — decide first.** It
  prepends `"Failed to load data: "` (`failure.dart:41`), which double-prefixes
  the clean messages above. Resolve once (drop the prefix, or add a verbatim
  variant); it ripples to every caller, so it's a deliberate app-wide call, not an
  ask-local one.

---

## 6. Open decisions

- ✅ **`userMessage` prefix → DECIDED:** add a verbatim-message `Failure` variant
  (`Failure.apiFailure`, `userMessage` returns the message as-is). Settled in the
  ask plan (§4.7); reuse it here unchanged.
- ✅ **`Failure` category enum → DECIDED:** one general `ApiErrorKind` enum on
  `apiFailure` (Stage 3 is effectively pulled forward by the ask pilot). Reuse it;
  do not add per-source variants.
- **`ApiClient` home:** start in `lib/data/datasources/`; promote to
  `wisdom_shared` once a second consumer (server, static site) wants it.
- **Where the app-token comes from:** `--dart-define` (simplest) vs remote config.
  Out of scope here; `ApiClient` only needs the resolved value.
