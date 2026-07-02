"""Structured, safe error envelope for /ask (gold-standard plan §3.1–3.2).

The two halves of "gold standard" are: the server classifies upstream/config
failures into the *right* HTTP status and returns a small, client-readable
envelope; the Flutter client reads that back into a typed error. This module is
the server half.

Every non-200 the client should branch on carries the same shape::

    {"error": {"code": "rate_limited", "message": "<user-safe>", "retriable": true}}

`code` is the precise signal the client maps 1:1 onto its `ApiErrorType`; the HTTP
status is the coarse fallback. Raw exception text NEVER reaches the client
(Finding #6) — the full traceback stays in `log.exception` server-side; only the
generic `message` here crosses the wire.
"""
from __future__ import annotations

from fastapi.responses import JSONResponse

# ── User-safe messages ───────────────────────────────────────────────────────
# Deliberately generic — they never contain store names, model ids, or SDK
# internals. The client re-localises by `code`, so these are effectively a
# fallback; keep them sensible but leak nothing.
RATE_LIMITED_MSG = "The answer service is at capacity. Please try again later."
SERVICE_BUSY_MSG = (
    "The answer service is busy or starting up. Please try again shortly."
)
NOT_AUTHORISED_MSG = "This client is not authorised to use the answer service."
CANNOT_ANSWER_MSG = "I couldn't answer that. Try rephrasing your question."
BAD_REQUEST_MSG = "The request was invalid."
SERVER_ERROR_MSG = "The answer service failed to respond. Please try again."


class AskError(Exception):
    """An /ask failure already classified into a client-facing envelope.

    Raise this anywhere in the request path (a dependency, the pipeline, the
    endpoint). The app-level handler (main.py) renders it as the JSON envelope
    above with the right status. `code` maps 1:1 onto the client's `ApiErrorType`
    (plan §3.2).
    """

    def __init__(
        self,
        status_code: int,
        code: str,
        message: str,
        *,
        retriable: bool,
        retry_after: int | None = None,
    ) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message
        self.retriable = retriable
        # Optional hint for 429/503 (plan §7: v1 client ignores it; harmless to
        # emit for later use).
        self.retry_after = retry_after

    def to_response(self) -> JSONResponse:
        headers = (
            {"Retry-After": str(self.retry_after)}
            if self.retry_after is not None
            else None
        )
        return JSONResponse(
            status_code=self.status_code,
            content={
                "error": {
                    "code": self.code,
                    "message": self.message,
                    "retriable": self.retriable,
                }
            },
            headers=headers,
        )


def classify_upstream(exc: Exception) -> AskError:
    """Map a Gemini SDK / pipeline exception to a safe client envelope.

    The raw exception is logged separately by the caller — only the returned
    (generic) message crosses the wire. Mirrors `pipeline._is_retryable`: the
    google-genai SDK raises ClientError/ServerError(APIError) with `.code` /
    `.status`; we also string-match the *named* statuses as a version-proof
    backstop (but never the bare "400"/"429" numbers, which false-positive).
    """
    code = getattr(exc, "code", None)
    status = (getattr(exc, "status", "") or "").upper()
    text = str(exc).upper()

    # Rate limit / quota exhausted (all rungs) → 429, retry later.
    if code == 429 or status == "RESOURCE_EXHAUSTED" or "RESOURCE_EXHAUSTED" in text:
        return AskError(429, "rate_limited", RATE_LIMITED_MSG, retriable=True)

    # Upstream busy / high demand (all rungs) → 503, retry shortly.
    if code == 503 or status == "UNAVAILABLE" or "UNAVAILABLE" in text:
        return AskError(503, "service_unavailable", SERVICE_BUSY_MSG, retriable=True)

    # Upstream rejected the request itself (safety block / bad prompt / invalid
    # argument): user-actionable → rephrase, not our server's fault (plan §2d).
    if (
        code in (400, 422)
        or status in ("INVALID_ARGUMENT", "FAILED_PRECONDITION")
        or "SAFETY" in text
        or "BLOCKED" in text
    ):
        return AskError(422, "cannot_answer", CANNOT_ANSWER_MSG, retriable=False)

    # Everything else → generic 502 (Finding #6: no raw exception in the body).
    return AskError(502, "server_error", SERVER_ERROR_MSG, retriable=True)
