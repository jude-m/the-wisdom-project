import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'keyboard_bindings.dart';
import 'shortcut_actions.dart';
import 'shortcut_intents.dart';

/// Top-level keyboard shortcut wrapper.
///
/// Mount this once near the root of the widget tree (inside
/// `MaterialApp.builder`). It:
///   1. Installs a [Focus] node so key events have somewhere to land before
///      any user widget has been clicked. Without this, on a fresh route
///      with no focused widget, Shortcuts would never receive events.
///   2. Installs a [Shortcuts] widget mapping default key combos → Intents.
///   3. Installs an [Actions] widget binding those Intents → Action
///      instances that read Riverpod providers via [WidgetRef].
///
/// ## Why focus-tree ancestry matters
///
/// Key events bubble UP the focus tree from the primary-focused widget. Any
/// [Shortcuts] / [Actions] widget that's an ancestor of the focused node
/// can handle them, with **deeper widgets winning first**. Mounting this
/// at the app root means:
///   - Deep widgets (TextField's internal Copy handler, SelectableRegion's
///     own Shortcuts) keep working — they're closer to focus, they win.
///   - When NOTHING deeper handles a key, our global bindings catch it.
///
/// That's why ESC works from anywhere (search bar, panel, reader, empty
/// space), Ctrl+F works in-place, and Ctrl+C has a fallback for the web
/// focus-tree quirk.
class AppShortcuts extends ConsumerWidget {
  final Widget child;

  const AppShortcuts({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: defaultBindings(),
      child: Actions(
        actions: <Type, Action<Intent>>{
          DismissTopOverlayIntent: DismissTopOverlayAction(ref),
          OpenInPageSearchIntent: OpenInPageSearchAction(ref),
          OpenMainSearchIntent: OpenMainSearchAction(ref),
          CloseActiveTabIntent: CloseActiveTabAction(ref),
          SmartCopyIntent: SmartCopyAction(ref),
        },
        // Autofocused fallback node. Holds focus only when no other widget
        // is focused (e.g. on a fresh route before any tap); as soon as the
        // user clicks anything, focus moves there naturally. Without this,
        // Shortcuts above would have no focus path to receive events from
        // on initial render.
        child: Focus(
          autofocus: true,
          // skipTraversal keeps this invisible to Tab-key focus traversal —
          // pressing Tab still walks through real interactive widgets.
          skipTraversal: true,
          child: child,
        ),
      ),
    );
  }
}
