# App Shell Navigation — NavigationRail (desktop) + NavigationBar (mobile), Stage 1

## Context

The Research feature is moving out of its v1 dialog into its own top-level tab (a full AI-chat UI with sessions — Stage 2, next session). That requires the app to gain top-level navigation first: **Home, Reader, Research, Notes** — where "Reader" is the entire current screen. Stage 1 (this plan) delivers only the shell: a `NavigationRail` on desktop/tablet, a `NavigationBar` (bottom) on mobile, with the Reader working **exactly as before** and the other three tabs as **blank canvases**. Main success criterion: navigation works on all clients.

"You" tab from the mockups: **skipped** per user decision (trivial to add later).

## Current state (verified)

- No router package; `main.dart:237` mounts `home: const ReaderScreen()` directly. All navigation is Riverpod-state-driven; zero `Navigator.push` in the app.
- The `MaterialApp.builder` chain (`DeepLinkListener → AppShortcuts → OverlayStackSync → Stack[child, UpdateAvailableBanner]`) wraps every screen — it stays untouched.
- In this codebase "tabs" means **reader document tabs** (`TabBarWidget`, `activeTabIndexProvider`). The new top-level concept is therefore named **"section"** to avoid collision.
- Breakpoints: `ResponsiveUtils.isMobile` (<768) / `isTabletOrDesktop` (≥768) — `lib/core/utils/responsive_utils.dart`.
- All link opens (OS deep links, web start URL, research citation "Open in reader") funnel through `openTipitakaLinkProvider` (`lib/presentation/providers/deep_link_provider.dart:36`).
- `researchChatProvider` is app-lifetime (non-autoDispose) — the v1 dialog keeps working unchanged.
- No test pumps the real app root (`MyApp`/`ReaderScreen`) — low breakage risk.

## Changes

### 1. NEW `lib/presentation/providers/app_section_provider.dart`
```dart
enum AppSection { home, reader, research, notes }

final selectedAppSectionProvider =
    StateProvider<AppSection>((ref) => AppSection.reader);
```
Default = `reader`, so launch lands exactly where it does today. **No persistence in Stage 1** (keeps behavior identical; the `activeTabIndexPersistenceProvider` pattern is there if we want it later).

### 2. NEW `lib/presentation/screens/app_shell.dart` — `AppShell` (ConsumerWidget)
Single `Scaffold`, one code path for both form factors:

```dart
Scaffold(
  body: Row(children: [
    if (isTabletOrDesktop) NavigationRail(...),   // labels under icons, like mockup
    Expanded(
      child: IndexedStack(
        index: section.index,
        children: [HomeScreen, ReaderScreen, ResearchScreen, NotesScreen],
      ),
    ),
  ]),
  bottomNavigationBar: isMobile ? NavigationBar(...) : null,
)
```

- **`IndexedStack`** keeps `ReaderScreen` alive across section switches — open reader tabs, tree expansion, scroll positions all survive. (Trailing-position child reconciliation also keeps the `Expanded` subtree alive when the rail appears/disappears on a breakpoint crossing.)
- Each section keeps its own inner `Scaffold`/`AppBar` (standard nested-Scaffold tab pattern) — Reader's AppBar is untouched.
- Icons (outlined/filled selected variants): Home `home`, Reader `menu_book`, Research `auto_awesome` (matches the existing `ResearchButton` icon), Notes `edit_note`.
- Styling: M3 defaults from the existing `colorScheme`; rail/bar pick up the theme automatically.

### 3. NEW blank-canvas screens (Stage-1 placeholders)
`lib/presentation/screens/home_screen.dart`, `research_screen.dart`, `notes_screen.dart` — each a minimal `Scaffold` with an empty body (blank canvas per user instruction). `ResearchScreen` gets replaced by the chat UI in Stage 2.

### 4. EDIT `lib/main.dart:237`
`home: const ReaderScreen()` → `home: const AppShell()`. Nothing else in `MyApp` changes.

