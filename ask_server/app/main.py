"""FastAPI entry point for the /ask service.

  POST /ask    — the §7 contract (stub or live, per ASK_STUB).
  GET  /health — liveness + which mode/model is active.
  GET  /       — short human-readable banner.

Run locally (stub mode, no key needed):
    uvicorn app.main:app --reload --port 8081
"""
from __future__ import annotations

from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .config import Settings, load_settings
from .contracts import AskRequest, AskResponse

settings: Settings = load_settings()

app = FastAPI(title="Wisdom Project — /ask", version="0.1.0")

# Flutter web calls this cross-origin; native does too. Tighten ASK_CORS_ORIGINS
# in production (default "*" is for local dev).
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


def require_token(x_app_token: str | None = Header(default=None)) -> None:
    """Optional shared-secret gate (cross-cutting #2 — the money endpoint).

    Open when ASK_APP_TOKEN is unset (local dev). When set, callers must send a
    matching `X-App-Token` header. Real rate-limiting still belongs at the edge
    (Cloud Run / API gateway); this just keeps a public URL from being trivially
    abusable.
    """
    if settings.app_token and x_app_token != settings.app_token:
        raise HTTPException(status_code=401, detail="invalid or missing app token")


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
        "store_configured": bool(settings.store),
    }


@app.post("/ask", response_model=AskResponse)
def ask(req: AskRequest, _: None = Depends(require_token)) -> AskResponse:
    if not req.question.strip():
        raise HTTPException(status_code=400, detail="question must not be empty")

    if settings.stub:
        from .stub import canned_answer

        return canned_answer(req.question)

    # Live mode — import lazily so stub deployments don't need google-genai.
    try:
        from . import pipeline

        return pipeline.answer(settings, req)
    except RuntimeError as exc:
        # Config problems (e.g. no store) → 503: the service isn't ready.
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001 — surface upstream failures as 502
        raise HTTPException(
            status_code=502, detail=f"ask backend error: {exc}"
        ) from exc
