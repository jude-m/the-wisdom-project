# Windows Sinhala IME Bug — Investigation & Findings

**Date:** 2026-03-18 (updated 2026-07-24)
**Status:** Open — Root cause identified (engine typo), fix PR #189968 pending merge
**Affects:** Windows desktop only, Sinhala phonetic keyboard (and other IME-based scripts)

---

## The Problem

When using a Sinhala phonetic keyboard (e.g. Helakuru Phonetic) on Windows, typing Sinhala characters in the main search bar causes characters to be dropped or replaced.

**Example:** Typing `අනිච්ච` with the phonetic keyboard:
- `අන්` appears correctly
- Adding the vowel sign `ි` should produce `අනි`
- Instead, `න` is removed and it becomes `අි`
- The consonant is lost, leaving only the base vowel + combining sign

Roman script (Singlish) input works fine on all platforms.

---

## Root Cause: Flutter Engine Bug

**This is a confirmed Flutter engine-level bug, not an application-level issue.** The bug reproduces in a minimal Flutter app with a single bare `TextField` — no state management, no callbacks.

### What happens internally

Flutter's `setEditingState` on Windows conflicts with the IME's composing state. When the IME is composing multi-codepoint Sinhala characters (consonant + virama + vowel sign), Flutter's internal text input handling prematurely commits the composing region. The IME then tries to update text it no longer controls, causing characters to be dropped.

### Affected scripts

