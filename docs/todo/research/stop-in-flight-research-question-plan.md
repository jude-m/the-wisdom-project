# Stop an In-Flight Research Question — Plan

> **Status: OPEN (2026-07-22). Client-only feature; no server change.** Lets the
> user halt a question that's still in flight and drop it back into the composer
> to edit/rephrase. This is a **UX** feature ("let me move on / fix my wording"),
> **not** a cost feature — see the two facts below before assuming otherwise.

## Decision

Build **Option A — "Stop & edit"** (client-only abandon). Frame the control as
**Stop**, not "cancel to save quota." Defer **Option B** (true server-side
cancellation); it's ~4× the work across two languages for a payoff that may not
exist.

## Two facts worth not re-deriving

- **The cost is committed the instant Gemini is called.** A client that stops
  waiting does not un-spend the quota. Same fact the datasource already leans on
  (`research_remote_datasource.dart:33`, "an answer we've paid for is worth
  waiting for") and that `next_gen_research_server.md` records (the 289s call the
  app abandoned at 120s still moved RPD 3→4). So **Stop does not reclaim quota.**
- **There's only a real window in Thinking mode.** Fast ≈ 10s (`DEADLINE_FAST_MS`
  55s cap); Thinking runs minutes (289s measured, `DEADLINE_THINKING_MS` 290s cap
  — `config.ts`). In Fast the request is usually already at/through Gemini before
  a human reacts, so Stop mostly just skips the last second of a wait. The feature
  earns its keep in Thinking, where the user has minutes to realize they phrased
  it wrong.

## Why not Option B (server cancel) now

Aborting the upstream fetch requires: a cancellable client (swap `package:http`
for `dio`/CancelToken or a fetch+`AbortSignal` client — `package:http` can't
cancel one request, only close the whole client), then threading
`request.signal` through Hono → `answer()` → `callWithLadder` → `generateContent`
(currently the only `AbortSignal` is `AbortSignal.timeout()` at `gemini.ts:52`).
**Even done perfectly, Gemini may finish and bill a generation already underway.**
Hard work, uncertain benefit. Revisit only under real quota pressure and after
confirming Google actually stops billing on abort.

## The core problem (not the button)

`package:http` has **no per-request cancel**. The `Future` from
`_repository.research(...)` stays alive and *will* resolve later — up to 5 min in
Thinking. So the real work is making the resolution harmless after a Stop:
`_run` must know its result was abandoned and **no-op** instead of folding a late
answer into the transcript and flipping `isLoading` back on.

This extends a guard `_run` already has: the "user opened another chat while the
answer was in flight" branch (`research_provider.dart:192`). Explicit Stop is the
same problem with the user staying in the same chat.

## Implementation

All changes are in **`research_provider.dart`** (`ResearchChatNotifier`) and
**`research_chat_view.dart`**, plus two ARB keys. No server, no datasource, no
`ApiClient` change.

### 1. Cancellation token in `ResearchChatNotifier`
Add a monotonic run counter (or a per-run token object):

```dart
int _runToken = 0; // bumped on every send/retry AND on stop()
```

- `_run` captures `final token = ++_runToken;` at entry (before the `await`).
- After `await _repository.research(...)` resolves, bail if stale:
  `if (token != _runToken) return;` — placed **before** both the cross-session
  fold and the live-state fold. A stopped (or superseded) answer then silently
  drops: no transcript write, no `isLoading` flip, no persist.
- Keep the existing `_pendingSessions.remove(sessionId)` cleanup, and also remove
  the session in `stop()` so a reopened chat shows no phantom "Thinking…" row.

