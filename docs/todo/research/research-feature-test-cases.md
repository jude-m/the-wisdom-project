# Research Feature — Test Case Catalogue

**Date:** 2026-07-14 · **Branch:** `feat/ai-qa` (multi-chat UI + fixes for review findings #1–#14)
**Status:** No tests exist yet for any part of this feature (client or server). This document is the
single reference for writing them — each case says *what* to assert and *which level* it belongs to,
so nothing needs re-deriving from the code later.

**Guards column** = which code-review finding the case is a regression guard for (the 14 bugs fixed
2026-07-14). Those cases are the highest-value ones: the bug existed once, so it can come back.
Bugs caught in later reviews use a dated `rev <date>` tag instead of a `#N` finding number.

**Addendum 2026-07-25 — per-chat Fast/Thinking tier.** The mode is no longer a global, disk-persisted
setting; it now rides each chat (`ChatSummary.mode`). `researchModeProvider` is a transient in-memory
cursor seeded by the chat lifecycle (new chat → Fast, open chat → that chat's tier). New cases below
carry the `rev 07-25` tag; one guards a review bug where the background-answer save stamped the *live*
chat's tier onto a different chat's summary. There is deliberately **no** global-persistence case —
a fresh chat and an app restart both start on Fast by design.

**Priority:** P0 = must have before the feature is trusted · P1 = should have · P2 = nice to have.

---

## 1. Scope — what "the feature" is

| Layer | Files under test |
|---|---|
| Domain | `chat_message.dart`, `chat_summary.dart`, `research_answer.dart`, `citation.dart`, `chat_history_repository.dart` (interface) |
| Data | `chat_history_repository_impl.dart`, `research_repository_impl.dart`, `research_remote_datasource.dart`, `api_client.dart` (error mapping) |
| State | `research_chat_state.dart`, `research_provider.dart` (`ResearchChatNotifier`), `research_mode_provider.dart` (`ResearchModeNotifier`) |
| Widgets | `research_chat_view.dart`, `chat_history_panel.dart`, `research_answer_view.dart`, `citation_source_sheet.dart`, `research_error_messages.dart`, `research_mode_selector.dart` |
| Screen | `research_screen.dart` (responsive shell + nested `Navigator`) |
| Cross-feature | citation → `openTipitakaLinkProvider` → Reader section (deep-link chain) |
| Server | `research_server/` (Python — separate suite, §6) |

---

## 2. Which level for what — the rules used here

- **Unit** — anything that runs without a widget tree: entities, the history repository against
  `InMemoryKeyValueStore`, and **all `ResearchChatNotifier` logic** via a `ProviderContainer`.
  Every timing race lives here, because a `Completer`-based fake repository makes "answer still in
  flight" deterministic (see §3). Races are near-impossible to test reliably at widget/E2E level.
- **Widget** — anything that is about what the user *sees or touches* for a given state: rendering,
  gating of buttons, the input controller's lifecycle, responsive layout. State is injected via
  provider overrides; no real network, no real prefs.
- **E2E (integration_test, `-d macos`)** — only full journeys that cross feature boundaries or app
  restarts: the citation → Reader deep-link chain, persistence across restart, multi-chat lifecycle.
  Everything provable at a lower level stays at the lower level.

---

## 3. Shared test doubles & fixtures (build once, reuse everywhere)

- **`InMemoryKeyValueStore`** — exists: `test/helpers/fake_key_value_store.dart`. Mirrors production
  JSON semantics. Use for all repository unit tests; inspect `_store` contents via `getJsonList`.
- **`defaultTestOverrides()` / `pumpApp`** — exist: `test/helpers/pump_app.dart`. Already override
  `keyValueStoreProvider` with a fresh in-memory store.
- **`FakeResearchRepository`** — NEW, the key fixture. Implements `ResearchRepository`; each
  `research()` call pulls the next `Completer<Either<Failure, ResearchAnswer>>` from a queue and
  awaits it. The test decides *when* an answer arrives and *what* it is. Also records
  `(text, history)` per call for history-content assertions. Wire in with
  `researchRepositoryProvider.overrideWithValue(fake)`.
- **Delaying store decorator** — NEW, small: wraps `InMemoryKeyValueStore`, adds an awaited
  `Future.delayed`/`Completer` to `setJson`/`remove`. Needed only for the repository concurrency
  cases (U-REPO-7/8).
- **Answer fixtures** — one canned `ResearchAnswer` with: prose containing `**bold**`, `*italic*`,
  a `- ` bullet, one inline `[[cite:sn15.3]]` marker, and two citations (one matching the inline
  uid, one extra → exercises "Other sources"). Citation titles / sutta names in **Sinhala script**
  (e.g. `අනමතග්ග සංයුත්තය`), per project convention — Pali/Sinhala content is never romanized.
- **Resolver/reader overrides** (citation sheet + E2E): `suttaCentralRefResolverProvider` override
  returning a fixed uid→nodeKey map (`sn15.3` → the real nested BJT key); a recording fake for
  `openTipitakaLinkProvider` in widget tests.

**Do not test:** generated code (`*.freezed.dart`, `*.g.dart`, generated l10n), Freezed `copyWith`
mechanics, the ARB files themselves. **Do not** add `@visibleForTesting` shims or expose private
members for tests — test through the public surface; duplicate a literal in the test if needed
(project rule).

---

## 4. Unit level

### 4.1 Entities — `test/domain/entities/research/`

| ID | Scenario | Expect | Guards | Pri |
|---|---|---|---|---|
| U-ENT-1 | `ChatMessage.toHistoryJson()` | Only `role` + `content` keys — citations stripped from the wire format | — | P0 |
| U-ENT-2 | `ChatMessage` JSON round-trip with citations | Citations survive save/load (chips survive restart) | — | P0 |
| U-ENT-3 | `ChatSummary` JSON round-trip | `updatedAt` survives via ISO-8601; `id`/`title` intact | — | P1 |
| U-ENT-4 | `ChatSummary` round-trip carries `mode` | Both `fast` and `thinking` survive save/load (per-chat tier persists) | rev 07-25 | P0 |
| U-ENT-5 | `ChatSummary.fromJson` with **no `mode` key** (pre-feature chat) | Defaults to `ResearchMode.fast`, no throw — old saved chats read back as Fast | rev 07-25 | P0 |

### 4.2 `ChatHistoryRepositoryImpl` — `test/data/repositories/chat_history_repository_impl_test.dart`

All against `InMemoryKeyValueStore`. Keys: `research_chat_index_v1`, `research_chat_v1_<id>`.

| ID | Scenario | Expect | Guards | Pri |
|---|---|---|---|---|
| U-REPO-1 | `saveChat` new chat, then `getSummaries` | Entry present, newest first | — | P0 |
| U-REPO-2 | `saveChat` same id twice (updated title/time) | Upsert: one entry, moved to top, fields updated | — | P0 |
| U-REPO-3 | Save 26 chats | Index capped at 25; evicted chat's **transcript key also removed** (no orphan) | — | P0 |
| U-REPO-4 | `getMessages` round-trip | Full transcript incl. assistant citations | — | P0 |
| U-REPO-5 | `deleteChat` | Transcript key AND index entry gone | — | P0 |
| U-REPO-6 | Corrupted index JSON (seed store with garbage string) | `getSummaries` → `[]`, key cleared, no throw | — | P1 |
| U-REPO-7 | Corrupted transcript (valid JSON list, bad element shape) | `getMessages` → `[]` **and index entry removed** — no phantom "Recent" row | **#9** | P0 |
| U-REPO-8 | Two overlapping `saveChat` calls for two different new ids (delaying store, fire both unawaited, then await both) | Both index entries present — the serialized queue prevents lost writes | **#6** | P0 |
| U-REPO-9 | First queued action throws (make store throw once), then a second `saveChat` | Second save still succeeds — a failure doesn't wedge the queue | **#6** | P1 |

### 4.3 `ResearchChatState` — `test/presentation/providers/research_chat_state_test.dart`

| ID | Scenario | Expect | Guards | Pri |
|---|---|---|---|---|
| U-ST-1 | `userTurnCount` on mixed transcript | Counts only user turns | — | P1 |
| U-ST-2 | `isAtTurnLimit` | False at 4 user turns, true at 5 (`maxUserTurns`) | — | P0 |

### 4.4 `ResearchChatNotifier` — `test/presentation/providers/research_provider_test.dart`

The heart of the suite. `ProviderContainer` with `FakeResearchRepository` +
`InMemoryKeyValueStore`; read `container.read(researchChatProvider)` and the store to assert.
Every "while in flight" case = don't complete the fake's `Completer` until the test says so.

| ID | Scenario | Expect | Guards | Pri |
|---|---|---|---|---|
| U-NOT-1 | `send("q")` happy path | User turn appended immediately + `isLoading`; on completion answer appended, `isLoading` false; transcript persisted; summary title = first question | — | P0 |
| U-NOT-2 | `send` gates | Empty/whitespace text, `isLoading`, or at turn limit → no state change, **no repository call** | — | P0 |
| U-NOT-3 | Session id minted on first send only | Non-null after first send; unchanged after second turn | — | P0 |
| U-NOT-4 | Question persisted **before** answer arrives | While in flight, store already has the transcript ending in the user turn (crash-safety) | — | P1 |
| U-NOT-5 | Failure result | `errorType` set, `isLoading` false, answer NOT appended; stored transcript still ends with the question (errors never persisted) | — | P0 |
| U-NOT-6 | `retry()` after failure | Repository called again with same text; **no duplicate user turn**; success appends answer | — | P0 |
| U-NOT-7 | `retry()` no-ops | While loading, on empty transcript, or when last turn is assistant | — | P1 |
| U-NOT-8 | `newChat()` | State reset to blank; a never-sent chat leaves **zero** keys in the store | — | P0 |
| U-NOT-9 | `openChat(id)` | Transcript loaded from store; same-id call is a no-op | — | P0 |
| U-NOT-10 | Reopen a chat whose answer is in flight | `isLoading` true on the reopened state (send stays gated); answer folds into live transcript on arrival | **#2** | P0 |
| U-NOT-11 | Switch to another chat while answer in flight; then complete | Live state untouched; answer appended to the **original chat's stored transcript**; summary refreshed | **#4** | P0 |
| U-NOT-12 | `newChat()` while answer in flight; then complete | No crash; answer filed to the original chat in storage; fresh canvas stays empty | **#4** | P0 |
| U-NOT-13 | `newChat()`/`openChat` landing **during send's persist await** (complete a delaying store mid-send) | No RangeError; request carries the original chat's history; answer filed under original id | **#4** | P1 |
| U-NOT-14 | `deleteChat` of the in-flight chat; then complete with success | Answer discarded — chat NOT resurrected in index or store | **#1** | P0 |
| U-NOT-15 | Failure arriving for a switched-away chat | Dropped entirely: no state change, stored transcript unchanged (still ends with question) | — | P1 |
| U-NOT-16 | `deleteChat` active vs non-active | Active → canvas cleared (blank state); non-active → live state untouched; both remove from store | — | P0 |
| U-NOT-17 | History sent on the wire (fake records it) | Turn N's call carries exactly the turns *before* the in-flight question, in order | — | P0 |
| U-NOT-18 | 5th question completes | `isAtTurnLimit` true; 6th `send` refused (U-NOT-2 overlap — assert via repository call count) | — | P0 |

**Per-chat Fast/Thinking tier** (read `container.read(researchModeProvider)` for the header cursor and
the saved `ChatSummary.mode` from the store). The notifier drives the seeding, not the selector widget.

| ID | Scenario | Expect | Guards | Pri |
|---|---|---|---|---|
| U-NOT-19 | `send()` stamps the active tier | With `researchModeProvider` = thinking, after the answer lands the saved `ChatSummary.mode` == `thinking` (and the question-time persist already wrote it) | rev 07-25 | P0 |
| U-NOT-20 | `newChat()` resets the header tier | After `newChat()`, `researchModeProvider` == `fast` regardless of the prior tier (a new chat always starts on Fast) | rev 07-25 | P0 |
| U-NOT-21 | `openChat(summary)` restores the chat's tier | Opening a summary with `mode: thinking` sets `researchModeProvider` == `thinking`; a `fast` summary → `fast`. Same-id open is still a no-op (tier untouched) | rev 07-25 | P0 |
| U-NOT-22 | **Switch chats mid-answer — original summary keeps its own tier** | Send in A under Thinking (hold the Completer) → `openChat(B)` (Fast) → release A's answer → A's stored `ChatSummary.mode` is **still `thinking`**, NOT the live chat's `fast` (background save must use the request's tier, not `state.inFlightMode`) | rev 07-25 | P0 |
| U-NOT-23 | Tier pinned at send time, not re-read at save | Send under Fast (hold the Completer), flip `researchModeProvider` to Thinking mid-flight, release → saved `ChatSummary.mode` == `fast` (mirrors the backend-mode pinning) | rev 07-25 | P1 |

---

## 5. Widget level

All with `pumpApp` + provider overrides. To render a specific state without a real notifier,
override `researchChatProvider` with a stub notifier seeded with the state under test; for
interaction flows use the real notifier + `FakeResearchRepository`.

### 5.1 `ResearchChatView` — `test/presentation/widgets/research/research_chat_view_test.dart`

| ID | Scenario | Expect | Guards | Pri |
|---|---|---|---|---|
| W-CHAT-1 | Blank state | `StatusMessageView` with `researchEmptyState` text | — | P0 |
| W-CHAT-2 | Transcript rendering | User turn = right-aligned bubble; assistant turn = "RESEARCH" label + `ResearchAnswerView` | — | P0 |
| W-CHAT-3 | `isLoading` | Thinking row (spinner + `researchThinking`) at the end; send button disabled | — | P0 |
| W-CHAT-4 | Retriable error (`timeout`) | Error text + Retry button; tap → notifier.retry() called | — | P0 |
| W-CHAT-5 | Non-retriable error (`notAuthorised`) | Error text, **no** Retry button | — | P1 |
| W-CHAT-6 | Enter pressed while loading | Typed text **stays** in the field; no send fired | **#3** | P0 |
| W-CHAT-7 | `cannotAnswer` arrives | Question restored into the (empty) input; if input already has text, it is NOT clobbered | — | P0 |
| W-CHAT-8 | Session switch with a draft typed | Input cleared — draft can't leak into the next chat | **#8** | P0 |
| W-CHAT-9 | At turn limit (not loading) | Banner replaces input; "New chat" button in banner works | — | P0 |
| W-CHAT-10 | At turn limit while final answer in flight | Banner NOT shown yet (input row + disabled send + thinking row) | — | P1 |
| W-CHAT-11 | Reopened chat ending in an unanswered user turn (no live error) | Neutral `researchQuestionNotAnswered` notice + Retry — including when at the turn limit (renders above the banner) | **#7** | P0 |
| W-CHAT-12 | New answer appended | List scrolled to bottom (`position.maxScrollExtent`) | — | P2 |

### 5.2 `ChatHistoryPanel` — `test/presentation/widgets/research/chat_history_panel_test.dart`

| ID | Scenario | Expect | Guards | Pri |
|---|---|---|---|---|
| W-PANEL-1 | Summaries render | Titles newest first; active chat's tile shows selected styling | — | P0 |
| W-PANEL-2 | Tap a tile | `openChat` effect (transcript switches) + `onChatSelected` callback fired (drawer-close contract) | — | P0 |
| W-PANEL-3 | "New chat" button | Blank canvas + `onChatSelected` fired | — | P0 |
| W-PANEL-4 | Delete non-active chat | Removed from list; `onChatSelected` NOT fired | — | P1 |
| W-PANEL-5 | Delete the active chat | Canvas cleared; `onChatSelected` fired | — | P0 |
| W-PANEL-6 | No chats | `StatusMessageView` "No chats yet" hint | — | P1 |
| W-PANEL-7 | Relative time labels (fixed `updatedAt` values, asserted via tile subtitle — helper is private, don't expose it) | <1 min → "Just now"; minutes; hours; yesterday-evening <48 h → "Yesterday"; 2–6 days → "N days ago"; ≥7 days → short date | — | P1 |

### 5.3 `ResearchAnswerView` — `test/presentation/widgets/research/research_answer_view_test.dart`

Use the shared answer fixture (§3). Remember: bilingual content in Sinhala script.

| ID | Scenario | Expect | Guards | Pri |
|---|---|---|---|---|
| W-ANS-1 | Markdown subset | `**bold**`/`*italic*` styled; `- ` lines become bullet rows; blank lines split paragraphs; soft line breaks coalesce | — | P0 |
| W-ANS-2 | Inline `[[cite:uid]]` | Chip rendered with the citation's `ref`; marker text not visible | — | P0 |
| W-ANS-3 | Tap a chip | `CitationSourceSheet` opens (bottom sheet appears) | — | P0 |
| W-ANS-4 | Marker with unknown uid | Silently dropped — no chip, no crash, surrounding text intact | — | P1 |
| W-ANS-5 | Citations not named inline | Rendered once under "Other sources"; inline-cited uids NOT duplicated there | — | P1 |

### 5.4 `CitationSourceSheet` — `test/presentation/widgets/research/citation_source_sheet_test.dart`

Override `suttaCentralRefResolverProvider` (fixed uid→nodeKey map) and, where needed,
`openTipitakaLinkProvider` with a recording fake.

| ID | Scenario | Expect | Guards | Pri |
|---|---|---|---|---|
| W-SHEET-1 | Unresolved uid | English snippet shown; "not linked yet" note; NO action buttons | — | P0 |
| W-SHEET-2 | Resolved uid | "Open in reader" + "Copy link" buttons present | — | P0 |
| W-SHEET-3 | Snippet `**match**` markers | Matched terms bold, markers not visible | — | P1 |
| W-SHEET-4 | Copy link | Clipboard gets the built URL; button flips to "Link copied" and disables | — | P1 |
| W-SHEET-5 | "Open in reader" | Recording fake receives the right `nodeKey`; sheet pops | — | P0 |
| W-SHEET-6 | Active session changes while sheet is open (switch/delete under the desktop panel) | Sheet auto-closes | **#5** | P0 |
| W-SHEET-7 | Sinhala preview (override document providers) | Sutta's Sinhala title + up to 4 entries; empty-slice edge (sutta starting at page's last entry) renders nothing, no crash | — | P2 |

### 5.5 `ResearchScreen` — `test/presentation/screens/research_screen_test.dart`

Drive width via `tester.view.physicalSize` (breakpoint: 768 logical px).

| ID | Scenario | Expect | Guards | Pri |
|---|---|---|---|---|
| W-SCR-1 | Wide layout | Persistent 280px history panel + chat side by side; no drawer/hamburger | — | P0 |
| W-SCR-2 | Narrow layout | Hamburger opens drawer containing the panel; tap a chat → drawer closes | — | P0 |
| W-SCR-3 | Narrow AppBar title | Blank chat → section name; with messages → two lines (first question + section subtitle), ellipsized | — | P1 |
| W-SCR-4 | Narrow + `textScaleFactor` 2.0 with a chat open | No overflow errors (`FlutterError.onError` clean) | **#10** | P1 |
| W-SCR-5 | Wide: citation sheet open, system back (`tester.binding.handlePopRoute()`) | Sheet closes; Research screen itself stays (nested-navigator back contract, the Android-tablet case) | **#5** | P0 |
| W-SCR-6 | Wide: sheet layout | Sheet constrained to `researchContentMaxWidth`, centered over the chat column (not full window width) | — | P2 |

### 5.6 `ResearchModeSelector` — `test/presentation/widgets/research/research_mode_selector_test.dart`

Override `researchModeProvider` to seed the shown tier; use the real notifier for the tap flow.

| ID | Scenario | Expect | Guards | Pri |
|---|---|---|---|---|
| W-MODE-1 | Renders the active tier | Chip shows the current tier's friendly label (Fast/Thinking, never a raw Gemini id); menu marks the active one with a check | rev 07-25 | P1 |
| W-MODE-2 | Pick a tier from the menu | `researchModeProvider.notifier.set(m)` fires; chip updates to the chosen tier | rev 07-25 | P1 |

---

## 6. E2E level — `integration_test/research_flow_test.dart` (run with `-d macos`)

Hermetic: override `researchRepositoryProvider` with `FakeResearchRepository` via the
`test_overrides.dart` pattern — **no real network, no Python server**. The rest of the app (tree,
reader, documents, prefs) is real. Add to `all_tests.dart`; note the suite's known flakiness under
shared-DB contention — if a run hangs on a spinner, re-run the file **alone** before blaming the code.

| ID | Journey | Steps → expect | Guards | Pri |
|---|---|---|---|---|
| E2E-1 | **Citation deep-link chain** (the crown jewel) | Research section → ask → answer with `[[cite:sn15.3]]` chip → tap chip → peek shows snippet + Sinhala preview → "Open in reader" → app switches to Reader section with the correct BJT sutta open (verify via Sinhala sutta title) | — | P0 |
| E2E-2 | **Multi-chat lifecycle** | Ask in chat A → New chat → ask B → Recent shows both (B first) → tap A → full transcript restored → delete B → gone from list | — | P0 |
| E2E-3 | **Persistence across restart** | Ask (answer with citations) → re-pump the app with the same prefs store → Recent list intact → open chat → transcript AND citation chips restored | — | P0 |
| E2E-4 | **Turn-limit journey** | 5 Q&A turns → banner replaces input → "New chat" → fresh canvas, input back | — | P1 |
| E2E-5 | **Switch-while-thinking** | Ask in A (hold the Completer) → switch to B → back to A: thinking row still up, send disabled → release answer → appears in A only, transcript ordered Q,A | **#2 #4** | P0 |
| E2E-6 | **Retry journey** | Ask (fake fails with timeout) → error + Retry → tap Retry (fake succeeds) → answer appended, no duplicate question | — | P1 |
| E2E-7 | Narrow-window happy path | Resize window below 768 → E2E-1's core via the drawer | — | P2 |
| E2E-8 | **Per-chat tier restored on reopen** | Ask in A under Thinking → New chat (header back to Fast) → ask B under Fast → reopen A from Recent → header shows **Thinking** again (each chat remembers its own tier) | rev 07-25 | P1 |

**Optional (manual/smoke, not in CI):** one run against the real `research_server` in stub mode
(`RESEARCH_STUB=1`, `RESEARCH_BASE_URL=http://localhost:8081`) to validate the HTTP contract
end-to-end. Keep out of `all_tests.dart`.

---

## 7. Server side (separate suite — `research_server/tests/`, pytest)

No tests exist. Out of scope for the Flutter suites above, but the contract cases worth having:

- `/research` stub mode: 200 with canned answer + citations shape the client parses.
- Error classification: Gemini 429/503/timeouts → the documented HTTP statuses + clean bodies
  (the client's typed-error mapping in §4/§5 assumes these).
- Model-ladder fallback: primary 429 → next rung used; all rungs down → classified error.
- Linkifier: known uid → `[[cite:uid]]` markers present in prose; unknown uid never emitted.
- `X-App-Token` gate: missing/wrong token → 401 when `RESEARCH_APP_TOKEN` set; open when unset.
- History passed through: request with `history` → forwarded turns in the prompt (stub can echo).

---

## 8. Run commands & conventions

```bash
# Unit + widget
flutter test test/data/repositories/chat_history_repository_impl_test.dart
flutter test test/presentation/providers/research_provider_test.dart

# E2E (macOS is the default device for this project)
flutter test integration_test/research_flow_test.dart -d macos
```

- Sinhala/Pali fixture text must be in Sinhala script (`එවං මෙ සුතං`), never romanized.
- Reuse `pumpApp`/`defaultTestOverrides`/`InMemoryKeyValueStore`; put `FakeResearchRepository`
  in `test/helpers/` so unit, widget, and E2E share it.
- No `@visibleForTesting` shims for private members (`_relativeTime`, `_maxChats`…) — test through
  the public surface; duplicate literals in tests where needed.
- Tests are written by the test-generator agent on request — this catalogue is its input.
