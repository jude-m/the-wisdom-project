# Font System Standardization - Report & Implementation Plan

## Executive Summary

This document analyzes the current typography system in The Wisdom Project and provides a standardized font implementation plan for a reader-focused application across web, mobile, and desktop platforms.

**Status: IMPLEMENTED** - Fonts are bundled, optimized via subsetting, and configured in pubspec.yaml.

---

## Typography Centralization (January 2025)

Created a single source of truth for ALL text styling using Flutter's ThemeExtension pattern.

### Architecture

```
AppFonts (constants)
    ├── Font families (sinhala, serif)
    ├── Fallback stacks
    ├── Base font size
    ├── UI font sizes (badge, label, tab, tree, pageNumber)
    └── UI line height

TextEntryTheme (content styles) ← Uses AppFonts
    ├── Content line heights (paragraph, gatha, heading)
    ├── headingStyles[1-5]
    ├── centeredStyles[0-5]
    ├── paragraphStyle
    ├── gathaStyle
    └── unindentedStyle

AppTypography (UI styles) ← Uses AppFonts
    ├── Labels: badgeLabel, sectionHeader, countBadge
    ├── Chips: chipLabel, chipLabelSelected
    ├── List items: resultTitle, resultSubtitle, resultMatchedText
    ├── Navigation: tabLabelActive/Inactive, treeNodeLabel/Selected
    ├── Dialogs: dialogTitle, menuSectionLabel, segmentedButtonLabel
    ├── Input: searchHint
    └── States: emptyStateMessage, errorMessage, pageNumber
```

### Usage

```dart
// Content styles (reader text)
Text(paragraph, style: context.textEntryTheme.paragraphStyle);
Text(heading, style: context.textEntryTheme.headingStyles[1]);

// UI styles (buttons, badges, tabs)
Text('BJT', style: context.typography.badgeLabel);
Text('Results', style: context.typography.sectionHeader);
Text(label, style: isActive ? context.typography.tabLabelActive : context.typography.tabLabelInactive);
```

### Files Changed

| File | Purpose |
|------|---------|
| `lib/core/theme/app_fonts.dart` | Added UI font size constants |
| `lib/core/theme/app_typography.dart` | **NEW** - 19 UI text styles |
| `lib/core/theme/text_entry_theme.dart` | Content line heights moved here |
| `lib/core/theme/app_theme.dart` | Registered AppTypography for all themes |
| `lib/presentation/widgets/...` | Migrated 14 files to use extensions |

### Benefits

- **Single source of truth**: Change font in one place, affects entire app
- **Separation of concerns**: Content vs UI typography clearly separated
- **Theme support**: All styles adapt to light/dark/warm themes automatically
- **Type-safe access**: `context.typography.badgeLabel` instead of manual `copyWith()`

---

## Part 1: Current Situation Analysis

### What's Currently in Place

| Aspect | Current State | Status |
|--------|--------------|--------|
| **Font Family** | Noto font family (Sinhala, Serif, Sans) | ✅ Implemented |
| **Custom Fonts** | Bundled in assets/fonts/ | ✅ Implemented |
| **Font Optimization** | Subset using pyftsubset | ✅ Optimized (~73% reduction) |
| **Typography System** | Well-structured via `TextEntryTheme` extension | ✅ Good |
| **Base Font Size** | 16px | ✅ Appropriate |
| **Paragraph Line Height** | 1.6 | ✅ Good for reading |
| **Gatha Line Height** | 1.4 | ✅ Appropriate for verse |

### Critical Finding: Content Language

Examining the content files (e.g., `an-1.json`), the "Pali" text is rendered in **Sinhala script** (e.g., "සුත්තන්තපිටකෙ", "අඞ්ගුත්තරනිකායො"). This means:

- **Primary font need**: Sinhala script support is critical
- **Secondary**: Romanized Pali with diacritics (for dictionary entries)
- **Tertiary**: English for UI and translations

### Current Files Structure

```
lib/core/theme/
  app_colors.dart      - Color definitions
  app_fonts.dart       - Font family constants
  app_theme.dart       - Theme construction
  text_entry_theme.dart - Typography extension
  theme_notifier.dart  - Theme state management
```

---

## Part 2: Typography Implementation

### Current Typography Settings

