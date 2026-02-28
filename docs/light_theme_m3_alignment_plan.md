# Light Theme M3 Color Alignment Plan

## Scope
- **Light theme only** — Dark and Warm themes are untouched in this pass.

## Context
The Light theme used custom color names (`accent`, `muted`, `secondaryAccent`) that didn't map to M3 role semantics. The `primary` slot held a dark brown heading color (`#2A2318`), which meant every default M3 widget rendered in dark brown instead of a proper interactive color. Multiple M3 roles were missing entirely, and several colors were alpha-hacked instead of solid.

This plan realigned the color roles to match M3 semantics while preserving the calm, scholarly visual identity of the app. The key design decision: `primary` is set to a deep warm brown (`#3B220B`) — dark enough to blend naturally with the warm palette while technically occupying the correct M3 role. Text labels (tabs, headers) use `onSurface` instead of `primary`, so the UI looks nearly identical to before.

---

## Audit Results

All `LightThemeColors.*` references were **centralized** in two files:
- `lib/core/theme/app_colors.dart` — definitions
- `lib/core/theme/app_theme.dart` — wiring into ColorScheme

No presentation widgets directly referenced `LightThemeColors.*` — everything flows through `Theme.of(context).colorScheme` or theme extensions. This made the refactor safe and localized.

`LightThemeColors.muted` was defined but **never referenced** anywhere — safely renamed.

---

## M3 Color Roles — Reference

### Primary group (interactive brand color)
| Role | Old Value | New Value | Notes |
|---|---|---|---|
| `primary` | `#2A2318` dark brown | `#3B220B` deep warm brown | Dark enough to blend, warm enough to feel intentional |
| `onPrimary` | `#FFFFFF` | `#FFFFFF` | Unchanged |
| `primaryContainer` | `accent @ 20% alpha` | `#FAEBD7` light antique peach | Solid — no more alpha hack |
| `onPrimaryContainer` | `#2A2318` | `#3A2510` deep warm brown | Slightly adjusted for peach bg |

### Secondary group (understated accent)
| Role | Old Value | New Value | Notes |
|---|---|---|---|
| `secondary` | `#D47E30` cinnamon | `#705E46` warm taupe | Quieter, complementary |
| `onSecondary` | `#FFFFFF` | `#FFFFFF` | Unchanged |
| `secondaryContainer` | `#705E46` dark taupe | `#705E46` dark taupe | **Kept as-is** — deliberate design choice for dark selected chips |
| `onSecondaryContainer` | `#FFFFFF` | `#FFFFFF` | **Kept as-is** — white text on dark chips |

### Tertiary group (contrasting accent)
| Role | Old Value | New Value | Notes |
|---|---|---|---|
| `tertiary` | `#FFD36A` golden amber | `#FFD36A` | Unchanged |
| `onTertiary` | **MISSING** | `#3A2A10` dark amber-brown | New — proper contrast on amber |
| `tertiaryContainer` | `#B8C7AB` sage green | `#B8C7AB` | Unchanged — well-suited for search highlights |
| `onTertiaryContainer` | `#2F3E28` dark green | `#2F3E28` | Unchanged |

### Error group
| Role | Old Value | New Value | Notes |
|---|---|---|---|
| `error` | `#C04000` orange-red | `#B3261E` cherry red | Changed — old orange-red too close to warm browns |
| `onError` | `#FFFFFF` | `#FFFFFF` | Unchanged |
| `errorContainer` | **MISSING** | `#FFDAD0` soft peach-red | New |
| `onErrorContainer` | **MISSING** | `#410001` dark maroon | New |

