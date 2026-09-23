import 'dart:convert';
import 'dart:developer' as developer;

import 'package:archive/archive.dart';

import '../database/local_database.dart';
import 'bjt_content_datasource.dart';

/// Reads `bjt_content` out of `bjt.db`, on the same connection
/// as the FTS index.
class BJTContentLocalDataSourceImpl implements BJTContentDataSource {
  static const String _dbName = 'bjt.db';
  static const List<String> _languages = ['pali', 'sinh'];

  // Mirrors DictionaryDataSourceImpl._log. No-op in release builds.
  void _log(String message, {Object? error}) {
    developer.log(message, name: 'BJTContentDataSource', error: error);
  }

  @override
  Future<List<Map<String, dynamic>>> loadPages(
    String fileId, {
    required int firstPage,
    int? lastPage,
  }) async {
    final db = await LocalDatabase.open(_dbName);

    // The whole span in one query, not one per page.
    final rows = await db.rawQuery(
      'SELECT pageIndex, language, pageNum, CAST(blob AS BLOB) AS blob '
      'FROM bjt_content WHERE filename = ? AND pageIndex >= ?'
      '${lastPage == null ? '' : ' AND pageIndex <= ?'} '
      'ORDER BY pageIndex',
      [fileId, firstPage, if (lastPage != null) lastPage],
    );

    final byPage = <int, Map<String, dynamic>>{};
    for (final row in rows) {
      final page = byPage[row['pageIndex'] as int] ??= {
        'pageNum': row['pageNum'] as int
      };
      page[row['language'] as String] = _decode(row, fileId);
    }

    // Nothing in range. An unknown file is a fault worth naming — a tree
    // pointing at a file the corpus does not have would otherwise open an
    // empty reader forever. A span starting past a real file's last page is
    // the tail case below, and comes back empty.
    if (byPage.isEmpty) {
      final known = await db.rawQuery(
        'SELECT 1 FROM bjt_content WHERE filename = ? LIMIT 1',
        [fileId],
      );
      if (known.isEmpty) throw StateError('No bjt_content rows for $fileId');
      return const [];
    }

    // Rows arrive in page order, so the last key is the last page present.
    // A bounded span may reach past the file's end — a tree and a corpus out
    // of step, which DocumentSlice clamps rather than refuses — so the tail is
    // allowed to be missing while a hole inside the span still throws.
    final lastPresent = byPage.keys.last;
    final last =
        lastPage == null || lastPage > lastPresent ? lastPresent : lastPage;
    return [
      for (var pageIndex = firstPage; pageIndex <= last; pageIndex++)
        _whole(byPage[pageIndex], fileId, pageIndex),
    ];
  }

  @override
  Future<Map<ContentPageKey, Map<String, dynamic>>> loadPageSides(
    Set<ContentPageKey> keys,
  ) async {
    if (keys.isEmpty) return {};
    final db = await LocalDatabase.open(_dbName);
    final wanted = keys.toList();

    // Joined against a VALUES list, so each key is one primary-key seek.
    final rows = await db.rawQuery(
      'WITH wanted(filename, pageIndex, language) AS '
      '(VALUES ${List.filled(wanted.length, '(?, ?, ?)').join(', ')}) '
      'SELECT c.filename, c.pageIndex, c.language, '
      'CAST(c.blob AS BLOB) AS blob '
      'FROM wanted w JOIN bjt_content c ON c.filename = w.filename '
      'AND c.pageIndex = w.pageIndex AND c.language = w.language',
      [
        for (final key in wanted) ...[key.fileId, key.pageIndex, key.language],
      ],
    );

    final sides = <ContentPageKey, Map<String, dynamic>>{};
    for (final row in rows) {
      final fileId = row['filename'] as String;
      final key = (
        fileId: fileId,
        pageIndex: row['pageIndex'] as int,
        language: row['language'] as String,
      );
      try {
        sides[key] = _decode(row, fileId);
      } on FormatException catch (error) {
        _log('Skipped a corrupt row', error: error);
      }
    }
    return sides;
  }

  /// A page assembled from a partial result set would crash in the parser's
  /// casts or render one language blank, so a missing row fails here instead.
  static Map<String, dynamic> _whole(
    Map<String, dynamic>? page,
    String fileId,
    int pageIndex,
  ) {
    for (final language in _languages) {
      if (page?[language] == null) {
        throw StateError('No bjt_content row for $fileId/$pageIndex/$language');
      }
    }
    return page!;
  }

  /// Inflates and parses one row's blob.
  ///
  /// Both queries `CAST` the column to BLOB: a value stored as TEXT would
  /// otherwise be read as a string inside SQLite and fail the whole query
  /// before the row could be named.
  ///
  /// Neither zlib decoder always throws on a bad blob: web can return empty
  /// bytes, native part of the page. Part of a page is never a whole JSON
  /// object, so decode and parse share one `try`, and anything thrown — an
  /// `Error` such as `RangeError` included — becomes one error naming the row.
  static Map<String, dynamic> _decode(Map<String, dynamic> row, String fileId) {
    try {
      final bytes = const ZLibDecoder()
          .decodeBytes(row['blob'] as List<int>, verify: true);
      if (bytes.isEmpty) throw const FormatException('empty blob');
      return json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (error) {
      throw FormatException(
        'Corrupt bjt_content row '
        '$fileId/${row['pageIndex']}/${row['language']}: $error',
      );
    }
  }
}
