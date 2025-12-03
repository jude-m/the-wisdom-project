/// Represents the formatting type of a content entry
enum EntryType {
  /// Standard paragraph text
  paragraph,

  /// Heading text (typically bold or emphasized)
  heading,

  /// Centered text
  centered,

  /// Gatha (verse) text with special formatting
  gatha,

  /// Unindented text
  unindented,
}

extension EntryTypeExtension on EntryType {
  /// Converts a string representation to EntryType enum
  static EntryType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'paragraph':
        return EntryType.paragraph;
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

  /// Converts EntryType enum to string representation
  String toStringValue() {
    switch (this) {
      case EntryType.paragraph:
        return 'paragraph';
      case EntryType.heading:
        return 'heading';
      case EntryType.centered:
        return 'centered';
      case EntryType.gatha:
        return 'gatha';
      case EntryType.unindented:
        return 'unindented';
    }
  }
}
