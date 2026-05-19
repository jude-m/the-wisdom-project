import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One dismissible overlay registered with the LIFO stack.
///
/// [id] is a stable string key (e.g. `'dictionary'`) so re-pushing is
/// idempotent — pushing the same id twice just moves it to the top instead
/// of duplicating it.
///
/// [dismiss] is called by the ESC handler. It should flip whichever
/// underlying provider controls the overlay's visibility; the resulting
/// state change then propagates back through [OverlayStackSync] which
/// removes the entry from the stack. We deliberately do NOT pop here so
/// that "user closes via X button" and "user presses ESC" funnel through
/// the same removal path.
@immutable
class DismissibleOverlay {
  final String id;
  final VoidCallback dismiss;

  const DismissibleOverlay({required this.id, required this.dismiss});
}

/// LIFO stack of currently-open dismissible overlays.
///
/// The most-recently-opened overlay sits at the end of the list. ESC pops
/// from there, so the dismissal order is "last opened, first closed" —
/// matching the convention every other GUI uses (browser dialogs, IDE
/// command palettes, macOS sheets).
class OverlayStackNotifier extends StateNotifier<List<DismissibleOverlay>> {
  OverlayStackNotifier() : super(const []);

  /// Pushes [overlay] onto the top of the stack.
  ///
  /// If an overlay with the same id is already in the stack, the existing
  /// entry is removed and the new one goes on top — keeps the API safe to
  /// call from a `ref.listen` that may fire on every rebuild.
  void push(DismissibleOverlay overlay) {
    state = [
      ...state.where((o) => o.id != overlay.id),
      overlay,
    ];
  }

  /// Removes the overlay with the given [id], wherever it is in the stack.
  /// Called when an overlay closes by any means (X button, tap-outside, ESC).
  void remove(String id) {
    state = state.where((o) => o.id != id).toList();
  }

  /// Dismisses the top overlay.
  ///
  /// Returns `true` if there was something to dismiss (used by the action's
  /// `isEnabled` check so ESC bubbles past us when nothing is open).
  bool dismissTop() {
    if (state.isEmpty) return false;
    state.last.dismiss();
    return true;
  }
}

/// Global LIFO stack of dismissible overlays. Drives the ESC keyboard
/// shortcut and is kept in sync with the underlying visibility providers by
/// `OverlayStackSync`.
final overlayStackProvider =
    StateNotifierProvider<OverlayStackNotifier, List<DismissibleOverlay>>(
  (ref) => OverlayStackNotifier(),
);
