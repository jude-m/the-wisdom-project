# Theme Implementation Guide
## The Wisdom Project

This guide explains how to implement and use the 3 theme system in the app. Follow these instructions carefully.

---

## Overview

We have **3 themes** for users to choose from:

| Theme | Description | Best For |
|-------|-------------|----------|
| ☀️ **Light** | Warm cream background, dark brown headings | Daytime reading, default |
| 🌙 **Dark** | High contrast black with white text | Night reading, accessibility |
| 🔥 **Warm** | Earthy dark browns with warm text | Evening reading, signature look |

---

## Color Definitions

### ☀️ Light Theme

```dart
class LightThemeColors {
  // Backgrounds
  static const background = Color(0xFFFDF8F3);      // Warm cream
  static const surface = Color(0xFFEDE6DD);         // Slightly darker cream (cards)
  static const surfaceContainer = Color(0xFFE8DFD0); // Gatha/verse background
  
  // Text
  static const primary = Color(0xFF2A2318);         // Dark brown (headings)
  static const onPrimary = Color(0xFFFFFFFF);       // White (text on buttons)
  static const onBackground = Color(0xFF422701);    // Deep brown (body text)
  static const muted = Color(0xFF705E46);           // Muted brown (secondary text)
  
  // Interactive
  static const accent = Color(0xFFD47E30);          // Cinnamon orange (links, buttons)
  
  // Utility
  static const divider = Color(0xFFD6C9B8);         // Light tan divider
  static const error = Color(0xFFC04000);           // Dark orange-red
}
```

### 🌙 Dark Theme

```dart
class DarkThemeColors {
  // Backgrounds
  static const background = Color(0xFF121212);      // Near black
  static const surface = Color(0xFF1E1E1E);         // Slightly lighter (cards)
  static const surfaceContainer = Color(0xFF2A2A2A); // Gatha/verse background
  
  // Text
  static const primary = Color(0xFFFFFFFF);         // Pure white (headings)
  static const onPrimary = Color(0xFF121212);       // Dark (text on light buttons)
  static const onBackground = Color(0xFFE0E0E0);    // Light gray (body text)
  static const muted = Color(0xFF9E9E9E);           // Medium gray (secondary text)
  
  // Interactive
  static const accent = Color(0xFFFF8C00);          // Bright orange (links, buttons)
  
  // Utility
  static const divider = Color(0xFF424242);         // Dark gray divider
  static const error = Color(0xFFFF6B6B);           // Bright red
}
```

### 🔥 Warm Theme

```dart
class WarmThemeColors {
  // Backgrounds
  static const background = Color(0xFF2A2318);      // Dark warm brown
  static const surface = Color(0xFF3D3428);         // Slightly lighter brown (cards)
  static const surfaceContainer = Color(0xFF4A3E2E); // Gatha/verse background
  
  // Text
  static const primary = Color(0xFFD47E30);         // Cinnamon orange (headings)
  static const onPrimary = Color(0xFF1A1408);       // Very dark (text on buttons)
  static const onBackground = Color(0xFFE8DFD0);    // Warm off-white (body text)
  static const muted = Color(0xFF8A7D6A);           // Muted tan (secondary text)
  
  // Interactive
  static const accent = Color(0xFFD6B588);          // Gold (links, buttons)
  
  // Utility
  static const divider = Color(0xFF524535);         // Dark brown divider
  static const error = Color(0xFFFF8A65);           // Soft orange-red
}
```

---

## Where to Apply Each Color

Use this table as a reference when styling widgets:

| UI Element | Color to Use | Example |
|------------|--------------|---------|
| **Screen background** | `background` | `Scaffold(backgroundColor: theme.background)` |
| **Cards, dialogs, bottom sheets** | `surface` | `Card(color: theme.surface)` |
| **Gatha/verse sections** | `surfaceContainer` | `Container(color: theme.surfaceContainer)` |
| **Main headings (H1, H2)** | `primary` | `Text(style: TextStyle(color: theme.primary))` |
| **Body text, paragraphs** | `onBackground` | `Text(style: TextStyle(color: theme.onBackground))` |
| **Secondary text (metadata)** | `muted` | `Text("Chapter 1", style: TextStyle(color: theme.muted))` |
| **Links** | `accent` | `TextButton(style: TextStyle(color: theme.accent))` |
| **Primary buttons** | `accent` + `onPrimary` | `ElevatedButton(backgroundColor: accent, foregroundColor: onPrimary)` |
| **Outline buttons** | `muted` for border | `OutlinedButton(side: BorderSide(color: theme.muted))` |
| **Dividers, borders** | `divider` | `Divider(color: theme.divider)` |
| **Error messages** | `error` | `Text("Error!", style: TextStyle(color: theme.error))` |

---

## Implementation Steps

### Step 1: Create the Theme Files

Create these files in `lib/presentation/theme/`:

```
lib/
  presentation/
    theme/
      app_colors.dart       // All 3 color classes above
      app_theme.dart        // ThemeData builders
      theme_provider.dart   // State management for theme switching
```

### Step 2: Define Color Classes

In `app_colors.dart`, add all 3 color classes from above.

