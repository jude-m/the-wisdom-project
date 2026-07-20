# Research Section — Fast / Thinking Mode Switcher (Stage 3)

> **Status: IMPLEMENTED 2026-07-15; hardened after code review 2026-07-16.**
> Backend (contract `mode`, `Settings.models_for_mode`, pipeline routing) +
> frontend (`ResearchMode` enum, persisted `researchModeProvider`,
> `ResearchModeSelector` in both app bars, mode-aware busy label) all landed and
> analyze clean.
>
> **Code-review fixes (2026-07-16):** (1) **critical** — the old global
> `RESEARCH_MODEL`/`RESEARCH_MODELS` overrides front-pinned onto BOTH tiers, so an
> operator's fast pin (present in `.env`) leaked into the Thinking ladder and
> Thinking silently answered with the fast model. Fixed: tiers are now the single
> source of truth, resolved once in `load_settings()` and frozen onto `Settings`;
> `models_for_mode` is a `Settings` method (no per-request env reads); the global
> pins are replaced by per-tier `RESEARCH_FAST_MODELS`/`RESEARCH_THINKING_MODELS`,
> and the harmful `.env` line removed. (2) De-duplicated the app-bar action + folded
> the four `mode == thinking ? …` checks into an exhaustive-`switch`
> `ResearchModeUi` extension (a 3rd mode now fails to compile). (3) The busy label
> now reads a send-time-pinned `ResearchChatState.inFlightMode` (see below).
> Outstanding: Sinhala strings are best-effort pending confirmation against
> tipitaka.lk terms; tests to be written by the test-writer agent.

## Context

Stage 2 (`research-multi-chat-ui-plan.md`) is mid-build: the Research
section is becoming a full multi-chat UI (left "Recent" panel, transcript,
citation chips, 5-turn cap). This stage adds a **mode switch** on top of it —
a Claude/Gemini-style selector that lets the user choose how much model muscle
each question gets, so the free Gemini quota is spent deliberately: cheap/fast
for lookups, heavier/slower for hard questions.

The two tiers were streamlined and confirmed online on 2026-07-14 and now live
in `research_server/app/config.py` as two ordered fallback ladders.

## Model tiers (done — `config.py`)

Each tier is its own fallback ladder, highest capability first; the pipeline
falls through a rung on a transient 429/503. All are free-tier and
File-Search-capable (re-confirmed against `ai.google.dev/gemini-api/docs/models`).

| Tier | Rung | Model ID | Why here |
|---|---|---|---|
| **FAST** | 1 | `gemini-3.1-flash-lite` | Newest lite, ~7s, most generous free quota — default primary |
| | 2 | `gemini-2.5-flash-lite` | Older lite, safety net |
| **THINKING** | 1 | `gemini-3.5-flash` | Most intelligent free flash (GA); slower / throttled |
| | 2 | `gemini-3-flash-preview` | "Gemini 3 Flash" — Gemini-3-gen full flash (preview, free) |
| | 3 | `gemini-2.5-flash` | Older full flash, safety net |

**Note resolution (from the old config comments):** `gemini-3-flash-preview`
and the "add Gemini 3 Flash" note were the **same model**. It *does* exist and
is free — AI Studio just labels it "Gemini 3 Flash" (display name) while the API
ID is `gemini-3-flash-preview`. So it stays, correctly placed as THINKING rung 2.
Nothing was removed.

## Backend changes (small, back-compat)

Mode defaults to `fast`, so an old client that sends no `mode` keeps today's
behaviour exactly.

- **`contracts.py`** — add to `ResearchRequest`:
  `mode: Literal["fast", "thinking"] = "fast"`.
- **`config.py`** — add `models_for_mode(mode) -> tuple[str, ...]` returning
  `FAST_MODELS` / `THINKING_MODELS` (optionally overridable via
  `RESEARCH_FAST_MODELS` / `RESEARCH_THINKING_MODELS` env, mirroring the
  existing `RESEARCH_MODELS` pattern; defaults to the tuples).
- **`pipeline.py`** — thread the request's `mode` into `_generate`, which walks
  `models_for_mode(mode)` instead of `cfg.models`. **The query-rewrite step
  stays on the cheap fast model regardless of mode** — rewriting doesn't need
  the thinking tier, which saves the expensive quota for the actual answer.

## Frontend changes

- **Domain** — `ResearchMode { fast, thinking }` enum (with wire values
  `'fast'`/`'thinking'`) in `lib/domain/entities/research/`.