### 2. `stop()` method
```dart
/// Halt the in-flight question and return it to the composer to edit.
/// Does NOT reclaim server quota (see plan). No-op when not loading.
void stop() {
  if (!state.isLoading) return;
  _runToken++;                       // orphan the pending _run
  final sessionId = state.sessionId;
  if (sessionId != null) _pendingSessions.remove(sessionId);
  // Drop the unanswered user turn so an edited resend REPLACES it
  // instead of appending a 2nd turn (both would count vs maxUserTurns=5).
  final trimmed = state.messages.isNotEmpty && state.messages.last.isUser
      ? state.messages.sublist(0, state.messages.length - 1)
      : state.messages;
  state = state.copyWith(
    messages: trimmed,
    isLoading: false,
    error: null,
    errorType: null,
  );
  _persistOrDropEmpty(sessionId); // re-persist trimmed transcript, or delete if now empty
}
```

- **Re-persist the trimmed transcript.** `send()` persisted the question up front
  (`research_provider.dart:141`); after trimming we must overwrite storage so a
  reopen doesn't resurrect the abandoned turn. If trimming empties a brand-new
  chat (its only turn was the stopped question), delete it from history so it
  doesn't linger in Recent as an empty/titleless entry — mirror the
  `stored.isEmpty` reasoning already in `_run`.

### 3. Restore the question to the composer (the "edit" half)
The view already does exactly this for `cannotAnswer`
(`research_chat_view.dart:98-105`): on the right transition, if the field is
empty, refill it from the last user turn. Since Stop *removes* the last turn,
capture its text in `stop()` and surface it for the view to repopulate — simplest
is to have the view listen for the loading→idle transition it caused and read the
text Stop stashes (e.g. a transient `lastStoppedText` on state, cleared on next
send), reusing the "only fill an empty field" rule so it never clobbers typing.

### 4. Swap send ⇄ stop in the composer
In `research_chat_view.dart`, the trailing `IconButton.filled`
(`:286`) currently just disables while `isLoading`. Replace with a conditional:

```dart
state.isLoading
  ? IconButton.filled(
      onPressed: () => ref.read(researchChatProvider.notifier).stop(),
      icon: const Icon(Icons.stop),
      tooltip: l10n.researchStop,
    )
  : IconButton.filled(
      onPressed: _send,
      icon: const Icon(Icons.send),
      tooltip: l10n.researchSend,
    )
```

Standard chat-composer pattern (Claude/ChatGPT). The `_BusyRow` spinner stays.

### 5. ARB keys
Add to `app_en.arb` + `app_si.arb`: `researchStop` ("Stop" / Sinhala), and if
used, a short toast/label for "Question returned for editing." Keep "AI" out of
labels per the feature's naming rule.

## Edge cases to get right

- **Stop then reopen another chat, then the orphaned answer lands.** Covered:
  `_runToken` mismatch drops it before the cross-session branch even runs.
- **Stop during `retry()`.** `retry()` shares `_run`, so the same token guard
  applies; `stop()` must handle "last message is the unanswered question" without
  double-trimming.
- **Turn cap.** Trimming the stopped turn keeps `userTurnCount` honest so an edited
  resend doesn't burn a turn twice. Verify against `maxUserTurns = 5`.
- **Fast mode double-tap.** In Fast the answer may arrive in the same frame the
  user taps Stop. Token guard makes whichever loses a clean no-op; no torn state.
- **Reopen a chat with a still-pending answer** (`_pendingSessions`): unaffected —
  Stop only runs for the live chat and clears its own pending entry.

## Out of scope

- Server cancellation / disconnect detection (Option B).
- Any change to `ApiClient`, timeouts, or the `/research` contract.
- Reclaiming quota — explicitly not a goal; don't message it as such.

## Effort / risk

~½ day, low risk. The button + ARB is trivial; the substance is the token guard
in `_run` and the trim-and-repersist in `stop()`. All contained in two files.

## Tests (for the test agent — not written here)

Per project rule, tests aren't generated with this plan. When asked, cover:
`stop()` no-ops when idle; token guard drops a late answer (no transcript growth,
`isLoading` false); trim removes exactly the last user turn and re-persists;
empty brand-new chat is deleted from history on stop; edited resend after stop
produces one user turn, not two; Stop during `retry()`.
