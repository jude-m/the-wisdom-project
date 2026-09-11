/// What a real page must survive being parsed into.
///
/// Written as the safety net for the JSON → `bjt_content` migration
/// (`docs/todo/retiring-dart-server/reduce_mobile_bundle_size.md`, step 1):
/// the parser is the seam the compressed page blob will feed, and until now it
/// had no direct coverage at all. Everything asserted here is something the
/// blob has to carry — markers, footnotes, levels, page numbers — so a blob
/// that drops any of it fails here rather than in the reader.
///
/// The fixture is `assets/text/kn-jat.json` pages 0–1, verbatim. Those two were
/// chosen because between them they hold every entry type, a `pageNum` that is
/// not the page index, sections with and without footnotes, a non-numeric
/// footnote label, and all three formatting markers.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/data/datasources/bjt_document_parser.dart';
import 'package:the_wisdom_project/domain/entities/bjt/bjt_document.dart';
import 'package:the_wisdom_project/domain/entities/content/entry_type.dart';

/// Path relative to the package root, which is `flutter test`'s working dir.
const _fixturePath = 'test/fixtures/kn_jat_pages_0_1.json';

const _fileId = 'kn-jat';

void main() {
  late Map<String, dynamic> fixture;
  late BJTDocument document;

  setUpAll(() {
    final file = File(_fixturePath);
    if (!file.existsSync()) {
      fail('Missing $_fixturePath. Run `flutter test` from the repo root.');
    }
    fixture = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
    document = BJTDocumentParser.parseDocument(_fileId, fixture);
  });

  group('BJTDocumentParser - real page fixture', () {
    test('document carries the id it was given and the BJT edition', () {
      expect(document.fileId, equals(_fileId));
      expect(document.editionId, equals('bjt'));
      expect(document.pageCount, equals(2));
    });

    test('page number comes from pageNum, not the page index', () {
      // kn-jat starts at printed page 2 and skips odd numbers, so an
      // implementation that used the index would still look plausible.
      expect(document.allPageNumbers, equals([2, 4]));
      expect(document.getPageByNumber(4), same(document.pages[1]));
      expect(document.getPageByNumber(1), isNull);
    });

    test('sections are tagged pi / si', () {
      for (final page in document.pages) {
        expect(page.paliSection.languageCode, equals('pi'));
        expect(page.sinhalaSection.languageCode, equals('si'));
        expect(page.hasBothLanguages, isTrue);
      }
    });

    test('every entry survives, in source order', () {
      for (var i = 0; i < document.pages.length; i++) {
        final page = document.pages[i];
        for (final (code, section) in [
          ('pali', page.paliSection),
          ('sinh', page.sinhalaSection),
        ]) {
          final source = _sourceEntries(fixture, i, code);
          expect(section.entryCount, equals(source.length),
              reason: 'page $i / $code entry count');
          expect(
            section.entries.map((e) => e.rawText).toList(),
            equals(source.map((e) => e['text']).toList()),
            reason: 'page $i / $code raw text, in order',
          );
        }
      }
    });

    test('all five entry types are mapped', () {
      final seen = <EntryType>{
        for (final page in document.pages)
          for (final section in [page.paliSection, page.sinhalaSection])
            for (final entry in section.entries) entry.entryType,
      };
      expect(seen, equals(EntryType.values.toSet()));

      // Spot-check the mapping against known rows rather than trusting the set.
      final firstPali = document.pages[0].paliSection.entries;
      expect(firstPali[0].entryType, equals(EntryType.centered));
      expect(firstPali[2].entryType, equals(EntryType.heading));
      expect(firstPali[7].entryType, equals(EntryType.gatha));
      expect(document.pages[0].sinhalaSection.entries[7].entryType,
          equals(EntryType.paragraph));
      expect(document.pages[1].paliSection.entries[13].entryType,
          equals(EntryType.unindented));
    });

    test('level is preserved, including where the source omits it', () {
      final pali = document.pages[0].paliSection.entries;
      expect(pali[0].level, equals(3));
      expect(pali[1].level, equals(5));
      expect(pali[2].level, equals(4));

      // Sinhala prose carries no level at all; null must not become 0.
      final prose = document.pages[0].sinhalaSection.entries[7];
      expect(prose.entryType, equals(EntryType.paragraph));
      expect(prose.level, isNull);
    });

    test('formatting markers are kept verbatim in rawText', () {
      final bold = document.pages[1].paliSection.entries[13];
      expect(bold.rawText, equals('**තස්සුද්දානං: **'));
      expect(bold.hasFormattingMarkers, isTrue);
      expect(bold.plainText, equals('තස්සුද්දානං: '));

      final underline = document.pages[1].sinhalaSection.entries[7];
      expect(underline.rawText, equals('8. ගාමණී__චණ්ඩ__ ජාතකය.'));
      expect(underline.plainText, equals('8. ගාමණීචණ්ඩ ජාතකය.'));

      // {n} is a reference INTO the section's footnote list; it has to stay in
      // the text, because the number is how a reader finds the note.
      final withRef = document.pages[0].paliSection.entries[10];
      expect(withRef.rawText, equals('2. වණ්ණුපථජාතකං.{4}'));
      expect(withRef.plainText, equals('2. වණ්ණුපථජාතකං.'));
    });

    test('footnotes are flattened to their text, in order', () {
      final notes = document.pages[0].paliSection.footnotes;
      expect(notes.length, equals(9));
      expect(notes.first, equals('1. තං ගණ්හෙය්ය අපණ්ණකං – මඡසං'));
      expect(notes.last, equals('9. චුල්ලක – මඡසං, ස්යා'));

      // getFootnote is 1-based, matching the {n} markers above.
      expect(document.pages[0].paliSection.getFootnote(4),
          equals('4. වණ්ණපථ – මඡසං'));
      expect(document.pages[0].paliSection.getFootnote(0), isNull);
    });

    test('a non-numeric footnote label is not dropped or renumbered', () {
      // Page 4's last Pali note is labelled "*.", not a digit — the FTS build
      // and the content blob both have to carry it as written.
      final notes = document.pages[1].paliSection.footnotes;
      expect(notes.length, equals(6));
      expect(notes.last, startsWith('*. '));
    });

    test('a section with no footnotes parses to an empty list, not null', () {
      for (final page in document.pages) {
        expect(page.sinhalaSection.footnotes, isEmpty);
        expect(page.sinhalaSection.hasFootnotes, isFalse);
      }
    });

    test('segment ids run unbroken across both languages and both pages', () {
      // The counter is shared, and advances pali-then-sinhala within a page
      // before moving on. Reader features that key off segmentId depend on
      // that ordering, so a per-page or per-language reset would be a break.
      final ids = [
        for (final page in document.pages)
          for (final section in [page.paliSection, page.sinhalaSection])
            for (final entry in section.entries) entry.segmentId,
      ];
      expect(ids.length, equals(60));
      expect(
        ids,
        equals([for (var i = 0; i < 60; i++) '$_fileId:bjt:$i']),
      );
    });
  });

  group('BJTDocumentParser - degenerate input', () {
    test('an unrecognised type falls back to paragraph', () {
      final parsed = BJTDocumentParser.parseDocument('x', _pageWith({
        'type': 'marginalia',
        'text': 'ඒ භගවත්',
      }));
      expect(parsed.pages[0].paliSection.entries[0].entryType,
          equals(EntryType.paragraph));
    });

    test('type matching ignores case', () {
      final parsed = BJTDocumentParser.parseDocument('x', _pageWith({
        'type': 'Gatha',
        'text': 'ඒ භගවත්',
      }));
      expect(parsed.pages[0].paliSection.entries[0].entryType,
          equals(EntryType.gatha));
    });
  });
}

/// The raw entry maps for one page/language of the fixture.
List<Map<String, dynamic>> _sourceEntries(
  Map<String, dynamic> fixture,
  int pageIndex,
  String language,
) {
  final page = (fixture['pages'] as List<dynamic>)[pageIndex]
      as Map<String, dynamic>;
  final section = page[language] as Map<String, dynamic>;
  return (section['entries'] as List<dynamic>).cast<Map<String, dynamic>>();
}

/// A one-page document whose single Pali entry is [entry].
Map<String, dynamic> _pageWith(Map<String, dynamic> entry) => {
      'pages': [
        {
          'pageNum': 1,
          'pali': {
            'entries': [entry]
          },
          'sinh': {'entries': <dynamic>[]},
        }
      ],
    };
