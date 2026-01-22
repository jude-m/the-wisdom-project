/// Extension methods for String manipulation
extension StringExtensions on String {
  /// Strips HTML tags and entities from the string
  ///
  /// Removes all HTML tags (e.g., <b>, <i>, <div>), replaces common
  /// HTML entities with their character equivalents, and collapses
  /// multiple whitespace characters into single spaces.
  ///
  /// Example:
  /// ```dart
  /// '<b>Hello</b>&nbsp;World'.stripHtml() // Returns 'Hello World'
  /// ```
  String stripHtml() {
    // Remove all HTML tags
    var text = replaceAll(RegExp(r'<[^>]*>'), ' ');

    // Replace common HTML entities
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");

    // Collapse multiple whitespace into single spaces and trim
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    return text.trim();
  }
}
