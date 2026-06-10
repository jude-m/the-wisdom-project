/// Ported from lib/presentation/models/reader_tab.dart (+ reader_layout.dart).
/// Freezed removed; fields trimmed to what the prototype exercises.
/// Tab state is plain data — that's what makes it portable from Flutter.
library;

import '../utils/text_utils.dart';

/// Reader layout mode (subset of the app's ReaderLayout).
enum ReaderLayout { paliOnly, sinhalaOnly, sideBySide }

/// A single reader tab: which content file is open, the loaded page window,
/// and the per-tab view state (layout, scroll position).
class ReaderTab {
  const ReaderTab({
    required this.id,
    required this.label,
    required this.fullName,
    required this.fileId,
    this.pageStart = 0,
    this.pageEnd = 2,
    this.entryAnchor,
    this.layout = ReaderLayout.sideBySide,
    this.scrollOffset = 0.0,
  });

  /// Stable identity (tabs list indexes shift on close) — used for DOM keys
  /// and the scroll registry.
  final int id;

  /// Short label for the tab strip (grapheme-safe truncated).
  final String label;

  /// Full name for the tooltip.
  final String fullName;

  /// Content file id, e.g. 'dn-1'.
  final String fileId;

  /// First loaded page index (where the reader starts rendering).
  final int pageStart;

  /// End of the loaded page range (exclusive). Grows as the user scrolls.
  final int pageEnd;

  /// Optional DOM anchor (`e-<page>-<lang>-<entry>`) to scroll to after
  /// opening — used when a tab is opened from a search match.
  final String? entryAnchor;

  /// Per-tab layout mode.
  final ReaderLayout layout;

  /// Last snapshotted scroll position (px) — restored on tab activation.
  final double scrollOffset;

  factory ReaderTab.create({
    required int id,
    required String name,
    required String fileId,
    int pageStart = 0,
    String? entryAnchor,
    ReaderLayout layout = ReaderLayout.sideBySide,
  }) {
    return ReaderTab(
      id: id,
      label: truncateGraphemes(name, 20),
      fullName: name,
      fileId: fileId,
      pageStart: pageStart,
      pageEnd: pageStart + 2,
      entryAnchor: entryAnchor,
      layout: layout,
    );
  }

  ReaderTab copyWith({
    int? pageStart,
    int? pageEnd,
    ReaderLayout? layout,
    double? scrollOffset,
    String? entryAnchor,
    bool clearEntryAnchor = false,
  }) {
    return ReaderTab(
      id: id,
      label: label,
      fullName: fullName,
      fileId: fileId,
      pageStart: pageStart ?? this.pageStart,
      pageEnd: pageEnd ?? this.pageEnd,
      entryAnchor:
          clearEntryAnchor ? null : (entryAnchor ?? this.entryAnchor),
      layout: layout ?? this.layout,
      scrollOffset: scrollOffset ?? this.scrollOffset,
    );
  }
}
