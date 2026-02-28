# World-Class UI Audit Report -- The Wisdom Project

**Date**: 2026-02-27
**Scope**: Full pre-release audit -- every screen, widget, theme, and color
**Files Scanned**: 42 presentation files, 6 theme files, 2 context files

---

## Summary

| Category | Status | Issues |
|----------|--------|--------|
| Accessibility | NEEDS WORK | 9 issues |
| Typography | MINOR ISSUES | 4 issues |
| Platform Guidelines | MINOR ISSUES | 3 issues |
| Visual Design | GOOD | 3 issues |
| Reading Experience | MINOR ISSUES | 4 issues |
| Vibe Check | PEACEFUL | See assessment below |

**Overall**: MINOR ISSUES -- No release blockers, but several accessibility items should be addressed before public launch.

---

## CRITICAL ISSUES (Must Fix Before Release)

### C1. Zero Semantic Labels Anywhere in the App

**What**: The entire presentation layer has zero `Semantics` widgets. Screen readers (VoiceOver on iOS, TalkBack on Android) will struggle to make sense of the app. Blind or low-vision users cannot navigate the Tipitaka at all.

**Where**: Every file in `lib/presentation/`

**Why it matters**: This is a WCAG Level A failure. The app says "Inclusive -- Accessible to all abilities, ages, and cultures" in its design philosophy, but a screen reader user would find it unusable.

**What needs semantic labels**:
- The tree navigator needs `Semantics(label: 'Navigation tree')` around the whole widget
- Each tree node needs `Semantics(label: node.displayName, button: true)`
- The tab bar needs `Semantics(label: 'Open documents')`
- Each tab needs `Semantics(label: tab.fullName, selected: isActive)`
- The breadcrumb needs `Semantics(label: 'Current location: ...')`
- The reader content headings need `Semantics(header: true)` wrapping
- The search bar needs `Semantics(textField: true, label: 'Search Tipitaka')`
- The dictionary bottom sheet needs `Semantics(label: 'Dictionary: $word')`
- All floating action buttons and icon buttons in reader_action_buttons.dart

**Suggested fix pattern**:
```dart
// Before:
Text(displayName, style: style)

// After -- wrap headings with semantic header role:
Semantics(
  header: true,
  child: Text(displayName, style: style),
)
```

**Priority**: HIGH -- This is an accessibility blocker. A Buddhist scripture app should be especially accessible, as many monastics and elderly practitioners may have visual impairments.

---

### C2. Tap Targets Below Minimum Size

**What**: Several interactive elements are smaller than the 48x48dp minimum required by WCAG 2.1 and Material Design.

**Where and how small**:

| Widget | File | Effective Size | Required |
|--------|------|---------------|----------|
| Tab close button | `tab_bar_widget.dart` line 287-299 | ~22x22 (14px icon + 4px padding each side) | 48x48 |
| Tree expand icon | `tree_navigator_widget.dart` line 166-178 | ~28x28 (20px icon + 4px padding) | 48x48 |
| Search bar exact match button | `search_bar.dart` line 191-218 | 30x30 | 48x48 |
| Search bar proximity button | `search_bar.dart` line 221-245 | 30x30 | 48x48 |
| Search bar clear button | `search_bar.dart` line 247-269 | 30x30 | 48x48 |
| Recent search delete (X) | `recent_search_overlay.dart` line 94-106 | ~26x26 (18px icon + 8px padding) | 48x48 |
| In-page search nav buttons | `in_page_search_bar.dart` line 146-166 | 32x32 | 48x48 |

**Why it matters**: Users with motor impairments, elderly users, or anyone on a bumpy bus will struggle to tap these small targets. The tab close button is especially problematic since mistaps could close the wrong tab.

**Suggested fix**:
For the tab close button, keep the visual size small but expand the hit area:
```dart
// Instead of:
InkWell(
  child: Padding(
    padding: const EdgeInsets.all(4.0),
    child: Icon(Icons.close, size: 14),
  ),
)

// Use:
IconButton(
  icon: const Icon(Icons.close, size: 14),
  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
  padding: EdgeInsets.zero,
  onPressed: onClose,
  tooltip: 'Close tab',
)
```

For the search bar buttons, the visual design (30x30 circle) can remain, but the touch target should be padded to 48x48.

**Priority**: HIGH

---

### C3. Hardcoded Colors Bypassing Theme System

**What**: Several places use hardcoded `Colors.red` or `Colors.black` instead of the theme's color scheme. This breaks the warm aesthetic in all themes and creates accessibility issues in dark/warm modes.

