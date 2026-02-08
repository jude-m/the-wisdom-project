# Light Theme M3 Color Alignment Plan

## Context
The Light theme uses custom colors that don't follow M3's intended role assignments. The biggest issue is `primary` (dark brown `#2A2318`) is being used as a heading text color, but in M3 `primary` means "interactive brand color" — so every default M3 widget (buttons, switches, FABs, sliders, navigation) renders in dark brown instead of cinnamon orange.

This plan realigns the color roles to match M3 semantics while preserving the exact visual appearance of the app — by updating the ColorScheme mapping in `app_theme.dart` and color definitions in `app_colors.dart`, and adjusting the handful of widgets that reference `colorScheme.primary` to mean "heading color."

---

## M3 Color Roles — What Each One Does

### Primary group (your interactive brand color)
| Role | Purpose | Current Value | Problem |
|---|---|---|---|
| `primary` | Fill for buttons, FABs, toggles, active indicators, links | `#2A2318` dark brown | Should be cinnamon orange — dark brown is a text color, not an interactive color |
| `onPrimary` | Text/icons sitting ON a `primary`-filled button | `#FFFFFF` white | OK |
| `primaryContainer` | Softer fill for less-prominent interactive elements (selected tree nodes, active toggle bg) | `accent @ 20% alpha` | Should be a solid opaque light-peach tint |
| `onPrimaryContainer` | Text/icons ON `primaryContainer` | `#2A2318` dark brown | OK conceptually, but value may change |

### Secondary group (your complementary understated accent)
| Role | Purpose | Current Value | Problem |
|---|---|---|---|
| `secondary` | Less prominent interactive elements (chips, filters) | `#D47E30` cinnamon | This IS primary. Secondary should be a different, quieter color |
| `onSecondary` | Text ON `secondary` fills | `#FFFFFF` white | OK |
| `secondaryContainer` | Fill for selected chips, pills, small selections | `#705E46` dark taupe | Too dark for light theme. M3 light containers are pastel/light with dark text |
| `onSecondaryContainer` | Text ON `secondaryContainer` | `#FFFFFF` white | Should be dark text (because container should be light) |

### Tertiary group (contrasting accent for visual balance)
| Role | Purpose | Current Value | Problem |
|---|---|---|---|
| `tertiary` | Contrasting accent color (used for current search match highlight) | `#FFD36A` golden amber | OK for the match highlight purpose |
| `onTertiary` | Text ON `tertiary` fills | **MISSING** | Flutter defaults to white — should be dark brown for contrast on golden amber |
| `tertiaryContainer` | Fill for search/dictionary highlights | `#B8C7AB` sage green | OK |
| `onTertiaryContainer` | Text ON sage green highlights | `#2F3E28` dark green | OK |

### Error group
| Role | Purpose | Current Value | Problem |
|---|---|---|---|
| `error` | Error icons, error text | `#C04000` dark orange-red | OK |
| `onError` | Text on error fills | `#FFFFFF` white | OK |
| `errorContainer` | Background for error banners, error cards | **MISSING** | Defaults don't match warm palette |
| `onErrorContainer` | Text on error backgrounds | **MISSING** | Same |

### Surface group (backgrounds & layered containers)
| Role | Purpose | Current Value | Problem |
|---|---|---|---|
| `surface` | Base background for the app. Most widgets read this. | `#EDE6DD` (a mid-level tan) | Should be your lightest cream `#FDF8F3`. Currently mismatches `scaffoldBackgroundColor` |
| `onSurface` | Primary body text color | `#422701` deep brown | OK |
| `onSurfaceVariant` | Secondary/muted text | `onBackground @ 70% alpha` | Should be a solid color, not alpha-hacked. Use `#705E46` warm taupe |
| `surfaceContainerLowest` | Lightest surface (inactive tabs, base layer) | `#FDF8F3` | OK |
| `surfaceContainerLow` | Slight lift (reader background) | `#F5EEE5` | OK |
| `surfaceContainer` | Standard containers (dropdown menus) | `#EDE6DD` | OK |
| `surfaceContainerHigh` | Prominent containers (search bars, cards) | `#E8DFD0` | OK |
| `surfaceContainerHighest` | Maximum prominence (active tabs, dialogs) | `#E0D7C8` | OK |
| `surfaceDim` | Dimmer alternative canvas | **MISSING** | |
| `surfaceBright` | Brighter alternative canvas | **MISSING** | |

