"""Environment-driven configuration (12-factor).

Everything the service needs comes from env vars, so the same image runs locally
in stub mode and on Cloud Run in live mode with no code change. See `.env.example`
for the full list.
"""
from __future__ import annotations

import os
from dataclasses import dataclass

# Free-tier + File-Search-capable generation models, grouped into the two tiers
# the app's Fast/Thinking switch chooses between (contracts.ResearchRequest.mode →
# Settings.models_for_mode). Each tier is its own fallback ladder, ordered
# highest-capability first; the pipeline falls through to the next rung on a
# transient error (429 rate limit / 503 high demand) instead of failing the
# request (free-tier 429s reset daily, and the popular flash tiers 503 under load).
# All are free-of-charge and File-Search-capable (verified 2026-06-28; the model
# set re-confirmed against ai.google.dev/gemini-api/docs/models on 2026-07-14).
#
#   FAST     — flash-lite tier: low latency, most generous free quota. Quick
#              lookups; the default when no mode is sent, and the tier the query
#              rewrite always uses (rewriting is cheap and mode-independent).
#   THINKING — full-flash tier: stronger reasoning, tighter/throttled quota.
#              Complex questions where a better answer is worth the extra wait.
#
# Each tier can be replaced wholesale from the environment via RESEARCH_FAST_MODELS
# / RESEARCH_THINKING_MODELS (CSV, highest priority first) — resolved ONCE in
# load_settings() and frozen onto Settings. They are kept per-tier on purpose: a
# single global pin can't express two tiers, so the old RESEARCH_MODEL /
# RESEARCH_MODELS overrides were dropped — front-pinning the fast model onto the
# Thinking ladder made Thinking silently answer with the fast model, defeating the
# switch.
#
# Excluded on purpose: gemini-3.1-pro (File Search ✔ but paid-only) and
# gemini-2.5-pro (free Standard quota too small to be a useful fallback).
#
# NOTE (2026-06-28): in FAST, gemini-3.1-flash-lite is fast (~7s) and reliable;
# in THINKING, gemini-3.5-flash gives the best answers but has been throttled
# (429) / 503'd and slow (~45s) — hence its fall-through rungs.

# FAST tier — flash-lite models, highest capability first.
FAST_MODELS = (
    "gemini-3.1-flash-lite",   # Gemini 3.1 Flash-Lite — newest lite, ~7s, most generous free quota
    "gemini-2.5-flash-lite",   # Gemini 2.5 Flash-Lite — older lite, final safety net
)

# THINKING tier — full flash models, highest capability first.
THINKING_MODELS = (
    "gemini-3.5-flash",        # Gemini 3.5 Flash — most intelligent free flash (GA); slower / more throttled
    "gemini-3-flash-preview",  # Gemini 3 Flash — Gemini-3-gen full flash (preview, free); AI Studio labels it "Gemini 3 Flash"
    "gemini-2.5-flash",        # Gemini 2.5 Flash — older full flash, safety net
)

# --- THINKING-tier reasoning cap (applied by pipeline._thinking_config) --------
#
# WHAT "THINKING" IS: before writing the answer the user sees, these models produce
# a private scratchpad — working the question through step by step. It is never
# returned to us, but it costs real time. The two settings below cap how much of it
# the model is allowed to do.
#
# They budget DELIBERATION, NOT CAPABILITY. "LOW" still runs the full
# gemini-3.5-flash; it just stops chewing sooner. The names read like quality grades
# ("LOW" sounds like a lesser model) and invite exactly that misreading — they are
# a stopwatch, not a tier.
#
# TWO SETTINGS, because the tier spans two model generations and the dial changed:
#   gemini-3.x  → thinking_level  (MINIMAL | LOW | MEDIUM | HIGH)
#   gemini-2.5  → thinking_budget (tokens; 0 = no thinking, -1 = uncapped)
# Sending the wrong one is a 400, which fails fast by design (see _is_retryable) and
# would take the whole tier down rather than degrade — hence the explicit
# per-generation mapping in _thinking_config instead of one setting for all rungs.
# In practice only thinking_level fires: gemini-2.5-flash is the THIRD rung, reached
# only when both Gemini 3 models are down.
#
# FAST MODE HAS NO EQUIVALENT and needs none. _generate applies these only when
# mode="thinking", so a Fast question never sends a thinking setting at all and
# flash-lite runs on its own default. (Flash-lite *can* think; Google just defaults
# it off. We simply never touch it — part of why Fast answers in ~9s.)
#
# WHY CAP AT ALL: uncapped, gemini-3.5-flash measured 289s — longer than the client
# is willing to wait, so the answer was binned and the quota spent regardless. LOW
# brought it to 170s.
#
# TUNING: LOW (~170s) is the working value; uncapped measured 289s. Keep any value
# under the client ceiling in research_remote_datasource._timeoutFor, or answers get
# discarded after we have already paid for them. Set either to None to lift the cap.
#
# MEDIUM has NEVER been measured. The 2026-07-16 attempt looked slow and was rolled
# back, but the log showed both runs 503'd off BOTH Gemini 3 rungs and were answered
# by gemini-2.5-flash — which takes thinking_budget, not thinking_level. No MEDIUM
# answer was ever generated; the slowness was the 503s (one rung took 369.7s just to
# refuse). Lesson: ALWAYS check which rung answered before attributing a timing.
# Retry when the free tier is calm.
THINKING_LEVEL: str | None = "LOW"
THINKING_BUDGET_TOKENS: int | None = 4096