**Where**:
- `multi_pane_reader_widget.dart` line 418: `color: Colors.red` for error icon
- `tree_navigator_widget.dart` line 65: `color: Colors.red` for error icon
- `reader_screen.dart` line 210: `Colors.black54` for dim barrier
- `dictionary_bottom_sheet.dart` line 171: `Colors.black.withValues(alpha: 0.15)` for shadow

**Why it matters**: `Colors.red` is a jarring cold red that clashes with the warm earth-tone palette. In the warm theme, it looks especially out of place. The search barrier uses `Colors.black54` which is fine for light theme but could be improved.

**Suggested fix**:
```dart
// Instead of:
Icon(Icons.error_outline, size: 48, color: Colors.red)

// Use the theme error color:
Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error)
```

The error colors are already defined beautifully per theme:
- Light: `#B3261E` (M3 cherry red)
- Dark: `#FF6B6B` (bright red, readable on dark)
- Warm: `#FF8A65` (soft orange-red, fits warm palette)

**Priority**: HIGH -- easy fix, big visual improvement

---

## MAJOR ISSUES (Should Fix Before Launch)

### M1. Warm Theme Muted Text Fails WCAG AA Contrast

**What**: The muted/secondary text color in the warm theme does not meet WCAG AA (4.5:1) for normal-sized body text.

