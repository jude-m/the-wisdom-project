/// Search at every width, on the real [ReaderScreen].
///
/// On phones (below 768px) the app bar shows a search icon; tapping it swaps
/// the breadcrumb for a full-width field with a back arrow. Tablets and
/// desktop have the 360px box, with the results as a side panel.
/// The other harnesses build a bare fixed-width `SearchBar`, which never
/// enters search mode, so this file pumps the screen itself. Which check runs
/// at which width: `search-width-checks-test-plan.md`.
///
/// Run with:
///   flutter test integration_test/search_mode_test.dart -d macos
library;

import 'dart:convert';

import 'package:flutter/gestures.dart';
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
import 'package:the_wisdom_project/presentation/providers/navigator_visibility_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_mode_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_provider.dart';
import 'package:the_wisdom_project/presentation/providers/tab_provider.dart';
import 'package:the_wisdom_project/presentation/screens/reader_screen.dart';
import 'package:the_wisdom_project/presentation/widgets/app/overlay_stack_sync.dart';
import 'package:the_wisdom_project/presentation/widgets/app/settings_menu_button.dart';
import 'package:the_wisdom_project/presentation/widgets/navigation/breadcrumb_widget.dart';
import 'package:the_wisdom_project/presentation/widgets/search/recent_search_overlay.dart';
import 'package:the_wisdom_project/presentation/widgets/search/search_bar.dart'
    as app;
import 'package:the_wisdom_project/presentation/widgets/search/search_result_tile.dart';
import 'package:the_wisdom_project/presentation/widgets/search/search_results_panel.dart';
import 'package:the_wisdom_project/presentation/widgets/search/singlish_preview.dart';

