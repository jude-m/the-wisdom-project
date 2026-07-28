import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wisdom_shared/wisdom_shared.dart';
import 'entry_type.dart';

part 'entry.freezed.dart';

/// Represents a single text entry (paragraph, heading, etc.)
///
/// Used by all editions (BJT, SuttaCentral, PTS, etc.)
@freezed
class Entry with _$Entry {
  const Entry._();

  const factory Entry({
    /// The type of this entry (paragraph, heading, centered, etc.)
    required EntryType entryType,

    /// The raw text with formatting markers
    /// Examples of markers: **bold**, __underline__, {footnote}
    required String rawText,

    /// Unique segment identifier for cross-edition alignment
    /// Generated at runtime for BJT (e.g., "dn-1:bjt:0")
    /// Loaded from JSON for SuttaCentral (e.g., "dn1:1.1")
    String? segmentId,

    /// Optional reference to a footnote
    String? footnoteReference,

    /// Hierarchy level for this entry (1-5 for heading/centered, 1-2 for gatha)
    /// Higher numbers = higher in hierarchy (level 5 = book title, level 1 = sub-section)
    int? level,
  }) = _Entry;

  /// Checks if this entry contains formatting markers
  bool get hasFormattingMarkers => ContentMarkers.hasMarkers(rawText);

  /// Checks if this entry has an associated footnote
  bool get hasFootnote => footnoteReference != null;

  /// Returns plain text with all formatting markers removed
  String get plainText => ContentMarkers.stripMarkers(rawText);

  // No `segments` accessor here on purpose. `parseContentMarkers` (wisdom_shared)
  // gives the richer view — underline and footnote labels, which the range API
  // cannot express — but nothing in the app consumes it yet, and the static-site
  // generator parses its own `ContentEntry` rather than going through `Entry`.
  // Add it when a widget actually renders underline, and cache it the way
  // `markedRanges` does below: an uncached getter called from `build()` would
  // re-parse every frame.

  /// Cached storage for [markedRanges]. Uses Expando (identity-based) so it
  /// works with Freezed's const constructor without changing the class signature.
  static final Expando<List<({int start, int end})>> _markedRangesCache =
      Expando('markedRanges');

  /// Character ranges in `plainText` coordinate space that correspond
  /// to text wrapped in `**...**` markers in `rawText`.
  ///
  /// Ranges are sorted by start position (left-to-right parse order).
  ///
  /// Computed once per instance and cached.
  ///
  /// The walk itself lives in `ContentMarkers.boldRanges` (wisdom_shared) so
  /// the static-site generator parses the corpus with the exact same grammar
  /// this app renders. Behaviour is unchanged: the shared implementation was
  /// diffed against the previous inline one over all 466,127 corpus entries
  /// with zero differences in either `plainText` or the ranges.
  List<({int start, int end})> get markedRanges {
    return _markedRangesCache[this] ??= ContentMarkers.boldRanges(rawText);
  }
}
