/// The chip row scrolls sideways with a mouse drag too (M12 in
/// `search-width-checks-test-plan.md`). The scope and dictionary chips both
/// sit in this row.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/presentation/widgets/common/pill_chip.dart';
import 'package:the_wisdom_project/presentation/widgets/common/pill_chip_row.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('a mouse drag scrolls the row', (tester) async {
    await tester.pumpApp(
      SizedBox(
        width: 200,
        height: 48,
        child: PillChipRow(
          children: [
            for (final label in const [
              'සුත්ත',
              'විනය',
              'අභිධම්ම',
              'අට්ඨකථා',
              'අන්‍ය',
            ])
              PillChip(label: label, selected: false, onPressed: () {}),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byType(Scrollable);
    double offset() => tester.state<ScrollableState>(row).position.pixels;
    expect(tester.state<ScrollableState>(row).position.maxScrollExtent,
        greaterThan(0),
        reason: 'the chips must not fit, or there is nothing to drag');

    await tester.dragFrom(
      tester.getCenter(row),
      const Offset(-100, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(offset(), greaterThan(0));
  });
}
