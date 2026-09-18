import 'package:wisdom_shared/wisdom_shared.dart';

import '../bjt/bjt_document.dart';
import '../bjt/bjt_page.dart';

/// A [SliceRange] laid over a loaded document — the pages the reader builds,
/// and where the unit starts and stops inside the first and last of them.
///
/// The app's half of `ContentSlicer`: the same coordinates, mapped onto
/// [BJTPage]s instead of the generator's flattened rows. It exists because a
/// unit can begin *and end* mid-page, which is the one thing the panes' old
/// "skip some entries on the first page" could not express.
class DocumentSlice {
  final List<BJTPage> pages;

  /// Index of `pages.first` in the whole document. Entry keys, search matches
  /// and scroll targets are all absolute, so the panes need this to translate.
  final int absolutePageStart;

  final int _firstEntry;
  final int? _endEntry;

  const DocumentSlice._(
    this.pages,
    this.absolutePageStart,
    this._firstEntry,
    this._endEntry,
  );

  static const empty = DocumentSlice._([], 0, 0, null);

  /// Cuts [document] to [range]. Empty when the range names pages the
  /// document does not hold — a corpus and a tree out of step, which throws
  /// in the generator but must not take the reader down.
  ///
  /// The document may hold the whole file (web, and anything that asked for
  /// it) or just this span's pages (the reader), so every page index here is
  /// translated through [BJTDocument.firstPageIndex] rather than used as a
  /// position in [BJTDocument.pages].
  factory DocumentSlice.of(BJTDocument document, SliceRange range) {
    if (document.pages.isEmpty) return empty;
    final firstLoaded = document.firstPageIndex;
    final lastLoaded = document.lastPageIndex;
    final span = range.pageSpan;
    final firstPage = span.firstPage;
    if (firstPage < firstLoaded || firstPage > lastLoaded) return empty;

    // No last page runs to the end of what was loaded — the last node in the
    // file, and every node sharing that last coordinate.
    var lastPage = span.lastPage ?? lastLoaded;
    var endEntry = span.endEntry;
    if (lastPage > lastLoaded) {
      lastPage = lastLoaded;
      endEntry = null;
    }
    if (lastPage < firstPage) return empty;

    return DocumentSlice._(
      document.pages
          .sublist(firstPage - firstLoaded, lastPage - firstLoaded + 1),
      firstPage,
      range.start.entryIndex,
      endEntry,
    );
  }

  bool get isEmpty => pages.isEmpty;

  /// The half-open entry range to render on the page at local [index], for a
  /// section holding [entryCount].
  ///
  /// Clamped here rather than at each caller because Pali and Sinhala do not
  /// always carry the same number of entries on a page, while the coordinate
  /// that bounds them is one — so every reader of this has to clamp, and every
  /// one of them would clamp slightly differently.
  (int start, int end) entriesOn(int index, int entryCount) {
    final start = (index == 0 ? _firstEntry : 0).clamp(0, entryCount);
    final end = _endEntry;
    final stop = (end == null || index != pages.length - 1) ? entryCount : end;
    return (start, stop.clamp(start, entryCount));
  }
}