# --- Per-rung request ceiling -------------------------------------------------
#
# How long ONE model gets before we abandon it and try the next rung.
#
# Why at all: a refusal can take far longer than an answer. Measured 2026-07-16 in a
# free-tier 503 storm — gemini-3-flash-preview spent 369.7s just to say "no", while
# the rung that then answered took 6.5s. Almost the entire 380s request was spent
# waiting for models to decline. Unset, the SDK sends timeout=None and httpx waits
# forever, so a wedged rung hangs the request until the CLIENT gives up.
#
# Why not lower: a slow rung that will SUCCEED is indistinguishable from one that
# will refuse, until it resolves. Observed successes (6.5 / 7.2 / 169.9 / 289.4s) and
# refusals (4.0 / 74.3 / 74.9 / 369.7s) overlap, so no value cleanly separates them.
# Under ~170s this would kill gemini-3.5-flash's legitimate answer every time and
# silently demote every Thinking question to the bottom rung — deleting the tier the
# switch exists to offer.
#
# COUPLED TO THINKING_LEVEL: must stay above the slowest legitimate answer. LOW
# answers in ~170s (fits); uncapped measured 289.4s (would NOT — raise this if you
# lift the cap). The worst case is this x the rung count, so also keep it sane against
# the client ceiling in research_remote_datasource._timeoutFor.
RUNG_TIMEOUT_SECONDS = 210


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
    # box; flip RESEARCH_STUB=0 (plus key + store) for real answers.
    stub: bool

    # --- Gemini (live mode) ------------------------------------------
    api_key: str | None
    store: str | None          # File Search store resource name (from ingest)
    fast_models: tuple[str, ...]      # FAST tier ladder; also the query-rewrite ladder
    thinking_models: tuple[str, ...]  # THINKING tier ladder
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
        """Primary answer model — the FAST tier's top rung (the default path and
        the rewrite lead). Back-compat alias for /health etc."""
        return self.fast_models[0]

    def models_for_mode(self, mode: str) -> tuple[str, ...]:
        """The answer ladder for the app's Fast/Thinking switch: `thinking` → the
        full-flash tier, anything else → the fast flash-lite tier. Resolved once
        at load time and frozen here, so a request never re-reads the environment
        (and /health reports exactly what questions run)."""
        return self.thinking_models if mode == "thinking" else self.fast_models


def _tier(env_name: str, default: tuple[str, ...]) -> tuple[str, ...]:
    """A model tier from the environment (CSV, highest priority first) or the
    built-in default. Per-tier on purpose, so the Fast/Thinking switch always
    routes to two distinct ladders (a single global pin can't — see FAST_MODELS)."""
    override = _csv(env_name)
    return tuple(override) if override else default


def load_settings() -> Settings:
    fast_models = _tier("RESEARCH_FAST_MODELS", FAST_MODELS)
    thinking_models = _tier("RESEARCH_THINKING_MODELS", THINKING_MODELS)
    return Settings(
        stub=_bool("RESEARCH_STUB", default=True),
        api_key=os.environ.get("GEMINI_API_KEY") or None,
        store=os.environ.get("RESEARCH_STORE") or None,
        fast_models=fast_models,
        thinking_models=thinking_models,
        # Query rewrite stays on the fast tier's primary (cheap, mode-independent);
        # override just that step with RESEARCH_REWRITE_MODEL.
        rewrite_model=os.environ.get("RESEARCH_REWRITE_MODEL") or fast_models[0],
        uid_manifest=os.environ.get("RESEARCH_UID_MANIFEST") or None,
        snippet_chars=int(os.environ.get("RESEARCH_SNIPPET_CHARS", "220")),
        cors_origins=_csv("RESEARCH_CORS_ORIGINS", "*") or ["*"],
        app_token=os.environ.get("RESEARCH_APP_TOKEN") or None,
        port=int(os.environ.get("PORT", "8081")),
        bilara_dir=os.environ.get("BILARA_DATA_DIR", "../bilara-data"),
    )
