"""FastAPI entry point for the /ask service.

  POST /ask    — the §7 contract (stub or live, per ASK_STUB).
  GET  /health — liveness + which mode/model is active.
  GET  /       — short human-readable banner.

Run locally (stub mode, no key needed):
    uvicorn app.main:app --reload --port 8081
"""
from __future__ import annotations

import logging

from fastapi import Depends, FastAPI, Header, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from . import errors
from .config import Settings, load_settings
from .contracts import AskRequest, AskResponse
from .errors import AskError

settings: Settings = load_settings()

# "ask" logger — like pipeline's "ask.pipeline", it propagates to uvicorn's
# console handler, so anything logged here shows up in the server terminal.
log = logging.getLogger("ask")

app = FastAPI(title="Wisdom Project — /ask", version="0.1.0")

# Flutter web calls this cross-origin; native does too. Tighten ASK_CORS_ORIGINS
# in production (default "*" is for local dev).
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


@app.exception_handler(AskError)
async def _ask_error_handler(request: Request, exc: AskError) -> JSONResponse:
    """Render a classified failure as the structured `{"error": {...}}` envelope
    (plan §3.2). Handled exceptions still pass back out through CORSMiddleware, so
    the cross-origin Flutter web client can read the body."""
    return exc.to_response()


def require_token(x_app_token: str | None = Header(default=None)) -> None:
    """Optional shared-secret gate (cross-cutting #2 — the money endpoint).

    Open when ASK_APP_TOKEN is unset (local dev). When set, callers must send a
    matching `X-App-Token` header. Real rate-limiting still belongs at the edge
    (Cloud Run / API gateway); this just keeps a public URL from being trivially
    abusable.
    """
    if settings.app_token and x_app_token != settings.app_token:
        raise AskError(
            401, "not_authorised", errors.NOT_AUTHORISED_MSG, retriable=False
        )


@app.get("/")
def root() -> dict:
    return {
        "service": "wisdom-ask",
        "mode": "stub" if settings.stub else "live",
        "see": "POST /ask",
    }


@app.get("/health")
def health() -> dict:
    return {
        "status": "ok",
        "mode": "stub" if settings.stub else "live",
        "model": None if settings.stub else settings.model,
        "models": None if settings.stub else list(settings.models),
        "store_configured": bool(settings.store),
    }


@app.post("/ask", response_model=AskResponse)
def ask(req: AskRequest, _: None = Depends(require_token)) -> AskResponse:
    if not req.question.strip():
        # Client-prevented (send is disabled on empty input); a 400 here is a
        # belt-and-braces guard the correct client never trips.
        raise AskError(400, "bad_request", errors.BAD_REQUEST_MSG, retriable=False)

    if settings.stub:
        from .stub import canned_answer

        return canned_answer(req.question)

    # Live mode — import lazily so stub deployments don't need google-genai.
    try:
        from . import pipeline

        return pipeline.answer(settings, req)
    except AskError:
        # Already classified inside the pipeline (e.g. the empty-answer guard) —
        # re-raise untouched so the handler renders its envelope as-is.
        raise
    except RuntimeError as exc:
        # Config problems (e.g. ASK_STORE unset) → 503: the service isn't ready.
        log.warning("ask not ready: %s", exc)
        raise AskError(
            503, "service_unavailable", errors.SERVICE_BUSY_MSG, retriable=True
        ) from exc
    except Exception as exc:  # noqa: BLE001 — classify upstream failures
        # Log the FULL traceback to the server console (never to the client —
        # Finding #6). Without this line, converting to an envelope would leave
        # the console showing only the bare status; the real cause (SDK error,
        # bad response, etc.) would be invisible. Then map to a safe status.
        log.exception("ask failed for question=%r", req.question)
        raise errors.classify_upstream(exc) from exc