### Step 3: Create ThemeData

In `app_theme.dart`:

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: LightThemeColors.background,
      cardColor: LightThemeColors.surface,
      dividerColor: LightThemeColors.divider,
      colorScheme: ColorScheme.light(
        primary: LightThemeColors.primary,
        onPrimary: LightThemeColors.onPrimary,
        secondary: LightThemeColors.accent,
        surface: LightThemeColors.surface,
        onSurface: LightThemeColors.onBackground,
        error: LightThemeColors.error,
      ),
      // Add text themes, button themes, etc.
    );
  }
  
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: DarkThemeColors.background,
      // ... similar pattern
    );
  }
  
  static ThemeData warm() {
    return ThemeData(
      brightness: Brightness.dark, // Warm is a dark theme variant
      scaffoldBackgroundColor: WarmThemeColors.background,
      // ... similar pattern
    );
  }
}
```

### Step 4: Create Theme Provider

In `theme_provider.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, warm }

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _mode = AppThemeMode.light;
  
  AppThemeMode get mode => _mode;
  
  ThemeData get themeData {
    switch (_mode) {
      case AppThemeMode.light:
        return AppTheme.light();
      case AppThemeMode.dark:
        return AppTheme.dark();
      case AppThemeMode.warm:
        return AppTheme.warm();
    }
  }
  
  Future<void> setTheme(AppThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    
    // Persist the choice
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', mode.name);
  }
  
  Future<void> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme');
    if (saved != null) {
      _mode = AppThemeMode.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppThemeMode.light,
      );
      notifyListeners();
    }
  }
}
```

### Step 5: Apply in main.dart

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final themeProvider = ThemeProvider();
  await themeProvider.loadSavedTheme();
  
  runApp(
    ChangeNotifierProvider.value(
      value: themeProvider,
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      theme: themeProvider.themeData,
      // ...
    );
  }
}
```

---

## Accessibility Notes

### Dark Theme (High Contrast)
- Designed for **visually impaired users**
- Meets **WCAG AAA** standards (7:1+ contrast ratio)
- Orange accent is **colorblind-safe** (visible to all types)
- Use this as the default for users who enable system accessibility settings

### Checking Contrast
- **Heading on background**: Must be at least **4.5:1** for normal text
- **Body text on background**: Must be at least **4.5:1**
- **Large text (18px+)**: Can be **3:1** minimum

All our themes exceed these requirements.

---

## Quick Reference Card

```
╔══════════════════════════════════════════════════════════════╗
║                    THEME COLOR MAPPING                        ║
╠══════════════════════════════════════════════════════════════╣
║  background      → Scaffold, screen backgrounds               ║
║  surface         → Cards, dialogs, sheets                     ║
║  surfaceContainer→ Gatha blocks, highlighted sections         ║
║  primary         → Headings (H1, H2, H3)                       ║
║  onBackground    → Body text, paragraphs                       ║
║  muted           → Secondary text, metadata, timestamps        ║
║  accent          → Links, buttons, interactive elements        ║
║  divider         → Lines, borders, separators                  ║
║  error           → Error messages, validation                  ║
╚══════════════════════════════════════════════════════════════╝
```

---

## Testing Checklist

Before shipping, verify each theme works correctly:

- [ ] All text is readable (no low contrast)
- [ ] Gatha sections have distinct background
- [ ] Links are visually distinct from body text
- [ ] Buttons have proper foreground/background colors
- [ ] Error messages are visible
- [ ] Dividers are subtle but visible
- [ ] Cards stand out from background
- [ ] Theme persists after app restart
- [ ] Theme switch is smooth (no flicker)

---

## Questions?

If anything is unclear, check the interactive preview tool at:
`tools/theme_preview.html`

You can adjust colors there and export updated Dart code.

---

## APPENDIX A: Current App Colors (Before Theme Implementation)

**Preserve these values for reference:**

```dart
// Current theme in main.dart (as of 2024-12-06)
theme: ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF8B4513), // Brown color for Buddhist theme (Saddle Brown)
    brightness: Brightness.light,
  ),
  useMaterial3: true,
  fontFamily: 'Roboto',
  extensions: [TextEntryTheme.light(...)],
),

darkTheme: ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF8B4513), // Same brown seed
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
  fontFamily: 'Roboto',
  extensions: [TextEntryTheme.dark(...)],
),

themeMode: ThemeMode.system,
```

**Material 3 Generated Colors** (from seed 0xFF8B4513):
- These were auto-generated by Flutter and worked well
- Can reference if needed during new theme implementation

---

## APPENDIX B: Revised Implementation Plan (Riverpod + Architecture)

### Architecture Decision

**File Structure:**
```
lib/
  core/
    theme/
      app_colors.dart           # Color palettes only (Light/Dark/Warm)
      app_theme.dart            # ThemeData builders
      text_entry_theme.dart     # Typography (existing - refactor to be color-independent)
      theme_notifier.dart       # Riverpod StateNotifier
```

**Separation of Concerns:**

1. **`text_entry_theme.dart`** (Color-Independent)
   - Line height/spacing
   - Font sizes (H1, H2, body, gatha)
   - Font weights
   - Letter spacing
   - Paragraph margins
   - Indentation rules
   - **Does NOT contain colors**
   - User can adjust font sizes later (independent of theme)

