# Research Section — Multi-Chat UI (Stage 2)

## Context

Stage 1 (docs/app-shell-navigation-plan.md) delivered the app shell: Home /
Reader / Research / Notes sections behind a NavigationRail (desktop) /
NavigationBar (mobile), with `ResearchScreen` as a blank canvas. Stage 2
(this plan) replaces that canvas with a full multi-chat AI research UI in
the style of Claude/ChatGPT, superseding the v1 `ResearchChatDialog` that
currently sits behind an AppBar button in the Reader.

Decisions locked with the user (2026-07-14):

- **Storage**: SharedPreferences via the existing `KeyValueStore`, split as
  a small index + one key per transcript. Max **25 chats**, oldest evicted.
- **Multi-turn**: yes — send prior turns as `history` (backend already
  accepts it, `research_server/app/contracts.py:32`). Hard cap of
  **5 user turns per chat**; after that the input is disabled with a
  "start a new chat" banner.
- **Mobile history UI**: Drawer from a hamburger icon (like the ChatGPT /
  Claude mobile apps). App bar shows the active chat's title with
  "Research" as subtitle (per mobile mockup).
- **Reader AppBar button**: removed; `research_chat_dialog.dart` and
  `research_button.dart` deleted (no test references them).

## Layout

- **Desktop/tablet (≥768, `ResponsiveUtils.isTabletOrDesktop`)**: persistent
  left panel (~280px) — "New chat" button + "RECENT" list — beside the chat
  area (desktop mockup).
- **Mobile**: same panel as a `Drawer`; input row sits above the bottom
  NavigationBar.
- Chat content column centered, max-width ~760px.
- Transcript rendering, citation chips, and the peek sheet
  (`ResearchAnswerView`, `CitationSourceSheet`) are reused unchanged.

## Storage scheme

- `research_chat_index` → JSON array of `{id, title, updatedAt}`, newest
  first. The sidebar reads only this — never the transcripts.
- `research_chat_<id>` → one key per transcript: full `ChatMessage` list
  **including citations**, so chips survive restarts.
- Cap 25: on save, chats beyond 25 are evicted oldest-first and their
  transcript keys deleted too (no orphans).
- Chat id = creation-time `microsecondsSinceEpoch`; title = first user
  question (ellipsized in the UI); corrupted data degrades to empty,
  matching `RecentSearchesRepositoryImpl`.

## New files

| File | Contents |
|---|---|
| `lib/domain/entities/research/chat_summary.dart` | Freezed `ChatSummary(id, title, updatedAt)` + JSON |
| `lib/domain/repositories/chat_history_repository.dart` | `getSummaries / getMessages(id) / saveChat / deleteChat` (plain Futures, like `RecentSearchesRepository`) |
| `lib/data/repositories/chat_history_repository_impl.dart` | `KeyValueStore`-backed impl of the scheme above |
| `lib/presentation/widgets/research/chat_history_panel.dart` | New-chat button, RECENT list (title + relative time, selected highlight, per-chat delete) |
| `lib/presentation/widgets/research/research_chat_view.dart` | Transcript + thinking row + error row + turn-limit banner + input (moved out of the dialog) |

## Changed files

- **`research_chat_state.dart`** — add `sessionId` (null = fresh unsaved
  chat) and an `isAtTurnLimit` getter (user turns >= 5).
- **`research_provider.dart`** (`ResearchChatNotifier`):
  - `send()` passes history = all prior turns (max 4 Q&A pairs given the
    cap — no further truncation needed).
  - 5-turn cap; retry of a *failed* 5th question still works (retry adds
    no turn).
  - Session created lazily on first send (empty chats never pollute
    history); persisted after the user turn and after each answer; sidebar
    refreshed via provider invalidation.
  - `openChat(id)` loads a saved transcript to continue it; `newChat()`
    clears; `deleteChat(id)` removes from storage (and clears the canvas
    if active).
  - Race guard: an answer arriving after the user switched chats is
    appended to its original chat's storage, not the live transcript.
- **`research_screen.dart`** — placeholder → responsive layout.
- **`reader_screen.dart`** — remove `ResearchButton`.

## Deletions

`research_chat_dialog.dart`, `research_button.dart`.

## Localization (EN + SI)

New keys: `researchRecent`, `researchNoRecentChats`,
`researchChatLimitReached`, `researchDeleteChat`, relative-time keys
(just now / N min / N hours / Yesterday / N days). Existing
`researchNewChat`, input hints, and error keys are reused.

## Deliberately out of scope

- "Search Tipitaka" field / search icon from the mockups (search lives in
  the Reader; a cross-section jump is its own task).
- Sidebar collapse toggle (desktop mockup's panel-collapse icons).
- "You" tab (skipped in Stage 1), AI-generated chat titles, streaming.

## Verification

`build_runner` (Freezed), `flutter gen-l10n`, `flutter analyze`, then run
on macOS: full chat flow against the local research server, restart to
confirm persistence, narrow window for the drawer, 5-turn limit, citation
→ "Open in reader" landing on the Reader section. Tests are NOT written
here (test-writer agent's job, per project rules).
