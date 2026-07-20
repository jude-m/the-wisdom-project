/// Machine-readable category of a remote-call failure.
///
/// Drives BOTH the user message and the UI affordance (retry vs rephrase vs
/// none). Many raw causes collapse into these eight categories — the full mapping is
/// in `docs/todo/research/research-error-handling-gold-standard-plan.md` §2. This is a
/// *general* (not research-specific) category: any remote call can produce it, so the
/// planned rollout to the other datasources reuses it unchanged.
enum ApiErrorType {
  /// Couldn't reach the service (offline, refused, DNS, wrong host).
  offline,

  /// Took too long (client timeout / gateway 504).
  timeout,

  /// 429 / Gemini quota exhausted — retry later.
  rateLimited,

  /// 503 / cold start / upstream UNAVAILABLE — retry shortly.
  serviceBusy,

  /// 401 / 403 — not user-fixable (a build/config issue).
  notAuthorised,

  /// 422 — safety block / empty answer → the user should rephrase.
  cannotAnswer,

  /// 502 / 500 / response-contract mismatch → retry.
  serverError,

  /// The host killed the request for exceeding its per-request compute budget
  /// (Cloudflare error 1102, HTTP 500 + HTML body). Retriable — the cost
  /// varies with what retrieval returns, so the same question can succeed.
  resourceLimit,
}