### 5. EDIT `lib/presentation/providers/deep_link_provider.dart`
In `openTipitakaLinkProvider`, on a successful open also set
`selectedAppSectionProvider = AppSection.reader` — so OS deep links, the web start URL, and citation "Open in reader" all land on the Reader section regardless of which section is active. One line; covers every link source since this provider is the single sink.

### 6. Localization
Add 4 short tab-label keys to `app_en.arb` / `app_si.arb`: `navHome`, `navReader`, `navResearch`, `navNotes` (EN: Home / Reader / Research / Notes; SI: මුල් පිටුව / ත්‍රිපිටකය / ගවේෂණය / සටහන් — `navReader` is deliberately ත්‍රිපිටකය (the Tipitaka) rather than a literal "reader", the term users actually navigate by). Regenerate with `flutter gen-l10n`.

### 7. Deliberately unchanged
- `ReaderScreen` — AppBar keeps `SearchBar`, `ResearchButton` (v1 dialog stays until Stage 2), `SettingsMenuButton`; body untouched.
- Research dialog + all research providers/domain/data.
- Overlay/ESC system (`AppShortcuts`, `overlayStackProvider`), theme, deep-link listener.

## Accepted behavior deltas (to sanity-check, not fix)
- Mobile: Reader's full-screen overlays (tree navigator, search results) live inside Reader's body `Stack`, so the bottom `NavigationBar` stays visible/tappable beneath them — standard tab-app behavior, matches the mockup.
- Cmd/Ctrl+F on a non-Reader section is disabled via an `isEnabled` guard in `OpenInPageSearchAction`. (Without it the shortcut would silently open the in-page search bar inside the hidden Reader — `openSearch()` is provider state, which, unlike focus, isn't blocked by `IndexedStack`.)
- ESC on a non-Reader section can still dismiss overlays living in the hidden Reader. Accepted for Stage 1: it only ever closes things, all overlays currently live in Reader, and Stage-2 sections may push onto the same overlay stack — a `== reader` guard added now would just be removed then.

## Clean-architecture fit
Pure presentation-layer change: three tiny screens, one shell widget, one `StateProvider`. Domain/data untouched. No router introduced — stays consistent with the app's state-driven navigation. Reuses `ResponsiveUtils` breakpoints and existing provider conventions.

## Files
- **New:** `lib/presentation/providers/app_section_provider.dart`, `lib/presentation/screens/app_shell.dart`, `home_screen.dart`, `research_screen.dart`, `notes_screen.dart`
- **Edit:** `lib/main.dart`, `lib/presentation/providers/deep_link_provider.dart`, `lib/core/localization/l10n/app_en.arb`, `app_si.arb` (+ regenerated localizations)
- Per project convention, also save this plan as `docs/app-shell-navigation-plan.md` at implementation time (plan mode restricts writes to this file).

## Verification
1. `flutter analyze` — clean.
2. `flutter run -d macos`:
   - Rail shows 4 destinations, Reader selected at launch; reader works exactly as before (tree, document tabs, search, dictionary sheet, research dialog, settings menu).
   - Switch to Home/Research/Notes → blank canvases; back to Reader → open tabs/scroll intact.
3. Resize the window below 768 px → bottom `NavigationBar` replaces the rail (mobile layout is MediaQuery-width-driven, so a narrow desktop window is a faithful mobile check); reader state survives the crossing. Optionally verify on iOS simulator too.
4. Deep link: from the Home section, open a citation via the research dialog ("Open in reader") and/or `open "sammaditthi://tipitaka/<nodeKey>"` → app switches to the Reader section with the sutta open.
5. Tests: none written/run (per project rule — test-writer agent handles tests separately; will notify on completion).

## Out of scope (Stage 2, next session)
AI chat UI in the Research tab (sessions/recent searches), removing `ResearchButton` from the AppBar, "You" tab, section persistence across restarts.
