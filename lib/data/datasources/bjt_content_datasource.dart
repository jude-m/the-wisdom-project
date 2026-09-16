/// One language side of one page. [language] is spelled the way `bjt_content`
/// and FTS matches spell it: `pali` or `sinh`, never `sinhala`.
typedef ContentPageKey = ({String fileId, int pageIndex, String language});

/// Page text from `bjt_content`, decoded back to the JSON it was built from.
abstract class BJTContentDataSource {
  /// Pages [firstPage] to [lastPage] of [fileId], inclusive — to the end of the
  /// file when [lastPage] is null — each shaped like one item of the JSON's
  /// `pages` list: `{pageNum, pali, sinh}`.
  ///
  /// Throws when a page in that span has no row for a language, or a row does
  /// not decode.
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
