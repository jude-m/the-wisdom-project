/// One language side of one page. [language] is spelled the way `bjt_content`
/// and FTS matches spell it: `pali` or `sinh`, never `sinhala`.
typedef ContentPageKey = ({String fileId, int pageIndex, String language});

/// Page text from `bjt_content`, decoded back to the JSON it was built from.
abstract class BJTContentDataSource {
  /// Pages [firstPage] to [lastPage] of [fileId], inclusive — to the end of the
  /// file when [lastPage] is null — each shaped like one item of the JSON's
  /// `pages` list: `{pageNum, pali, sinh}`.
  ///
  /// A span reaching past the file's last page stops there, and one starting
  /// past it comes back empty: a tree and a corpus out of step must not take
  /// the reader down. Throws when [fileId] has no rows at all, when a page
  /// *inside* the span has no row for a language, or when a row does not
  /// decode.
  Future<List<Map<String, dynamic>>> loadPages(
    String fileId, {
    required int firstPage,
    int? lastPage,
  });

  /// The language side of each page in [keys]. A key with no row, or with a
  /// row that does not decode, is left out, so one bad row costs only itself.
  Future<Map<ContentPageKey, Map<String, dynamic>>> loadPageSides(
    Set<ContentPageKey> keys,
  );
}