### Surface group
| Role | Old Value | New Value | Notes |
|---|---|---|---|
| `surface` | `#EDE6DD` mid-tan | `#FDF8F3` warm cream | Now matches `scaffoldBackgroundColor` |
| `onSurface` | `#422701` deep brown | `#422701` | Unchanged |
| `onSurfaceVariant` | `onBackground @ 70% alpha` | `#705E46` warm taupe | Solid — no more alpha hack |
| `surfaceContainerLowest` | `#FDF8F3` | `#FDF8F3` | Unchanged |
| `surfaceContainerLow` | `#F5EEE5` | `#F5EEE5` | Unchanged |
| `surfaceContainer` | `#EDE6DD` | `#EDE6DD` | Unchanged (old `surface` value lives here now) |
| `surfaceContainerHigh` | `#E8DFD0` | `#E8DFD0` | Unchanged |
| `surfaceContainerHighest` | `#E0D7C8` | `#E0D7C8` | Unchanged |
| `surfaceDim` | **MISSING** | `#DED8CE` muted cream | New |
| `surfaceBright` | **MISSING** | `#FDF8F3` warm cream | New |
| `surfaceTint` | **MISSING** | `#3B220B` deep warm brown | New — matches `primary` for warm elevation tint |

### Inverse group (snackbars, tooltips)
| Role | Old Value | New Value |
|---|---|---|
| `inverseSurface` | **MISSING** | `#362F25` dark warm brown |
| `inverseOnSurface` | **MISSING** | `#F5EEE5` light cream |
| `inversePrimary` | **MISSING** | `#FFB77C` light orange |

### Outline group
| Role | Old Value | New Value | Notes |
|---|---|---|---|
| `outline` | `#D6C9B8` | `#D6C9B8` | Unchanged |
| `outlineVariant` | `#D6C9B8 @ 50% alpha` | `#E0D7C8` warm sand | Solid — no more alpha hack |

### Utility
| Role | Old Value | New Value | Notes |
|---|---|---|---|
| `scrim` | **MISSING** | `#000000` black | Standard |
| `shadow` | **MISSING** | `#3A2510` warm dark brown | Warm-tinted instead of harsh pure black |

---

## Full Rename Map (`LightThemeColors`)

| Old Name | Old Value | New Name | New Value | M3 Role |
|---|---|---|---|---|
| `primary` | `#2A2318` | `heading` | `#2A2318` | custom (reader headings only) |
| `onPrimary` | `#FFFFFF` | `onPrimary` | `#FFFFFF` | stays same |
| `accent` | `#D47E30` | `primary` | `#3B220B` | M3 `primary` (deep warm brown) |
| `muted` | `#705E46` | `secondary` | `#705E46` | M3 `secondary` |
| `secondaryAccent` | `#FFD36A` | `tertiary` | `#FFD36A` | M3 `tertiary` |
| `onBackground` | `#422701` | `onSurface` | `#422701` | M3 `onSurface` |
| `divider` | `#D6C9B8` | `outline` | `#D6C9B8` | M3 `outline` |

**Alternative primary colors** are kept as comments in `app_colors.dart` for easy swapping:
```
#3B220B  (current) — Deep warm brown, blends naturally
#4A3218             — Earthy amber-brown, subtle step up
#5C3D1E             — Medium warm brown, noticeable warmth
#7D5A2F             — Warm brown, gentle distinction from text
#A0612B             — Dark cinnamon, clearly interactive
```

---

## Design Decisions

### Primary color: deep warm brown (`#3B220B`) instead of bright cinnamon
Bright cinnamon (`#D47E30`) was too attention-grabbing for a scholarly Tipitaka reading app. It overwhelmed chips, tab labels, and link text. After testing multiple options, `#3B220B` was chosen — dark enough to feel calm and natural, warm enough to have character. If users ever find interactive elements hard to identify, the primary can be bumped toward `#7D5A2F` or `#A0612B` with a one-line change.

### Typography: `onSurface` instead of `primary` for text labels
`sectionHeader` and `tabLabelActive` in `AppTypography` now use `colorScheme.onSurface` (dark brown `#422701`) instead of `colorScheme.primary`. This keeps text labels looking the same as before — dark and readable — while `primary` is reserved for M3 widget fills and indicators.

