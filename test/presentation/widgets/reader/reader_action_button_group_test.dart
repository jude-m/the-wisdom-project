/// Widget tests for [ReaderActionButtonGroup].
///
/// Owns the icon → `onSearchTap` wiring assertion. The in-page-search
/// integration tests (`integration_test/in_page_search_test.dart`) drive
/// `inPageSearchStatesProvider.openSearch()` directly instead of tapping
/// the icon — the floating button sits behind an
/// [IgnorePointer]/[AnimatedOpacity] gate that's not reliably hit-testable
/// on cold-load frames, which made integration assertions flake. That
/// decision left no test covering the button's `onSearchTap` callback;
/// this file fills the gap by pumping the group in isolation, where
/// nothing gates pointer events.
///
/// Run with: `flutter test test/presentation/widgets/reader/reader_action_button_group_test.dart`

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/domain/entities/navigation/tipitaka_tree_node.dart';
import 'package:the_wisdom_project/presentation/providers/parallel_text_provider.dart';
import 'package:the_wisdom_project/presentation/widgets/reader/reader_action_buttons.dart';

void main() {
  /// Pumps the button group with the providers it watches overridden to
  /// stable test defaults. Returns a counter that increments each time
  /// the search button's callback fires.
  Future<({int Function() searchTaps})> pumpGroup(
    WidgetTester tester, {
    TipitakaTreeNode? parallelTextNode,
    bool isCommentary = false,
    VoidCallback? onScrollTap,
  }) async {
    var searchTapCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Hide the commentary toggle by default — keeps the assertion
          // surface tight to the search button.
          parallelTextNodeProvider.overrideWith((ref) => parallelTextNode),
          isCommentaryProvider.overrideWith((ref) => isCommentary),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ReaderActionButtonGroup(
                onSearchTap: () => searchTapCount++,
                onScrollTap: onScrollTap,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (searchTaps: () => searchTapCount);
  }

  group('ReaderActionButtonGroup', () {
    testWidgets('tapping the search icon invokes onSearchTap', (tester) async {
      // Arrange
      final taps = await pumpGroup(tester);
      expect(taps.searchTaps(), 0);

      // Act — tap the in-page-search icon.
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      // Assert — the caller-provided callback fired exactly once. This is
      // the contract MultiPaneReaderWidget relies on when it wires
      // `onSearchTap: () => …openSearch()`.
      expect(taps.searchTaps(), 1);
    });

    testWidgets(
        'search icon is present even when commentary toggle is hidden',
        (tester) async {
      // No parallel-text node → commentary/root-text toggle is omitted.
      // The search button should still render.
      await pumpGroup(tester);

      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });
}
