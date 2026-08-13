import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/theme/text_entry_theme.dart';

void main() {
  // `readingPadding` needs a theme, not a widget: `TextEntryTheme.standard` is
  // a plain factory, so these run without a WidgetTester or a BuildContext.
  //
  // That is also what they are for. The theme is built through the REAL font
  // pipeline — `AppFonts.scaled(fontScale)` and the paragraph's own `* 1.1`
  // multiplier — so the size the column is measured against is production's
  // answer, not the test's. Handing a font size in (as the old
  // `ResponsiveUtils` form did) meant a change to that multiplier could not
  // fail anything here.
  //
  // The column is capped at a MEASURE, not a fixed width: 54.5x the paragraph
  // size, and twice that for the side-by-side pair. At the 17.6px default that
  // is 959.2px and 1918.4px; once the reader PANE is wider than the cap + 24*2,
  // the leftover is split into equal left/right margins, and at or below it the
  // padding stays a uniform 24px.
  //
  // Expected numbers are written as plain arithmetic on purpose (rather than
  // derived from the production constants) so the test pins the padding a user
  // actually sees, and fails loudly if the tuned values change. `closeTo` only
  // absorbs binary floating-point drift in that arithmetic.

  /// The paragraph size at the default 1.0x font scale — `AppFonts.baseFontSize
  /// (16) * 1.1`. Spelled out rather than imported for the reason above.
  const defaultParagraph = 17.6;

  TextEntryTheme themeAt([double fontScale = 1.0]) => TextEntryTheme.standard(
        headingColor: const Color(0xFF000000),
        bodyColor: const Color(0xFF000000),
        fontScale: fontScale,
      );

  group('TextEntryTheme.readingPadding', () {
    group('narrow panes keep the standard uniform 24px padding', () {
      test('phone width (400)', () {
        expect(themeAt().readingPadding(400), const EdgeInsets.all(24));
      });

      test('tablet portrait width (768)', () {
        expect(themeAt().readingPadding(768), const EdgeInsets.all(24));
      });

      test('exactly at the threshold (959.2 + 48) still stays uniform', () {
        // The branch is `availableWidth <= maxColumn + 48`, so the boundary
        // itself is uniform — margins only begin strictly above it.
        expect(
          themeAt().readingPadding(54.5 * defaultParagraph + 48),
          const EdgeInsets.all(24),
        );
      });
    });

    group('wide panes cap the column and split the rest into equal margins',
        () {
      test('just past the threshold grows continuously from 24 (no jump)', () {
        // One pixel past the boundary the horizontal padding is still ~24.5,
        // so there is no visible jump.
        final padding =
            themeAt().readingPadding(54.5 * defaultParagraph + 49);
        expect(padding.left, closeTo(24.5, 0.01));
      });

      test('tablet landscape width (1024) -> ~32px each side', () {
        // (1024 - 959.2) / 2 = 32.4
        expect(themeAt().readingPadding(1024).left, closeTo(32.4, 0.01));
      });

      test('14-inch MacBook Pro (1512) -> ~276px each side', () {
        // (1512 - 959.2) / 2 = 276.4
        expect(themeAt().readingPadding(1512).left, closeTo(276.4, 0.01));
      });

      test('large external monitor (1920) -> ~480px each side', () {
        // (1920 - 959.2) / 2 = 480.4
        expect(themeAt().readingPadding(1920).left, closeTo(480.4, 0.01));
      });

      test('left and right margins are always equal; vertical stays at 24', () {
        final padding = themeAt().readingPadding(1700);
        // Equal gutters are the whole point of the "calm" centered column.
        expect(padding.left, padding.right);
        // The wider margins are horizontal-only — vertical never changes.
        expect(padding.top, 24);
        expect(padding.bottom, 24);
      });
    });

    group('the column tracks the font scale, so the measure never moves', () {
      // The reason the cap is a measure and not a width: FontScaleNotifier lets
      // a reader run 0.7x–1.5x, and a fixed 960px would have meant 78em of text
      // at the small end and 36em at the large one.
      test('the resulting column is always 54.5x the paragraph size', () {
        for (final scale in [0.7, 1.0, 1.25, 1.5]) {
          // A 2560px pane is wide enough that every scale is capped.
          final padding = themeAt(scale).readingPadding(2560);
          final column = 2560 - padding.horizontal;
          expect(column / (defaultParagraph * scale), closeTo(54.5, 0.01),
              reason: 'measure drifted at ${scale}x');
        }
      });

      test('a 1.5x reader gets a visibly wider column than a 1.0x one', () {
        // Wider column means narrower margins.
        expect(themeAt(1.5).readingPadding(2560).left,
            lessThan(themeAt().readingPadding(2560).left));
      });
    });
  });

  group('TextEntryTheme.readingPadding(columns: 2)', () {
    test('a laptop pane is untouched — the pair still gets the whole window',
        () {
      // 1440 is well under 1918.4 + 24*2, so side-by-side reads exactly as it
      // did before the cap existed.
      expect(themeAt().readingPadding(1440, columns: 2),
          const EdgeInsets.all(24));
    });

    test('exactly at the threshold (1918.4 + 48) still stays uniform', () {
      expect(
        themeAt().readingPadding(2 * 54.5 * defaultParagraph + 48, columns: 2),
        const EdgeInsets.all(24),
      );
    });

    test('large external monitor (2560) -> ~321px each side', () {
      // (2560 - 1918.4) / 2 = 320.8 — without this each column would be
      // 1240px, as long a line as the single-column layout used to allow.
      expect(themeAt().readingPadding(2560, columns: 2).left,
          closeTo(320.8, 0.01));
    });

    test('the pair is exactly twice the single-script measure', () {
      // The point of deriving it: each side reads at the same measure as a
      // single-script pane, so switching layout does not change the line.
      final theme = themeAt();
      final pair = 2560 - theme.readingPadding(2560, columns: 2).horizontal;
      final single = 2560 - theme.readingPadding(2560).horizontal;
      expect(pair / single, closeTo(2.0, 0.001));
    });

    test('caps later than the single-script column', () {
      // The pair is allowed more room than one column: at 1440 side-by-side is
      // still uniform while the single-script panes have long been centered.
      final theme = themeAt();
      expect(
          theme.readingPadding(1440, columns: 2), const EdgeInsets.all(24));
      expect(theme.readingPadding(1440).left, greaterThan(24));
    });
  });
}
