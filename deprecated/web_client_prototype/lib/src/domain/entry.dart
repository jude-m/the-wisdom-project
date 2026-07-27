/// Ported from lib/domain/entities/content/entry.dart + entry_type.dart.
/// Freezed removed (plain immutable class); marker-parsing logic is identical.
/// Prototype-only duplication — the real build extracts these into a shared package.
library;

/// Represents the formatting type of a content entry.
enum EntryType {
  paragraph,
  heading,
  centered,
  gatha,
  unindented;

  static EntryType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'heading':
        return EntryType.heading;
      case 'centered':
        return EntryType.centered;
      case 'gatha':
        return EntryType.gatha;
      case 'unindented':
        return EntryType.unindented;
      default:
        return EntryType.paragraph;
    }
  }
}

/// Represents a single text entry (paragraph, heading, etc.)
///
/// Raw text carries formatting markers: **bold**, __underline__, {footnote}.
class Entry {
  const Entry({
    required this.entryType,
    required this.rawText,
    this.segmentId,
    this.footnoteReference,
    this.level,
  });

  final EntryType entryType;
  final String rawText;
  final String? segmentId;
  final String? footnoteReference;
  final int? level;

  bool get hasFormattingMarkers {
    return rawText.contains('**') ||
        rawText.contains('__') ||
        rawText.contains('{');
  }

  /// Returns plain text with all formatting markers removed.
  String get plainText {
    return rawText
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll(RegExp(r'\{[^}]*\}'), '');
  }

  /// Cached storage for [markedRanges] (identity-based, like the app's Expando).
  static final Expando<List<({int start, int end})>> _markedRangesCache =
      Expando('markedRanges');

  /// Character ranges in `plainText` coordinate space that correspond
  /// to text wrapped in `**...**` markers in `rawText`.
  List<({int start, int end})> get markedRanges {
    return _markedRangesCache[this] ??= _computeMarkedRanges();
  }

  List<({int start, int end})> _computeMarkedRanges() {
    final ranges = <({int start, int end})>[];
    final raw = rawText;
    final len = raw.length;
    int i = 0; // position in rawText
    int plainIndex = 0; // position in plainText
    bool inMarked = false;
    int markedStart = 0;

    while (i < len) {
      // Check for ** marker (bold toggle)
      if (i + 1 < len && raw[i] == '*' && raw[i + 1] == '*') {
        if (!inMarked) {
          inMarked = true;
          markedStart = plainIndex;
        } else {
          inMarked = false;
          if (plainIndex > markedStart) {
            ranges.add((start: markedStart, end: plainIndex));
          }
        }
        i += 2;
        continue;
      }

      // Check for __ marker (underline — stripped, not rendered)
      if (i + 1 < len && raw[i] == '_' && raw[i + 1] == '_') {
        i += 2;
        continue;
      }

      // Check for {footnote} marker — skip entire content
      if (raw[i] == '{') {
        final closeBrace = raw.indexOf('}', i);
        if (closeBrace != -1) {
          i = closeBrace + 1;
          continue;
        }
      }

      plainIndex++;
      i++;
    }

    // Close any unclosed marked range (defensive against malformed input)
    if (inMarked && plainIndex > markedStart) {
      ranges.add((start: markedStart, end: plainIndex));
    }

    return ranges;
  }
}