| Metric | Value | Notes |
|--------|-------|-------|
| Base Font Size | 16px | Standard for reading apps |
| Body Font Size | 17.6px (1.1× base) | Slightly larger for readability |
| Paragraph Line Height | 1.6 | Optimized for long-form Sinhala text |
| Gatha Line Height | 1.4 | Tighter for verse formatting |
| Heading Line Height | 1.3 | Compact for titles |
| UI Line Height | 1.4 | Standard for interface elements |
| Line Length | Controlled via max-width | Ensures 45-75 characters |
| Contrast Ratio | Meets WCAG AA | 4.5:1 minimum |

### Serif vs Sans-Serif for Reading

Research findings:

1. **Modern screens support serif well** - High-resolution displays have eliminated the historic advantage of sans-serif on screens
2. **Long-form reading** - Serif fonts (like Georgia, Noto Serif) provide better reading flow for extended text
3. **Multi-script considerations** - Sinhala has complex conjuncts requiring specialized fonts
4. **UI elements** - Sans-serif remains preferable for buttons, labels, and navigation

### Recommended Font Stack

| Purpose | Primary Font | Fallback | Rationale |
|---------|-------------|----------|-----------|
| **Sinhala script (content)** | Noto Sans Sinhala | Iskoola Pota | Best Sinhala rendering, clear glyphs |
| **Romanized Pali/English** | Noto Serif | Georgia, serif | Supports diacritics (ā ī ū ṃ ṅ ñ ṭ ḍ ṇ ḷ) |
| **UI elements** | Noto Sans | Roboto, system-ui | Clean, modern interface |

### Why Noto Family?

1. **Complete Unicode coverage** - Supports all Pali diacritics
2. **Multi-script support** - Same design language across scripts
3. **Cross-platform consistency** - Looks identical on web, iOS, Android, desktop
4. **Open source** - Apache 2.0 license
5. **Google quality** - Well-hinted, professionally designed

---

## Part 3: Key Design Decisions

### Decision 1: Bundle Fonts vs google_fonts Package

**Decision: Bundle fonts in assets** ✅

| Factor | google_fonts | Bundled Fonts |
|--------|-------------|---------------|
| Offline support | Requires caching | Works offline immediately |
| Initial load | Network request | Instant from assets |
| Bundle size | Smaller APK | ~1.2MB (after optimization) |
| Cross-platform | May have issues | Consistent everywhere |
| Desktop apps | Configuration needed | Works natively |

**Rationale**: A Tipitaka reader is for contemplative study, often offline. Reliability trumps bundle size.

### Decision 2: Variable vs Static Fonts

**Decision: Static fonts** ✅

- More mature Flutter support
- Predictable rendering
- We use 3 weights: 400 (Regular), 500 (Medium), 600 (SemiBold)

### Decision 3: Sinhala Font Choice

**Decision: Noto Sans Sinhala** (not Noto Serif Sinhala) ✅

- Better readability on screens
- Clearer glyph differentiation
- Noto Serif Sinhala has limited weight variants

### Decision 4: Consistent Font Weights

**Decision: Use SemiBold (600) instead of Bold (700) for emphasis** ✅

- All three font families now have matching weights: Regular (400), Medium (500), SemiBold (600)
- SemiBold provides sufficient emphasis without being too heavy
- Ensures Flutter doesn't synthesize fake weights

---

## Part 4: Final Implementation

### Font Assets Structure

```
assets/fonts/
  noto-sans-sinhala/
    NotoSansSinhala-Regular.ttf    (240KB - full, not subset)
    NotoSansSinhala-Medium.ttf     (240KB - full, not subset)
    NotoSansSinhala-SemiBold.ttf   (240KB - full, not subset)
  noto-serif/
    NotoSerif-Regular.ttf          (88KB - subset)
    NotoSerif-Italic.ttf           (96KB - subset)
    NotoSerif-Medium.ttf           (88KB - subset)
    NotoSerif-SemiBold.ttf         (88KB - subset)
  noto-sans/
    NotoSans-Regular.ttf           (44KB - subset)
    NotoSans-Medium.ttf            (44KB - subset)
    NotoSans-SemiBold.ttf          (44KB - subset)
```

### pubspec.yaml Configuration

