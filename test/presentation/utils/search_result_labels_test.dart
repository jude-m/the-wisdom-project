import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/utils/pali_conjunct_transformer.dart';
import 'package:the_wisdom_project/domain/entities/content/content_language.dart';
import 'package:the_wisdom_project/domain/entities/navigation/tipitaka_tree_node.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result_type.dart';
import 'package:the_wisdom_project/presentation/providers/navigation_tree_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_display_language_provider.dart';
import 'package:the_wisdom_project/presentation/utils/search_result_labels.dart';

import '../../helpers/pump_app.dart';

// Test plan 2.2 — `searchResultLabels`. It re-derives a result's title and
// breadcrumb PATH from its tree node in the active Content Language (the same
// pipeline the tree/breadcrumbs use), rather than trusting the repo's
// query-matched strings. The title's two-language rendering is owned by the
// seam (1.1) and the staged search integration test; here we focus on the
// PATH, the dictionary fallback, and live reactivity to a language change.

// A StateProvider we can flip at runtime to prove the labels re-render live.
final _testLang = StateProvider<ContentLanguage>((ref) => ContentLanguage.sinhala);

void main() {
  // root (sp) → parent (dn) → leaf (dn-1). All Pali names carry a consonant
  // cluster so the conjunct transform visibly changes them.
  const tree = [
    TipitakaTreeNode(
      nodeKey: 'sp',
      paliName: 'සුත්ත',
      sinhalaName: 'සුත් පෙළ',
      hierarchyLevel: 0,
      entryPageIndex: 0,
      entryIndexInPage: 0,
      childNodes: [
        TipitakaTreeNode(
          nodeKey: 'dn',
          paliName: 'සංයුත්ත',
          sinhalaName: 'සංයුත් සඟිය',
          parentNodeKey: 'sp',
          hierarchyLevel: 1,
          entryPageIndex: 0,
          entryIndexInPage: 0,
          childNodes: [
            TipitakaTreeNode(
              nodeKey: 'dn-1',
              paliName: 'ධම්ම',
              sinhalaName: 'දම් පෙළ',
              parentNodeKey: 'dn',
              hierarchyLevel: 2,
              entryPageIndex: 0,
              entryIndexInPage: 0,
            ),
          ],
        ),
      ],
    ),
  ];

  // Builds a search result. `nodeKey` empty/unknown exercises the fallback.
  SearchResult result({
    required String nodeKey,
    String title = 'repo-title',
    String subtitle = 'repo-subtitle',
  }) {
    return SearchResult(
      id: 'r1',
      editionId: 'bjt',
      resultType: SearchResultType.title,
      title: title,
      subtitle: subtitle,
      matchedText: 'match',
      contentFileId: 'dn-1',
      pageIndex: 0,
      entryIndex: 0,
      nodeKey: nodeKey,
      language: 'pali',
    );
  }

  Future<void> pumpProbe(
    WidgetTester tester,
    SearchResult r, {
    required List<Override> languageOverrides,
  }) {
    return tester.pumpApp(
      _LabelProbe(r),
      overrides: [
        // A fixed, fully-loaded tree so node + ancestor lookups resolve.
        navigationTreeProvider.overrideWith((ref) => tree),
        ...languageOverrides,
      ],
    );
  }

  group('searchResultLabels (2.2) -', () {
    testWidgets('Sinhala: title + breadcrumb path use the nodes\' Sinhala names',
        (tester) async {
      await pumpProbe(
        tester,
        result(nodeKey: 'dn-1'),
        languageOverrides: [
          effectiveSearchDisplayLanguageProvider
              .overrideWithValue(ContentLanguage.sinhala),
        ],
      );
      await tester.pumpAndSettle();

      // Title = leaf's Sinhala name (unchanged).
      expect(find.text('දම් පෙළ'), findsOneWidget);
      // Path = ancestors root→parent, joined ' > ', EXCLUDING the leaf itself.
      expect(find.text('සුත් පෙළ > සංයුත් සඟිය'), findsOneWidget);
    });

    testWidgets('Pali: every breadcrumb path segment carries conjunct ligatures',
        (tester) async {
      await pumpProbe(
        tester,
        result(nodeKey: 'dn-1'),
        languageOverrides: [
          effectiveSearchDisplayLanguageProvider
              .overrideWithValue(ContentLanguage.pali),
        ],
      );
      await tester.pumpAndSettle();

      // Path is this test's unique target: prove the function applies the
      // formatter to each ancestor segment on the Pali branch. The title's
      // two-language rendering is owned by the seam (1.1) + the Sinhala case
      // above, so we don't re-assert the transformed title here.
      final expectedPath =
          '${applyConjunctConsonants('සුත්ත')} > ${applyConjunctConsonants('සංයුත්ත')}';
      expect(find.text(expectedPath), findsOneWidget);
    });

    testWidgets('dictionary fallback: unknown nodeKey keeps the repo strings',
        (tester) async {
      // A dictionary result carries an empty nodeKey → no tree node, so the
      // function returns the repo-built title/subtitle verbatim.
      await pumpProbe(
        tester,
        result(nodeKey: '', title: 'Dictionary Word', subtitle: 'අර්ථ පථය'),
        languageOverrides: [
          effectiveSearchDisplayLanguageProvider
              .overrideWithValue(ContentLanguage.pali),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Dictionary Word'), findsOneWidget);
      expect(find.text('අර්ථ පථය'), findsOneWidget);
    });

    testWidgets('live switch: flipping the language re-renders the same tile',
        (tester) async {
      await pumpProbe(
        tester,
        result(nodeKey: 'dn-1'),
        languageOverrides: [
          // Follow the runtime-flippable test provider.
          effectiveSearchDisplayLanguageProvider
              .overrideWith((ref) => ref.watch(_testLang)),
        ],
      );
      await tester.pumpAndSettle();

      // Starts Sinhala.
      expect(find.text('දම් පෙළ'), findsOneWidget);

      // Flip to Pali — the watching tile must rebuild with conjuncts.
      final container =
          ProviderScope.containerOf(tester.element(find.byType(_LabelProbe)));
      container.read(_testLang.notifier).state = ContentLanguage.pali;
      await tester.pumpAndSettle();

      expect(find.text(applyConjunctConsonants('ධම්ම')), findsOneWidget);
      expect(find.text('දම් පෙළ'), findsNothing);
    });
  });
}

/// Minimal probe: calls the function under test and renders its two outputs.
class _LabelProbe extends ConsumerWidget {
  const _LabelProbe(this.result);

  final SearchResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = searchResultLabels(ref, result);
    return Column(
      children: [
        Text(labels.title),
        Text(labels.path),
      ],
    );
  }
}