### Inverse group (flipped-contrast elements like snackbars)
| Role | Purpose | Current Value |
|---|---|---|
| `inverseSurface` | Background for snackbars, tooltips | **MISSING** — Flutter default is gray, looks alien in warm theme |
| `inverseOnSurface` | Text on snackbars | **MISSING** |
| `inversePrimary` | Primary accent on dark snackbar bg | **MISSING** |

### Outline group (borders & dividers)
| Role | Purpose | Current Value | Status |
|---|---|---|---|
| `outline` | Standard borders (outlined buttons, inputs) | `#D6C9B8` light tan | OK |
| `outlineVariant` | Subtle dividers | `#D6C9B8 @ 50% alpha` | Should be solid. Use `#E0D7C8` |

### Utility
| Role | Purpose | Current Value |
|---|---|---|
| `scrim` | Dark overlay behind modals/drawers | **MISSING** — defaults to black, which is fine |
| `shadow` | Shadow color | **MISSING** — defaults to black, which is fine |
| `surfaceTint` | Tonal elevation overlay tint | **MISSING** |

---

## What's Missing (Summary)

10 M3 roles are not explicitly set:
1. `onTertiary`
2. `errorContainer`
3. `onErrorContainer`
4. `surfaceDim`
5. `surfaceBright`
6. `inverseSurface`
7. `inverseOnSurface`
8. `inversePrimary`
9. `scrim`
10. `shadow`

Of these, the **inverse** group matters most — any snackbar or tooltip will look out-of-place without them.

---

## Visually Most Drastic Change

### What changes on screen (from most noticeable to least):

**1. Active tab labels, section headers, "Clear All" button, search nav buttons — all change from dark brown to cinnamon orange**
These 27+ usages of `colorScheme.primary` currently render as dark brown text/icons. After the fix, they'll be cinnamon orange because `primary` becomes the interactive accent color.

> **Impact:** This is the single biggest visual shift. Active tab text, the in-page search arrows, the "RECENT SEARCHES" header, the exact-match/proximity toggle active states — all go from dark brown to cinnamon orange.

**2. Selected scope filter chips flip from dark fill + white text to light fill + dark text**
`secondaryContainer` changes from dark taupe `#705E46` -> light beige `#EDE4D8`, and `onSecondaryContainer` from white -> dark brown. So chips like "Sutta", "Vinaya" when selected will look like soft beige pills with dark text instead of dark pills with white text.

**3. Reader headings stay the same (no visible change)**
`TextEntryTheme` receives `headingColor` and `bodyColor` directly — NOT from `colorScheme.primary`. So reader content headings will continue to be dark brown `#2A2318`. No change to the reading experience.

**4. `primaryContainer` backgrounds become solid instead of semi-transparent**
Selected tree nodes, active toggle backgrounds, etc. go from a shimmery alpha overlay to a solid light peach. Subtle difference — they'll look more "solid" and consistent regardless of what's underneath.

**5. Snackbars/tooltips become warm-toned instead of default gray**
Currently they use Flutter's gray defaults. With `inverseSurface` set to dark warm brown, they'll match the app's warm aesthetic.

---

## New Colors Being Added

```
app_colors.dart — LightThemeColors additions:
```

