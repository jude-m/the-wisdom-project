import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'shortcut_intents.dart';

/// Single source of truth for the app's default keyboard shortcuts.
///
/// To add a new shortcut: append entries to the returned map (one per
/// modifier flavour you support) and make sure the corresponding [Intent]
/// + [Action] exist in `shortcut_intents.dart` / `shortcut_actions.dart`.
///
/// ## Cross-platform convention (Ctrl vs Cmd)
///
/// Flutter's `SingleActivator` has independent `control:` and `meta:` flags.
/// We register the **same intent twice** — once with `control: true` for
/// Windows / Linux / Web / Android, once with `meta: true` for macOS / iOS.
/// This matches Flutter's framework convention for its own copy/paste
/// shortcuts and avoids any `Platform.isMacOS` branching at call sites.
///
/// ## Future: user-customised bindings
///
/// When we add a settings UI for remapping shortcuts, this function gets
/// replaced by a Riverpod provider that:
///   1. Loads overrides from SharedPreferences (keyed by stable command IDs,
///      e.g. `"OpenInPageSearchIntent"`).
///   2. Merges them on top of these defaults.
///   3. The `AppShortcuts` widget watches that provider, so live remapping
///      Just Works with no other code changes.
Map<ShortcutActivator, Intent> defaultBindings() {
  return <ShortcutActivator, Intent>{
    // ─── ESC: dismiss the top overlay (LIFO) ─────────────────────────────
    const SingleActivator(LogicalKeyboardKey.escape):
        const DismissTopOverlayIntent(),

    // ─── Ctrl/Cmd + F: open in-page search ───────────────────────────────
    const SingleActivator(LogicalKeyboardKey.keyF, control: true):
        const OpenInPageSearchIntent(),
    const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
        const OpenInPageSearchIntent(),

    // ─── Ctrl/Cmd + Shift + F: focus the main FTS search bar ─────────────
    const SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true):
        const OpenMainSearchIntent(),
    const SingleActivator(LogicalKeyboardKey.keyF, meta: true, shift: true):
        const OpenMainSearchIntent(),

    // ─── Ctrl/Cmd + Alt/Option + W: close the active reader tab ──────────
    // Why not plain Cmd/Ctrl+W? Browsers reserve that at the OS layer
    // (close-tab) and intercept it before the page ever sees a keydown —
    // unlike Cmd+F, which goes through the page first and is preventable.
    // Cmd/Ctrl+Shift+W closes the whole browser window. Cmd/Ctrl+Shift+Q
    // hits the macOS log-out shortcut. Adding Alt/Option to W is the
    // closest combo that is genuinely free on every platform, and macOS
    // already uses the same modifier shape for "close all windows" so the
    // muscle-memory is consistent.
    const SingleActivator(LogicalKeyboardKey.keyW, control: true, alt: true):
        const CloseActiveTabIntent(),
    const SingleActivator(LogicalKeyboardKey.keyW, meta: true, alt: true):
        const CloseActiveTabIntent(),

    // ─── Ctrl/Cmd + C: smart copy ────────────────────────────────────────
    // Dispatches a custom SmartCopyIntent — the handler first delegates to
    // the focused widget's native CopySelectionTextIntent action (preserves
    // TextField + SelectableRegion behaviour) and falls back to copying
    // the last-highlighted reader text if no native handler responds.
    // The fallback is what rescues Ctrl+C on web.
    const SingleActivator(LogicalKeyboardKey.keyC, control: true):
        const SmartCopyIntent(),
    const SingleActivator(LogicalKeyboardKey.keyC, meta: true):
        const SmartCopyIntent(),
  };
}
