import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/constants/constants.dart';
import 'package:the_wisdom_project/core/theme/app_fonts.dart';
import 'package:the_wisdom_project/core/theme/app_typography.dart';
import 'package:the_wisdom_project/core/theme/text_entry_theme.dart';
import 'package:the_wisdom_project/core/theme/theme_notifier.dart';

void main() {
  // `proseColumnMaxWidth` needs a theme, not a widget:
  // `AppTypography.fromColorScheme` is a plain factory, so these run without a
  // WidgetTester or a BuildContext.
  //
  // That is also what they are for. The cap is built through the REAL font
  // pipeline — `AppFonts.scaled(fontScale).tree`, by way of
  // `definitionBody.fontSize` — so the width a sheet is constrained to is
  // production's answer, not the test's. Reading the em out of the constants
  // file and multiplying it here would have meant a change to `AppFonts.scaled`
  // could not fail anything.
  //
  // The prose surfaces (dictionary sheet, research column, citation peek) are
  // capped at a MEASURE, not a fixed width: 44x the definition size, plus the
  // 16px gutter on each side, because what a call site constrains is the
  // CONTAINER and what the measure describes is the text inside it. At the 14px
  // default that is 44*14 + 32 = 648px.
  //
  // Expected WIDTHS are written as plain arithmetic on purpose (rather than
  // derived from the production constants) so the test pins the width a user
  // actually sees, and fails loudly if the tuned values change. `closeTo` only
  // absorbs binary floating-point drift in that arithmetic. Two tests assert a
  // RELATIONSHIP between production values instead — that the cap tracks
  // `definitionBody`'s own size, and that it is that style and not one of the
  // six same-sized siblings — and those are complementary to the spelled-out
  // numbers, not a breach of them.

  /// The definition size at the default 1.0x font scale — `AppFonts
  /// .treeFontSize`. Spelled out rather than imported for the reason above.
  const defaultDefinition = 14.0;

  /// The reader paragraph at 1.0x — `AppFonts.baseFontSize (16) * 1.1`. Only
  /// needed to show the two measures are not the same measure.
  const defaultParagraph = 17.6;

  AppTypography typographyAt([double fontScale = 1.0]) =>
      AppTypography.fromColorScheme(
        const ColorScheme.light(),
        fontScale: fontScale,
      );

  TextEntryTheme readerThemeAt([double fontScale = 1.0]) =>
      TextEntryTheme.standard(
        headingColor: const Color(0xFF000000),
        bodyColor: const Color(0xFF000000),
        fontScale: fontScale,
      );

  group('the numbers this file spells out', () {
    // Spelling the arithmetic out is what makes the rest of the file pin a
    // width a user sees — but it also means moving one production constant
    // fails five tests at once, each reporting bare arithmetic. This group
    // fails BY NAME, so those become consequences rather than the diagnosis.
    test('are still the production values', () {
      expect(AppFonts.treeFontSize, defaultDefinition,
          reason: 'the definition size moved');
      expect(AppFonts.baseFontSize * 1.1, closeTo(defaultParagraph, 0.01),
          reason: 'the reader paragraph moved');
      expect(PaneWidthConstants.proseColumnMeasureEm, 44.0,
          reason: 'the prose measure moved');
      expect(PaneWidthConstants.proseColumnGutter, 16.0,
          reason: 'the gutter moved');
      expect(PaneWidthConstants.readingColumnMeasureEm, 54.5,
          reason: 'the reader measure moved');
    });

    test('0.7x and 1.5x are still the ends of the slider', () {
      // Tests below are NAMED "smallest reader" and "largest reader". Widen
      // the slider and this file keeps passing while its names lie.
      expect(FontScaleNotifier.minScale, 0.7);
      expect(FontScaleNotifier.maxScale, 1.5);
    });
  });

  group('AppTypography.proseColumnMaxWidth', () {
    test('smallest reader (0.7x) -> 44 * 9.8 + 32', () {
      // 44 * (14 * 0.7) + 16 * 2 = 431.2 + 32 = 463.2
      expect(typographyAt(0.7).proseColumnMaxWidth, closeTo(463.2, 0.01));
    });

    test('native default (1.0x) -> 44 * 14 + 32', () {
      // 44 * 14 + 16 * 2 = 616 + 32 = 648. Native only: web starts at
      // `AppFonts.webDefaultScale` (0.9), so an untouched web reader gets
      // 583.2. Both are points on the same line; 1.0 is the one worth pinning.
      expect(typographyAt().proseColumnMaxWidth, closeTo(648.0, 0.01));
    });

    test('largest reader (1.5x) -> 44 * 21 + 32', () {
      // 44 * (14 * 1.5) + 16 * 2 = 924 + 32 = 956
      expect(typographyAt(1.5).proseColumnMaxWidth, closeTo(956.0, 0.01));
    });

    test('the cap is always 44x the definition size, plus both gutters', () {
      // The same three numbers said as one rule: whatever the scale, strip the
      // gutters and what is left is 44 definition-sizes of text.
      for (final scale in [0.7, 1.0, 1.25, 1.5]) {
        final text = typographyAt(scale).proseColumnMaxWidth - 16 * 2;
        expect(text / (defaultDefinition * scale), closeTo(44.0, 0.01),
            reason: 'measure drifted at ${scale}x');
      }
    });

    test('the cap follows definitionBody, whatever size that style is', () {
      // Complementary to the literal test above, and the diagnosis when both
      // fail: this one still holds if definitionBody is deliberately re-sized
      // (the cap is SUPPOSED to move with it) and breaks only if the cap stops
      // being 44em of it.
      //
      // What it cannot catch is the getter being re-pointed at one of the six
      // siblings that also take `scaledFonts.tree` — they all report the same
      // 14, so the arithmetic is identical. The copyWith group below is
      // what pins ownership; confirmed by re-pointing the getter at
      // treeNodeLabel and watching only that group go red.
      for (final scale in [0.7, 1.0, 1.5]) {
        final typography = typographyAt(scale);
        expect(typography.proseColumnMaxWidth,
            closeTo(44 * typography.definitionBody.fontSize! + 32, 0.01),
            reason: 'cap detached from definitionBody at ${scale}x');
      }
    });
  });

  group('the cap tracks the font scale', () {
    // This is the regression B6 exists to kill. The three surfaces used to be
    // capped at fixed pixel widths (800 for the dictionary sheet, 760 for the
    // research column), and a fixed width is FLAT across the slider: a 1.5x
    // reader got the same 800px, which is 38em of text instead of 57em. An em
    // cap cannot be flat.
    test('strictly monotonic across 0.7x -> 1.0x -> 1.5x', () {
      expect(typographyAt(0.7).proseColumnMaxWidth,
          lessThan(typographyAt(1.0).proseColumnMaxWidth));
      expect(typographyAt(1.0).proseColumnMaxWidth,
          lessThan(typographyAt(1.5).proseColumnMaxWidth));
    });

    test('a 1.5x reader gets a visibly wider column than a 0.7x one', () {
      // Not just "different" — the whole slider range has to move the cap by
      // more than a rounding error, or the measure is not holding.
      expect(
        typographyAt(1.5).proseColumnMaxWidth -
            typographyAt(0.7).proseColumnMaxWidth,
        greaterThan(400),
      );
    });
  });

  group('the prose measure is independent of the reader measure', () {
    // "A different number for different content, not a copy of 54.5." Sinhala
    // says the same thing in shorter words than the reader's Pali, so the same
    // em would buy the UI a longer line. These two tests are here so a future
    // tidy-up cannot quietly fold one constant into the other.
    test('the two ems are different numbers', () {
      expect(PaneWidthConstants.proseColumnMeasureEm,
          isNot(PaneWidthConstants.readingColumnMeasureEm));
    });

    test('the prose cap is not the reader cap at the same scale', () {
      for (final scale in [0.7, 1.0, 1.5]) {
        // The reader's cap, taken from the real pipeline: a 4000px pane is wide
        // enough that every scale is capped, so the leftover column IS the cap.
        // text_entry_theme_test.dart owns that contract; re-deriving it here is
        // what makes this comparison self-verifying rather than trusting a
        // number copied across files.
        final readerCap =
            4000 - readerThemeAt(scale).readingPadding(4000).horizontal;
        expect(readerCap, closeTo(54.5 * defaultParagraph * scale, 0.01),
            reason: 'reader cap moved at ${scale}x');

        final proseCap = typographyAt(scale).proseColumnMaxWidth;
        expect(proseCap, isNot(closeTo(readerCap, 1)),
            reason: 'prose cap collapsed onto the reader cap at ${scale}x');
        // And specifically NARROWER: 44em of a 14px face is less than 54.5em of
        // a 17.6px one even after the gutters are added back.
        expect(proseCap, lessThan(readerCap));
      }
    });
  });

  group('definitionBody survives a lerp', () {
    // `proseColumnMaxWidth` reads `definitionBody.fontSize!`. ThemeData
    // interpolates extensions on every theme animation, so the style the getter
    // actually divides by is usually a lerped one — if a lerp could drop the
    // size, the `!` would throw mid-transition rather than at build time.
    test('fontSize is non-null at both ends and in the middle', () {
      final small = typographyAt(0.7);
      final large = typographyAt(1.5);

      for (final t in [0.0, 0.5, 1.0]) {
        final lerped = small.lerp(large, t) as AppTypography;
        expect(lerped.definitionBody.fontSize, isNotNull, reason: 't = $t');
        // The `!` is only safe if the getter itself runs, so run it.
        expect(lerped.proseColumnMaxWidth, isPositive, reason: 't = $t');
      }
    });

    test('the midpoint cap is the midpoint of the two caps', () {
      // A round trip that changes the value is fine; one that changes the RULE
      // is not. Halfway between 0.7x and 1.5x is 1.1x: 44 * 15.4 + 32 = 709.6.
      final midpoint =
          typographyAt(0.7).lerp(typographyAt(1.5), 0.5) as AppTypography;
      expect(midpoint.proseColumnMaxWidth, closeTo(709.6, 0.01));
    });

    test('lerping a theme with itself is a no-op', () {
      final theme = typographyAt();
      final same = theme.lerp(theme, 0.5) as AppTypography;
      expect(same.definitionBody.fontSize, closeTo(defaultDefinition, 0.01));
      expect(same.proseColumnMaxWidth, closeTo(648.0, 0.01));
    });
  });

  group('the cap follows a copyWith', () {
    // The other way an AppTypography gets built, the other half of the "`!` is
    // safe" claim — and the ONLY test in this file that pins WHICH style the
    // cap is measured against. `scaledFonts.tree` sizes seven styles
    // (resultSubtitle, resultMatchedText, listRowTitle, treeNodeLabel and the
    // rest), so every test above survives the getter being re-pointed at any
    // of them. Replacing definitionBody alone is what separates the seven, and
    // "a measure is arithmetic on the type it measures" is the whole argument
    // for the getter living on this class.
    test('a substituted definitionBody moves the cap with it', () {
      final swapped = typographyAt().copyWith(
        definitionBody: const TextStyle(fontSize: 20),
      ) as AppTypography;
      // 44 * 20 + 16 * 2 = 880 + 32 = 912.
      expect(swapped.proseColumnMaxWidth, closeTo(912.0, 0.01));
    });

    test('a definitionBody with no size declines to guess one', () {
      // Narrower than "the case the `!` exists for": nothing constructs a
      // sizeless definitionBody — the factory always sizes it, lerp preserves
      // it, both tested above. What this pins is the DECLINE, and it fails on
      // exactly one edit: `fontSize!` becoming `fontSize ?? <anything>`.
      //
      // That edit cannot be written correctly. AppTypography keeps no
      // fontScale field — only styles — so the scale survives in precisely the
      // one place a fallback has just failed to read. Any constant put there
      // is therefore flat across the slider, which is the fixed-width cap B6
      // removed, walking back in through a different door.
      final sizeless = typographyAt().copyWith(
        definitionBody: const TextStyle(),
      ) as AppTypography;
      expect(() => sizeless.proseColumnMaxWidth, throwsA(isA<TypeError>()));
    });

    test('an untouched copyWith leaves the cap alone', () {
      final copy = typographyAt().copyWith(badgeLabel: const TextStyle())
          as AppTypography;
      expect(copy.proseColumnMaxWidth, closeTo(648.0, 0.01));
    });
  });
}
