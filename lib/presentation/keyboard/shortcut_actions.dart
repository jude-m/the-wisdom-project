import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/in_page_search_focus_provider.dart';
import '../providers/in_page_search_provider.dart';
import '../providers/last_selected_text_provider.dart';
import '../providers/main_search_focus_provider.dart';
import '../providers/overlay_stack_provider.dart';
import '../providers/tab_lifecycle_provider.dart';
import '../providers/tab_provider.dart';
import 'shortcut_intents.dart';

/// Closes the topmost overlay on the LIFO stack.
///
/// `isEnabled` returns false when the stack is empty so the ESC keystroke
/// bubbles past us (lets nested widgets — e.g. a future dialog with its own
/// ESC handler — still take precedence).
class DismissTopOverlayAction extends ContextAction<DismissTopOverlayIntent> {
  final WidgetRef ref;
  DismissTopOverlayAction(this.ref);

  @override
  Object? invoke(DismissTopOverlayIntent intent, [BuildContext? context]) {
    ref.read(overlayStackProvider.notifier).dismissTop();
    return null;
  }

  @override
  bool isEnabled(DismissTopOverlayIntent intent, [BuildContext? context]) {
    return ref.read(overlayStackProvider).isNotEmpty;
  }
}

/// Opens the in-page search bar for the currently active tab — or, when it's
/// already visible, snaps focus back to its input (Chrome / VS Code muscle
/// memory) instead of bluntly re-running the idempotent open.
///
/// Suppressed when the main FTS search bar holds focus, so Ctrl/Cmd+F
/// doesn't yank a typing user out of the global search.
class OpenInPageSearchAction extends ContextAction<OpenInPageSearchIntent> {
  final WidgetRef ref;
  OpenInPageSearchAction(this.ref);

  @override
  Object? invoke(OpenInPageSearchIntent intent, [BuildContext? context]) {
    final isVisible = ref.read(activeInPageSearchStateProvider).isVisible;
    if (isVisible) {
      // Already open — jump focus back to the existing input. Mirrors
      // OpenMainSearchAction. The node is owned by the provider (the bar just
      // borrows it), so it's always available while the bar is mounted.
      ref.read(inPageSearchFocusNodeProvider).requestFocus();
    } else {
      ref.read(inPageSearchStatesProvider.notifier).openSearch();
    }
    return null;
  }

  @override
  bool isEnabled(OpenInPageSearchIntent intent, [BuildContext? context]) {
    final searchBarNode = ref.read(mainSearchFocusNodeProvider);
    if (searchBarNode != null && searchBarNode.hasFocus) {
      // Main FTS bar is focused — let the user keep typing.
      return false;
    }
    return true;
  }
}

/// Moves keyboard focus into the main FTS search bar.
///
/// Always enabled — pressing Ctrl/Cmd+Shift+F from inside any other widget
/// (including another text field) jumps to the global search bar.
class OpenMainSearchAction extends ContextAction<OpenMainSearchIntent> {
  final WidgetRef ref;
  OpenMainSearchAction(this.ref);

  @override
  Object? invoke(OpenMainSearchIntent intent, [BuildContext? context]) {
    final node = ref.read(mainSearchFocusNodeProvider);
    node?.requestFocus();
    return null;
  }
}

/// Closes the currently active reader tab.
///
/// Delegates to the existing [closeTabProvider] so the X-button and the
/// shortcut share one code path (per-tab state cleanup, navigator sync,
/// and the previous-tab-becomes-active behaviour all come for free).
///
/// `isEnabled` returns false when no tab is open so Cmd+W bubbles past us
/// rather than calling close on index `-1`.
class CloseActiveTabAction extends ContextAction<CloseActiveTabIntent> {
  final WidgetRef ref;
  CloseActiveTabAction(this.ref);

  @override
  Object? invoke(CloseActiveTabIntent intent, [BuildContext? context]) {
    final activeIndex = ref.read(activeTabIndexProvider);
    if (activeIndex < 0) return null;
    ref.read(closeTabProvider)(activeIndex);
    return null;
  }

  @override
  bool isEnabled(CloseActiveTabIntent intent, [BuildContext? context]) {
    return ref.read(activeTabIndexProvider) >= 0;
  }
}

/// Copies the current selection to the clipboard.
///
/// Resolution order:
///   1. Ask the currently focused widget to handle `CopySelectionTextIntent`
///      via `Actions.maybeInvoke`. `SelectableRegion` and `EditableText`
///      both register a handler — so a focused TextField or in-focus
///      SelectionArea keeps its native behaviour and wins.
///   2. If nothing handled it (typical on web when the focus tree drops
///      out of the SelectableRegion), fall back to `lastSelectedTextProvider`
///      — the text the user most recently highlighted in a reader pane.
///
/// This is the action that actually fixes Ctrl+C on web.
class SmartCopyAction extends ContextAction<SmartCopyIntent> {
  final WidgetRef ref;
  SmartCopyAction(this.ref);

  @override
  Object? invoke(SmartCopyIntent intent, [BuildContext? context]) {
    // 1. Native path: let the focused widget's own CopySelectionTextIntent
    //    action handle it if it can.
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext != null) {
      final handled = Actions.maybeInvoke(
        focusedContext,
        CopySelectionTextIntent.copy,
      );
      if (handled != null) {
        return null;
      }
    }

    // 2. Fallback path: copy the last text the user highlighted in a
    //    reader SelectionArea, even if focus has since moved away.
    final text = ref.read(lastSelectedTextProvider);
    if (text != null && text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
    }
    return null;
  }
}