This is not Sinhala-specific. The same class of bug affects:
- Korean IME (#172270)
- Japanese IME (#101953, #102021)
- Chinese Pinyin IME (#81257)

### Relevant Flutter issues

- [#72980](https://github.com/flutter/flutter/issues/72980) — Characters disappear when adding characters to a TextField while typing with IME
- [#172270](https://github.com/flutter/flutter/issues/172270) — Critical Korean IME Cursor Issue in Flutter Desktop (Windows)
- [#65574](https://github.com/flutter/flutter/issues/65574) — Full IME support for Windows
- [#78827](https://github.com/flutter/flutter/issues/78827) — Discourage committing the current composing region when there's an open input connection

---

## Investigation Summary

### What we tried (Dart-level fixes)

During investigation, we identified and fixed several unnecessary widget rebuilds that were happening on every keystroke in the search bar. These are valid **performance improvements** but did not fix the IME bug since it lives in the Flutter engine.

#### Fix 1: ReaderScreen selective watch (kept as performance fix)

`reader_screen.dart` was watching the **entire** `searchStateProvider`:
```dart
// Before — rebuilds entire screen on every keystroke
final searchState = ref.watch(searchStateProvider);

// After — only rebuilds when panel visibility changes
final isSearchPanelVisible = ref.watch(
  searchStateProvider.select((s) => s.isResultsPanelVisible),
);
```
`isResultsPanelVisible` was the only property ReaderScreen used. Without `.select()`, every keystroke updated `rawQueryText` in state, which triggered a full rebuild of the screen, AppBar, and all children.

#### Fix 2: Remove redundant setState in SearchBar (kept as performance fix)

`search_bar.dart` had a redundant `setState(() {})` in `onChanged`:
```dart
// Before — two rebuilds per keystroke
onChanged: (value) {
  ref.read(searchStateProvider.notifier).updateQuery(value);
  setState(() {});  // redundant: ref.watch(rawQueryText) already triggers rebuild
},

// After — one rebuild per keystroke
onChanged: (value) {
  ref.read(searchStateProvider.notifier).updateQuery(value);
},
```

#### Fix 3: Controller text sync removal (reverted)

We tried removing the `ref.listen` that syncs state back to the controller (`_controller.text = next`). This was reverted because:
- The sync is needed for programmatic text changes (e.g. selecting a recent search)
- The `if (_controller.text != next)` guard already prevents unnecessary writes during normal typing
- The IME bug persisted regardless

#### Fix 4: Controller-based button visibility (reverted)

We tried replacing `ref.watch(rawQueryText)` with a `_controller.addListener` that only calls `setState` when button visibility changes. Reverted because the root cause was the Flutter engine, not widget rebuilds.

### Verification: bare TextField test

A minimal Flutter app with just a `TextField` (no state management, no callbacks) reproduced the exact same bug on Windows with the Sinhala phonetic keyboard. This confirmed the issue is in Flutter's Windows text input engine, not in application code.

---

## Current Workarounds

### For users

**Singlish transliteration** — The app already supports typing Romanized Sinhala (Singlish) which gets automatically converted to Sinhala script. For example, typing `anichchcha` produces `අනිච්ච`. This works correctly on all platforms including Windows.

### For developers

| Option | Effort | Status |
|--------|--------|--------|
| Singlish input (already available) | None | ✅ Works on all platforms |
| Use Wijesekara fixed-layout keyboard | None | ✅ Works — fixed-layout keys emit codepoints directly, no IME composing involved |
| Flutter master channel | Low | ❌ Still broken as of 2026-06-05 (pre-fix PR); retest after PR #189968 merges |
| Web build (`flutter build web`) | Low | ✅ Browser handles IME correctly |
| Native Win32 text field via platform channel | High | 🔲 Would fully fix it — not implemented |

---

## Root Cause Identified (2026-07-24)

**A one-line typo in `shell/platform/windows/text_input_plugin.cc`** (lines 330–331):

```cpp
int composing_base   = base->value.GetInt();
int composing_extent = base->value.GetInt();  // BUG: reads 'base' instead of 'extent'
```

The second line should read `extent->value.GetInt()`. Because `composing_base` always equals `composing_extent`, the composing range is always zero-length (collapsed). A collapsed composing range signals "no active composition" to the `TextInputModel`, so it commits the composing region prematurely on every `setEditingState` call. The IME's subsequent replacement of the composing text then lands at the wrong position, dropping characters.

This has been present since IME support was first added for Windows in engine PR #23853 (March 2021).

**Important Dart-level implication:** Because the composing range is always collapsed in the engine, `TextEditingValue.composing` is always `TextRange.empty` from Dart, even during active IME composition. There is no reliable way to detect "user is composing" from Dart code, which is why Dart-level workarounds cannot fix this.

### The Fix

**Flutter PR #189968** — "[Windows] Preserve composing extent in setEditingState"
- Author: tjcGoogle
- Opened: 2026-07-24
- Status: **Open, pending Windows team review**
- Fix: one-line correction in `text_input_plugin.cc`, with regression test
- Will enter master → then stable at next Flutter release
- Tested: still present on Flutter master as of 2026-06-05 (before this PR)

**Monitor this PR for merge: [flutter/flutter#189968](https://github.com/flutter/flutter/pull/189968)**

### Other IME fixes that landed (but do NOT fix character dropping)

- **Engine PR #186353** (merged June 2026, Flutter 3.45+): Fixed Korean IME cursor visual position (`GCS_CURSORPOS` flag). Cursor display only, not character dropping.
- **Engine PR #29620** (2022): Fixed Sogou IME (`GCS_COMPSTR` + `GCS_RESULTSTR` in same message).
- **Engine PR #24713** (2021): Added Korean input support (handling `GCS_RESULTSTR` without ending composition).
- Web-only IME fixes in Flutter 3.35 and 3.44 — Windows unaffected.

### Architecture note

Flutter's Windows embedder uses **IMM32** (Win95-era legacy API), not **TSF** (Text Services Framework, used by all modern Windows apps). Issue #74547 tracks TSF/reconversion support. The composing extent typo lives in the IMM32 path.

---

## Action Items

- [x] Test on Flutter master channel — still broken as of 2026-06-05 (pre-fix PR)
- [ ] **Monitor [flutter/flutter#189968](https://github.com/flutter/flutter/pull/189968)** — merge expected within days/weeks; once merged, switch to master channel and retest Helakuru phonetic input
- [ ] File Sinhala-specific bug on the Flutter repo (once PR merges, reference it as fixed)
- [ ] Consider adding a hint/tooltip for Windows users pointing them to Singlish input until fix ships in stable


-------------


# Flutter Issue Draft

**Title:** [Windows] Sinhala IME characters dropped during composing in TextField

---

## Steps to reproduce

1. Install a Sinhala phonetic keyboard on Windows (e.g. Windows built-in Sinhala keyboard with phonetic layout)
2. Create a minimal Flutter app with a single `TextField`:

```dart
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(
  home: Scaffold(
    body: Padding(
      padding: EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(hintText: 'Type Sinhala here'),
      ),
    ),
  ),
));
```

3. Switch to the Sinhala phonetic keyboard
4. Type the Pali/Sinhala word `අනිච්ච` (anichchcha) character by character

## Expected results

The TextField should display `අනිච්ච` — each character preserved as typed.

## Actual results

Characters are dropped during IME composition. Specifically:

- Typing `අන්` works correctly
- When adding the vowel sign `ි` (U+0DD2), the preceding consonant `න` (U+0DAF) is deleted
- Result: `අි` instead of `අනි`
- The IME's composing region appears to be committed prematurely by the framework, so the IME's subsequent replacement of the composing text goes to the wrong position or deletes characters

This happens with a completely bare `TextField` — no `onChanged`, no state management, no `inputFormatters`.

## Sinhala script context

Sinhala is a complex Brahmic script where:
- Consonants combine with a virama (්, U+0DCA) to form half-forms: `න්` = `න` + `්`
- Vowel signs (dependent vowels) replace the virama: `නි` = `න` + `ි`
- The IME handles this by updating the composing region when transitioning from `න්` → `නි`

When Flutter commits the composing region before the IME finishes this transition, the replacement fails and characters are lost.

## Related issues

This is the same class of bug affecting other complex-script IMEs on Windows:

- #72980 — Characters disappear when adding characters to a TextField while typing with IME
- #172270 — Critical Korean IME Cursor Issue in Flutter Desktop (Windows)
- #65574 — Full IME support for Windows
- #78827 — Discourage committing the current composing region when there's an open input connection
- #101953 — Windows + Microsoft Japanese IME, last char committed when deleting composing text
- #81257 — Unable to delete text from TextFormField using Chinese pinyin keyboard on Windows

Adding this issue to highlight that Sinhala (and likely other South/Southeast Asian Brahmic scripts — Tamil, Hindi, Thai, Khmer, Myanmar) are also affected, not just CJK and Korean.

## Environment

```
Flutter 3.44.1 • channel stable (current as of 2026-07-24)
Tools • Dart 3.12.1
Windows 11

Also reproduced on Flutter master (3.45.0-1.0.pre, 2026-06-05) — pre-dates fix PR #189968
```

## Impact

Sinhala is the native language of ~17 million people in Sri Lanka. This bug makes Flutter desktop apps on Windows unusable for direct Sinhala text input, forcing users to rely on transliteration workarounds.

