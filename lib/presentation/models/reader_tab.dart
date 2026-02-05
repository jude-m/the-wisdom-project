import 'package:freezed_annotation/freezed_annotation.dart';
import 'column_display_mode.dart';
import 'reader_pane.dart';

part 'reader_tab.freezed.dart';

/// Represents a single tab in the reader interface
/// Holds reference to the content being viewed and navigation state
@freezed
class ReaderTab with _$ReaderTab {
  const ReaderTab._();

  @Assert(
    'splitRatio >= 0.0 && splitRatio <= 1.0',
    'splitRatio must be between 0.0 and 1.0',
  )
  const factory ReaderTab({
    /// Short label for tab display (truncated if needed)
    required String label,

    /// Full name for tooltip or expanded view
    required String fullName,

    /// ID of the content file currently loaded in this tab
    String? contentFileId,

    /// Current page index within the content file
    @Default(0) int pageIndex,

    /// Start of loaded page range (for pagination)
    @Default(0) int pageStart,

    /// End of loaded page range (for pagination, exclusive)
    @Default(1) int pageEnd,

    /// Entry index to start from on the first visible page
    /// This allows opening a sutta mid-page without showing earlier entries
    @Default(0) int entryStart,

    /// Reference to the tree node key for navigation sync
    String? nodeKey,

    /// Pali name of the node for reference
    String? paliName,

    /// Sinhala name of the node for reference
    String? sinhalaName,

    /// Universal text identifier (e.g., 'dn1', 'mn100', 'sn1-1')
    /// This is edition-agnostic and used for cross-edition alignment
    /// Nullable for backward compatibility - derived from contentFileId if needed
    String? textId,

    /// List of panes to display in this tab
    /// Each pane shows one TextLayer (edition + language + script combination)
    /// Empty list means using legacy dual-pane mode (Pali + Sinhala)
    /// Nullable for backward compatibility
    @Default([]) List<ReaderPane> panes,

    /// Column display mode for this tab (per-tab setting)
    /// Defaults to paliOnly for portrait mode, can be changed by user
    @Default(ColumnDisplayMode.paliOnly) ColumnDisplayMode columnMode,

    /// Split ratio for "both" column mode (0.0 to 1.0)
    /// Represents the proportion of width for the left (Pali) pane
    @Default(0.5) double splitRatio,
  }) = _ReaderTab;

  /// Creates a tab from a tree node
  factory ReaderTab.fromNode({
    required String nodeKey,
    required String paliName,
    required String sinhalaName,
    String? contentFileId,
    int pageIndex = 0,
    int entryStart = 0,
    ColumnDisplayMode columnMode = ColumnDisplayMode.paliOnly,
  }) {
    // Create a short label (max 20 characters)
    final displayName = paliName;
    final label = displayName.length > 20
        ? '${displayName.substring(0, 20)}...'
        : displayName;

    return ReaderTab(
      label: label,
      fullName: '$paliName / $sinhalaName',
      contentFileId: contentFileId,
      pageIndex: pageIndex,
      pageStart: pageIndex, // Initialize pagination to entry page
      pageEnd: pageIndex + 1, // Load only the entry page initially
      entryStart: entryStart, // Entry to start from on first page
      nodeKey: nodeKey,
      paliName: paliName,
      sinhalaName: sinhalaName,
      columnMode: columnMode,
    );
  }

  /// Returns true if this tab has content to display
  bool get hasContent => contentFileId != null && contentFileId!.isNotEmpty;
}
