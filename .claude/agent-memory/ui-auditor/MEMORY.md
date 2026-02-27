# UI Auditor Memory -- The Wisdom Project

## Architecture
- Single screen app: `ReaderScreen` with navigator sidebar, tab bar, reader pane, search panel
- Theme system: 3 themes (Light/Dark/Warm) in `lib/core/theme/`
- Two ThemeExtensions: `TextEntryTheme` (reader content) and `AppTypography` (UI elements)
- Font system: `AppFonts` separates reader (serif) from UI (sans-serif) fonts
- Sinhala script is primary -- `AppFonts.reader = readerSinhala`, `AppFonts.ui = uiSinhala`

## Theme Color Summary
- Light: Warm cream (#FDF8F3) bg, deep brown (#422701) text -- AAA pass everywhere
- Dark: Near black (#121212) bg, light gray (#E0E0E0) text -- AAA pass
- Warm: Dark brown (#2A2318) bg, off-white (#E8DFD0) text -- AAA pass for body
- ISSUE: Warm muted (#8A7D6A) on bg = 3.86:1 (AA-large only, fails AA-normal)
- ISSUE: Warm muted (#8A7D6A) on surface = 3.04:1 (barely AA-large, fails AA-normal)

## Accessibility Gaps (First Audit 2026-02-27)
- Zero `Semantics` widgets in entire presentation layer
- Zero `header: true` semantic annotations on headings
- No `MediaQuery.disableAnimationsOf` checks (12 animated widgets)
- Hardcoded `Colors.red` in error states (should use colorScheme.error)
- Tab close button: 22x22 effective size (below 48x48 minimum)
- Tree navigator expand icon: 28x28 effective (below 48x48)
- Search bar action buttons: 30x30 (below 48x48)
- GestureDetectors on scope chips lack semantic labels
- ~30 hardcoded English strings not using localization (l10n)

## Typography Notes
- Paragraph line height: 1.5 (guidelines say 1.7-1.8 for Sinhala)
- Gatha line height: 1.4 (acceptable for verse)
- Heading line height: 1.2 (tight, acceptable for headings)
- UI line height: 1.4 (fine for interface)
- No max-width constraint on reading content (guidelines say 720px max)
- Body text size: 17.6sp (16 * 1.1) -- reasonable for Sinhala

## Key Widget Files
- `lib/presentation/screens/reader_screen.dart` -- main screen
- `lib/presentation/widgets/multi_pane_reader_widget.dart` -- reader content
- `lib/presentation/widgets/reader/text_entry_widget.dart` -- text rendering
- `lib/presentation/widgets/tab_bar_widget.dart` -- browser-style tabs
- `lib/presentation/widgets/tree_navigator_widget.dart` -- navigation tree
- `lib/presentation/widgets/dictionary/dictionary_bottom_sheet.dart` -- dictionary
- `lib/presentation/widgets/search/search_bar.dart` -- global search
- `lib/presentation/widgets/reader/reader_action_buttons.dart` -- FAB and pill

## Responsive Layout
- Breakpoints differ from guidelines: 768/1024 used vs 600/840/1200 recommended
- No reading content max-width constraint on wide screens
- Mobile: full-screen overlays for navigator and search
- Desktop: sidebar navigator + overlay search panel
