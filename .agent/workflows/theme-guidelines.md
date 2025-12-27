# Theme Guidelines — The Wisdom Project

Design system reference for The Wisdom Project, a Tipitaka reader app. This document defines **design decisions** (the "what"). The [world-class-ui-auditor](file://.agent/workflows/world-class-ui-auditor.md) verifies implementation (the "how to check").

---

## 1. Design Philosophy

### Core Principles

| Principle | Meaning |
|-----------|---------|
| **Peaceful** | Opening the app feels like entering a quiet space |
| **Humble** | Non-commercial, respects the sacred nature of texts |
| **Readable** | Typography optimized for long-form contemplative reading |
| **Inclusive** | Accessible to all abilities, ages, and cultures |
| **Timeless** | Classic aesthetics that won't feel dated in 5 years |

### This App Should Feel Like

- A quiet library reading room
- Quality hardcover book typography
- Traditional palm-leaf manuscript presentation (dignified, spacious)
- Japanese minimalism — *ma* (間) — the beauty of negative space

### This App Should NOT Feel Like

| Avoid | Why |
|-------|-----|
| Social media app | No notifications, gamification, engagement metrics |
| Corporate/enterprise app | No logo-heavy branding, no upsells |
| News app | No urgency, no "breaking" anything, no red badges |
| Productivity app | No aggressive task management vibes |
| Trendy modern app | No gradients, glassmorphism, or flavor-of-the-year aesthetics |

### The Monastic Test

> Would a Buddhist monastic feel comfortable using this app for study?

If the aesthetic feels flashy, commercial, or distracting — it fails.

---

## 2. Color System

Colors are defined in `lib/core/theme/app_colors.dart`. Three themes support different reading contexts.

### 2.1 Light Theme

*Warm cream background with dark brown text — perfect for daytime reading.*

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#FDF8F3` | Page background (warm cream) |
| `surface` | `#EDE6DD` | Cards, panels |
| `surfaceContainerHigh` | `#E8DFD0` | Gāthā backgrounds, highlights |
| `primary` | `#2A2318` | Headings (dark brown) |
| `onBackground` | `#422701` | Body text (deep brown) |
| `muted` | `#705E46` | Secondary text, captions |
| `accent` | `#D47E30` | Links, interactive elements (cinnamon) |
| `divider` | `#D6C9B8` | Borders, separators |
| `error` | `#C04000` | Destructive actions |
| `secondaryContainer` | `#705E46` | Selected states |

**Rationale**: Warm earth tones evoke natural materials — aged paper, wood, saffron robes. Easier on eyes than pure white for long reading sessions.

### 2.2 Dark Theme

*High contrast for low-light reading — WCAG AAA compliant.*

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#121212` | Page background (near black) |
| `surface` | `#1E1E1E` | Cards, panels |
| `surfaceContainerHigh` | `#2A2A2A` | Gāthā backgrounds, highlights |
| `primary` | `#FFFFFF` | Headings (pure white) |
| `onBackground` | `#E0E0E0` | Body text (light gray) |
| `muted` | `#9E9E9E` | Secondary text |
| `accent` | `#FF8C00` | Links, interactive (bright orange) |
| `divider` | `#424242` | Borders |
| `error` | `#FF6B6B` | Destructive actions |

**Rationale**: True dark background for OLED efficiency and nighttime reading. High contrast meets AAA standards.

### 2.3 Warm Theme ⭐

*Signature Buddhist aesthetic — earthy dark browns with warm text.*

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#2A2318` | Page background (dark warm brown) |
| `surface` | `#3D3428` | Cards, panels |
| `surfaceContainerHigh` | `#4A3E2E` | Gāthā backgrounds |
| `primary` | `#D47E30` | Headings (cinnamon orange) |
| `onBackground` | `#E8DFD0` | Body text (warm off-white) |
| `muted` | `#8A7D6A` | Secondary text |
| `accent` | `#D6B588` | Links, interactive (gold) |
| `divider` | `#524535` | Borders |
| `error` | `#FF8A65` | Destructive actions |

**Rationale**: This is our distinctive theme. Colors inspired by traditional robe colors, temple interiors, and aged manuscripts. Use this theme in marketing screenshots.

### 2.4 Color Distribution

Follow the **60-30-10 rule**:

| Proportion | Usage | Tokens |
|------------|-------|--------|
| 60% | Background/surface | `background`, `surface`, `surfaceContainer*` |
| 30% | Text | `onBackground`, `muted`, `primary` |
| 10% | Accent/interactive | `accent`, `error`, `secondaryContainer` |

### 2.5 Interactive States

How colors shift on user interaction:

| State | Light Theme | Dark Theme | Warm Theme |
|-------|-------------|------------|------------|
| **Hover** | Surface +4% darker | Surface +8% lighter | Surface +6% lighter |
| **Pressed** | Surface +8% darker | Surface +12% lighter | Surface +10% lighter |
| **Focused** | 2dp outline in `accent` | 2dp outline in `accent` | 2dp outline in `accent` |
| **Disabled** | 38% opacity | 38% opacity | 38% opacity |
| **Selected** | `secondaryContainer` bg | `secondaryContainer` bg | `secondaryContainer` bg |

### 2.6 Semantic Colors

| Purpose | Light | Dark | Warm | Usage |
|---------|-------|------|------|-------|
| **Error** | `#C04000` | `#FF6B6B` | `#FF8A65` | Destructive actions, validation errors |
| **Success** | `#228B22` | `#4CAF50` | `#81C784` | Confirmations, completed states |
| **Warning** | `#D47E30` | `#FF8C00` | `#D6B588` | Cautions (often same as accent) |
| **Info** | `#5D4E37` | `#B0AAA0` | `#8A7D6A` | Neutral information (use sparingly) |

---

## 3. Typography

### 3.1 Type Scale

| Element | Size | Weight | Line Height | Font | Usage |
|---------|------|--------|-------------|------|-------|
| Display | 32sp | Regular | 1.25 | Noto Serif | Hero text, splash |
| Headline | 24sp | Medium | 1.3 | Noto Serif | Screen titles |
| Title | 20sp | Medium | 1.35 | Noto Sans | Section headers |
| Body Large | 18sp | Regular | 1.6 | Noto Serif | Sutta text (primary) |
| Body | 16sp | Regular | 1.6 | Noto Serif | Sutta text (compact) |
| Label | 14sp | Medium | 1.4 | Noto Sans | UI labels, buttons |
| Caption | 12sp | Regular | 1.4 | Noto Sans | Metadata, timestamps |

### 3.2 Responsive Typography

Text sizes adjust based on screen width:

| Element | Compact (<600) | Medium (600-840) | Expanded (>840) |
|---------|----------------|------------------|-----------------|
| Body Large | 18sp | 19sp | 20sp |
| Body | 16sp | 17sp | 18sp |
| Headline | 24sp | 26sp | 28sp |
| Display | 32sp | 36sp | 40sp |

### 3.3 Letter Spacing

| Element | Spacing | Reason |
|---------|---------|--------|
| Display | -0.5px | Tighten large text |
| Headline | -0.25px | Slightly tighter |
| Body | 0 (normal) | Optimal readability |
| Caption | +0.2px | Open up small text |
| ALL CAPS (if used) | +1.5px | Required for legibility |

### 3.4 Font Stack

| Purpose | Primary | Fallback |
|---------|---------|----------|
| Sutta text (Pali/English) | Noto Serif | Georgia, serif |
| UI elements | Noto Sans | Roboto, system-ui |
| Sinhala script | Noto Sans Sinhala | Iskoola Pota |

**Required character support**: `ā ī ū ṃ ṅ ñ ṭ ḍ ṇ ḷ` (Pali diacritics)

### 3.5 Multi-Script Considerations

| Script | Min Line Height | Notes |
|--------|-----------------|-------|
| English | 1.5 | Standard |
| Pali (romanized) | 1.5 | Same as English |
| Sinhala | 1.7–1.8 | Tall glyphs, complex conjuncts |
| Mixed Pali+Sinhala | 1.8 | Use tallest requirement |

**Sinhala-specific**:
- Font size +1-2sp larger than English equivalent
- Test rendering of: `අ ආ ඉ ඊ උ ඌ ඍ එ ඒ ඓ ඔ ඕ ඖ`
- Verify conjunct consonants render correctly

### 3.6 Line Length (Measure)

Optimal reading requires controlled line length:

| Context | Target | Max Width |
|---------|--------|-----------|
| Mobile (<600) | 45–55 chars | 100% with 16px padding |
| Tablet (600-900) | 55–65 chars | 600px |
| Desktop (>900) | 65–75 chars | 720px |

**Implementation**: Always wrap reading content in `ConstrainedBox(maxWidth: 720)`.

### 3.7 Paragraph & Section Spacing

| Element | Spacing |
|---------|---------|
| Between paragraphs | 1em (16px at body size) |
| Between sections | 2em (32px) |
| After headings | 0.5em (8px) |
| Before headings | 1.5em (24px) |

### 3.8 Micro-Typography Rules

Use typographically correct characters in all UI strings:

| Wrong | Correct | Character | Notes |
|-------|---------|-----------|-------|
| `--` | `—` | Em-dash (U+2014) | For breaks in thought |
| `-` | `–` | En-dash (U+2013) | For ranges: "1–10" |
| `...` | `…` | Ellipsis (U+2026) | Single character |
| `"` `"` | `"` `"` | Curly quotes (U+201C/D) | Opening/closing |
| `'` | `'` | Apostrophe (U+2019) | Also closing single quote |
| `'` `'` | `'` `'` | Single quotes (U+2018/9) | Opening/closing |

**Additional rules**:
- No double spaces after periods
- Use non-breaking space before units: `5 km` → `5 km` (U+00A0)

---

## 4. Spacing & Layout

### 4.1 Spacing Scale

Base unit: **4px**. All spacing should use this scale:

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4px | Icon-to-label gap |
| `sm` | 8px | Tight spacing, inline elements |
| `md` | 12px | List item padding |
| `base` | 16px | Standard padding, paragraph spacing |
| `lg` | 24px | Section gaps |
| `xl` | 32px | Major section dividers |
| `xxl` | 48px | Page margins, large gaps |

**Rule**: Never use arbitrary values like 15px, 17px, 23px. Always use the scale.

### 4.2 Responsive Breakpoints

| Name | Width | Layout Pattern |
|------|-------|----------------|
| `compact` | <600px | Single column, bottom navigation |
| `medium` | 600–840px | Single column, navigation rail optional |
| `expanded` | 840–1200px | Two-pane layout possible |
| `large` | 1200–1600px | Two-pane with side navigation |
| `extraLarge` | >1600px | Three-pane possible |

### 4.3 Safe Areas

Always respect platform safe areas:
- iOS notch and home indicator
- Android navigation bar and status bar
- Desktop window controls

---

## 5. Reading-Specific Design

### 5.1 Scripture Element Styling

| Element | Treatment |
|---------|-----------|
| **Gāthā (verse)** | Indent 24px, `surfaceContainerHigh` background, Body size |
| **Uddāna (summary)** | Italic, slightly smaller, `surfaceContainerHigh` background |
| **Nidāna (introduction)** | Normal body style |
| **Prose** | Standard body typography |
| **Speaker labels** | Bold, same line or above quote |

### 5.2 Verse (Gāthā) Formatting

```
┌─────────────────────────────────────────┐
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ (surfaceContainerHigh bg)       │    │
│  │                                 │    │
│  │    Manopubbaṅgamā dhammā,       │    │  ← 24px indent
│  │    manoseṭṭhā manomayā;         │    │
│  │    Manasā ce paduṭṭhena,        │    │
│  │    bhāsati vā karoti vā.        │    │
│  │                                 │    │
│  └─────────────────────────────────┘    │
│                                         │
│  Regular prose continues here...        │
│                                         │
└─────────────────────────────────────────┘
```

### 5.3 Parallel Text Layout

For Pali + Translation display:

**Mobile (stacked)**:
```
┌─────────────────────────┐
│ Pali text here...       │
├─────────────────────────┤
│ Sinhala translation...  │
└─────────────────────────┘
```

**Tablet+ (side-by-side)**:
```
┌────────────────┬────────────────┐
│ Pali text...   │ Sinhala...     │
│                │                │
└────────────────┴────────────────┘
```

### 5.4 Footnote & Reference Styling

| Element | Style |
|---------|-------|
| Footnote marker | Superscript number in `accent` color |
| Footnote text | Caption size, `muted` color |
| Cross-reference link | `accent` color, underline on hover |
| External link | `accent` color + external icon |

### 5.5 User Annotation Colors

For highlights and bookmarks:

| Color | Hex (Light) | Hex (Dark/Warm) | Purpose |
|-------|-------------|-----------------|---------|
| Yellow | `#FFF3B0` | `#4A4000` | Default highlight |
| Green | `#C8E6C9` | `#1B3D1B` | Important passages |
| Blue | `#BBDEFB` | `#0D3B66` | Questions, review later |
| Pink | `#F8BBD9` | `#5D2A42` | Personal reflections |

---

## 6. Motion & Animation

### 6.1 Timing Scale

| Token | Duration | Usage |
|-------|----------|-------|
| `instant` | 0ms | Toggle states (checkbox, switch) |
| `fast` | 100–150ms | Micro-interactions (button feedback) |
| `normal` | 200–300ms | Standard transitions (page, overlay) |
| `slow` | 400–500ms | Emphasis, onboarding reveals |

### 6.2 Easing Curves

| Curve | Usage |
|-------|-------|
| `Curves.easeOut` | Elements entering view |
| `Curves.easeIn` | Elements exiting view |
| `Curves.easeInOut` | Position/size changes |
| `Curves.linear` | Progress indicators only |

### 6.3 Motion Principles

| Do | Don't |
|----|-------|
| Calm, purposeful motion | Bouncy, playful animations |
| Fades and slides | Scaling, rotation, 3D effects |
| Subtle feedback | Attention-grabbing motion |
| Respect reduced motion | Ignore accessibility settings |

**Reduced motion**: Always check `MediaQuery.disableAnimationsOf(context)` and provide instant alternatives.

### 6.4 Prohibited Animations

- ❌ Parallax scrolling effects
- ❌ Auto-playing animations
- ❌ Bouncing/elastic effects
- ❌ Continuous looping animations (except loading)
- ❌ Flashing or strobing (WCAG violation)

---

## 7. Iconography

### 7.1 Icon System

| Context | Size | Stroke | Source |
|---------|------|--------|--------|
| Navigation | 24dp | 1.5px | Material Symbols |
| In-button | 20dp | 1.5px | Material Symbols |
| Inline with text | 16-18dp | 1.5px | Material Symbols |
| Decorative | 32-48dp | 1.5px | Material Symbols |

### 7.2 Icon Style

- **Outlined** style preferred (not filled) — lighter, more peaceful
- **Rounded** corners — softer appearance
- Use semantic icons consistently (same icon = same meaning everywhere)

### 7.3 Custom Icons

If creating custom icons for Buddhist/Pali concepts:
- Match Material Symbols stroke weight (1.5px at 24dp)
- Keep simple, single-color
- Test at small sizes for legibility

---

## 8. Implementation Reference

### 8.1 File Structure

```
lib/core/theme/
├── app_colors.dart      ← Color definitions (Light/Dark/Warm)
├── app_theme.dart       ← ThemeData construction
├── text_styles.dart     ← TextStyle definitions
├── spacing.dart         ← Spacing constants
└── durations.dart       ← Animation timing constants
```

### 8.2 Theme Switching

Support three modes:
1. **System** — Follow device light/dark setting
2. **Manual** — User selects Light, Dark, or Warm
3. **Scheduled** — Optional: time-based switching

### 8.3 Design Token Usage

Always use tokens, never hardcode values:

```dart
// ❌ Wrong
Container(color: Color(0xFFFDF8F3))
Text('Hello', style: TextStyle(fontSize: 16))

// ✅ Correct  
Container(color: Theme.of(context).colorScheme.surface)
Text('Hello', style: Theme.of(context).textTheme.bodyMedium)
```

---

## 9. Quick Reference Card

### Colors (Light Theme)
- Background: `#FDF8F3`
- Text: `#422701`
- Accent: `#D47E30`

### Typography
- Body: Noto Serif, 16-18sp, 1.6 line height
- Max width: 720px

### Spacing
- Base unit: 4px
- Standard padding: 16px

### Motion
- Standard transition: 200-300ms
- Curve: easeInOut

### Accessibility
- Minimum contrast: 4.5:1 (body), 3:1 (large text)
- Minimum tap target: 48×48dp

---

## Changelog

| Date | Change |
|------|--------|
| [Current] | Initial comprehensive version |
