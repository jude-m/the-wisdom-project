/// A breadcrumb trail too long for its bar (M2 in
/// `search-width-checks-test-plan.md`). The 16px before the search icon needs
/// the real app bar, so `integration_test/search_mode_test.dart` checks it.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/presentation/providers/breadcrumb_provider.dart';
import 'package:the_wisdom_project/presentation/widgets/navigation/breadcrumb_widget.dart';

import '../../helpers/pump_app.dart';

typedef _Trail = List<({String nodeKey, String displayName})>;

// Two deep suttas, each far wider than the bar below.
const _Trail _brahmajala = [
  (nodeKey: 'sp', displayName: 'සුත්තපිටකං'),
  (nodeKey: 'dn', displayName: 'දීඝනිකායො'),
  (nodeKey: 'dn-1', displayName: 'සීලක්ඛන්ධවග්ගො'),
  (nodeKey: 'dn-1-1', displayName: 'බ්‍රහ්මජාලසුත්තං'),
];
const _Trail _mulapariyaya = [
  (nodeKey: 'sp', displayName: 'සුත්තපිටකං'),
  (nodeKey: 'mn', displayName: 'මජ්ඣිමනිකායො'),
  (nodeKey: 'mn-1', displayName: 'මූලපණ්ණාසකං'),
  (nodeKey: 'mn-1-1', displayName: 'මූලපරියායවග්ගො'),
  (nodeKey: 'mn-1-1-1', displayName: 'මූලපරියායසුත්තං'),
];

void main() {
  // The active tab's trail. Setting it is opening another sutta.
  final trailProvider = StateProvider<_Trail>((ref) => _brahmajala);

  Future<ProviderContainer> pumpBreadcrumb(WidgetTester tester) async {
    await tester.pumpApp(
      const Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 200, height: 56, child: BreadcrumbWidget()),
      ),
      overrides: [
        breadcrumbPathProvider.overrideWith((ref) => ref.watch(trailProvider)),
      ],
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(BreadcrumbWidget)),
    );
  }

  // What shows: the scroll view's box. The trail: the whole text, mostly
  // off screen.
  Rect window(WidgetTester tester) => tester.getRect(find.descendant(
        of: find.byType(BreadcrumbWidget),
        matching: find.byType(Scrollable),
      ));
  Finder trailText() => find.descendant(
        of: find.byType(BreadcrumbWidget),
        matching: find.byType(RichText),
      );
  Rect trail(WidgetTester tester) => tester.getRect(trailText());

  // Drags from the middle of what shows: the trail's own middle is off screen.
  Future<void> drag(
      WidgetTester tester, double dx, PointerDeviceKind kind) async {
    await tester.dragFrom(
      window(tester).center,
      Offset(dx, 0),
      kind: kind,
    );
    await tester.pumpAndSettle();
  }

  void expectAtEnd(WidgetTester tester, String step) {
    expect(trail(tester).right, moreOrLessEquals(window(tester).right),
        reason: '$step: the sutta name shows');
    expect(trail(tester).left, lessThan(window(tester).left),
        reason: '$step: the first parents are cut');
  }

  void expectAtStart(WidgetTester tester, String step) {
    expect(trail(tester).left, moreOrLessEquals(window(tester).left),
        reason: '$step: the first parent shows');
  }

  testWidgets('a long trail stays on one line and opens at its end',
      (tester) async {
    await pumpBreadcrumb(tester);

    expect(trail(tester).width, greaterThan(window(tester).width),
        reason: 'one line: wrapped, it would fit its window');

    expectAtEnd(tester, 'opened');
  });

  testWidgets('a mouse drag and a touch drag reach the first parent',
      (tester) async {
    await pumpBreadcrumb(tester);
    final overflow = trail(tester).width;

    await drag(tester, overflow, PointerDeviceKind.mouse);
    expectAtStart(tester, 'mouse drag');

    await drag(tester, -overflow, PointerDeviceKind.mouse);
    expectAtEnd(tester, 'mouse drag back');

    await drag(tester, overflow, PointerDeviceKind.touch);
    expectAtStart(tester, 'touch drag');
  });

  testWidgets('opening another sutta opens its trail at the end again',
      (tester) async {
    final container = await pumpBreadcrumb(tester);
    await drag(tester, trail(tester).width, PointerDeviceKind.touch);
    expectAtStart(tester, 'scrolled to the start');

    container.read(trailProvider.notifier).state = _mulapariyaya;
    await tester.pumpAndSettle();

    expect(find.textContaining('මූලපරියායසුත්තං', findRichText: true),
        findsOneWidget);
    expectAtEnd(tester, 'another sutta');
  });
}