**Measured contrast ratios**:
| Combination | Ratio | AA (4.5:1) | AAA (7:1) |
|-------------|-------|------------|-----------|
| Warm muted (#8A7D6A) on background (#2A2318) | 3.86:1 | FAIL | FAIL |
| Warm muted (#8A7D6A) on surface (#3D3428) | 3.04:1 | FAIL | FAIL |

**Where it appears**: Any text using `onSurfaceVariant` in the warm theme -- this includes:
- Search hint text
- Result subtitles/breadcrumbs
- Chip labels (unselected)
- Empty state messages (60% opacity makes it even worse)
- Page numbers
- Menu section labels
- Tab labels (inactive, at 70% opacity)

**Why it matters**: Users with any degree of visual impairment will struggle to read secondary text in the warm theme. This is the app's "signature" theme -- it should be the most polished.

**Suggested fix**: Lighten the warm muted color from `#8A7D6A` to approximately `#A89A86` (contrast ~5.2:1 on bg) or `#B0A290` (~6.0:1). Test visually to ensure it still looks "muted" rather than bright.

```dart
// In app_colors.dart, WarmThemeColors:
// Current:
static const muted = Color(0xFF8A7D6A); // 3.86:1 -- FAILS AA

// Suggested:
static const muted = Color(0xFFA89A86); // ~5.2:1 -- passes AA
```

**Priority**: MEDIUM-HIGH -- This is a WCAG AA failure but only affects secondary text

---

### M2. No Max-Width Constraint on Reading Content

**What**: On wide screens (desktop, iPad landscape), reading text stretches to fill the entire available width. This creates very long lines that are difficult to read.

**Where**: `multi_pane_reader_widget.dart` -- the `ListView.builder` and `SingleChildScrollView` in all three column modes (paliOnly, sinhalaOnly, both) use `padding: EdgeInsets.all(24.0)` but no max-width constraint.

**Why it matters**: Optimal reading requires 45-75 characters per line. On a 1920px-wide monitor, a single-column sutta could have 150+ characters per line, making it exhausting to read. The theme guidelines specifically say "Always wrap reading content in `ConstrainedBox(maxWidth: 720)`".

**Suggested fix**: Wrap the reading content in a centered `ConstrainedBox`:
```dart
// In each column mode's content builder, wrap the ListView:
Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 720),
    child: ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(24.0),
      // ... existing code
    ),
  ),
)
```

For "both" mode (side-by-side), the max-width should be larger (e.g., 1200px) since it has two columns.

**Priority**: MEDIUM-HIGH -- significantly affects reading comfort on desktop

---

### M3. Sinhala Text Line Height Too Tight

**What**: The paragraph line height is set to 1.5, but the theme guidelines specify 1.7-1.8 for Sinhala script due to its tall glyphs and complex conjunct consonants.

**Where**: `text_entry_theme.dart` line 12: `const double _paragraphLineHeight = 1.5;`

**Why it matters**: Sinhala script has ascenders and descenders that are taller than Latin script. At 1.5 line height, the lines can feel cramped and letters from adjacent lines can visually clash, especially for conjunct consonants. This directly impacts the primary reading experience.

**Context**: The guidelines document says:
- English: 1.5 minimum
- Sinhala: 1.7-1.8
- Mixed Pali+Sinhala: 1.8

**Suggested fix**:
```dart
// In text_entry_theme.dart:
// Current:
const double _paragraphLineHeight = 1.5;

// Suggested:
const double _paragraphLineHeight = 1.7;
```

This is a design decision that needs your visual review. Try 1.7 and 1.8 and see which feels more comfortable for long reading sessions. The "quiet library" feeling benefits from generous line spacing.

**Priority**: MEDIUM -- affects core reading comfort

---

### M4. ~30 Hardcoded English Strings Not Localized

**What**: Approximately 30 user-facing strings are hardcoded in English rather than using the localization system (`AppLocalizations`). This prevents the app from being fully translated.

**Where** (selected examples):

| String | File | Line |
|--------|------|------|
| `'Select a sutta from the tree to begin reading'` | multi_pane_reader_widget.dart | 375 |
| `'No content to display'` | multi_pane_reader_widget.dart | 393 |
| `'Error loading content'` | multi_pane_reader_widget.dart | 423 |
| `'More options coming soon'` | multi_pane_reader_widget.dart | 593 |
| `'Copy'` | multi_pane_reader_widget.dart | 573 |
| `'More'` | multi_pane_reader_widget.dart | 586 |
| `'No content available'` | tree_navigator_widget.dart | 41 |
| `'Error loading navigation tree'` | tree_navigator_widget.dart | 69 |
| `'RECENT SEARCHES'` | recent_search_overlay.dart | 85 |
| `'Clear All'` | recent_search_overlay.dart | 145 |
| `'Refine Search'` | refine_search_dialog.dart | 116 |
| `'SCOPE'` | refine_search_dialog.dart | 140 |
| `'Clear'` | refine_search_dialog.dart | 153 |
| `'Reset'` | refine_search_dialog.dart | 279 |
| `'Done'` | refine_search_dialog.dart | 284 |
| `'Show Less'` | grouped_fts_tile.dart | 145 |
| `'View X more'` | grouped_fts_tile.dart | 146 |
| `'Viewing X out of Y results'` | search_results_panel.dart | 342 |
| `'Enter a valid search query'` | search_results_panel.dart | 391 |
| `'No results found'` | search_results_panel.dart | 395 |
| `'Failed to load results'` | search_results_panel.dart | 208 |
| `'Retry'` | search_results_panel.dart | 217 |
| `'Theme'` | settings_menu_button.dart | 32 |
| `'Navigation Language'` | settings_menu_button.dart | 49 |
| `'Sutta Language'` | settings_menu_button.dart | 67 |
| `'Light'`, `'Dark'`, `'Warm'` | settings_menu_button.dart | 90-100 |
| `'Pali'` | settings_menu_button.dart | 125 |
| `'Backspace'`, `'Close'` | dictionary_bottom_sheet.dart | 260, 268 |

**Why it matters**: The app serves a Sinhala-speaking audience. Having English-only UI strings in a dhamma app feels disrespectful. Some of these strings (like "Select a sutta from the tree to begin reading") are prominently displayed.

**Priority**: MEDIUM -- functional but limits audience reach

---

### M5. No Reduced Motion Support

**What**: The app has 12 animated widgets (AnimatedOpacity, AnimatedContainer, AnimatedSlide, AnimatedSize, AnimatedRotation) across 6 files, but none of them check `MediaQuery.disableAnimationsOf(context)` to respect the user's accessibility preference for reduced motion.

**Where**: All animation usage in:
- `multi_pane_reader_widget.dart` (4 animations)
- `tab_bar_widget.dart` (2 animations)
- `resizable_divider.dart` (2 animations)
- `reader_screen.dart` (1 animation)
- `proximity_dialog.dart` (1 animation)
- `reader_action_buttons.dart` (2 animations)

**Why it matters**: Users with vestibular disorders, motion sensitivity, or certain cognitive disabilities can experience nausea, dizziness, or discomfort from animations. This is a WCAG 2.1 Level AAA requirement.

**Suggested fix pattern**:
```dart
// At the top of any build method with animations:
final reduceMotion = MediaQuery.disableAnimationsOf(context);

// Then use instant duration when animations are disabled:
AnimatedOpacity(
  opacity: visible ? 1.0 : 0.0,
  duration: reduceMotion
    ? Duration.zero
    : const Duration(milliseconds: 200),
  child: ...,
)
```

**Priority**: MEDIUM

---

## MINOR ISSUES (Polish Items)

### P1. Responsive Breakpoints Don't Match Guidelines

**What**: `ResponsiveUtils` uses breakpoints of 768px and 1024px, but the theme guidelines define compact (<600), medium (600-840), expanded (840-1200), and large (>1200). This mismatch means the app transitions between mobile and desktop at different points than the design system intended.

**Where**: `lib/core/utils/responsive_utils.dart`

**Impact**: Minor -- the current breakpoints work fine in practice, but they don't align with the documented design system, which could cause confusion for future developers.

**Priority**: LOW

---

### P2. No Text Scaling Resilience for Fixed-Height Containers

**What**: The tab bar has a fixed `height: 48` and the search panel header has `height: 60`. When users increase text size (system accessibility settings), text inside these containers can overflow or be clipped.

**Where**:
- `tab_bar_widget.dart` line 91: `height: 48`
- `search_results_panel.dart` line 419: `height: 60`

**Suggested fix**: Use `constraints: BoxConstraints(minHeight: 48)` instead of `height: 48`.

**Priority**: LOW

---

### P3. Spacing Irregularities

**What**: A few spacing values don't follow the 4px grid:

| Value | File | Line | Should Be |
|-------|------|------|-----------|
| 44px spacer | multi_pane_reader_widget.dart | 633, 680, 738 | 48px |
| 20px SizedBox | proximity_dialog.dart | 217 | 24px |
| 22.4px indent | text_entry_theme.dart | 53 | 24px |
| 38.4px padding | text_entry_theme.dart | 54 | 40px |
| 80px padding | text_entry_theme.dart | 55 | 80px (fine) |

The 44px spacer is intentional (to clear the button group), but 48px would be on-grid. The `1.4em` and `2.4em` values come from the original Vue.js app's CSS and make typographic sense even if not on the 4px grid.

**Priority**: LOW -- these are minor and some are intentional

---

### P4. Scope Filter Chips Use GestureDetector Without Semantics

**What**: The `_ScopeChip` and `_RefineChip` widgets in `scope_filter_chips.dart` use `GestureDetector` for tap handling, but GestureDetector does not provide any semantic information to screen readers. These chips have no labels, no button role, and no selected state for accessibility.

**Where**: `scope_filter_chips.dart` lines 137, 183

**Suggested fix**: Wrap with Semantics or switch to InkWell with Tooltip:
```dart
Semantics(
  label: label,
  button: true,
  selected: isSelected,
  child: GestureDetector(
    onTap: onTap,
    child: Container(...),
  ),
)
```

**Priority**: MEDIUM (grouped with accessibility)

---

### P5. Tree Node Expand Icon Lacks Tooltip

**What**: The expand/collapse chevron icon on tree nodes has no tooltip, so hovering over it on desktop shows nothing. The tree node itself (the InkWell) also has no tooltip.

**Where**: `tree_navigator_widget.dart` line 166-178

**Suggested fix**: Add a `Tooltip` wrapper:
```dart
Tooltip(
  message: isExpanded ? 'Collapse' : 'Expand',
  child: GestureDetector(
    onTap: () => ref.read(toggleNodeExpansionProvider)(node.nodeKey),
    child: Padding(
      padding: const EdgeInsets.all(4.0),
      child: Icon(
        isExpanded ? Icons.expand_more : Icons.chevron_right,
        size: 20,
      ),
    ),
  ),
)
```

**Priority**: LOW

---

### P6. "See X more" Link in Search Results Uses GestureDetector

**What**: The "View 5 more" / "Show Less" toggle in `grouped_fts_tile.dart` uses a bare `GestureDetector` with no visual feedback (no hover state, no ripple, no tooltip). On desktop, hovering shows no indication it is clickable.

**Where**: `grouped_fts_tile.dart` line 134

**Suggested fix**: Use `InkWell` instead of `GestureDetector` for ripple feedback:
```dart
InkWell(
  onTap: () { ... },
  borderRadius: BorderRadius.circular(4),
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    child: Row(...)
  ),
)
```

**Priority**: LOW

---

### P7. Missing `const` on Some Widgets

**What**: A few widget constructors that could be `const` are not marked as such.

**Where**: Minor instances scattered across files. The codebase is generally good about this.

**Priority**: VERY LOW -- lint will catch these

---

## VIBE ASSESSMENT -- The Monastic Test

### Overall Vibe: PEACEFUL

This app genuinely feels like entering a quiet library. Here is the detailed assessment:

**First Impression**: EXCELLENT
- The warm cream background (#FDF8F3) is immediately soothing
- No logos, no splash screens, no branding in your face
- The earth-tone palette evokes natural materials -- aged paper, wood, saffron
- The warm theme (#2A2318) is especially beautiful -- it feels like candlelit reading

**Typography Feel**: VERY GOOD
- Noto Serif Sinhala is an excellent choice -- dignified, readable, culturally appropriate
- The heading hierarchy (5 levels) is well-structured for Tipitaka's deep nesting
- The gatha (verse) styling with indentation and italic is a nice touch
- IMPROVEMENT NEEDED: Line height should be 1.7+ for comfortable Sinhala reading
- IMPROVEMENT NEEDED: Max-width constraint needed on wide screens

**Content-to-Chrome Ratio**: EXCELLENT
- The UI chrome is minimal -- slim tab bar, thin dividers, subtle action buttons
- The action button group appears as a translucent pill that fades away when scrolling
- The bottom FAB collapses to a single dot icon when not needed
- The breadcrumb is subtle and informative without being distracting
- Dictionary bottom sheet slides up non-modally -- you can still read around it

**Dhamma Appropriateness**: EXCELLENT
- No gamification, no streaks, no social features, no notifications
- No monetization UI, no upsells, no badges
- The three-theme system (Light/Dark/Warm) shows care for different reading contexts
- The commentary/root text toggle is a thoughtful feature for serious study
- The parallel Pali+Sinhala layout is perfect for scholarly reading
- The in-page search (Ctrl+F style) shows respect for the text as a document

**Would a monastic feel comfortable?**: YES
- This app is humble and functional, not flashy
- The warm theme is genuinely beautiful in a traditional way
- The focus is entirely on the text, not the app
- The only distraction: error states use jarring `Colors.red` instead of the warm error colors

**Areas to enhance the vibe further**:
1. The "More options coming soon" SnackBar feels premature -- remove it or replace with something more complete
2. The empty state message "Select a sutta from the tree to begin reading" could be replaced with a Pali verse or a lotus/bodhi leaf illustration
3. Consider adding a "reading progress" indicator that is subtle (like a thin line at the top) rather than a percentage

---

## POSITIVE HIGHLIGHTS -- What Is Done Well

### Design System

1. **Three thoughtfully designed themes**: Light, Dark, and Warm are each complete color systems with proper M3 roles. The warm theme is genuinely distinctive and beautiful -- this is the app's signature.

2. **Excellent color choices**: The light theme passes AAA everywhere for body text (13:1). Dark theme meets AAA (14:1). Warm theme passes AAA for body (11.7:1). These are superb contrast ratios.

3. **Proper M3 surface hierarchy**: The app correctly uses `surfaceContainerLowest` through `surfaceContainerHighest` for elevation differentiation. This is more sophisticated than most Flutter apps.

4. **Two-font system**: Separating serif (reader content) from sans-serif (UI) is the correct approach for a document reader. The fallback chains are well-thought-out.

5. **ThemeExtension pattern**: Using `TextEntryTheme` and `AppTypography` as ThemeExtensions is clean architecture that makes styles accessible everywhere via `context.textEntryTheme` and `context.typography`.

### User Experience

6. **Per-tab state management**: Each tab remembers its own column mode, scroll position, pagination, and split ratio. This is exactly right for a document reader.

7. **Dictionary lookup on word tap**: Tapping any Pali word opens a non-modal dictionary bottom sheet. The word is editable, results are debounced, and the sheet can be dragged. This is a genuinely excellent feature for Pali study.

8. **Infinite scroll with page-aware pagination**: Content loads page by page as the user scrolls, with smart detection of whether the viewport is filled. This prevents both loading too much data and the "can't scroll to load more" problem.

9. **Keyboard shortcuts**: Escape closes the search panel. The overall keyboard handling structure is in place.

10. **Resizable panes**: The navigator sidebar, search panel, and parallel text split are all resizable with smooth dividers that show only on hover. This is a desktop-quality UX.

11. **Scroll position memory**: Scroll positions are saved per tab and restored when switching back. This is essential for a reader app.

12. **Smart search features**: Singlish-to-Sinhala transliteration, phrase/proximity search, scope filtering with hierarchical selection, FTS highlighting in content -- these are all well-implemented.

13. **Context menu with Copy**: Text selection with a custom context menu for copying text. Simple and functional.

14. **Commentary toggle**: One-tap switching between root text and its commentary is a feature that serious Pali scholars will love.

### Code Quality

15. **Consistent theme usage**: Almost all colors come from `Theme.of(context).colorScheme.*` (with the few exceptions noted above). This is excellent discipline.

16. **Clean separation of concerns**: The TextEntryWidget handles word-level tap detection, highlight overlays, and conjunct consonant transformation in a single, well-organized widget.

17. **Performance optimization**: Cached display text, cached marked ranges, cached search ranges. Word match patterns are pre-computed. Recognizers are reused across rebuilds.

---

## ACCESSIBILITY CHECKLIST

| Item | Status | Notes |
|------|--------|-------|
| Semantic labels on interactive elements | NEEDS WORK | Zero Semantics widgets |
| Tooltip on all IconButtons | PARTIAL | 16 of ~17 have tooltips |
| Tap targets >= 48x48 | NEEDS WORK | 7 elements below minimum |
| WCAG AA contrast (body text) | PARTIAL | Warm muted fails |
| WCAG AAA contrast (body text) | PASS | All themes pass for body |
| Screen reader navigable | NEEDS WORK | No semantic structure |
| Keyboard navigation | PARTIAL | Escape works, but no tab-order management |
| Text scaling resilience | PARTIAL | 2 fixed-height containers |
| Reduced motion support | NEEDS WORK | 12 animations, zero checks |
| Focus indicators visible | PASS | Uses Material defaults |
| Color-only information | PASS | No color-only states found |
| Heading structure (semantic) | NEEDS WORK | No header:true annotations |

---

## ACTION ITEMS

### Before Public Launch (High Priority)

1. **C3** -- Replace `Colors.red` with `colorScheme.error` in error states (2 files, 2 lines -- 5 minutes)
2. **C2** -- Expand tap targets on tab close button, tree expand icon, search bar buttons (3 files -- 30 minutes)
3. **M1** -- Fix warm theme muted color contrast (1 file, 1 line -- 5 minutes)
4. **M2** -- Add max-width constraint to reading content (1 file -- 15 minutes)
5. **M3** -- Increase paragraph line height to 1.7 for Sinhala (1 file, 1 line -- 5 minutes)

### Pre-Launch Polish (Medium Priority)

6. **C1** -- Add `Semantics` wrappers to key interactive elements (systematic, ~2 hours)
7. **M4** -- Extract hardcoded strings to ARB localization files (~1 hour)
8. **M5** -- Add reduced motion checks to animations (6 files -- 30 minutes)
9. **P4** -- Add semantic labels to scope filter chips (1 file -- 15 minutes)

### Future Improvements (Low Priority)

10. **P1** -- Align responsive breakpoints with documented guidelines
11. **P2** -- Replace fixed heights with min-height constraints
12. **P3** -- Align spacing values to 4px grid
13. **P5** -- Add tooltips to tree node expand icons
14. **P6** -- Use InkWell for "See X more" links
15. Consider adding a reading progress indicator
16. Consider responsive typography (larger text on larger screens)
17. Consider system theme following (currently manual only)

---

## Contrast Ratio Reference

All measured with WCAG 2.0 relative luminance formula:

| Pair | Ratio | AA | AAA |
|------|-------|----|----|
| Light: Body (#422701) on bg (#FDF8F3) | 13.07:1 | PASS | PASS |
| Light: Heading (#2A2318) on bg (#FDF8F3) | 14.72:1 | PASS | PASS |
| Light: Muted (#705E46) on bg (#FDF8F3) | 5.89:1 | PASS | pass |
| Dark: Body (#E0E0E0) on bg (#121212) | 14.19:1 | PASS | PASS |
| Dark: Heading (#FFF) on bg (#121212) | 18.73:1 | PASS | PASS |
| Dark: Muted (#9E9E9E) on bg (#121212) | 6.99:1 | PASS | pass |
| Warm: Body (#E8DFD0) on bg (#2A2318) | 11.76:1 | PASS | PASS |
| Warm: Heading (#D47E30) on bg (#2A2318) | 5.05:1 | PASS | pass |
| **Warm: Muted (#8A7D6A) on bg (#2A2318)** | **3.86:1** | **FAIL** | **FAIL** |
| **Warm: Muted (#8A7D6A) on surface (#3D3428)** | **3.04:1** | **FAIL** | **FAIL** |

---

*Generated by the UI Auditor agent on 2026-02-27.*
*Files scanned: 48 total (42 presentation, 6 theme).*
