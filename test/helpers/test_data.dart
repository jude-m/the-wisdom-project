import 'package:the_wisdom_project/core/constants/constants.dart';
import 'package:the_wisdom_project/domain/entities/navigation/tipitaka_tree_node.dart';
import 'package:the_wisdom_project/domain/entities/bjt/bjt_document.dart';
import 'package:the_wisdom_project/domain/entities/bjt/bjt_page.dart';
import 'package:the_wisdom_project/domain/entities/bjt/bjt_section.dart';
import 'package:the_wisdom_project/domain/entities/content/entry.dart';
import 'package:the_wisdom_project/domain/entities/content/entry_type.dart';
import 'package:the_wisdom_project/domain/entities/failure.dart';
import 'package:the_wisdom_project/domain/entities/reader/reader_unit.dart';
import 'package:wisdom_shared/wisdom_shared.dart'
    show SliceCoordinate, SliceRange, TipitakaNode;

/// Test fixtures for unit and widget tests
class TestData {
  TestData._();

  // ============================================================
  // TipitakaTreeNode fixtures
  // ============================================================

  /// A simple root node (Sutta Pitaka)
  static TipitakaTreeNode get rootNode => const TipitakaTreeNode(
        nodeKey: TipitakaNodeKeys.suttaPitaka,
        paliName: 'Sutta Pitaka',
        sinhalaName: 'සූත්‍ර පිටකය',
        hierarchyLevel: 0,
        entryPageIndex: 0,
        entryIndexInPage: 0,
        parentNodeKey: null,
        contentFileId: null,
        childNodes: [],
        hasAudioAvailable: false,
      );

  /// A leaf node with content (Digha Nikaya sutta 1)
  static TipitakaTreeNode get leafNodeWithContent => const TipitakaTreeNode(
        nodeKey: 'sp-1-1-1',
        paliName: 'Brahmajala Sutta',
        sinhalaName: 'බ්‍රහ්මජාල සූත්‍රය',
        hierarchyLevel: 3,
        entryPageIndex: 0,
        entryIndexInPage: 0,
        parentNodeKey: 'sp-1-1',
        contentFileId: 'dn-1',
        childNodes: [],
        hasAudioAvailable: false,
      );

  /// A container node with children (Digha Nikaya)
  static TipitakaTreeNode get containerNode => TipitakaTreeNode(
        nodeKey: 'sp-1',
        paliName: 'Digha Nikaya',
        sinhalaName: 'දීඝ නිකාය',
        hierarchyLevel: 1,
        entryPageIndex: 0,
        entryIndexInPage: 0,
        parentNodeKey: 'sp',
        contentFileId: null,
        childNodes: [childNode1, childNode2],
        hasAudioAvailable: false,
      );

  /// First child node
  static TipitakaTreeNode get childNode1 => const TipitakaTreeNode(
        nodeKey: 'sp-1-1',
        paliName: 'Silakkhandha Vagga',
        sinhalaName: 'සීලක්ඛන්ධ වග්ගය',
        hierarchyLevel: 2,
        entryPageIndex: 0,
        entryIndexInPage: 0,
        parentNodeKey: 'sp-1',
        contentFileId: null,
        childNodes: [],
        hasAudioAvailable: false,
      );

  /// Second child node
  static TipitakaTreeNode get childNode2 => const TipitakaTreeNode(
        nodeKey: 'sp-1-2',
        paliName: 'Maha Vagga',
        sinhalaName: 'මහා වග්ගය',
        hierarchyLevel: 2,
        entryPageIndex: 0,
        entryIndexInPage: 0,
        parentNodeKey: 'sp-1',
        contentFileId: null,
        childNodes: [],
        hasAudioAvailable: false,
      );

  /// A complete tree structure for testing
  static List<TipitakaTreeNode> get sampleTree => [
        TipitakaTreeNode(
          nodeKey: TipitakaNodeKeys.suttaPitaka,
          paliName: 'Sutta Pitaka',
          sinhalaName: 'සූත්‍ර පිටකය',
          hierarchyLevel: 0,
          entryPageIndex: 0,
          entryIndexInPage: 0,
          parentNodeKey: null,
          contentFileId: null,
          childNodes: [containerNode],
          hasAudioAvailable: false,
        ),
        const TipitakaTreeNode(
          nodeKey: TipitakaNodeKeys.vinayaPitaka,
          paliName: 'Vinaya Pitaka',
          sinhalaName: 'විනය පිටකය',
          hierarchyLevel: 0,
          entryPageIndex: 0,
          entryIndexInPage: 0,
          parentNodeKey: null,
          contentFileId: null,
          childNodes: [],
          hasAudioAvailable: false,
        ),
      ];

  // ============================================================
  // Entry fixtures
  // ============================================================

  /// A simple paragraph entry
  static Entry get paragraphEntry => const Entry(
        entryType: EntryType.paragraph,
        rawText: 'Evam me sutam.',
        segmentId: 'dn-1:bjt:0',
      );

