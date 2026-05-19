import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/dictionary_provider.dart'
    show dictionaryHighlightProvider, selectedDictionaryWordProvider;
import '../../providers/in_page_search_provider.dart'
    show activeInPageSearchStateProvider, inPageSearchStatesProvider;
import '../../providers/last_selected_text_provider.dart';
import '../../providers/main_search_focus_provider.dart';
import '../../providers/overlay_stack_provider.dart';
import '../../providers/search_provider.dart' show searchStateProvider;
import '../../providers/tab_provider.dart' show activeTabIndexProvider;

/// Keeps `overlayStackProvider` in sync with the visibility of every
/// dismissible overlay in the app.
///
/// Mount this once near the root (inside `AppShortcuts`). It listens to the
/// three providers that own overlay visibility and pushes / removes entries
/// on the LIFO stack as they open and close. The stack itself is then read
/// by `DismissTopOverlayAction` to handle ESC.
///
/// ## Why a single sync widget instead of each overlay registering itself?
///
/// Two reasons:
///   1. The dictionary sheet and in-page search bar are mounted/unmounted
///      conditionally based on their visibility providers. If they pushed
///      themselves in `initState`, we'd hit lifecycle race conditions on
///      rebuild (double-register) and dispose timing.
///   2. Centralising the sync makes it trivial to add or remove overlays —
///      one `ref.listen` block per overlay, all in this file. The overlay
///      widgets themselves stay free of keyboard concerns.
class OverlayStackSync extends ConsumerWidget {
  final Widget child;

  const OverlayStackSync({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // NOTE: The `ref.listen` calls below intentionally live in `build`, not
    // in an `initState`-style hook. Don't "optimise" them by converting
    // this to a ConsumerStatefulWidget — Riverpod's `ref.listen` in build
    // is the supported pattern for cross-cutting subscriptions, and moving
    // them would silently break hot-reload state resets (listens would
    // only re-attach across full rebuilds, not StateNotifier resets).
    final stack = ref.read(overlayStackProvider.notifier);

    // ─── FTS search results panel ────────────────────────────────────────
    // Visibility derived from searchStateProvider; close path matches the
    // existing "click backdrop / tap result" behaviour in reader_screen.
    ref.listen<bool>(
      searchStateProvider.select((s) => s.isResultsPanelVisible),
      (_, isOpen) {
        if (isOpen) {
          stack.push(DismissibleOverlay(
            id: 'fts-panel',
            // Release the search bar before flipping isPanelDismissed: true.
            // Without this, focus stays on the TextField, so onFocus() never
            // re-fires when the user types again — leaving isPanelDismissed
            // permanently true and the panel hidden despite a non-empty query.
            // Unfocusing returns focus to the autofocused Focus in
            // AppShortcuts; the next click on the search bar re-runs
            // onFocus() which resets isPanelDismissed: false.
            dismiss: () {
              ref.read(mainSearchFocusNodeProvider)?.unfocus();
              ref.read(searchStateProvider.notifier).dismissResultsPanel();
            },
          ));
        } else {
          stack.remove('fts-panel');
        }
      },
    );

    // ─── In-page search bar (per active tab) ─────────────────────────────
    // Visibility lives on the active tab's InPageSearchState. closeSearch()
    // hides the bar but retains the query — same as clicking the X.
    ref.listen<bool>(
      activeInPageSearchStateProvider.select((s) => s.isVisible),
      (_, isOpen) {
        if (isOpen) {
          stack.push(DismissibleOverlay(
            id: 'in-page-search',
            dismiss: () =>
                ref.read(inPageSearchStatesProvider.notifier).closeSearch(),
          ));
        } else {
          stack.remove('in-page-search');
        }
      },
    );

    // ─── Cross-tab selection hygiene ─────────────────────────────────────
    // lastSelectedTextProvider holds the most recent reader text selection
    // and is used as SmartCopyAction's fallback for the web Ctrl+C case.
    // It belongs to whichever tab the selection was made in, but the
    // provider itself isn't tab-scoped — so if the user selects in tab A,
    // switches to tab B, then presses Ctrl+C with nothing selected on B,
    // they'd silently copy A's text. Clearing the provider on every tab
    // switch makes Ctrl+C either copy what's actually visible/selected on
    // the new tab or be a no-op — never the wrong tab's text.
    ref.listen<int>(activeTabIndexProvider, (_, __) {
      ref.read(lastSelectedTextProvider.notifier).state = null;
    });

    // ─── Dictionary bottom sheet ─────────────────────────────────────────
    // Visibility = "is a word selected". Closing also clears the highlight
    // so the underlying reader text returns to its normal style — mirrors
    // the manual close path inside DictionaryBottomSheet.
    ref.listen<String?>(selectedDictionaryWordProvider, (_, word) {
      if (word != null) {
        stack.push(DismissibleOverlay(
          id: 'dictionary',
          dismiss: () {
            ref.read(selectedDictionaryWordProvider.notifier).state = null;
            ref.read(dictionaryHighlightProvider.notifier).state = null;
          },
        ));
      } else {
        stack.remove('dictionary');
      }
    });

    return child;
  }
}
