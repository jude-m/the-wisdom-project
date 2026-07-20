// Classified failures → the {"error": {code, message, retriable}} envelope the
// client maps onto its typed ApiErrorType. Raw upstream text never crosses the
// wire; it stays in the server log.

// User-facing copy mirrors the app's localised strings (app_en.arb) so an API
// consumer without the app sees the same wording. The client re-localises by
// error.code, so these are never shown in the app itself. The Thinking-mode
// "switch to Fast mode" rate-limit hint is client-only (the server is
// mode-aware but source-agnostic about UI affordances).
export const MSG = {
  rateLimited: 'Research has had a lot of questions just now. Please try again in a few minutes.',
  serviceBusy: 'Research is busy right now. Please try again in a moment.',
  notAuthorised: "Research isn't available right now. Please try again later.",
  cannotAnswer: "I couldn't find an answer to that in the canon. Try rephrasing, or ask about a specific teaching.",
  badRequest: 'The request was invalid.',
  serverError: 'Something went wrong on our end. Please try again.',
} as const;

export class ResearchError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
    public readonly retriable: boolean,
  ) {
    super(message);
  }

  toBody() {
    return {
      error: { code: this.code, message: this.message, retriable: this.retriable },
    };
  }
}

// Upstream (Gemini REST) failure carrying the HTTP status + google.rpc status
// name, thrown by gemini.ts and classified here or retried by the ladder.
export class GeminiError extends Error {
  constructor(
    public readonly httpStatus: number,
    public readonly rpcStatus: string,
    message: string,
  ) {
    super(message);
  }
}

// A 200 from Gemini with no usable answer text (thought-only parts or empty
// candidates). To the ladder this is the same event as a 503 — the rung was
// useless — so it's retryable and falls to the next model; it only becomes a
// 422 cannot_answer when every rung answers empty. A genuine "not in the
// corpus" is NOT this: the system prompt makes the model say so in text.
export class EmptyAnswerError extends Error {
  constructor(public readonly model: string) {
    super('empty answer text');
    this.name = 'EmptyAnswerError';
  }
}

export const isTimeoutError = (e: unknown): boolean =>
  e instanceof Error && (e.name === 'TimeoutError' || e.name === 'AbortError');

export const isRetryable = (e: unknown): boolean =>
  isTimeoutError(e) ||
  e instanceof EmptyAnswerError ||
  (e instanceof GeminiError &&
    (e.httpStatus === 429 ||
      e.httpStatus === 503 ||
      e.rpcStatus === 'RESOURCE_EXHAUSTED' ||
      e.rpcStatus === 'UNAVAILABLE'));

export function classifyUpstream(e: unknown): ResearchError {
  if (e instanceof EmptyAnswerError) {
    return new ResearchError(422, 'cannot_answer', MSG.cannotAnswer, false);
  }
  if (e instanceof GeminiError) {
    const text = e.message.toUpperCase();
    if (e.httpStatus === 429 || e.rpcStatus === 'RESOURCE_EXHAUSTED') {
      return new ResearchError(429, 'rate_limited', MSG.rateLimited, true);
    }
    if (e.httpStatus === 503 || e.rpcStatus === 'UNAVAILABLE') {
      return new ResearchError(503, 'service_unavailable', MSG.serviceBusy, true);
    }
    if (
      e.httpStatus === 400 ||
      e.httpStatus === 422 ||
      ['INVALID_ARGUMENT', 'FAILED_PRECONDITION'].includes(e.rpcStatus) ||
      text.includes('SAFETY') ||
      text.includes('BLOCKED')
    ) {
      return new ResearchError(422, 'cannot_answer', MSG.cannotAnswer, false);
    }
  }
  return new ResearchError(502, 'server_error', MSG.serverError, true);
}