```yaml
flutter:
  fonts:
    # Sinhala script for Pali content (primary reading font)
    - family: NotoSansSinhala
      fonts:
        - asset: assets/fonts/noto-sans-sinhala/NotoSansSinhala-Regular.ttf
        - asset: assets/fonts/noto-sans-sinhala/NotoSansSinhala-Medium.ttf
          weight: 500
        - asset: assets/fonts/noto-sans-sinhala/NotoSansSinhala-SemiBold.ttf
          weight: 600

    # Serif font for romanized Pali with diacritics and English
    - family: NotoSerif
      fonts:
        - asset: assets/fonts/noto-serif/NotoSerif-Regular.ttf
        - asset: assets/fonts/noto-serif/NotoSerif-Italic.ttf
          style: italic
        - asset: assets/fonts/noto-serif/NotoSerif-Medium.ttf
          weight: 500
        - asset: assets/fonts/noto-serif/NotoSerif-SemiBold.ttf
          weight: 600

    # Noto Sans for UI elements
    - family: NotoSans
      fonts:
        - asset: assets/fonts/noto-sans/NotoSans-Regular.ttf
        - asset: assets/fonts/noto-sans/NotoSans-Medium.ttf
          weight: 500
        - asset: assets/fonts/noto-sans/NotoSans-SemiBold.ttf
          weight: 600
```

### Font Configuration Constants

File: `lib/core/theme/app_fonts.dart`
```dart
abstract class AppFonts {
  // Font families (must match pubspec.yaml)
  static const String sinhala = 'NotoSansSinhala';
  static const String serif = 'NotoSerif';
  static const String sans = 'NotoSans';

  // Fallbacks
  static const List<String> sinhalaFallback = ['Iskoola Pota', 'sans-serif'];
  static const List<String> serifFallback = ['Georgia', 'serif'];
  static const List<String> sansFallback = ['Roboto', 'system-ui', 'sans-serif'];

  // Line heights
  static const double paragraphLineHeight = 1.6;
  static const double gathaLineHeight = 1.4;
  static const double headingLineHeight = 1.3;
  static const double uiLineHeight = 1.4;

  // Base sizes
  static const double baseFontSize = 16.0;
}
```

---

## Part 5: Font Optimization (Subsetting)

### Why Subset Fonts?

Original Noto fonts contain thousands of glyphs for 100+ languages. For this app, we only need:
- Sinhala script (U+0D80-0DFF)
- Basic Latin for English (U+0020-007F)
- Pali diacritics (U+0100-017F, U+1E00-1EFF)
- General punctuation (U+2000-206F)

### Subsetting Tool

Using `pyftsubset` from the `fonttools` Python package:

```bash
pip install fonttools
```

### Subsetting Strategy

| Font Family | Unicode Ranges | Rationale |
|-------------|----------------|-----------|
| **Noto Sans Sinhala** | Not subset (kept full) | Only 15% reduction; risk of missing characters not worth it |
| **Noto Serif** | Basic Latin, Latin-1 Supplement, Latin Extended-A, Latin Extended Additional, General Punctuation | Pali diacritics needed (ā ī ū ṃ ṇ ṭ ḍ ḷ ñ) |
| **Noto Sans** | Basic Latin, Latin-1 Supplement, General Punctuation | UI only, no diacritics needed |

### Subsetting Commands

```bash
# Noto Serif (with Pali diacritics)
pyftsubset NotoSerif-Regular.ttf \
  --output-file=NotoSerif-Regular-Subset.ttf \
  --layout-features='*' \
  --unicodes=U+0020-007F,U+00A0-00FF,U+0100-017F,U+1E00-1EFF,U+2000-206F

# Noto Sans (UI only)
pyftsubset NotoSans-Regular.ttf \
  --output-file=NotoSans-Regular-Subset.ttf \
  --layout-features='*' \
  --unicodes=U+0020-007F,U+00A0-00FF,U+2000-206F
```

**Important**: `--layout-features='*'` preserves OpenType shaping rules, critical for correct text rendering.

### Size Reduction Results

| Font Family | Original | After Subset | Reduction |
|-------------|----------|--------------|-----------|
| Noto Sans Sinhala (×3) | 720KB | 720KB (not subset) | 0% |
| Noto Serif (×4) | 2,012KB | 360KB | **82%** |
| Noto Sans (×3) | 1,856KB | 132KB | **93%** |
| **Total** | **~4.5MB** | **~1.2MB** | **73%** |

### Why Noto Sans Sinhala Was Not Subset

- Original: 453 characters → Subset would have: 201 characters
- Reduction: Only 240KB → 204KB per file (15%)
- Removed characters included Latin Extended-A (ā, ī, ū) which could be needed
- Risk of missing symbols (©, €, ।, ॥) not worth the minimal savings
- Sinhala fonts are already lean single-script fonts