2. **`app_colors.dart`** (Only Colors)
   - `LightThemeColors` class
   - `DarkThemeColors` class
   - `WarmThemeColors` class
   - No typography information

3. **`app_theme.dart`** (Combines Both)
   - Builds `ThemeData` for each mode
   - Uses colors from `app_colors.dart`
   - Uses typography from `text_entry_theme.dart`
   - Creates final Material 3 theme

4. **`theme_notifier.dart`** (State Management)
   - Riverpod `StateNotifier<AppThemeMode>`
   - Persists choice with `shared_preferences`
   - Provides current theme to app

### Updated Implementation Steps

#### Step 1: Add Dependencies

```yaml
# pubspec.yaml
dependencies:
  shared_preferences: ^2.2.2
```

#### Step 2: Refactor `text_entry_theme.dart`

Remove color dependencies, keep only typography:

```dart
class TextEntryTheme extends ThemeExtension<TextEntryTheme> {
  // Typography only - no colors
  final double headingFontSize;
  final double bodyFontSize;
  final double gathaFontSize;
  final double lineHeight;
  final double paragraphSpacing;
  // ... etc
  
  // Remove all Color fields - those go in app_colors.dart
}
```

#### Step 3: Create `app_colors.dart`

Exactly as shown in main guide (Light/Dark/Warm classes).

#### Step 4: Create `app_theme.dart`

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'text_entry_theme.dart';

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: LightThemeColors.background,
      cardColor: LightThemeColors.surface,
      dividerColor: LightThemeColors.divider,
      colorScheme: ColorScheme.light(
        primary: LightThemeColors.primary,
        onPrimary: LightThemeColors.onPrimary,
        secondary: LightThemeColors.accent,
        surface: LightThemeColors.surface,
        onSurface: LightThemeColors.onBackground,
        error: LightThemeColors.error,
      ),
      extensions: [
        TextEntryTheme.standard(), // Color-independent typography
      ],
    );
  }
  
  static ThemeData dark() { /* similar */ }
  static ThemeData warm() { /* similar */ }
}
```

#### Step 5: Create `theme_notifier.dart` (Riverpod)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, warm }

class ThemeNotifier extends StateNotifier<AppThemeMode> {
  ThemeNotifier() : super(AppThemeMode.light);

  Future<void> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme');
    if (saved != null) {
      state = AppThemeMode.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppThemeMode.light,
      );
    }
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', mode.name);
  }
}

final themeNotifierProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier();
});

final currentThemeDataProvider = Provider<ThemeData>((ref) {
  final mode = ref.watch(themeNotifierProvider);
  switch (mode) {
    case AppThemeMode.light:
      return AppTheme.light();
    case AppThemeMode.dark:
      return AppTheme.dark();
    case AppThemeMode.warm:
      return AppTheme.warm();
  }
});
```

#### Step 6: Update `main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Load saved theme on startup
    Future.microtask(() => ref.read(themeNotifierProvider.notifier).loadSavedTheme());
  }

  @override
  Widget build(BuildContext context) {
    final themeData = ref.watch(currentThemeDataProvider);
    
    return MaterialApp(
      theme: themeData, // Single theme based on current mode
      // Remove darkTheme and themeMode - we handle it manually
      // ... rest of app
    );
  }
}
```

#### Step 7: Add Theme Switcher UI

In the reader header, next to column mode selector:

```dart
// In multi_pane_reader_widget.dart header
SegmentedButton<AppThemeMode>(
  segments: const [
    ButtonSegment(value: AppThemeMode.light, icon: Icon(Icons.light_mode)),
    ButtonSegment(value: AppThemeMode.dark, icon: Icon(Icons.dark_mode)),
    ButtonSegment(value: AppThemeMode.warm, icon: Icon(Icons.wb_twilight)),
  ],
  selected: {ref.watch(themeNotifierProvider)},
  onSelectionChanged: (Set<AppThemeMode> newSelection) {
    ref.read(themeNotifierProvider.notifier).setTheme(newSelection.first);
  },
),
```

### Key Differences from Original Guide

1. ✅ **Riverpod instead of ChangeNotifier** - Consistent with codebase
2. ✅ **`lib/core/theme/` instead of `lib/presentation/theme/`** - Matches existing structure
3. ✅ **Typography separated from colors** - `text_entry_theme.dart` is color-independent
4. ✅ **Material 3** - Continues using Material 3 (useMaterial3: true)
5. ✅ **Single theme mode** - We switch ThemeData, not use system dark/light mode
6. ✅ **Theme switcher in reader header** - Next to column mode selector

---

## Testing the Implementation

After implementation, verify:

- [ ] App remembers theme choice after restart
- [ ] All 3 themes render correctly
- [ ] Theme switcher UI works smoothly
- [ ] No color artifacts during theme switch
- [ ] Typography (font sizes, spacing) is identical across all themes
- [ ] Existing `text_entry_theme.dart` functionality preserved
- [ ] No conflicts with Material 3 color scheme