### Selected chips: kept dark (`secondaryContainer` = `#705E46`)
M3 convention says `secondaryContainer` should be light in a light theme, but the app's dark taupe chips with white text are a deliberate design choice that looks right in this palette. The values are kept as-is.

### Error color: cherry red (`#B3261E`) replaces orange-red (`#C04000`)
The old error color was too close to the warm brown palette and could be confused with primary interactive elements. Cherry red is clearly distinct.

### Shadow: warm dark brown (`#3A2510`) instead of pure black
Pure black shadows look harsh against a warm cream palette. Warm dark brown shadows feel part of the environment.

### Sage green tertiary container (`#B8C7AB`): verified correct
Low saturation, appropriate lightness for highlights, ~5.5:1 contrast with `onTertiaryContainer` text. The cool-toned green provides natural contrast against the warm palette — fitting for a Buddhist text app (nature/monastery aesthetic).

---

## What Changed (Files)

### `lib/core/theme/app_colors.dart` (Color definitions)
- Full rename of all `LightThemeColors` constants per the rename map
- Added 18 new M3 role constants
- Removed `accent`, `muted`, `secondaryAccent`, `onBackground`, `divider` as standalone names
- Added `heading` as a custom constant for reader headings
- Alternative primary colors listed as comments for easy swapping
- `error` changed from `#C04000` → `#B3261E`
- `shadow` set to `#3A2510` (warm, not black)

### `lib/core/theme/app_theme.dart` (ColorScheme wiring)
- All 35+ M3 roles now explicitly set via `ColorScheme.light(...)` — no missing roles
- No more `.withValues(alpha: ...)` hacks — all solid colors
- `cardColor` → `surfaceContainer`, `dividerColor` → `outline`
- `TextEntryTheme.standard()` uses `LightThemeColors.heading` for reader headings

### `lib/core/theme/app_typography.dart` (Two changes)
- `sectionHeader` color: `colorScheme.primary` → `colorScheme.onSurface`
- `tabLabelActive` color: `colorScheme.primary` → `colorScheme.onSurface`

### Not changed
- `lib/core/theme/text_entry_theme.dart` — fallback at line 249 uses `colorScheme.primary` for heading color, which would now give deep warm brown instead of the original dark brown if the extension is missing. Since the extension is always registered, this never triggers in practice. No code change needed.
- All presentation widgets — no changes needed, colors flow through `colorScheme`
- Dark theme, Warm theme — untouched

---

## Visual Changes (Most → Least Noticeable)

**1. `primaryContainer` backgrounds become solid instead of semi-transparent**
Selected tree nodes, active toggle backgrounds go from alpha overlay to solid light peach `#FAEBD7`. Subtle — they look more "solid" and consistent.

**2. Snackbars/tooltips become warm-toned**
With `inverseSurface` set to dark warm brown `#362F25`, they match the warm aesthetic instead of Flutter's default gray.

**3. Error color shifts from orange-red to cherry red**
`#C04000` → `#B3261E`. More clearly "error" and distinct from the warm palette.

**4. Elevated surfaces get warm tint**
`surfaceTint: #3B220B` gives elevated overlays a subtle warm brown tint.

**5. Everything else looks the same**
Tab labels, section headers, reader headings, selected chips, body text — all unchanged visually.

---

## Verification

1. `flutter build macos --debug` — **passed** with zero errors
2. Visual spot-check:
   - **Reader screen**: Headings dark brown, body text unchanged
   - **Tab bar**: Active/inactive tabs look the same as before (dark brown text)
   - **Search results**: Section headers ("TITLES", "FULL TEXT") dark brown
   - **Scope filter chips**: Selected chips dark taupe + white text (unchanged)
   - **Tree navigator**: Selected node has solid peach background
   - **Elevated overlays**: Subtle warm tint on recent search, inline dictionary
   - **Snackbar**: Dark warm brown background
3. No test changes needed (per CLAUDE.md instructions)