  /// A heading entry (default level)
  static Entry get headingEntry => const Entry(
        entryType: EntryType.heading,
        rawText: 'Brahmajala Sutta',
        segmentId: 'dn-1:bjt:1',
      );

  /// A heading entry with level 5 (largest - book title)
  static Entry get headingLevel5Entry => const Entry(
        entryType: EntryType.heading,
        rawText: 'Digha Nikaya',
        segmentId: 'dn-1:bjt:h5',
        level: 5,
      );

  /// A heading entry with level 3 (mid-level)
  static Entry get headingLevel3Entry => const Entry(
        entryType: EntryType.heading,
        rawText: 'Silakkhandha Vagga',
        segmentId: 'dn-1:bjt:h3',
        level: 3,
      );

  /// A heading entry with level 1 (smallest)
  static Entry get headingLevel1Entry => const Entry(
        entryType: EntryType.heading,
        rawText: 'Section Title',
        segmentId: 'dn-1:bjt:h1',
        level: 1,
      );

  /// A gatha (verse) entry (default level)
  static Entry get gathaEntry => const Entry(
        entryType: EntryType.gatha,
        rawText: 'Ye dhamma hetuppabhava...',
        segmentId: 'dn-1:bjt:2',
      );

  /// A gatha entry with level 1 (standard indent)
  static Entry get gathaLevel1Entry => const Entry(
        entryType: EntryType.gatha,
        rawText: 'Ye dhamma hetuppabhava...',
        segmentId: 'dn-1:bjt:g1',
        level: 1,
      );

  /// A gatha entry with level 2 (deeper indent - nested verse)
  static Entry get gathaLevel2Entry => const Entry(
        entryType: EntryType.gatha,
        rawText: 'Selo yatha ekaghano\nvatena na samirath',
        segmentId: 'dn-1:bjt:g2',
        level: 2,
      );

  /// A centered entry with level 5 (largest)
  static Entry get centeredLevel5Entry => const Entry(
        entryType: EntryType.centered,
        rawText: 'Namo Tassa',
        segmentId: 'dn-1:bjt:c5',
        level: 5,
      );

  /// A centered entry with level 1 (smallest)
  static Entry get centeredLevel1Entry => const Entry(
        entryType: EntryType.centered,
        rawText: 'Centered text',
        segmentId: 'dn-1:bjt:c1',
        level: 1,
      );

  /// An entry with formatting markers
  static Entry get formattedEntry => const Entry(
        entryType: EntryType.paragraph,
        rawText: '**Bold text** and __underlined__ with {1} footnote.',
        segmentId: 'dn-1:bjt:3',
        footnoteReference: '1',
      );

  /// Sinhala paragraph entry
  static Entry get sinhalaEntry => const Entry(
        entryType: EntryType.paragraph,
        rawText: 'මෙසේ මා විසින් අසන ලදී.',
        segmentId: 'dn-1:bjt:4',
      );

  // ============================================================
  // BJTSection fixtures
  // ============================================================

  /// A Pali section with entries
  static BJTSection get paliSection => BJTSection(
        languageCode: 'pi',
        entries: [paragraphEntry, headingEntry],
        footnotes: const ['This is footnote 1'],
      );

  /// A Sinhala section with entries
  static BJTSection get sinhalaSection => BJTSection(
        languageCode: 'si',
        entries: [sinhalaEntry],
        footnotes: const [],
      );

  /// An empty section
  static BJTSection get emptySection => const BJTSection(
        languageCode: 'pi',
        entries: [],
        footnotes: [],
      );

  // ============================================================
  // BJTPage fixtures
  // ============================================================

  /// A complete page with both sections
  static BJTPage get completePage => BJTPage(
        pageNumber: 1,
        paliSection: paliSection,
        sinhalaSection: sinhalaSection,
      );

  /// A second page for multi-page tests
  static BJTPage get secondPage => const BJTPage(
        pageNumber: 2,
        paliSection: BJTSection(
          languageCode: 'pi',
          entries: [
            Entry(
              entryType: EntryType.paragraph,
              rawText: 'Second page pali text.',
              segmentId: 'dn-1:bjt:10',
            ),
          ],
          footnotes: [],
        ),
        sinhalaSection: BJTSection(
          languageCode: 'si',
          entries: [
            Entry(
              entryType: EntryType.paragraph,
              rawText: 'දෙවන පිටුව සිංහල පෙළ.',
              segmentId: 'dn-1:bjt:11',
            ),
          ],
          footnotes: [],
        ),
      );

  // ============================================================
  // BJTDocument fixtures
  // ============================================================

  /// A complete document with pages
  static BJTDocument get sampleDocument => BJTDocument(
        fileId: 'dn-1',
        pages: [completePage, secondPage],
        editionId: 'bjt',
      );

  /// An empty document
  static BJTDocument get emptyDocument => const BJTDocument(
        fileId: 'empty',
        pages: [],
        editionId: 'bjt',
      );

