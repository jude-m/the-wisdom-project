/// Widget tests for [ReaderActionButtonGroup].
///
/// Owns the icon → callback wiring assertions. The in-page-search
/// integration tests (`integration_test/in_page_search_test.dart`) drive
/// `inPageSearchStatesProvider.openSearch()` directly instead of tapping
/// the icon — the floating button sits behind an
/// [IgnorePointer]/[AnimatedOpacity] gate that's not reliably hit-testable
/// on cold-load frames, which made integration assertions flake. That
/// decision left no test covering the button's `onSearchTap` callback;
/// this file fills the gap by pumping the group in isolation, where
/// nothing gates pointer events.
///
/// The two step slots are covered here for the same reason and one more: the
/// group decides *which icon* each direction gets, and only a caller passing
/// both at once can show they do not collide.
///
/// Run with: `flutter test test/presentation/widgets/reader/reader_action_button_group_test.dart`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/domain/entities/navigation/tipitaka_tree_node.dart';
import 'package:the_wisdom_project/presentation/providers/parallel_text_provider.dart';
import 'package:the_wisdom_project/presentation/widgets/reader/reader_action_buttons.dart';

void main() {
  /// Pumps the button group with the providers it watches overridden to
  /// stable test defaults. Returns a counter per callback so a test can say
  /// which one fired, not merely that something did.
  Future<({int Function() search, int Function() previous, int Function() next})>
      pumpGroup(
    WidgetTester tester, {
    TipitakaTreeNode? parallelTextNode,
    bool isCommentary = false,
    String? previousTooltip,
    String? nextTooltip,
  }) async {
    var searchTaps = 0;
    var previousTaps = 0;
    var nextTaps = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Hide the commentary toggle by default — keeps the assertion
          // surface tight to the buttons under test.
          parallelTextNodeProvider.overrideWith((ref) => parallelTextNode),
          isCommentaryProvider.overrideWith((ref) => isCommentary),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ReaderActionButtonGroup(
                onSearchTap: () => searchTaps++,
                previous: previousTooltip == null
                    ? null
                    : (
                        tooltip: previousTooltip,
                        onTap: () => previousTaps++,
                      ),
                next: nextTooltip == null
                    ? null
                    : (tooltip: nextTooltip, onTap: () => nextTaps++),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (
      search: () => searchTaps,
      previous: () => previousTaps,
      next: () => nextTaps,
    );
  }

  group('ReaderActionButtonGroup', () {
    testWidgets('tapping the search icon invokes onSearchTap', (tester) async {
      // Arrange
      final taps = await pumpGroup(tester);
      expect(taps.search(), 0);

      // Act — tap the in-page-search icon.
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      // Assert — the caller-provided callback fired exactly once. This is
      // the contract MultiPaneReaderWidget relies on when it wires
      // `onSearchTap: () => …openSearch()`.
      expect(taps.search(), 1);
    });

    testWidgets(
        'search icon is present even when commentary toggle is hidden',
        (tester) async {
      // No parallel-text node → commentary/root-text toggle is omitted.
      // The search button should still render.
      await pumpGroup(tester);

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('tapping the previous icon invokes only that target',
        (tester) async {
      final taps = await pumpGroup(
        tester,
        previousTooltip: 'Go to: බ්රහ්මජාලසුත්තං',
        nextTooltip: 'Go to: අම්බට්ඨසුත්තං',
      );

      await tester.tap(find.byIcon(Icons.skip_previous));
      await tester.pumpAndSettle();

      expect(taps.previous(), 1);
      // The two slots take the same shape of argument, so a group that wired
      // both to one callback would pass every assertion but this one.
      expect(taps.next(), 0);
    });

    testWidgets('tapping the next icon invokes only that target',
        (tester) async {
      final taps = await pumpGroup(
        tester,
        previousTooltip: 'Go to: බ්රහ්මජාලසුත්තං',
        nextTooltip: 'Go to: අම්බට්ඨසුත්තං',
      );

      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pumpAndSettle();

      expect(taps.next(), 1);
      expect(taps.previous(), 0);
    });

    testWidgets('each step slot carries its own tooltip', (tester) async {
      await pumpGroup(
        tester,
        previousTooltip: 'Go to: බ්රහ්මජාලසුත්තං',
        nextTooltip: 'Go to: අම්බට්ඨසුත්තං',
      );

      Tooltip tooltipOn(IconData icon) => tester.widget<Tooltip>(
            find.ancestor(
              of: find.byIcon(icon),
              matching: find.byType(Tooltip),
            ),
          );

      expect(tooltipOn(Icons.skip_previous).message, 'Go to: බ්රහ්මජාලසුත්තං');
      expect(tooltipOn(Icons.skip_next).message, 'Go to: අම්බට්ඨසුත්තං');
    });

    testWidgets('a null step target renders no button', (tester) async {
      // The corpus edges: nothing before the first leaf, nothing after the
      // last. The group is what turns "no leaf that way" into "no button".
      await pumpGroup(tester, nextTooltip: 'Go to: අම්බට්ඨසුත්තං');

      expect(find.byIcon(Icons.skip_previous), findsNothing);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);

      await pumpGroup(tester, previousTooltip: 'Go to: බ්රහ්මජාලසුත්තං');

      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsNothing);
    });
  });
}
