import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/presentation/providers/overlay_stack_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_state.dart';
import 'package:the_wisdom_project/presentation/widgets/search/match_options_menu.dart';

import '../../helpers/fake_search_state_notifier.dart';
import '../../helpers/pump_app.dart';

const _oneWord = 'එවං';
const _twoWords = 'එවං මෙ';

/// A Sinhala query: what is searched is what was typed.
SearchState _query(String text) =>
    SearchState(rawQueryText: text, effectiveQueryText: text);

/// Pumps the button at the top left, with room below for the open menu.
Future<FakeSearchStateNotifier> _pumpButton(
  WidgetTester tester,
  SearchState state,
) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final notifier = FakeSearchStateNotifier(state);
  await tester.pumpApp(
    const Align(alignment: Alignment.topLeft, child: MatchOptionsButton()),
    overrides: [searchStateProvider.overrideWith((ref) => notifier)],
  );
  return notifier;
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(MatchOptionsButton));
  await tester.pumpAndSettle();
}

/// A menu option by its title. Scoped to the radio rows, as the button's
/// own label can read the same ("Starts with").
Finder _option(String title) => find.ancestor(
      of: find.text(title),
      matching: find.byWidgetPredicate((w) => w is RadioMenuButton),
    );

void main() {
  group('MatchOptionsButton label', () {
    final cases = [
      (_query(_oneWord), 'Starts with'),
      (_query(_oneWord).copyWith(isExactMatch: true), 'Whole word'),
      // A second word adds where the words sit.
      (_query(_twoWords), 'Starts with · Phrase'),
      (
        _query(_twoWords).copyWith(
          isPhraseSearch: false,
          isAnywhereInText: true,
        ),
        'Starts with · Anywhere',
      ),
      (
        _query(_twoWords).copyWith(
          isExactMatch: true,
          isPhraseSearch: false,
          proximityDistance: 20,
        ),
        'Whole word · Near 20',
      ),
      // Counts the words that are searched: the leading space is dropped.
      (
        const SearchState(rawQueryText: ' dhamma', effectiveQueryText: 'දම්ම'),
        'Starts with',
      ),
    ];

    for (final (state, label) in cases) {
      testWidgets('"${state.rawQueryText}" reads "$label"', (tester) async {
        await _pumpButton(tester, state);

        expect(find.text(label), findsOneWidget);
      });
    }
  });

  group('Match options menu', () {
    testWidgets('one word: only the "match each word" options', (tester) async {
      await _pumpButton(tester, _query(_oneWord));
      await _openMenu(tester);

      expect(_option('Starts with'), findsOneWidget);
      expect(_option('Whole word'), findsOneWidget);
      expect(find.text('As a phrase'), findsNothing);
      expect(find.text('Near each other'), findsNothing);
    });

    testWidgets('a second word adds the "how words sit together" options',
        (tester) async {
      await _pumpButton(tester, _query(_twoWords));
      await _openMenu(tester);

      expect(_option('As a phrase'), findsOneWidget);
      expect(_option('Anywhere in the same text'), findsOneWidget);
      expect(_option('Near each other'), findsOneWidget);
      expect(find.text('Within 10 words'), findsOneWidget);
    });

    testWidgets('the examples use the typed words', (tester) async {
      await _pumpButton(tester, _query(_twoWords));
      await _openMenu(tester);

      expect(find.text('එවං… · මෙ…'), findsOneWidget); // Starts with
      expect(find.text('Only එවං · මෙ'), findsOneWidget); // Whole word
      expect(find.text('“එවං මෙ”'), findsOneWidget); // As a phrase
      expect(find.text('මෙ · · · · · · එවං'), findsOneWidget); // Anywhere
      expect(find.text('එවං · · මෙ'), findsOneWidget); // Near each other
    });

    testWidgets('a Singlish query shows its examples in Sinhala',
        (tester) async {
      await _pumpButton(
        tester,
        const SearchState(
            rawQueryText: 'evan me', effectiveQueryText: 'එවන් මෙ'),
      );
      await _openMenu(tester);

      expect(find.text('එවන්… · මෙ…'), findsOneWidget);
      expect(find.text('“එවන් මෙ”'), findsOneWidget);
    });

    testWidgets('a word the search drops is left out of the examples',
        (tester) async {
      await _pumpButton(
        tester,
        const SearchState(rawQueryText: 'එවං %&', effectiveQueryText: 'එවං'),
      );
      await _openMenu(tester);

      expect(find.text('Only එවං'), findsOneWidget);
    });

    testWidgets('picking an option applies it and keeps the menu open',
        (tester) async {
      final notifier = await _pumpButton(tester, _query(_twoWords));
      await _openMenu(tester);

      await tester.tap(_option('Whole word'));
      await tester.pumpAndSettle();

      expect(notifier.state.isExactMatch, isTrue);
      expect(find.text('Whole word · Phrase'), findsOneWidget);
      // Still open, so a second option can be picked straight away.
      expect(_option('Anywhere in the same text'), findsOneWidget);
    });

    testWidgets('is on the Esc stack only while open', (tester) async {
      await _pumpButton(tester, _query(_twoWords));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MatchOptionsButton)),
      );
      List<String> stack() =>
          [for (final o in container.read(overlayStackProvider)) o.id];

      await _openMenu(tester);
      expect(stack(), ['match-options-menu']);

      // What Esc does: close the overlay on top, here the menu.
      container.read(overlayStackProvider.notifier).dismissTop();
      await tester.pumpAndSettle();

      expect(_option('Whole word'), findsNothing);
      expect(stack(), isEmpty);
    });

    testWidgets('"Reset to default" is off at the defaults', (tester) async {
      await _pumpButton(tester, _query(_twoWords));
      await _openMenu(tester);

      final reset = tester.widget<MenuItemButton>(
        find.widgetWithText(MenuItemButton, 'Reset to default'),
      );
      expect(reset.onPressed, isNull);
    });

    testWidgets('"Reset to default" is off when only hidden options differ',
        (tester) async {
      // "Anywhere" was picked, then the query went back to one word.
      await _pumpButton(
        tester,
        _query(_oneWord).copyWith(
          isPhraseSearch: false,
          isAnywhereInText: true,
        ),
      );
      await _openMenu(tester);

      final reset = tester.widget<MenuItemButton>(
        find.widgetWithText(MenuItemButton, 'Reset to default'),
      );
      expect(reset.onPressed, isNull);
    });

    testWidgets('"Reset to default" restores every option', (tester) async {
      final notifier = await _pumpButton(
        tester,
        _query(_twoWords).copyWith(
          isExactMatch: true,
          isPhraseSearch: false,
          isAnywhereInText: true,
          proximityDistance: 30,
        ),
      );
      await _openMenu(tester);

      await tester.tap(find.widgetWithText(MenuItemButton, 'Reset to default'));
      await tester.pumpAndSettle();

      const defaults = SearchState();
      expect(notifier.state.isExactMatch, defaults.isExactMatch);
      expect(notifier.state.isPhraseSearch, defaults.isPhraseSearch);
      expect(notifier.state.isAnywhereInText, defaults.isAnywhereInText);
      expect(notifier.state.proximityDistance, defaults.proximityDistance);
    });

    testWidgets('+ steps the distance and picks "Near each other"',
        (tester) async {
      // Starts on "As a phrase".
      final notifier = await _pumpButton(tester, _query(_twoWords));
      await _openMenu(tester);

      await tester.tap(find.byTooltip('More words'));
      await tester.pumpAndSettle();

      expect(notifier.state.proximityDistance, 11);
      expect(notifier.state.isPhraseSearch, isFalse);
      expect(notifier.state.isAnywhereInText, isFalse);
      expect(find.text('Within 11 words'), findsOneWidget);
    });

    VoidCallback? stepper(WidgetTester tester, IconData icon) => tester
        .widget<IconButton>(find.widgetWithIcon(IconButton, icon))
        .onPressed;

    testWidgets('− is off at 1 word apart', (tester) async {
      await _pumpButton(
        tester,
        _query(_twoWords).copyWith(isPhraseSearch: false, proximityDistance: 1),
      );
      await _openMenu(tester);

      expect(stepper(tester, Icons.remove), isNull);
      expect(stepper(tester, Icons.add), isNotNull);
    });

    testWidgets('+ is off at 100 words apart', (tester) async {
      await _pumpButton(
        tester,
        _query(_twoWords)
            .copyWith(isPhraseSearch: false, proximityDistance: 100),
      );
      await _openMenu(tester);

      expect(stepper(tester, Icons.add), isNull);
      expect(stepper(tester, Icons.remove), isNotNull);
    });
  });
}
