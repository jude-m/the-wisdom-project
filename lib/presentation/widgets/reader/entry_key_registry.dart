import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Manages GlobalKeys for entry pair widgets across layout switches.
///
/// Each entry is identified by (absolutePageIndex, entryIndex). When the
/// user switches layouts, [findTopVisibleEntry] uses these keys to determine
/// which entry is at the viewport top, allowing the parent to reset
/// pagination to that entry.
///
/// Owned by [MultiPaneReaderWidget] state and passed to pane widgets.
class EntryKeyRegistry {
  final Map<(int, int), GlobalKey> _keys = {};

  /// Returns the GlobalKey for the entry at (absolutePageIndex, entryIndex).
  /// Creates a new key on first access; returns the cached key thereafter.
  GlobalKey keyFor(int absolutePageIndex, int entryIndex) {
    return _keys.putIfAbsent(
      (absolutePageIndex, entryIndex),
      () => GlobalKey(debugLabel: 'entry_${absolutePageIndex}_$entryIndex'),
    );
  }

  /// Finds the entry closest to the current viewport top.
  ///
  /// Iterates through all registered keys with mounted contexts, computes
  /// each entry's scroll offset via [RenderAbstractViewport.getOffsetToReveal],
  /// and returns the one whose reveal offset is closest to (but not exceeding)
  /// the current scroll offset.
  ///
  /// Returns null if no keys are mounted or the controller has no clients.
  (int absolutePageIndex, int entryIndex)? findTopVisibleEntry(
    ScrollController controller,
  ) {
    if (!controller.hasClients) return null;

    final currentOffset = controller.offset;
    (int, int)? bestEntry;
    double smallestDist = double.infinity;

    for (final entry in _keys.entries) {
      final context = entry.value.currentContext;
      if (context == null) continue;

      final renderObject = context.findRenderObject();
      if (renderObject == null || !renderObject.attached) continue;

      final viewport = RenderAbstractViewport.maybeOf(renderObject);
      if (viewport == null) continue;

      // getOffsetToReveal returns the scroll offset that would place this
      // entry at the top of the viewport (alignment 0.0)
      final revealedOffset =
          viewport.getOffsetToReveal(renderObject, 0.0).offset;

      // diff > 0: entry top is ABOVE viewport (scrolled past by diff px)
      // diff < 0: entry top is BELOW viewport (by -diff px)
      final diff = currentOffset - revealedOffset;

      // Pick the entry closest to the viewport top. Among equidistant
      // entries, prefer the one below the top (the entry the user is
      // currently reading) over one scrolled past. The +0.5 penalty on
      // above-viewport entries ensures this tie-breaking.
      final dist = diff >= 0 ? diff + 0.5 : -diff;

      if (dist < smallestDist) {
        smallestDist = dist;
        bestEntry = entry.key;
      }
    }

    return bestEntry;
  }

  /// Removes all keys. Call when switching tabs or loading a new document.
  void clear() {
    _keys.clear();
  }
}
