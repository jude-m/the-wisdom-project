import 'package:freezed_annotation/freezed_annotation.dart';

part 'reader_pane.freezed.dart';

/// Represents a single column/pane in the multi-pane reader
///
/// A ReaderPane displays one TextLayer (e.g., BJT Pali, BJT Sinhala, SC English).
/// Multiple panes can be shown side-by-side for parallel text viewing.
///
/// All panes within a tab share the same scroll position, maintaining vertical
/// alignment like an HTML table (current behavior).
@freezed
class ReaderPane with _$ReaderPane {
  const factory ReaderPane({
    /// Unique identifier for this pane instance
    /// Generated as UUID when creating a new pane
    required String paneId,

    /// Reference to the TextLayer being displayed
    /// Format: "{fileId}-{languageCode}-{scriptCode}[-{translator}]"
    /// Examples: 'dn1-pi-sinh', 'dn1-si-sinh', 'mn1-en-latn-sujato'
    required String layerId,

    /// Whether this pane is currently visible
    /// Hidden panes preserve their state but don't render
    @Default(true) bool isVisible,
  }) = _ReaderPane;
}
