/// Search mode below desktop width, on the real [ReaderScreen].
///
/// Below 1024px the app bar shows a search icon; tapping it swaps the
/// breadcrumb for a full-width field with a back arrow.
/// The other harnesses build a bare fixed-width `SearchBar`, which never
/// enters search mode, so this file pumps the screen itself.
///
/// Run with:
///   flutter test integration_test/search_mode_test.dart -d macos
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/data/datasources/bjt_document_local_datasource.dart';
import 'package:the_wisdom_project/presentation/keyboard/app_shortcuts.dart';
import 'package:the_wisdom_project/presentation/providers/app_section_provider.dart';
import 'package:the_wisdom_project/presentation/providers/document_provider.dart';
import 'package:the_wisdom_project/presentation/providers/navigation_tree_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_mode_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_provider.dart';
import 'package:the_wisdom_project/presentation/providers/tab_provider.dart';
import 'package:the_wisdom_project/presentation/screens/reader_screen.dart';
import 'package:the_wisdom_project/presentation/widgets/app/overlay_stack_sync.dart';
import 'package:the_wisdom_project/presentation/widgets/navigation/breadcrumb_widget.dart';
import 'package:the_wisdom_project/presentation/widgets/search/search_bar.dart'
    as app;
import 'package:the_wisdom_project/presentation/widgets/search/search_result_tile.dart';
import 'package:the_wisdom_project/presentation/widgets/search/search_results_panel.dart';

import 'search_test_helper.dart';
import 'test_overrides.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets(
    'phone width: the search icon opens search mode; a tap outside, '
    'widening, back arrow, system back, Esc and picking a result close it',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            bjtDocumentDataSourceProvider
                .overrideWithValue(BJTDocumentLocalDataSourceImpl()),
            keyValueStoreOverride(),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // As in main.dart: Esc and Ctrl/Cmd+Shift+F come from these.
            builder: (context, child) =>
                AppShortcuts(child: OverlayStackSync(child: child!)),
            home: const ReaderScreen(),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ReaderScreen)),
      );
      await container.read(navigationTreeProvider.future);
      await pumpForSettle(tester);

      final searchIcon = find.descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip('Search'),
      );
      // Its tooltip says Hide or Show, by the navigator's state.
      final menuButton = find.byTooltip(RegExp(r'^(Hide|Show) Navigator$'));
      final backArrow = find.descendant(
        of: find.byType(app.SearchBar),
        matching: find.byType(BackButton),
      );

      EditableText field() => tester.widget<EditableText>(find.descendant(
            of: find.byType(app.SearchBar),
            matching: find.byType(EditableText),
          ));
      bool fieldHasFocus() => field().focusNode.hasFocus;

      // Closed: the breadcrumb and the icon, no field. Also checks that a
      // closed search mode disposed its field without throwing.
      void expectClosed(String step) {
        expect(find.byType(app.SearchBar), findsNothing, reason: step);
        expect(find.byType(SearchResultsPanel), findsNothing, reason: step);
        expect(find.byType(BreadcrumbWidget), findsOneWidget, reason: step);
        expect(searchIcon, findsOneWidget, reason: step);
        expect(menuButton, findsOneWidget, reason: step);
        expect(container.read(searchModeProvider), isFalse, reason: step);
      }

      Future<void> openSearchMode() async {
        await tester.tap(searchIcon);
        await pumpForSettle(tester);
      }

      Future<void> pressSearchShortcut() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await pumpForSettle(tester);
      }

      // The shell keeps the reader alive behind other sections. This test
      // has no shell, so the reader stays on screen; only the section moves.
      final section = container.read(selectedAppSectionProvider.notifier);

      // ---- 1. Closed at first ----
      expectClosed('1. start');

      // ---- 2. The icon opens search mode, with the field focused ----
      await openSearchMode();
      expect(find.byType(app.SearchBar), findsOneWidget);
      expect(find.byType(BreadcrumbWidget), findsNothing);
      expect(menuButton, findsNothing,
          reason: '2. search mode has no menu button');
      expect(backArrow, findsOneWidget);
      expect(fieldHasFocus(), isTrue, reason: '2. typing can start at once');

      // ---- 3. With no query, a tap below the bar closes it ----
      await tester.tapAt(const Offset(200, 600));
      await pumpForSettle(tester);
      expectClosed('3. tap outside');

      // ---- 4. Widening to the desktop box ends search mode ----
      // A tablet turned sideways. Narrowing again shows the breadcrumb.
      await openSearchMode();
      tester.view.physicalSize = const Size(1200, 800);
      await pumpForSettle(tester);
      expect(find.byType(app.SearchBar), findsOneWidget,
          reason: '4. the desktop box');
      expect(container.read(searchModeProvider), isFalse);
      tester.view.physicalSize = const Size(400, 800);
      await pumpForSettle(tester);
      expectClosed('4. widened, then narrowed');

      // ---- 5. Typing opens the full-screen panel ----
      await openSearchMode();
      await tester.searchFor('mahaasathi');
      expect(find.byType(SearchResultsPanel), findsOneWidget);

      // ---- 6. The back arrow closes everything but keeps the query ----
      await tester.tap(backArrow);
      await pumpForSettle(tester);
      expectClosed('6. back arrow');
      expect(container.read(searchStateProvider).rawQueryText, 'mahaasathi');

      // ---- 7. Reopening shows the last query and its results ----
      await openSearchMode();
      expect(fieldHasFocus(), isTrue);
      expect(field().controller.text, 'mahaasathi');
      expect(find.byType(SearchResultsPanel), findsOneWidget);

      // ---- 8. System back closes it ----
      // maybePop is what Android's back button reaches. Not handlePopRoute:
      // were nothing to stop the pop, it would quit the app.
      await tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .maybePop();
      await pumpForSettle(tester);
      expectClosed('8. system back');

      // ---- 9. Esc closes it ----
      await openSearchMode();
      expect(find.byType(SearchResultsPanel), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await pumpForSettle(tester);
      expectClosed('9. Esc');

      // ---- 10. On another section the shortcut does nothing ----
      section.state = AppSection.home;
      await pressSearchShortcut();
      expectClosed('10. shortcut on Home');
      section.state = AppSection.reader;
      await pumpForSettle(tester);

      // ---- 11. Ctrl+Shift+F opens it with no field to focus ----
      await pressSearchShortcut();
      expect(find.byType(app.SearchBar), findsOneWidget,
          reason: '11. the shortcut opens search mode');
      expect(fieldHasFocus(), isTrue);

      // ---- 12. On another section, back leaves the reader's search alone ----
      section.state = AppSection.home;
      await pumpForSettle(tester);
      await tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .maybePop();
      await pumpForSettle(tester);
      expect(container.read(searchModeProvider), isTrue,
          reason: '12. back on Home keeps it open');
      section.state = AppSection.reader;
      await pumpForSettle(tester);

      // ---- 13. Picking a result opens it and leaves search mode ----
      expect(find.byType(SearchResultsPanel), findsOneWidget);
      await tester.tap(find.byType(SearchResultTile).first);
      await pumpForSettle(tester, const Duration(seconds: 2));
      expect(container.read(tabsProvider), hasLength(1));
      expectClosed('13. result picked');
      // The breadcrumb names what opened.
      expect(
        find.descendant(
          of: find.byType(BreadcrumbWidget),
          matching: find.byType(RichText),
        ),
        findsOneWidget,
      );
    },
  );
}