| New Color Constant | Hex Value | Visual | Purpose |
|---|---|---|---|
| `primaryFixed` | `#D47E30` | Cinnamon orange | The new `primary` (swapped from `accent`) |
| `onPrimaryFixed` | `#FFFFFF` | White | Stays the same |
| `primaryContainerFixed` | `#FAEBD7` | Light antique peach | Solid replacement for alpha-hacked container |
| `onPrimaryContainerFixed` | `#3A2510` | Deep warm brown | Text on peach container |
| `secondaryFixed` | `#705E46` | Warm taupe | The new `secondary` (was `muted`) |
| `onSecondaryFixed` | `#FFFFFF` | White | Text on taupe buttons |
| `secondaryContainerFixed` | `#EDE4D8` | Light warm beige | Light container for selected chips |
| `onSecondaryContainerFixed` | `#2A2318` | Dark brown | Text on beige chips |
| `onTertiary` | `#3A2A10` | Dark amber-brown | Text on golden amber |
| `errorContainer` | `#FFDAD0` | Soft peach-red | Error banner backgrounds |
| `onErrorContainer` | `#410001` | Dark maroon | Text on error banners |
| `surfaceDim` | `#DED8CE` | Muted cream | Dimmer canvas option |
| `surfaceBright` | `#FDF8F3` | Warm cream | Bright canvas (= current bg) |
| `inverseSurface` | `#362F25` | Dark warm brown | Snackbar/tooltip backgrounds |
| `inverseOnSurface` | `#F5EEE5` | Light cream | Snackbar text |
| `inversePrimary` | `#FFB77C` | Light orange | Primary on snackbar |
| `scrim` | `#000000` | Black | Modal overlay |
| `shadow` | `#000000` | Black | Drop shadows |
| `outlineVariantSolid` | `#E0D7C8` | Warm sand | Solid replacement for alpha-hacked outlineVariant |

---

## Where to Expect Changes

### Files to modify:

**1. `lib/core/theme/app_colors.dart`** (Color definitions)
- Rename/restructure `LightThemeColors` to add the new constants listed above
- Remove `accent` and `muted` as standalone names (fold them into their M3 roles)
- Keep `background` for `scaffoldBackgroundColor` backward compat

**2. `lib/core/theme/app_theme.dart`** (ColorScheme wiring)
- Remap `primary` -> cinnamon orange (`#D47E30`)
- Remap `secondary` -> warm taupe (`#705E46`)
- Set `primaryContainer` to solid `#FAEBD7`
- Set `secondaryContainer` to light beige `#EDE4D8`
- Set `surface` -> `#FDF8F3` (match scaffold)
- Set `surfaceContainer` -> `#EDE6DD` (current surface value)
- Add all missing roles: `onTertiary`, `errorContainer`, `onErrorContainer`, `surfaceDim`, `surfaceBright`, `inverseSurface`, `inverseOnSurface`, `inversePrimary`, `scrim`, `shadow`
- Set `onSurfaceVariant` to solid `#705E46` (no alpha)
- Set `outlineVariant` to solid `#E0D7C8` (no alpha)
- Update `TextEntryTheme.standard()` call — keep passing `#2A2318` for `headingColor` (reader headings should NOT change)

**3. `lib/core/theme/app_typography.dart`** (No changes needed)
- All typography reads from `colorScheme` already. The visual changes propagate automatically through the new `primary`/`secondary` values.

**4. Presentation widgets — NO changes needed**
- All widgets reference `colorScheme.*` roles. The new values flow through automatically.
- The one area to double-check: widgets using `colorScheme.primary` for text that should remain dark brown. Based on the audit:
  - `sectionHeader` uses `colorScheme.primary` -> will change to cinnamon orange (intentional — section headers become the accent color)
  - `tabLabelActive` uses `colorScheme.primary` -> will change to cinnamon orange (intentional — active tabs get the accent)
  - `TextEntryTheme` fallback uses `colorScheme.primary` -> but the normal path passes explicit colors, so no change in practice

---

## Verification

1. Run `flutter build` to confirm no compile errors
2. Visual spot-check these screens:
   - **Reader screen**: Headings should stay dark brown, body text unchanged
   - **Search bar**: Active toggle buttons (exact match, proximity) should show cinnamon orange accent
   - **Tab bar**: Active tab label should be cinnamon orange, inactive tabs unchanged
   - **Search results panel**: Section headers ("RECENT SEARCHES") should be cinnamon orange
   - **Scope filter chips**: Selected chips should be light beige with dark text (not dark taupe with white text)
   - **Tree navigator**: Selected node should have solid peach background
   - **Snackbar**: Trigger any snackbar — should have dark warm brown background
3. No test changes needed (per CLAUDE.md instructions)
