import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/utils/responsive_utils.dart';

void main() {
  // `readingColumnPadding` is a pure function (no BuildContext), so it can be
  // exercised directly without a WidgetTester.
  //
  // It caps the single-script reader column at 1240px: once the reader PANE is
  // wider than 1240 + 24*2 = 1288px, the leftover space is split into equal
  // left/right margins; at or below 1288px it keeps the standard uniform 24px.
  //
  // The expected numbers below are written as plain literals on purpose (rather
  // than derived from the production constants) so the test pins the exact
  // padding a user actually sees, and fails loudly if the tuned values change.
  group('ResponsiveUtils.readingColumnPadding', () {
    group('narrow panes keep the standard uniform 24px padding', () {
      test('phone width (400)', () {
        expect(
          ResponsiveUtils.readingColumnPadding(400),
          const EdgeInsets.all(24),
        );
      });

      test('tablet portrait width (768)', () {
        expect(
          ResponsiveUtils.readingColumnPadding(768),
          const EdgeInsets.all(24),
        );
      });

      test('tablet landscape width (1024)', () {
        expect(
          ResponsiveUtils.readingColumnPadding(1024),
          const EdgeInsets.all(24),
        );
      });

      test('exactly at the 1288px threshold still stays uniform', () {
        // The branch is `availableWidth <= 1288`, so the boundary itself is
        // uniform — margins only begin strictly above it.
        expect(
          ResponsiveUtils.readingColumnPadding(1288),
          const EdgeInsets.all(24),
        );
      });
    });

    group('wide panes cap the column and split the rest into equal margins', () {
      test('just past the threshold grows continuously from 24 (no jump)', () {
        // (1289 - 1240) / 2 = 24.5 — i.e. one pixel past the boundary the
        // horizontal padding is still ~24, so there is no visible jump.
        expect(
          ResponsiveUtils.readingColumnPadding(1289),
          const EdgeInsets.symmetric(horizontal: 24.5, vertical: 24),
        );
      });

      test('14-inch MacBook Pro (1512) -> 136px each side', () {
        // (1512 - 1240) / 2 = 136
        expect(
          ResponsiveUtils.readingColumnPadding(1512),
          const EdgeInsets.symmetric(horizontal: 136, vertical: 24),
        );
      });

      test('large external monitor (1920) -> 340px each side', () {
        // (1920 - 1240) / 2 = 340
        expect(
          ResponsiveUtils.readingColumnPadding(1920),
          const EdgeInsets.symmetric(horizontal: 340, vertical: 24),
        );
      });

      test('left and right margins are always equal; vertical stays at 24', () {
        final padding = ResponsiveUtils.readingColumnPadding(1700);
        // Equal gutters are the whole point of the "calm" centered column.
        expect(padding.left, padding.right);
        // The wider margins are horizontal-only — vertical never changes.
        expect(padding.top, 24);
        expect(padding.bottom, 24);
      });
    });
  });
}
