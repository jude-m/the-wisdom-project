/// Ported from lib/domain/entities/bjt/bjt_document.dart / bjt_page.dart /
/// bjt_section.dart. Freezed removed (plain immutable classes).
/// Prototype-only duplication — the real build extracts these into a shared package.
library;

import 'entry.dart';

/// A section of BJT text in a specific language ('pi' = Pali, 'si' = Sinhala).
class BJTSection {
  const BJTSection({
    required this.languageCode,
    this.entries = const [],
    this.footnotes = const [],
  });

  final String languageCode;
  final List<Entry> entries;
  final List<String> footnotes;

  bool get hasEntries => entries.isNotEmpty;
  bool get hasFootnotes => footnotes.isNotEmpty;
}

/// A single BJT page with parallel Pali and Sinhala sections.
class BJTPage {
  const BJTPage({
    required this.pageNumber,
    required this.paliSection,
    required this.sinhalaSection,
  });

  final int pageNumber;
  final BJTSection paliSection;
  final BJTSection sinhalaSection;
}

/// A complete BJT document (one content file, e.g. 'dn-1').
class BJTDocument {
  const BJTDocument({
    required this.fileId,
    this.pages = const [],
    this.editionId = 'bjt',
  });

  final String fileId;
  final List<BJTPage> pages;
  final String editionId;

  int get pageCount => pages.length;

  BJTPage? getPageByIndex(int index) {
    if (index < 0 || index >= pages.length) return null;
    return pages[index];
  }
}