  /// A single-page document
  static BJTDocument get singlePageDocument => BJTDocument(
        fileId: 'single',
        pages: [completePage],
        editionId: 'bjt',
      );

  // ============================================================
  // Failure fixtures
  // ============================================================

  /// Data load failure
  static Failure get dataLoadFailure => const Failure.dataLoadFailure(
        message: 'Failed to load navigation tree',
        error: 'Network error',
      );

  /// Not found failure
  static Failure get notFoundFailure => const Failure.notFoundFailure(
        message: 'Node with key "invalid-key" not found',
      );

  /// Unexpected failure
  static Failure get unexpectedFailure => const Failure.unexpectedFailure(
        message: 'Something went wrong',
        error: 'Unknown error',
      );

  // ============================================================
  // JSON fixtures for datasource testing
  // ============================================================

  /// Sample tree.json structure (flat format as stored in assets)
  static Map<String, dynamic> get treeJsonData => {
        'sp': [
          'Sutta Pitaka',
          'සූත්‍ර පිටකය',
          0,
          [0, 0],
          'root',
          null
        ],
        'sp-1': [
          'Digha Nikaya',
          'දීඝ නිකාය',
          1,
          [0, 0],
          'sp',
          null
        ],
        'sp-1-1': [
          'Silakkhandha Vagga',
          'සීලක්ඛන්ධ වග්ගය',
          2,
          [0, 0],
          'sp-1',
          null
        ],
        'sp-1-1-1': [
          'Brahmajala Sutta',
          'බ්‍රහ්මජාල සූත්‍රය',
          3,
          [0, 0],
          'sp-1-1',
          'dn-1'
        ],
      };

  /// Sample BJT document JSON structure
  static Map<String, dynamic> get documentJsonData => {
        'pages': [
          {
            'pageNum': 1,
            'pali': {
              'entries': [
                {'type': 'heading', 'text': 'Brahmajala Sutta'},
                {'type': 'paragraph', 'text': 'Evam me sutam.'},
              ],
              'footnotes': [
                {'text': 'This is footnote 1'}
              ],
            },
            'sinh': {
              'entries': [
                {'type': 'heading', 'text': 'බ්‍රහ්මජාල සූත්‍රය'},
                {'type': 'paragraph', 'text': 'මෙසේ මා විසින් අසන ලදී.'},
              ],
              'footnotes': [],
            },
          },
        ],
      };

  /// Sample BJT document JSON with entry levels
  static Map<String, dynamic> get documentJsonDataWithLevels => {
        'pages': [
          {
            'pageNum': 1,
            'pali': {
              'entries': [
                {'type': 'heading', 'text': 'Digha Nikaya', 'level': 5},
                {'type': 'heading', 'text': 'Silakkhandha Vagga', 'level': 3},
                {'type': 'heading', 'text': 'Brahmajala Sutta', 'level': 1},
                {'type': 'centered', 'text': 'Namo Tassa', 'level': 5},
                {'type': 'paragraph', 'text': 'Evam me sutam.'},
                {'type': 'gatha', 'text': 'Verse level 1', 'level': 1},
                {'type': 'gatha', 'text': 'Nested verse', 'level': 2},
              ],
              'footnotes': [],
            },
            'sinh': {
              'entries': [
                {'type': 'heading', 'text': 'දීඝ නිකාය', 'level': 5},
                {'type': 'heading', 'text': 'සීලක්ඛන්ධ වග්ගය', 'level': 3},
                {'type': 'heading', 'text': 'බ්‍රහ්මජාල සූත්‍රය', 'level': 1},
                {'type': 'centered', 'text': 'නමෝ තස්ස', 'level': 5},
                {'type': 'paragraph', 'text': 'මෙසේ මා විසින් අසන ලදී.'},
                {'type': 'gatha', 'text': 'ගාථා මට්ටම 1', 'level': 1},
                {'type': 'gatha', 'text': 'කැදැලි ගාථා', 'level': 2},
              ],
              'footnotes': [],
            },
          },
        ],
      };

  // ============================================================
  // ReaderUnit fixtures
  // ============================================================

  /// A leaf owning all of [fileId], from its first row to the end.
  ///
  /// The reader renders from the *unit*, so a widget test that only sets a
  /// content file id gets the "select a sutta" hint no matter what loaded.
  static ReaderUnit readerUnit(String fileId) => ReaderUnit(
        node: TipitakaNode(
          nodeKey: fileId,
          paliName: 'Test Sutta',
          sinhalaName: 'Test Sutta',
          hierarchyLevel: 1,
          entryPageIndex: 0,
          entryIndexInPage: 0,
          parentNodeKey: null,
          contentFileId: fileId,
          childKeys: const [],
        ),
        contentFileId: fileId,
        range: SliceRange(
          nodeKey: fileId,
          start: const SliceCoordinate(0, 0),
        ),
      );
}
