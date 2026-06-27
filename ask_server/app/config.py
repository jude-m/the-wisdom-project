"""Environment-driven configuration (12-factor).

Everything the service needs comes from env vars, so the same image runs locally
in stub mode and on Cloud Run in live mode with no code change. See `.env.example`
for the full list.
"""
from __future__ import annotations

import os
from dataclasses import dataclass


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
    model: str                 # Flash-class generation model
    rewrite_model: str         # (optionally cheaper) model for query rewrite
    uid_manifest: str | None   # optional known-uid list, drives the linkifier

    # --- Service ------------------------------------------------------
    cors_origins: list[str]    # Flutter web calls this cross-origin
    app_token: str | None      # optional shared secret (X-App-Token gate)
    port: int

    # --- Ingest -------------------------------------------------------
    bilara_dir: str            # local checkout of bilara-data

    @property
    def live(self) -> bool:
        return not self.stub


def load_settings() -> Settings:
    return Settings(
        stub=_bool("ASK_STUB", default=True),
        api_key=os.environ.get("GEMINI_API_KEY") or None,
        store=os.environ.get("ASK_STORE") or None,
        model=os.environ.get("ASK_MODEL", "gemini-2.5-flash"),
        rewrite_model=(
            os.environ.get("ASK_REWRITE_MODEL")
            or os.environ.get("ASK_MODEL", "gemini-2.5-flash")
        ),
        uid_manifest=os.environ.get("ASK_UID_MANIFEST") or None,
        cors_origins=_csv("ASK_CORS_ORIGINS", "*") or ["*"],
        app_token=os.environ.get("ASK_APP_TOKEN") or None,
        port=int(os.environ.get("PORT", "8081")),
        bilara_dir=os.environ.get("BILARA_DATA_DIR", "../bilara-data"),
    )
