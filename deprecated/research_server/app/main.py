"""FastAPI entry point for the /research service.

  POST /research    — the §7 contract (stub or live, per RESEARCH_STUB).
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
from .contracts import ResearchRequest, ResearchResponse
from .errors import ResearchError

settings: Settings = load_settings()

# uvicorn configures only its OWN loggers, never the root one, so our "research.*"
# records propagate to a root with no handlers and land on logging.lastResort —
# which is WARNING-level. That is why the ladder's fall-through warnings reached
# the console while everything milder was dropped on the floor: an INFO line was
# invisible. Configure the root here so the pipeline's START / per-rung / DONE
# lines actually print (and reach Cloud Run's stdout, which captures the stream).
# basicConfig is a no-op if a handler is already installed, so a host that brings
# its own logging setup still wins.
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-7s %(message)s",
    datefmt="%H:%M:%S",
)

# Root-level INFO also switches on every third-party library's INFO stream. httpx —
# which the Gemini SDK calls through — narrates one "HTTP Request: <long google
# url>" line per model call, restating the per-rung line next to it with less
# information. Keep the libraries at WARNING so the research.* narrative stays the
# readable thing in the console; a genuine transport failure still gets through.
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)
# google_genai repeats "AFC is enabled with max remote calls: 10" on every single
# call. Automatic function calling is irrelevant here — file_search runs server-side
# at Google, not as a local Python function — so the line is pure noise between the
# per-rung lines it interleaves with.
logging.getLogger("google_genai").setLevel(logging.WARNING)

# "research" logger — like pipeline's "research.pipeline", it propagates to the root
# handler configured above, so anything logged here shows up in the server terminal.
log = logging.getLogger("research")

app = FastAPI(title="Wisdom Project — /research", version="0.1.0")

# Flutter web calls this cross-origin; native does too. Tighten RESEARCH_CORS_ORIGINS
# in production (default "*" is for local dev).
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


@app.exception_handler(ResearchError)
async def _research_error_handler(request: Request, exc: ResearchError) -> JSONResponse:
    """Render a classified failure as the structured `{"error": {...}}` envelope
    (plan §3.2). Handled exceptions still pass back out through CORSMiddleware, so
    the cross-origin Flutter web client can read the body."""
    return exc.to_response()


def require_token(x_app_token: str | None = Header(default=None)) -> None:
    """Optional shared-secret gate (cross-cutting #2 — the money endpoint).

    Open when RESEARCH_APP_TOKEN is unset (local dev). When set, callers must send a
    matching `X-App-Token` header. Real rate-limiting still belongs at the edge
    (Cloud Run / API gateway); this just keeps a public URL from being trivially
    abusable.
    """
    if settings.app_token and x_app_token != settings.app_token:
        raise ResearchError(
            401, "not_authorised", errors.NOT_AUTHORISED_MSG, retriable=False
        )


@app.get("/")
def root() -> dict:
    return {
        "service": "wisdom-research",
        "mode": "stub" if settings.stub else "live",
        "see": "POST /research",
    }


@app.get("/health")
def health() -> dict:
    return {
        "status": "ok",
        "mode": "stub" if settings.stub else "live",
        # The two tiers the Fast/Thinking switch routes between — exactly what a
        # request runs. `model` = the fast primary (the default/rewrite lead).
        "model": None if settings.stub else settings.model,
        "fast_models": None if settings.stub else list(settings.fast_models),
        "thinking_models": None if settings.stub else list(settings.thinking_models),
        "store_configured": bool(settings.store),
    }


@app.post("/research", response_model=ResearchResponse)
def research(req: ResearchRequest, _: None = Depends(require_token)) -> ResearchResponse:
    if not req.question.strip():
        # Client-prevented (send is disabled on empty input); a 400 here is a
        # belt-and-braces guard the correct client never trips.
        raise ResearchError(400, "bad_request", errors.BAD_REQUEST_MSG, retriable=False)

    if settings.stub:
        from .stub import canned_answer

        return canned_answer(req.question)

    # Live mode — import lazily so stub deployments don't need google-genai.
    try:
        from . import pipeline

        return pipeline.answer(settings, req)
    except ResearchError:
        # Already classified inside the pipeline (e.g. the empty-answer guard) —
        # re-raise untouched so the handler renders its envelope as-is.
        raise
    except RuntimeError as exc:
        # Config problems (e.g. RESEARCH_STORE unset) → 503: the service isn't ready.
        log.warning("research not ready: %s", exc)
        raise ResearchError(
            503, "service_unavailable", errors.SERVICE_BUSY_MSG, retriable=True
        ) from exc
    except Exception as exc:  # noqa: BLE001 — classify upstream failures
        # Log the FULL traceback to the server console (never to the client —
        # Finding #6). Without this line, converting to an envelope would leave
        # the console showing only the bare status; the real cause (SDK error,
        # bad response, etc.) would be invisible. Then map to a safe status.
        log.exception("research failed for question=%r", req.question)
        raise errors.classify_upstream(exc) from exc
