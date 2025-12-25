# Theme Guidelines — The Wisdom Project

Reference guide for color palettes, typography, and design tokens. Used by [a11y-ui-auditor](file://.agent/workflows/a11y-ui-auditor.md) and during theme reviews.

---

## Color Palettes

### Light Mode (Recommended)

| Token | Hex | Usage | Contrast on Surface |
|-------|-----|-------|---------------------|
| `surface` | `#FAF8F5` | Page background | — |
| `surfaceVariant` | `#F0EDE8` | Cards, elevated surfaces | — |
| `textPrimary` | `#333333` | Body text | 10.5:1 ✅ |
| `textSecondary` | `#666666` | Captions, metadata | 5.7:1 ✅ |
| `textMuted` | `#888888` | Hints, disabled | 3.5:1 ⚠️ (large text only) |
| `primary` | `#5D4E37` | Interactive elements | 7.8:1 ✅ |
| `primaryContainer` | `#D4C9B8` | Selected states | — |
| `accent` | `#C4A35A` | Highlights, warnings | 3.2:1 ⚠️ |
| `success` | `#228B22` | Confirmations | 4.9:1 ✅ |
| `error` | `#8B0000` | Destructive actions | 8.2:1 ✅ |
| `outline` | `#C9C5BE` | Borders, dividers | — |

### Dark Mode (Recommended)

| Token | Hex | Usage | Contrast on Surface |
|-------|-----|-------|---------------------|
| `surface` | `#1E1C1A` | Page background | — |
| `surfaceVariant` | `#2A2725` | Cards, elevated surfaces | — |
| `textPrimary` | `#E8E4DE` | Body text | 12.1:1 ✅ |
| `textSecondary` | `#B0AAA0` | Captions, metadata | 6.8:1 ✅ |
| `textMuted` | `#807A70` | Hints, disabled | 3.4:1 ⚠️ |
| `primary` | `#D4C9B8` | Interactive elements | 9.2:1 ✅ |
| `primaryContainer` | `#5D4E37` | Selected states | — |
| `accent` | `#E8C46A` | Highlights, warnings | 8.5:1 ✅ |
| `success` | `#4CAF50` | Confirmations | 7.2:1 ✅ |
| `error` | `#CF6679` | Destructive actions | 5.4:1 ✅ |
| `outline` | `#4A4540` | Borders, dividers | — |

### Color Rationale

**60-30-10 Rule**:
- **60% Surface/Background** — Warm neutrals, easy on eyes
- **30% Text colors** — High contrast for readability
- **10% Accent/Primary** — Used sparingly for interaction

**Why these colors?**
- **Warm earth tones** — Evoke natural materials (paper, wood, saffron robes)
- **Soft contrast** — Reduces eye strain for long reading sessions
- **Saffron accent** — Traditional Buddhist color, warm and inviting
- **No pure black/white** — Softer edges, more peaceful

---

## Typography

### Recommended Type Scale

| Element | Size | Weight | Line Height | Font |
|---------|------|--------|-------------|------|
| Display | 32sp | Regular | 1.25 | Noto Serif |
| Headline | 24sp | Medium | 1.3 | Noto Serif |
| Title | 20sp | Medium | 1.4 | Noto Sans |
| Body Large | 18sp | Regular | 1.6 | Noto Serif |
| Body | 16sp | Regular | 1.6 | Noto Serif |
| Label | 14sp | Medium | 1.4 | Noto Sans |
| Caption | 12sp | Regular | 1.4 | Noto Sans |

### Font Recommendations

| Purpose | Primary | Fallback |
|---------|---------|----------|
| **Sutta text** | Noto Serif | Georgia, serif |
| **UI elements** | Noto Sans | Roboto, system-ui |
| **Sinhala script** | Noto Sans Sinhala | — |
| **Pali diacritics** | Noto Serif | Ensure: ā ī ū ṃ ṅ ñ ṭ ḍ ṇ ḷ |

### Special Considerations

1. **Line height for Sinhala**: Minimum 1.6 (script has tall glyphs)
2. **Pali diacritics**: Test rendering of: `āīūṃṅñṭḍṇḷ`
3. **Verse formatting**: Indent gāthā lines by 16-24px

---

## Spacing Scale

Use consistent spacing based on 4px base unit:

```
4   - Minimal (icon-to-label)
8   - Tight (inline elements)
12  - Compact (list items)
16  - Standard (paragraph spacing)
24  - Relaxed (section gaps)
32  - Loose (major sections)
48  - Spacious (page margins)
```

---

## Platform Guidelines Reference

### Material 3 (Android/Flutter default)

| Aspect | Guideline |
|--------|-----------|
| **Tap targets** | 48x48dp minimum |
| **Typography** | Use `TextTheme` from `Theme.of(context)` |
| **Elevation** | Tonal elevation (surface tint, not shadows) |
| **States** | hover → +8% overlay, pressed → +12% overlay |
| **Focus** | 3dp focus ring, primary color |

### Apple HIG (iOS)

| Aspect | Guideline |
|--------|-----------|
| **Tap targets** | 44x44pt minimum |
| **Typography** | Support Dynamic Type |
| **Dark mode** | True black (#000) acceptable for OLED |
| **Navigation** | Bottom tab bar preferred |
| **Safe areas** | Respect notch/home indicator |

---

## Color Theory Quick Reference

### Harmony Types

| Type | Description | Example |
|------|-------------|---------|
| **Analogous** | Adjacent on color wheel | Browns + Oranges + Golds ✅ |
| **Complementary** | Opposite on wheel | Brown + Blue (use sparingly) |
| **Triadic** | Three equidistant | Avoid for reading apps |

### Accessibility Colors

| State | Color Type | Notes |
|-------|------------|-------|
| **Error** | Warm red | Not too bright, #8B0000 not #FF0000 |
| **Success** | Forest green | Earthy, #228B22 not #00FF00 |
| **Warning** | Amber/Saffron | Natural, #C4A35A |
| **Info** | Muted blue | Optional, use sparingly |

---

## WCAG Contrast Requirements

| Element | AA Minimum | AAA Enhanced |
|---------|------------|--------------|
| Body text (<18pt) | 4.5:1 | 7:1 |
| Large text (≥18pt or 14pt bold) | 3:1 | 4.5:1 |
| UI components | 3:1 | — |
| Icons | 3:1 | — |

**Tools for checking**:
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)
- Figma: Stark plugin
- VS Code: Color Highlight extension

---

## Theme File Implementation

### Expected Structure

```dart
// lib/core/theme/app_theme.dart

class AppColors {
  // Light mode
  static const surface = Color(0xFFFAF8F5);
  static const textPrimary = Color(0xFF333333);
  static const textSecondary = Color(0xFF666666);
  static const primary = Color(0xFF5D4E37);
  static const accent = Color(0xFFC4A35A);
  static const success = Color(0xFF228B22);
  static const error = Color(0xFF8B0000);
  
  // Dark mode
  static const surfaceDark = Color(0xFF1E1C1A);
  static const textPrimaryDark = Color(0xFFE8E4DE);
  // ... etc
}

class AppTextStyles {
  static const bodyLarge = TextStyle(
    fontSize: 18,
    height: 1.6,
    fontFamily: 'NotoSerif',
  );
  // ... etc
}
```

### Theme Audit Checklist

When reviewing theme files:

- [ ] All foreground/background combinations meet WCAG AA
- [ ] Dark mode has equivalent semantic colors
- [ ] Spacing uses consistent scale (multiples of 4)
- [ ] Typography scale is consistent
- [ ] Colors defined as constants, not inline
- [ ] No pure black (#000) on pure white (#FFF)
