import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/domain/entities/bjt/bjt_document.dart';
import 'package:the_wisdom_project/domain/entities/bjt/bjt_page.dart';
import 'package:the_wisdom_project/domain/entities/bjt/bjt_section.dart';
import 'package:the_wisdom_project/domain/entities/reader/document_slice.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// [DocumentSlice] is the app's half of the slicing rule — the coordinates a
/// [SliceRange] carries, laid over the pages actually loaded. It decides what
/// text reaches the screen, and it is the half that has to survive a tree and a
/// corpus being out of step, because the reader must not go down where the
/// generator would throw.
void main() {
  group('of — which pages the unit covers', () {
    test('a unit ending mid-page keeps that page', () {
      final slice = DocumentSlice.of(_document(5), _range((1, 2), (3, 4)));
      expect(slice.pages.map((p) => p.pageNumber), [1, 2, 3]);
      expect(slice.absolutePageStart, 1);
    });

    test('a unit ending at entry 0 stops on the page before', () {
      // The next unit starts at the top of page 3, so that whole page is
      // theirs — the same reading the site takes.
      final slice = DocumentSlice.of(_document(5), _range((1, 2), (3, 0)));
      expect(slice.pages.map((p) => p.pageNumber), [1, 2]);
    });

    test('no end runs to the last page of the file', () {
      final slice = DocumentSlice.of(_document(5), _range((3, 1), null));
      expect(slice.pages.map((p) => p.pageNumber), [3, 4]);
    });
  });

  group('of — a range the document cannot honour', () {
    test('a start outside the document is empty, not a crash', () {
      expect(DocumentSlice.of(_document(2), _range((5, 0), null)).isEmpty, true);
      expect(
          DocumentSlice.of(_document(2), _range((-1, 0), null)).isEmpty, true);
      expect(DocumentSlice.of(_document(0), _range((0, 0), null)).isEmpty, true);
    });

    test('an end past the last page clamps, and drops its entry bound with it',
        () {
      final slice = DocumentSlice.of(_document(2), _range((0, 0), (9, 3)));
      expect(slice.pages.map((p) => p.pageNumber), [0, 1]);
      // The end named a page that does not exist, so nothing on the real last
      // page may be cut off at entry 3.
      expect(slice.entriesOn(1, 10), (0, 10));
    });

    test('an end at or before the start leaves nothing to render', () {
      expect(
          DocumentSlice.of(_document(3), _range((1, 0), (1, 0))).isEmpty, true);
      expect(
          DocumentSlice.of(_document(3), _range((2, 0), (1, 5))).isEmpty, true);
    });
  });

  group('entriesOn — where to start and stop on each page', () {
    // Pages 1..3 of a four-page file, starting at entry 3 and stopping at
    // entry 2 of the last one.
    final slice = DocumentSlice.of(_document(4), _range((1, 3), (3, 2)));

    test('the first page starts at the unit, later pages at the top', () {
      expect(slice.entriesOn(0, 10), (3, 10));
      expect(slice.entriesOn(1, 10), (0, 10));
    });

    test('the last page stops where the next unit begins', () {
      expect(slice.entriesOn(2, 10), (0, 2));
    });

    test('a side with fewer entries clamps instead of throwing', () {
      // Pali and Sinhala do not always carry the same number of entries on a
      // page, and the coordinate that bounds them is one.
      expect(slice.entriesOn(0, 2), (2, 2));
      expect(slice.entriesOn(2, 1), (0, 1));
    });
  });
}

SliceRange _range((int, int) start, (int, int)? end) => SliceRange(
      nodeKey: 'bk-1',
      start: SliceCoordinate(start.$1, start.$2),
      end: end == null ? null : SliceCoordinate(end.$1, end.$2),
    );

/// A document of [pageCount] pages, each numbered with its own index so a
/// slice's pages name the absolute positions they came from.
BJTDocument _document(int pageCount) => BJTDocument(
      fileId: 'f1',
      editionId: 'bjt',
      pages: [
        for (var i = 0; i < pageCount; i++)
          BJTPage(
            pageNumber: i,
            paliSection: const BJTSection(
              languageCode: 'pi',
              entries: [],
              footnotes: [],
            ),
            sinhalaSection: const BJTSection(
              languageCode: 'si',
              entries: [],
              footnotes: [],
            ),
          ),
      ],
    );
