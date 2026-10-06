/// Widget tests for [ReaderExpandableFab].
///
/// The FAB closes before its Share menu opens, so Copy link must still work
/// once the Share item is gone. The pill's test
/// (`reader_action_button_group_test.dart`) cannot show that.
///
/// Run with: `flutter test test/presentation/widgets/reader/reader_expandable_fab_test.dart`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/presentation/models/reader_layout.dart';
import 'package:the_wisdom_project/presentation/providers/deep_link_provider.dart';
import 'package:the_wisdom_project/presentation/providers/parallel_text_provider.dart';
import 'package:the_wisdom_project/presentation/providers/tab_provider.dart';
import 'package:the_wisdom_project/presentation/widgets/reader/reader_action_buttons.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

void main() {
  group('ReaderExpandableFab', () {
    testWidgets('Share → Copy link still copies after the FAB has closed',
        (tester) async {
      // Records the link instead of writing the clipboard.
      TipitakaLink? copied;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // No commentary item; the FAB's layout row needs a layout.
            parallelTextNodeProvider.overrideWith((ref) => null),
            isCommentaryProvider.overrideWith((ref) => false),
            activeReaderLayoutProvider
                .overrideWith((ref) => ReaderLayout.paliOnly),
            activeNodeKeyProvider.overrideWith((ref) => 'sn-2-3-1-3'),
            copyTipitakaLinkProvider.overrideWith(
              (ref) => (link) async {
                copied = link;
              },
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              // Bottom-right, where the reader puts it.
              body: Align(
                alignment: Alignment.bottomRight,
                child: ReaderExpandableFab(
                  onSearchTap: () {},
                  onScrollTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      // Act — open the FAB and tap its Share item.
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      // The FAB has closed: the Share item is gone while the menu is open.
      expect(find.text('Share'), findsNothing);

      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();

      // Assert — the tab being read was copied, and the reader is told.
      expect(copied?.nodeKey, 'sn-2-3-1-3');
      expect(find.text('Link copied'), findsOneWidget);
    });
  });
}