### Subsetting Script

A reusable script is available at `assets/fonts/subset_fonts.sh` for future font updates.

---

## Part 6: Files Modified

| File | Changes |
|------|---------|
| `pubspec.yaml` | Font asset declarations |
| `lib/core/theme/app_fonts.dart` | Centralized font configuration |
| `lib/core/theme/app_theme.dart` | Font family settings |
| `lib/core/theme/text_entry_theme.dart` | Font family parameters |
| `web/index.html` | Font preload hints |
| `assets/fonts/subset_fonts.sh` | Subsetting script |

---

## Part 7: Verification Checklist

After implementation, verify:

- [x] Sinhala script renders correctly on all platforms (web, iOS, Android, desktop)
- [x] Pali diacritics (ā ī ū ṃ ṅ ñ ṭ ḍ ṇ ḷ) display correctly in dictionary
- [ ] Fonts load without visible delay on web
- [x] Gatha (verse) text is visually distinct
- [x] Headings use SemiBold weight
- [x] All three themes (light, dark, warm) render correctly
- [x] Offline usage works (fonts bundled)
- [ ] No FOUT (Flash of Unstyled Text) on web

---

## Part 8: Future Considerations

### User-Adjustable Font Size (Not in This Scope)

The architecture supports this via:
- `TextEntryTheme.standard(baseFontSize: userPreference)`
- All sizes are relative multipliers of base

Future implementation path:
1. Create `fontSizeProvider` in Riverpod
2. Store preference in SharedPreferences
3. Pass dynamic base size to TextEntryTheme

### Potential Enhancements

- Font weight customization (for accessibility)
- Line spacing adjustment
- Dyslexia-friendly font option (OpenDyslexic)

---

## Part 9: Lessons from Old tipitaka.lk Project

Analysis of the existing Vue.js tipitaka.lk app reveals proven patterns.

### Fonts Used in Old App

| Font | Family Name | Purpose | Size |
|------|-------------|---------|------|
| **UN-Abhaya.ttf** | `'sinhala'` | Primary Sinhala body text | ~102KB |
| **AbhayaLibre-SemiBold.ttf** | `'heading2'` | Headings and centered text | ~637KB |
| **UN-Alakamanda-4-95.ttf** | `'styled'` | Alternative styling (rarely used) | ~106KB |

### Key Typography Settings (Old App)

| Setting | Value | Notes |
|---------|-------|-------|
| **Base font size** | 16px | Same as current |
| **User adjustment range** | -6 to +12px | Allows 10px to 28px |
| **Line height** | 130% (1.3) | Lower than our 1.6 |
| **Text alignment** | `justify` | For paragraph layout |

### Final Decision: Noto Font Family (CONFIRMED)

**Selected: Noto Sans Sinhala + Noto Serif + Noto Sans**
- Modern, consistent design language
- Better cross-platform support
- Complete Unicode coverage for Pali diacritics
- **~1.2MB bundle size** (after optimization, down from ~4.5MB)
- SemiBold (600) used for emphasis across all families

---

## Part 10: Summary of Implementation

| Aspect | Before | After |
|--------|--------|-------|
| Default font | Roboto | NotoSans (UI), NotoSansSinhala (content) |
| Font bundle size | N/A | ~1.2MB (optimized) |
| Paragraph line height | 1.8 | 1.6 |
| Gatha line height | 1.6 | 1.4 |
| Heading weight | Bold (700) | SemiBold (600) |
| Weight consistency | Mixed | All families: 400, 500, 600 |
| Text justification | Already implemented | No change needed |

---

## Sources

Research references:
- [Best Fonts for Reading - Fontfabric](https://www.fontfabric.com/blog/best-fonts-for-reading/)
- [UI Font Size Guidelines - b13](https://b13.com/blog/designing-with-type-a-guide-to-ui-font-size-guidelines)
- [Serifs and Font Legibility - PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC4612630/)
- [Typography Best Practices 2025 - adoc Studio](https://www.adoc-studio.app/blog/typography-guide)
- [Serif vs Sans Serif - Adobe](https://www.adobe.com/creativecloud/design/discover/serif-vs-sans-serif.html)
- [Mobile Typography Tips - Toptal](https://www.toptal.com/designers/typography/typography-for-mobile-apps)
- [fonttools/pyftsubset](https://fonttools.readthedocs.io/) - Font subsetting tool
- **tipitaka.lk Vue.js app** - Production-tested Sinhala typography patterns
