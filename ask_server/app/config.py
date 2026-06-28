"""Environment-driven configuration (12-factor).

Everything the service needs comes from env vars, so the same image runs locally
in stub mode and on Cloud Run in live mode with no code change. See `.env.example`
for the full list.
"""
from __future__ import annotations

import os
from dataclasses import dataclass

# Free-tier + File-Search-capable generation models, walked as a fallback ladder.
# The pipeline falls through to the next rung on a transient error (429 rate limit
# / 503 high demand): a throttled or busy rung falls through instead of failing the
# request (free-tier 429s reset daily, and the popular flash tiers 503 under load).
# All are free-of-charge and work with the File Search tool (verified 2026-06-28).
# Excluded on purpose: gemini-3.1-pro (File Search ✔ but paid-only) and
# gemini-2.5-pro (free Standard quota too small to be a useful fallback).
# Override the whole ladder with ASK_MODELS (CSV) or pin the primary with ASK_MODEL.
#
# NOTE (2026-06-28): gemini-3.1-flash-lite leads FOR NOW — it's fast (~7s) and
# reliable, whereas gemini-3.5-flash has been heavily throttled (429) / 503'd and
# slow (~45s). The heavier flash models trail as fallback. Revisit once the 3.5
# behaviour is understood — those rungs give better answers when available.
DEFAULT_MODELS = (
    "gemini-3.1-flash-lite",   # fast, reliable, generous free quota — default for now
    "gemini-3.5-flash",        # most capable free flash (slow / often throttled)
    "gemini-3-flash-preview",  # Gemini 3 Flash
    "gemini-2.5-flash",        # older full flash
    "gemini-2.5-flash-lite",   # final safety net
)


def _bool(name: str, default: bool = False) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def _csv(name: str, default: str = "") -> list[str]:
    raw = os.environ.get(name, default)
    return [part.strip() for part in raw.split(",") if part.strip()]


@dataclass(frozen=True)
class Settings:
    # --- Mode ---------------------------------------------------------
    # Stub mode returns canned answers and needs neither an API key nor the
    # google-genai package. It is the default so a fresh clone runs out of the
    # box; flip ASK_STUB=0 (plus key + store) for real answers.
    stub: bool

    # --- Gemini (live mode) ------------------------------------------
    api_key: str | None
    store: str | None          # File Search store resource name (from ingest)
    models: tuple[str, ...]    # generation fallback ladder; models[0] is primary
    rewrite_model: str         # (optionally cheaper) model for query rewrite
    uid_manifest: str | None   # optional known-uid list, drives the linkifier
    snippet_chars: int         # max length of each Sources snippet (window slice)

    # --- Service ------------------------------------------------------
    cors_origins: list[str]    # Flutter web calls this cross-origin
    app_token: str | None      # optional shared secret (X-App-Token gate)
    port: int

    # --- Ingest -------------------------------------------------------
    bilara_dir: str            # local checkout of bilara-data

    @property
    def live(self) -> bool:
        return not self.stub

    @property
    def model(self) -> str:
        """Primary (top-of-ladder) model — back-compat alias for /health etc."""
        return self.models[0]


def _model_ladder() -> tuple[str, ...]:
    """The generation ladder: ASK_MODELS verbatim, else DEFAULT_MODELS with an
    optional ASK_MODEL pinned to the front (so a single-model override keeps its
    fallback rungs)."""
    explicit = _csv("ASK_MODELS")
    if explicit:
        return tuple(explicit)
    primary = os.environ.get("ASK_MODEL")
    base = list(DEFAULT_MODELS)
    if primary:
        base = [primary] + [m for m in base if m != primary]
    return tuple(base)


def load_settings() -> Settings:
    models = _model_ladder()
    return Settings(
        stub=_bool("ASK_STUB", default=True),
        api_key=os.environ.get("GEMINI_API_KEY") or None,
        store=os.environ.get("ASK_STORE") or None,
        models=models,
        rewrite_model=os.environ.get("ASK_REWRITE_MODEL") or models[0],
        uid_manifest=os.environ.get("ASK_UID_MANIFEST") or None,
        snippet_chars=int(os.environ.get("ASK_SNIPPET_CHARS", "220")),
        cors_origins=_csv("ASK_CORS_ORIGINS", "*") or ["*"],
        app_token=os.environ.get("ASK_APP_TOKEN") or None,
        port=int(os.environ.get("PORT", "8081")),
        bilara_dir=os.environ.get("BILARA_DATA_DIR", "../bilara-data"),
    )
