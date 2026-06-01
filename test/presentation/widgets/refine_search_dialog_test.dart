/// Widget tests for the පාළි / සිංහල language toggle in [RefineSearchDialog].
///
/// Focus is the toggle's *contract*: it renders the edition's languages, drives
/// `setLanguageFilter`, enforces "at least one language always on", and hides
/// itself when the edition has fewer than two languages. The scope tree is fed
/// an empty list so only the toggle is under test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/domain/entities/content/content_language.dart';
import 'package:the_wisdom_project/domain/entities/navigation/tipitaka_tree_node.dart';
import 'package:the_wisdom_project/presentation/providers/content_language_provider.dart';
import 'package:the_wisdom_project/presentation/providers/navigation_tree_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_state.dart';
import 'package:the_wisdom_project/presentation/widgets/search/refine_search_dialog.dart';

import '../../helpers/pump_app.dart';

/// A [SearchStateNotifier] stand-in that records `setLanguageFilter` calls and
/// applies them to its state, so the dialog's SegmentedButton reflects changes.
class _RecordingSearchNotifier extends StateNotifier<SearchState>
    implements SearchStateNotifier {
  _RecordingSearchNotifier(super.state);

  final List<({bool? pali, bool? sinhala})> languageCalls = [];

  @override
  void setLanguageFilter({bool? pali, bool? sinhala}) {
    languageCalls.add((pali: pali, sinhala: sinhala));
    state = state.copyWith(
      searchInPali: pali ?? state.searchInPali,
      searchInSinhala: sinhala ?? state.searchInSinhala,
    );
  }

  // The tree checkboxes / Reset button call this; harmless no-op for these tests.
  @override
  void setScope(Set<String> nodeKeys) =>
      state = state.copyWith(scope: nodeKeys);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'Not needed for this test: ${invocation.memberName}',
      );
}

void main() {
  /// Pumps the dialog and returns the recording notifier so tests can inspect
  /// the `setLanguageFilter` calls it received.
  Future<_RecordingSearchNotifier> pumpDialog(
    WidgetTester tester, {
    required bool searchInPali,
    required bool searchInSinhala,
    required List<ContentLanguage> available,
  }) async {
    final notifier = _RecordingSearchNotifier(
      SearchState(
        rawQueryText: 'metta',
        searchInPali: searchInPali,
        searchInSinhala: searchInSinhala,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...defaultTestOverrides(),
          searchStateProvider.overrideWith((ref) => notifier),
          availableContentLanguagesProvider.overrideWithValue(available),
          // The tree rows render in this language; value is irrelevant here.
          effectiveContentLanguageProvider
              .overrideWithValue(ContentLanguage.sinhala),
          // Empty tree → the scope section builds nothing of interest.
          navigationTreeProvider
              .overrideWith((ref) async => const <TipitakaTreeNode>[]),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: RefineSearchDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  SegmentedButton<ContentLanguage> readToggle(WidgetTester tester) =>
      tester.widget<SegmentedButton<ContentLanguage>>(
        find.byType(SegmentedButton<ContentLanguage>),
      );

  testWidgets('renders both language segments, both selected when both on',
      (tester) async {
    await pumpDialog(
      tester,
      searchInPali: true,
      searchInSinhala: true,
      available: const [ContentLanguage.pali, ContentLanguage.sinhala],
    );

    // Header is present (mirror of the "hidden when <2 languages" test below).
    expect(find.text('LANGUAGE'), findsOneWidget);
    expect(find.text('Pali'), findsOneWidget);
    expect(find.text('Sinhala'), findsOneWidget);
    expect(
      readToggle(tester).selected,
      {ContentLanguage.pali, ContentLanguage.sinhala},
    );
  });

  testWidgets(
      'tapping a selected segment (both on) narrows the filter to the other',
      (tester) async {
    final notifier = await pumpDialog(
      tester,
      searchInPali: true,
      searchInSinhala: true,
      available: const [ContentLanguage.pali, ContentLanguage.sinhala],
    );

    // Tapping the (selected) Pali segment deselects it → only Sinhala remains.
    await tester.tap(find.text('Pali'));
    await tester.pumpAndSettle();

    expect(notifier.languageCalls, isNotEmpty);
    expect(notifier.languageCalls.last, (pali: false, sinhala: true));
  });

  testWidgets(
      'MANDATORY: tapping the only selected segment cannot turn it off',
      (tester) async {
    // Only Pali is on. Its segment is locked (disabled), so a tap is a no-op —
    // the user can never reach "zero languages selected".
    final notifier = await pumpDialog(
      tester,
      searchInPali: true,
      searchInSinhala: false,
      available: const [ContentLanguage.pali, ContentLanguage.sinhala],
    );

    await tester.tap(find.text('Pali'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(notifier.languageCalls, isEmpty);
    // Selection is unchanged: still exactly Pali.
    expect(readToggle(tester).selected, {ContentLanguage.pali});
  });

  testWidgets('edition with fewer than two languages hides the whole toggle',
      (tester) async {
    await pumpDialog(
      tester,
      searchInPali: true,
      searchInSinhala: true,
      available: const [ContentLanguage.pali], // single-language edition
    );

    expect(find.byType(SegmentedButton<ContentLanguage>), findsNothing);
    expect(find.text('LANGUAGE'), findsNothing);
  });
}
