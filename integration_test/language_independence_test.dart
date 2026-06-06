import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations_en.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations_si.dart';
import 'package:the_wisdom_project/core/localization/app_language.dart';
import 'package:the_wisdom_project/core/utils/pali_conjunct_transformer.dart';
import 'package:the_wisdom_project/domain/entities/content/content_language.dart';
import 'package:the_wisdom_project/presentation/models/reader_tab.dart';
import 'package:the_wisdom_project/presentation/providers/app_language_provider.dart';
import 'package:the_wisdom_project/presentation/providers/content_language_provider.dart';
import 'package:the_wisdom_project/presentation/providers/navigation_tree_provider.dart';
import 'package:the_wisdom_project/presentation/providers/tab_provider.dart';
import 'package:the_wisdom_project/presentation/providers/document_provider.dart';
import 'package:the_wisdom_project/presentation/widgets/navigation/breadcrumb_widget.dart';
import 'package:the_wisdom_project/presentation/widgets/navigation/tab_bar_widget.dart';
import 'package:the_wisdom_project/presentation/widgets/navigation/tree_navigator_widget.dart';
import 'package:the_wisdom_project/presentation/widgets/reader/multi_pane_reader_widget.dart';
import 'package:the_wisdom_project/data/datasources/bjt_document_local_datasource.dart';

import 'test_overrides.dart';

/// Test plan 3.1 — the headline claim of commit 81d2900: **App Language**
/// (UI chrome) and **Content Language** (data labels) are two INDEPENDENT axes.
///
/// Only a running app can prove orthogonality, because it needs MaterialApp
/// localization and the data widgets alive together. We move one axis at a time
/// and assert the OTHER one does not budge:
///   - flip App Language    → chrome localizes, the data label is unchanged.
///   - flip Content Language → the data label switches, chrome is unchanged.
///
/// Per the plan, integration only checks "it works" — one chrome string and one
/// data label, not a sweep across every surface (that's owned by lower layers).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App vs Content Language independence', () {
    // The app, with MaterialApp.locale wired to appLanguageProvider exactly
    // like main.dart. A localized chrome label sits above the data surfaces.
    Future<ProviderContainer> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Pin the device locale so the baseline App Language is English
            // regardless of the host machine's locale.
            deviceLocalesProvider.overrideWithValue(const [Locale('en')]),
            bjtDocumentDataSourceProvider.overrideWithValue(
              BJTDocumentLocalDataSourceImpl(),
            ),
            keyValueStoreOverride(),
          ],
          child: const _IndependenceApp(),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      await container.read(navigationTreeProvider.future);
      await pumpForSettle(tester);
      return container;
    }

    ReaderTab tabAtBeginning(ProviderContainer container, String nodeKey) {
      final node = container.read(nodeByKeyProvider(nodeKey))!;
      return ReaderTab.fromNode(
        nodeKey: node.nodeKey,
        paliName: node.paliName,
        sinhalaName: node.sinhalaName,
        contentFileId: node.isReadableContent ? node.contentFileId : null,
        pageIndex: node.isReadableContent ? node.entryPageIndex : 0,
        entryStart: node.isReadableContent ? node.entryIndexInPage : 0,
      );
    }

    String breadcrumbText(WidgetTester tester) {
      final finder = find.descendant(
        of: find.byType(BreadcrumbWidget),
        matching: find.byType(RichText),
      );
      if (finder.evaluate().isEmpty) return '';
      return _extractPlainText(tester.widget<RichText>(finder.first).text);
    }

    String chrome(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('chrome-label'))).data!;

    Locale appLocale(WidgetTester tester) =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).locale!;

    testWidgets(
      'moving one language axis never moves the other',
      (tester) async {
        final container = await pumpApp(tester);

        // Open a deep sutta whose Pali and Sinhala names genuinely differ
        // (dn-1-1 = බ්‍රහ්මජාලසුත්තං), so the Content-Language switch is visible.
        final leaf = container.read(nodeByKeyProvider('dn-1-1'))!;
        final sinhalaName = leaf.sinhalaName;
        final paliTransformed = applyConjunctConsonants(leaf.paliName);

        container.read(tabsProvider.notifier).addTab(
              tabAtBeginning(container, 'dn-1-1'),
            );
        container.read(activeTabIndexProvider.notifier).state =
            container.read(tabsProvider).length - 1;
        await pumpForSettle(tester, const Duration(seconds: 2));

        // ---------- Baseline: App = English, Content = Sinhala ----------
        expect(appLocale(tester), const Locale('en'));
        expect(chrome(tester), AppLocalizationsEn().settings,
            reason: 'chrome starts in English');
        expect(breadcrumbText(tester), contains(sinhalaName),
            reason: 'data label starts in Sinhala (default Content Language)');

        // ---------- Move App Language ONLY → Sinhala ----------
        await container
            .read(appLanguageProvider.notifier)
            .setLanguage(AppLanguage.sinhala);
        await pumpForSettle(tester);

        // Chrome localized to Sinhala...
        expect(appLocale(tester), const Locale('si'),
            reason: 'MaterialApp.locale follows App Language');
        expect(chrome(tester), AppLocalizationsSi().settings,
            reason: 'chrome string is now Sinhala');
        // ...but the DATA label did NOT move (Content Language untouched).
        expect(breadcrumbText(tester), contains(sinhalaName),
            reason: 'App Language change must NOT alter data labels');
        expect(breadcrumbText(tester), isNot(contains(paliTransformed)));

        final chromeAfterAppSwitch = chrome(tester);

        // ---------- Move Content Language ONLY → Pali ----------
        await container
            .read(contentLanguageProvider.notifier)
            .setLanguage(ContentLanguage.pali);
        await pumpForSettle(tester);

        // Data label switched to Pali (with conjuncts); Sinhala gone...
        expect(breadcrumbText(tester), contains(paliTransformed),
            reason: 'Content Language change switches data labels to Pali');
        expect(breadcrumbText(tester), isNot(contains(sinhalaName)));
        // ...but the CHROME did NOT move (App Language untouched).
        expect(appLocale(tester), const Locale('si'),
            reason: 'Content Language change must NOT alter chrome locale');
        expect(chrome(tester), chromeAfterAppSwitch,
            reason: 'chrome string is unaffected by Content Language');
      },
    );
  });
}

/// The app under test. A [ConsumerWidget] so `MaterialApp.locale` tracks the
/// App Language (mirrors `main.dart`). Lays a localized chrome label above the
/// real tree / tab / breadcrumb / reader surfaces.
class _IndependenceApp extends ConsumerWidget {
  const _IndependenceApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLanguage = ref.watch(appLanguageProvider);
    return MaterialApp(
      locale: appLanguage.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          children: [
            // Chrome: follows App Language via AppLocalizations.
            Builder(
              builder: (context) => Text(
                AppLocalizations.of(context).settings,
                key: const Key('chrome-label'),
              ),
            ),
            const BreadcrumbWidget(),
            const Expanded(
              child: Row(
                children: [
                  SizedBox(width: 250, child: TreeNavigatorWidget()),
                  Expanded(
                    child: Column(
                      children: [
                        TabBarWidget(),
                        Expanded(child: MultiPaneReaderWidget()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flattens an [InlineSpan] tree to plain text (breadcrumb is a RichText).
String _extractPlainText(InlineSpan span) {
  final buffer = StringBuffer();
  if (span is TextSpan) {
    if (span.text != null) buffer.write(span.text);
    if (span.children != null) {
      for (final child in span.children!) {
        buffer.write(_extractPlainText(child));
      }
    }
  }
  return buffer.toString();
}
