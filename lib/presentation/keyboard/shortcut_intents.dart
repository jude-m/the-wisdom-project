import 'package:flutter/widgets.dart';

/// App-wide keyboard intents.
///
/// An [Intent] in Flutter is just a data class that names "what the user wants
/// to happen". It carries no behaviour — the behaviour lives in the matching
/// [Action] (see `shortcut_actions.dart`). Keys are mapped to intents in
/// `keyboard_bindings.dart`.
///
/// Keeping intents as pure data classes is what lets us swap the keybindings
/// (defaults vs user overrides) without touching any other file.

/// Dismiss the most-recently-opened overlay (LIFO).
///
/// Wired to ESC. Pops the top entry of `overlayStackProvider` so the user's
/// "undo the last thing I opened" mental model holds, regardless of which
/// overlay (FTS panel / in-page search / dictionary sheet) it is.
class DismissTopOverlayIntent extends Intent {
  const DismissTopOverlayIntent();
}

/// Open the reader's in-page search bar for the active tab.
///
/// Wired to Ctrl/Cmd+F. Suppressed when the main FTS search bar already has
/// focus, so the user can keep typing into it.
class OpenInPageSearchIntent extends Intent {
  const OpenInPageSearchIntent();
}

/// Move keyboard focus into the main FTS search bar in the app bar.
///
/// Wired to Ctrl/Cmd+Shift+F. Always fires, even from inside another text
/// field — that's the standard "jump to global search" behaviour.
class OpenMainSearchIntent extends Intent {
  const OpenMainSearchIntent();
}

/// Close the currently active reader tab.
///
/// Wired to Ctrl/Cmd+Alt/Option+W. Mirrors the X button on each tab —
/// the focus moves to the previous tab automatically (handled by
/// [closeTabProvider]). No-op when there are no tabs open.
///
/// We can't use plain Cmd/Ctrl+W because browsers reserve that combo at
/// the OS layer (close-tab) and don't dispatch a keydown event to the
/// page — so neither Flutter nor any JS can override it. Adding Alt/Option
/// produces a combo that genuinely reaches the page on every platform.
class CloseActiveTabIntent extends Intent {
  const CloseActiveTabIntent();
}

/// Copy the current selection to the clipboard.
///
/// Wired to Ctrl/Cmd+C. The corresponding action first tries the focused
/// widget's native copy handler (so TextField + SelectableRegion keep their
/// default behaviour); if no native handler responds, it falls back to
/// copying the last text the user highlighted in any reader SelectionArea.
///
/// The fallback is the path that rescues Ctrl+C on web, where the focus tree
/// sometimes leaves the SelectableRegion unfocused even though the user has
/// a visible selection.
class SmartCopyIntent extends Intent {
  const SmartCopyIntent();
}