- **Datasource / repository** — `research(...)` gains a `mode` param, added to
  the POST body (`ResearchRemoteDataSourceImpl`, `ResearchRepository`,
  `ResearchRepositoryImpl`).
- **Mode is global + persisted** (not per-chat) — one `researchModeProvider`
  (Notifier) reads/writes a `research_mode` key via the existing `KeyValueStore`,
  defaulting to `fast`. This matches Google's app-level selector and keeps the
  multi-chat storage scheme untouched. `ResearchChatNotifier.send()` reads the
  current mode and passes it to the repo. (Per-chat mode is a later option —
  it would live in the transcript; out of scope now.)
- **UI — `ResearchModeSelector`** — a chip button (current mode + chevron) in
  the Research header/app bar (top-right, like the mockup), opening a menu of
  the modes with a one-line subtitle and a check on the active one. Reuses the
  section's existing app bar being built in Stage 2.
- **Localization (EN + SI)** — mode chip/menu: `researchModeFast` ("Fast"),
  `researchModeFastHint` ("Fastest answers"), `researchModeThinking`
  ("Thinking"), `researchModeThinkingHint` ("Deeper reasoning"). In-flight
  labels are refactored too — see "In-flight label" below. Sinhala is mined
  from the settled tipitaka.lk terms, not guessed.

## Fit with the multi-chat build (Stage 2, in flight)

- The switcher is **additive** and its backend is **independently safe** (mode
  defaults to `fast`) — the contract + pipeline + config changes can land now
  without waiting on the multi-chat UI.
- The **UI switcher** slots into the same Research header/app bar that Stage 2
  is creating, so it lands with or just after the multi-chat view — not before
  (it needs that header to exist).
- Mode being global means it does **not** touch the `research_chat_index` /
  `research_chat_<id>` storage scheme — no migration, no new per-chat field.

## Switcher presentation — DECIDED (2026-07-14)

**Friendly labels** ("Fast" / "Thinking"), each with a one-line hint — no
Gemini model IDs surfaced. The per-tier fallback ladder stays an internal
detail. (Chosen over the "named models" variant: model IDs are jargon for a
general-audience dhamma app.)

Menu shape (both modes shown, check on the active one):

```
Header chip:  [ ⚡ Fast ▾ ]

  ✓  ⚡ Fast          Fastest answers
     🧠 Thinking      Deeper reasoning
```

## In-flight ("busy") label — mode-aware (refactor)

While an answer is in flight the transcript shows a spinner row. Today that's
one string — `researchThinking` = "Thinking…" (SI "සිතමින්…"), rendered by
`_ThinkingRow` (`research_chat_view.dart`). With a **Thinking mode** now, that
word is overloaded, so the label becomes mode-aware and the naming is
refactored to match (decided 2026-07-15):

- **Fast mode → "Answering…"**, **Thinking mode → "Thinking…"**. The differing
  word also quietly signals the longer wait in Thinking.
- Rename the key `researchThinking` → `researchBusyThinking` (value unchanged,
  "Thinking…" / "සිතමින්…") and add `researchBusyFast` = "Answering…" (SI
  candidate "පිළිතුරු දෙමින්…" — confirm against tipitaka.lk terms). Rename the
  widget `_ThinkingRow` → `_BusyRow`; it picks the key from the active mode.
- Blast radius is contained: the key has one call site
  (`research_chat_view.dart:289`) plus the ARB pair and the generated l10n
  (rebuilt by `flutter gen-l10n`); the widget is private to that file. No tests
  reference either.
- The label reads a send-time-pinned mode, NOT the live global mode: `send()`/
  `retry()` record the chosen mode on `ResearchChatState.inFlightMode` (and the
  `_pendingSessions` map, so a reopened in-flight chat labels correctly), and
  `_BusyRow` watches that. So flipping the switch mid-answer never relabels the
  request already running — matching how `send()` pins the mode it sends.
  (Revised from the original "it's cosmetic, don't pin" call after code review
  2026-07-16: the notifier already goes to trouble to pin the sent mode, so the
  label following the live mode was an inconsistency worth removing.)

## Verification

`build_runner` (enum/Freezed), `flutter gen-l10n`, `flutter analyze`; server
pytest for `models_for_mode` + contract back-compat (absent `mode` → fast);
manual on macOS: toggle mode, ask, confirm the chosen tier answered (server
log), and that the choice survives a restart. Tests written by the test-writer
agent per project rules.