import 'search_test_helper.dart';
import 'test_overrides.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final searchIcon = find.descendant(
    of: find.byType(AppBar),
    matching: find.byTooltip('Search'),
  );
  // Its tooltip says Hide or Show, by the navigator's state.
  final menuButton = find.byTooltip(RegExp(r'^(Hide|Show) Navigator$'));
  final searchField = find.byType(app.SearchBar);
  final backArrow = find.descendant(
    of: searchField,
    matching: find.byType(BackButton),
  );
  final clearButton = find.descendant(
    of: searchField,
    matching: find.byTooltip('Clear'),
  );
  final recentRows = find.descendant(
    of: find.byType(RecentSearchOverlay),
    matching: find.byType(ListTile),
  );

  // Five, the most the recent list shows.
  const recentQueries = ['සති', 'මෙත්තා', 'ධම්ම', 'සීල', 'පඤ්ඤා'];

  // The file shares one prefs, and other files read it too.
  void forgetRecentSearchesAfterTest() =>
      addTearDown(() => prefs.remove('recent_searches'));

  /// Saves [queries] as recent searches, newest first. The key is
  /// RecentSearchesRepositoryImpl's private one, copied rather than exposed.
  Future<void> seedRecentSearches(List<String> queries) async {
    forgetRecentSearchesAfterTest();
    await prefs.setString(
      'recent_searches',
      jsonEncode([
        for (final query in queries)
          {'queryText': query, 'timestamp': '2026-10-09T00:00:00.000'},
      ]),
    );
  }

  /// Pumps the reader at [size], as main.dart builds it, and waits for the
  /// tree. Pinned: the macOS test window's own size varies.
  Future<ProviderContainer> pumpReader(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
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
    return container;
  }

  // Every simulated key names its physical key. Left out, the simulator looks
  // one up by debug name, which release web builds drop: a null error.
  Future<void> pressEsc(WidgetTester tester) => tester.sendKeyEvent(
        LogicalKeyboardKey.escape,
        physicalKey: PhysicalKeyboardKey.escape,
      );

  /// System back, as Android's back button sends it; true when the screen
  /// took it. Untaken, it would ask the platform to quit the app: that call
  /// is swallowed, so a failure reads as a failed check, not a closed app.
  Future<bool> pressSystemBack(WidgetTester tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        SystemChannels.platform, (_) async => null);
    final bool handled;
    try {
      handled = await tester.binding.handlePopRoute();
    } finally {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    }
    await pumpForSettle(tester);
    return handled;
  }

  Future<void> resize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    await pumpForSettle(tester);
  }

  EditableText field(WidgetTester tester) =>
      tester.widget<EditableText>(find.descendant(
        of: searchField,
        matching: find.byType(EditableText),
      ));

  // Closed at phone width: the breadcrumb and the icon, no field. Also checks
  // that a closed search mode disposed its field without throwing.
  void expectClosed(ProviderContainer container, String step) {
    expect(searchField, findsNothing, reason: step);
    expect(find.byType(SearchResultsPanel), findsNothing, reason: step);
    expect(find.byType(BreadcrumbWidget), findsOneWidget, reason: step);
    expect(searchIcon, findsOneWidget, reason: step);
    expect(menuButton, findsOneWidget, reason: step);
    expect(container.read(searchModeProvider), isFalse, reason: step);
  }

  // The open recent list, on a screen short enough that in full it reaches
  // where a 300px keyboard will be. With the keyboard up, it ends above it.
  Future<void> expectRecentListClearsKeyboard(
    WidgetTester tester,
    Size shortScreen,
    String step,
  ) async {
    const keyboard = 300.0;
    final keyboardTop = shortScreen.height - keyboard;
    double listBottom() =>
        tester.getRect(find.byType(RecentSearchOverlay)).bottom;

    await resize(tester, shortScreen);
    expect(recentRows, findsNWidgets(recentQueries.length), reason: step);
    expect(listBottom(), greaterThan(keyboardTop),
        reason: '$step: the full list must reach the keyboard, or this '
            'checks nothing');

    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    await pumpForSettle(tester);
    expect(listBottom(), lessThanOrEqualTo(keyboardTop),
        reason: '$step: the list ends above the keyboard');
    tester.view.resetViewInsets();
  }

  testWidgets(
    'phone width: the search icon opens search mode; a tap outside, '
    'widening, back arrow, system back, Esc and picking a result close it',
    (tester) async {
      // Picking a result (step 13) saves a recent search.
      forgetRecentSearchesAfterTest();
      final container = await pumpReader(tester, const Size(400, 800));

      bool fieldHasFocus() => field(tester).focusNode.hasFocus;

      Future<void> openSearchMode() async {
        await tester.tap(searchIcon);
        await pumpForSettle(tester);
      }

      // Ctrl+Shift+F, or Cmd+Shift+F, the macOS binding.
      Future<void> pressSearchShortcut({bool cmd = false}) async {
        final (modifier, physicalModifier) = cmd
            ? (LogicalKeyboardKey.metaLeft, PhysicalKeyboardKey.metaLeft)
            : (LogicalKeyboardKey.controlLeft, PhysicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(modifier, physicalKey: physicalModifier);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft,
            physicalKey: PhysicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyF,
            physicalKey: PhysicalKeyboardKey.keyF);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft,
            physicalKey: PhysicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(modifier, physicalKey: physicalModifier);
        await pumpForSettle(tester);
      }

      // The shell keeps the reader alive behind other sections. This test
      // has no shell, so the reader stays on screen; only the section moves.
      final section = container.read(selectedAppSectionProvider.notifier);

      // ---- 1. Closed at first ----
      expectClosed(container, '1. start');

      // ---- 2. The icon opens search mode, with the field focused ----
      await openSearchMode();
      expect(searchField, findsOneWidget);
      expect(find.byType(BreadcrumbWidget), findsNothing);
      expect(menuButton, findsNothing,
          reason: '2. search mode has no menu button');
      expect(find.byType(SettingsMenuButton), findsNothing,
          reason: '2. nor a settings button');
      expect(backArrow, findsOneWidget);
      expect(fieldHasFocus(), isTrue, reason: '2. typing can start at once');
      // The field spans the bar, 8px from each side.
      final bar = tester.getRect(find.byType(AppBar));
      final box = tester.getRect(searchField);
      expect(box.left - bar.left, 8, reason: '2. gap at the start');
      expect(bar.right - box.right, 8, reason: '2. gap at the end');

      // ---- 3. With no query, a tap below the bar closes it ----
      await tester.tapAt(const Offset(200, 600));
      await pumpForSettle(tester);
      expectClosed(container, '3. tap outside');

      // ---- 4. Widening to the box ends search mode ----
      // A tablet turned sideways. Narrowing again shows the breadcrumb.
      await openSearchMode();
      await resize(tester, const Size(1200, 800));
      expect(searchField, findsOneWidget, reason: '4. the box');
      expect(container.read(searchModeProvider), isFalse);
      await resize(tester, const Size(400, 800));
      expectClosed(container, '4. widened, then narrowed');

      // ---- 5. Typing opens the full-screen panel ----
      await openSearchMode();
      await tester.searchFor('mahaasathi');
      expect(find.byType(SearchResultsPanel), findsOneWidget);

      // ---- 6. The back arrow closes everything but keeps the query ----
      await tester.tap(backArrow);
      await pumpForSettle(tester);
      expectClosed(container, '6. back arrow');
      expect(container.read(searchStateProvider).rawQueryText, 'mahaasathi');

      // ---- 7. Reopening shows the last query and its results ----
      await openSearchMode();
      expect(fieldHasFocus(), isTrue);
      expect(field(tester).controller.text, 'mahaasathi');
      expect(
        field(tester).controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 'mahaasathi'.length),
        reason: '7. all selected, so the next key replaces it',
      );
      expect(find.byType(SearchResultsPanel), findsOneWidget);

      // ---- 8. System back closes it ----
      expect(await pressSystemBack(tester), isTrue,
          reason: '8. the screen takes the back');
      expectClosed(container, '8. system back');

      // ---- 9. Esc closes it ----
      await openSearchMode();
      expect(find.byType(SearchResultsPanel), findsOneWidget);
      await pressEsc(tester);
      await pumpForSettle(tester);
      expectClosed(container, '9. Esc');

      // ---- 10. On another section the shortcut does nothing ----
      section.state = AppSection.home;
      await pressSearchShortcut();
      expectClosed(container, '10. shortcut on Home');
      section.state = AppSection.reader;
      await pumpForSettle(tester);

      // ---- 11. Ctrl+Shift+F opens it with no field to focus ----
      await pressSearchShortcut();
      expect(searchField, findsOneWidget,
          reason: '11. Ctrl+Shift+F opens search mode');
      expect(fieldHasFocus(), isTrue);
      await pressEsc(tester);
      await pumpForSettle(tester);
      expectClosed(container, '11. Esc again');
      // Cmd+Shift+F, the macOS binding, does the same.
      await pressSearchShortcut(cmd: true);
      expect(searchField, findsOneWidget,
          reason: '11. Cmd+Shift+F opens search mode');
      expect(fieldHasFocus(), isTrue);

      // ---- 12. On another section, back leaves the reader's search alone ----
      section.state = AppSection.home;
      await pumpForSettle(tester);
      expect(await pressSystemBack(tester), isFalse,
          reason: '12. the reader leaves back to the section');
      expect(container.read(searchModeProvider), isTrue,
          reason: '12. back on Home keeps it open');
      section.state = AppSection.reader;
      await pumpForSettle(tester);

      // ---- 13. Picking a result opens it and leaves search mode ----
      expect(find.byType(SearchResultsPanel), findsOneWidget);
      await tester.tap(find.byType(SearchResultTile).first);
      await pumpForSettle(tester, const Duration(seconds: 2));
      expect(container.read(tabsProvider), hasLength(1));
      expectClosed(container, '13. result picked');
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

  testWidgets(
    '360px phone: nothing overflows, the breadcrumb ends 16px before the '
    'search icon, and a long Singlish query keeps its typed text in view',
    (tester) async {
      // A layout overflow fails the test by itself, so each pump below
      // checks for one: search closed, then open with results.
      final container = await pumpReader(tester, const Size(360, 800));

      // A deep sutta: its trail is longer than the bar.
      await openTab(tester, container, tabFromNode(container, 'dn-1-1'));
      final trailWindow = tester.getRect(find.descendant(
        of: find.byType(BreadcrumbWidget),
        matching: find.byType(Scrollable),
      ));
      final trail = tester.getRect(find.descendant(
        of: find.byType(BreadcrumbWidget),
        matching: find.byType(RichText),
      ));
      expect(trail.width, greaterThan(trailWindow.width),
          reason: 'the trail must be cut, or this checks nothing');
      expect(
        tester.getRect(searchIcon).left - trailWindow.right,
        greaterThanOrEqualTo(16),
      );

      await tester.tap(searchIcon);
      await pumpForSettle(tester);
      await tester.searchFor('mahaasathipatthaana suththaya dheegha nikaaya');
      expect(find.byType(SearchResultsPanel), findsOneWidget);

      // The preview's cap is a share of the field's real width, not of the
      // desktop box's 360px.
      final fieldWidth = tester.getSize(searchField).width;
      expect(fieldWidth, 360 - 2 * 8);
      final preview = tester.getSize(find.byType(SinglishPreview)).width;
      expect(preview, lessThanOrEqualTo(fieldWidth * 0.45));
      expect(preview, greaterThan(fieldWidth * 0.45 - 1),
          reason: 'the query must reach the cap, or this checks nothing');
      // The typed text keeps the rest, about a third of the field.
      final typed = tester
          .getSize(find.descendant(
            of: searchField,
            matching: find.byType(EditableText),
          ))
          .width;
      expect(typed, greaterThan(fieldWidth / 4));
    },
  );

  testWidgets(
    '400px phone: recent searches are a card under the bar, lined up with '
    'the field and clear of the keyboard; a row searches; ✕ brings them back',
    (tester) async {
      await seedRecentSearches(recentQueries);
      final container = await pumpReader(tester, const Size(400, 800));

      await tester.tap(searchIcon);
      await pumpForSettle(tester);
      expect(recentRows, findsNWidgets(recentQueries.length));

      // A card at the bar's bottom edge, its sides lined up with the field's.
      final bar = tester.getRect(find.byType(AppBar));
      final box = tester.getRect(searchField);
      final card = tester.getRect(find.byType(RecentSearchOverlay));
      expect(card.top, bar.bottom, reason: 'at the bar\'s bottom edge');
      expect(card.left, box.left, reason: 'lined up with the field');
      expect(card.right, box.right, reason: 'lined up with the field');

      // A short screen, so the full list would run under the keyboard.
      await expectRecentListClearsKeyboard(
          tester, const Size(400, 560), 'phone');
      await resize(tester, const Size(400, 800));

      // Tapping a row searches it.
      await tester.tap(find.descendant(
        of: find.byType(RecentSearchOverlay),
        matching: find.text('සති'),
      ));
      await tester.waitForSearchResults();
      expect(container.read(searchStateProvider).rawQueryText, 'සති');
      expect(field(tester).controller.text, 'සති');
      expect(find.byType(SearchResultsPanel), findsOneWidget);

      // ✕ empties the query and the list comes back, still in search mode.
      await tester.tap(clearButton);
      await pumpForSettle(tester);
      expect(find.byType(SearchResultsPanel), findsNothing);
      expect(container.read(searchModeProvider), isTrue);
      expect(recentRows, findsNWidgets(recentQueries.length));
    },
  );

  testWidgets(
    'tablet: the box from 768px; its side panel closes by back arrow and by '
    'system back; recent searches clear the keyboard',
    (tester) async {
      await seedRecentSearches(recentQueries);
      final container = await pumpReader(tester, const Size(767, 800));

      // ---- 1. The switch: 767px is a phone, 768px a tablet ----
      expect(searchIcon, findsOneWidget, reason: '1. 767px: the icon');
      expect(searchField, findsNothing);
      await resize(tester, const Size(768, 800));
      expect(searchIcon, findsNothing, reason: '1. 768px: the box');
      expect(searchField, findsOneWidget);

      // ---- 2. 900px with the navigator open: the 360px box ----
      await resize(tester, const Size(900, 800));
      expect(container.read(navigatorVisibleProvider), isTrue);
      expect(tester.getSize(searchField).width, 360);

      // ---- 3. The recent list clears the keyboard; Esc closes it ----
      await tester.tap(searchField);
      await expectRecentListClearsKeyboard(
          tester, const Size(900, 560), '3. tablet');
      await pressEsc(tester);
      await resize(tester, const Size(900, 800));
      expect(find.byType(RecentSearchOverlay), findsNothing);

      // ---- 4. A side panel, not full screen ----
      await tester.searchFor('mahaasathi');
      final panel = tester.getRect(find.byType(SearchResultsPanel));
      expect(panel.left, greaterThan(0), reason: '4. beside the reader');
      expect(panel.right, 900);

      // ---- 5. The box's back arrow closes it and keeps the query ----
      await tester.tap(backArrow);
      await pumpForSettle(tester);
      expect(find.byType(SearchResultsPanel), findsNothing);
      expect(container.read(searchStateProvider).rawQueryText, 'mahaasathi');

      // ---- 6. System back closes it too ----
      // Focusing the box again reopens it.
      await tester.tap(searchField);
      await tester.waitForSearchResults();
      expect(find.byType(SearchResultsPanel), findsOneWidget);
      expect(await pressSystemBack(tester), isTrue,
          reason: '6. the screen takes the back');
      expect(find.byType(SearchResultsPanel), findsNothing);
    },
  );

  testWidgets(
    'desktop: the 360px box shows only its hint; the panel has no close '
    'button of its own; a click outside the recent list keeps the filters; '
    'narrowed with the panel open, its back arrow still closes it',
    (tester) async {
      await seedRecentSearches(const ['සති']);
      final container = await pumpReader(tester, const Size(1280, 800));

      // ---- 1. The box: 360px, its hint and nothing else ----
      expect(tester.getSize(searchField).width, 360);
      final l10n = AppLocalizations.of(tester.element(searchField));
      expect(
        tester
            .widgetList<Text>(find.descendant(
              of: searchField,
              matching: find.byType(Text),
            ))
            .map((text) => text.data),
        [l10n.searchHint],
        reason: '1. no shortcut text',
      );
      expect(backArrow, findsNothing);

      // ---- 2. The box's back arrow is the panel's one close button ----
      await tester.searchFor('mahaasathi');
      expect(find.byType(SearchResultsPanel), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(backArrow, findsOneWidget);
      // Its old close button was an IconButton (→, or ✕ on phones). With the
      // match menu shut, the panel has no icon buttons at all.
      expect(
        find.descendant(
          of: find.byType(SearchResultsPanel),
          matching: find.byType(IconButton),
        ),
        findsNothing,
      );

      // ---- 3. ✕ brings the recent list back ----
      await tester.tapScopeChip('Sutta');
      await tester.toggleExactMatch();
      final sutta = tester.getSearchState().scope;
      expect(sutta, isNotEmpty);
      expect(tester.getSearchState().isExactMatch, isTrue);

      await tester.tap(clearButton);
      await pumpForSettle(tester);
      expect(recentRows, findsOneWidget, reason: '3. the recent list is back');

      // ---- 4. A click outside it closes it and keeps the filters ----
      await tester.tapAt(const Offset(200, 700), kind: PointerDeviceKind.mouse);
      await pumpForSettle(tester);
      expect(find.byType(RecentSearchOverlay), findsNothing);
      expect(tester.getSearchState().scope, sutta,
          reason: '4. the Sutta filter stays');
      expect(tester.getSearchState().isExactMatch, isTrue,
          reason: '4. the match option stays');

      // ---- 5. Narrowed to 900px with the panel open: nothing changes ----
      await tester.searchFor('mahaasathi');
      expect(find.byType(SearchResultsPanel), findsOneWidget);
      await resize(tester, const Size(900, 800));
      expect(tester.getSize(searchField).width, 360, reason: '5. the box');
      expect(backArrow, findsOneWidget);
      expect(
        tester.getRect(find.byType(SearchResultsPanel)).left,
        greaterThan(0),
        reason: '5. a side panel',
      );

      // ---- 6. At 400px it fills the screen under a full-width field ----
      await resize(tester, const Size(400, 800));
      final bar = tester.getRect(find.byType(AppBar));
      expect(tester.getSize(searchField).width, 400 - 2 * 8);
      expect(backArrow, findsOneWidget);
      expect(
        tester.getRect(find.byType(SearchResultsPanel)),
        Rect.fromLTRB(0, bar.bottom, 400, 800),
        reason: '6. full screen under the bar',
      );

      // ---- 7. One tap closes it ----
      await tester.tap(backArrow);
      await pumpForSettle(tester);
      expectClosed(container, '7. back arrow');
    },
  );
}
