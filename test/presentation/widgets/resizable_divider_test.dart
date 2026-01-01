import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/presentation/widgets/resizable_divider.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('ResizableDivider -', () {
    group('Disabled state', () {
      testWidgets('should return empty SizedBox when disabled', (tester) async {
        // ARRANGE & ACT
        await tester.pumpApp(
          ResizableDivider(
            isEnabled: false,
            onDragUpdate: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        // ASSERT - Should not render the full divider structure
        // When disabled, it returns SizedBox.shrink() which has 0x0 dimensions
        expect(find.byType(AnimatedContainer), findsNothing);
        expect(find.byType(Center), findsNothing);
      });

      testWidgets('should not render MouseRegion when disabled',
          (tester) async {
        // ARRANGE & ACT
        await tester.pumpApp(
          ResizableDivider(
            isEnabled: false,
            onDragUpdate: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        // ASSERT - MouseRegion should not be present as a descendant of ResizableDivider
        expect(
          find.descendant(
            of: find.byType(ResizableDivider),
            matching: find.byType(MouseRegion),
          ),
          findsNothing,
        );
      });

      testWidgets('should not render GestureDetector when disabled',
          (tester) async {
        // ARRANGE & ACT
        await tester.pumpApp(
          ResizableDivider(
            isEnabled: false,
            onDragUpdate: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        // ASSERT - GestureDetector should not be present as a descendant of ResizableDivider
        expect(
          find.descendant(
            of: find.byType(ResizableDivider),
            matching: find.byType(GestureDetector),
          ),
          findsNothing,
        );
      });
    });

    group('Enabled state', () {
      testWidgets('should show pill-shaped indicator when enabled',
          (tester) async {
        // ARRANGE & ACT
        await tester.pumpApp(
          ResizableDivider(
            isEnabled: true,
            onDragUpdate: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        // ASSERT - Should find the pill indicator (inner Container with specific dimensions)
        // The pill is inside a Center widget inside an AnimatedContainer
        expect(find.byType(Center), findsOneWidget);

        // Find the Container that forms the pill
        // It should have width: 4, height: 32
        final containers = find.byType(Container);
        expect(containers, findsWidgets);
      });

      testWidgets('should render with 8px width when enabled', (tester) async {
        // ARRANGE & ACT
        await tester.pumpApp(
          ResizableDivider(
            isEnabled: true,
            onDragUpdate: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        // ASSERT - AnimatedContainer should have width of 8
        final animatedContainer =
            tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
        // Width is set via constraints property
        expect(animatedContainer.constraints?.maxWidth, equals(8.0));
      });

      testWidgets('should render MouseRegion when enabled', (tester) async {
        // ARRANGE & ACT
        await tester.pumpApp(
          ResizableDivider(
            isEnabled: true,
            onDragUpdate: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        // ASSERT - MouseRegion should be present as a descendant of ResizableDivider
        expect(
          find.descendant(
            of: find.byType(ResizableDivider),
            matching: find.byType(MouseRegion),
          ),
          findsOneWidget,
        );
      });

      testWidgets('should render GestureDetector when enabled', (tester) async {
        // ARRANGE & ACT
        await tester.pumpApp(
          ResizableDivider(
            isEnabled: true,
            onDragUpdate: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        // ASSERT
        expect(find.byType(GestureDetector), findsOneWidget);
      });
    });

    group('Drag callbacks', () {
      testWidgets('onDragUpdate callback should receive correct delta values',
          (tester) async {
        // ARRANGE
        final List<double> capturedDeltas = [];

        await tester.pumpApp(
          ResizableDivider(
            isEnabled: true,
            onDragUpdate: (delta) {
              capturedDeltas.add(delta);
            },
          ),
        );
        await tester.pumpAndSettle();

        // ACT - Perform a horizontal drag
        final divider = find.byType(ResizableDivider);
        await tester.drag(divider, const Offset(50.0, 0.0));
        await tester.pumpAndSettle();

        // ASSERT - Should have received drag updates
        expect(capturedDeltas.isNotEmpty, isTrue);
        // The total delta should approximate 50.0
        final totalDelta =
            capturedDeltas.fold(0.0, (sum, delta) => sum + delta);
        expect(totalDelta, closeTo(50.0, 5.0)); // Allow some tolerance
      });

      testWidgets(
          'onDragUpdate callback should receive negative delta for left drag',
          (tester) async {
        // ARRANGE
        final List<double> capturedDeltas = [];

        await tester.pumpApp(
          ResizableDivider(
            isEnabled: true,
            onDragUpdate: (delta) {
              capturedDeltas.add(delta);
            },
          ),
        );
        await tester.pumpAndSettle();

        // ACT - Perform a horizontal drag to the left
        final divider = find.byType(ResizableDivider);
        await tester.drag(divider, const Offset(-30.0, 0.0));
        await tester.pumpAndSettle();

        // ASSERT - Total delta should be negative
        final totalDelta =
            capturedDeltas.fold(0.0, (sum, delta) => sum + delta);
        expect(totalDelta, isNegative);
        expect(totalDelta, closeTo(-30.0, 5.0));
      });

      testWidgets('onDragEnd callback should be invoked when drag ends',
          (tester) async {
        // ARRANGE
        bool dragEndCalled = false;

        await tester.pumpApp(
          ResizableDivider(
            isEnabled: true,
            onDragUpdate: (_) {},
            onDragEnd: () {
              dragEndCalled = true;
            },
          ),
        );
        await tester.pumpAndSettle();

        // ACT - Perform a drag gesture
        final divider = find.byType(ResizableDivider);
        await tester.drag(divider, const Offset(20.0, 0.0));
        await tester.pumpAndSettle();

        // ASSERT
        expect(dragEndCalled, isTrue);
      });

      testWidgets('should handle null onDragEnd callback gracefully',
          (tester) async {
        // ARRANGE - No onDragEnd callback provided
        await tester.pumpApp(
          ResizableDivider(
            isEnabled: true,
            onDragUpdate: (_) {},
            // onDragEnd is not provided
          ),
        );
        await tester.pumpAndSettle();

        // ACT - Perform a drag gesture (should not throw)
        final divider = find.byType(ResizableDivider);
        await tester.drag(divider, const Offset(20.0, 0.0));
        await tester.pumpAndSettle();

        // ASSERT - No exception should be thrown
        // (test passes if we reach this point)
        expect(true, isTrue);
      });

      testWidgets('vertical drag should not trigger onDragUpdate',
          (tester) async {
        // ARRANGE
        final List<double> capturedDeltas = [];

        await tester.pumpApp(
          ResizableDivider(
            isEnabled: true,
            onDragUpdate: (delta) {
              capturedDeltas.add(delta);
            },
          ),
        );
        await tester.pumpAndSettle();

        // ACT - Perform a purely vertical drag
        final divider = find.byType(ResizableDivider);
        await tester.drag(divider, const Offset(0.0, 50.0));
        await tester.pumpAndSettle();

        // ASSERT - No horizontal deltas should be captured
        // (or only very small values from gesture detection)
        final totalDelta =
            capturedDeltas.fold(0.0, (sum, delta) => sum + delta);
        expect(totalDelta.abs(), lessThan(5.0));
      });
    });

    group('showPillBorder option', () {
      testWidgets('should show border when showPillBorder is true',
          (tester) async {
        // ARRANGE & ACT
        await tester.pumpApp(
          ResizableDivider(
            isEnabled: true,
            showPillBorder: true,
            onDragUpdate: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        // ASSERT - The pill Container should have a border
        // We verify by checking that the widget tree contains the expected structure
        expect(find.byType(Center), findsOneWidget);

        // Find containers and verify one has decoration with border
        final containers = tester.widgetList<Container>(find.byType(Container));

        // Look for a container with BoxDecoration that has a border
        bool foundBorderedContainer = false;
        for (final container in containers) {
          if (container.decoration is BoxDecoration) {
            final decoration = container.decoration as BoxDecoration;
            if (decoration.border != null) {
              foundBorderedContainer = true;
              break;
            }
          }
        }
        expect(foundBorderedContainer, isTrue,
            reason: 'Should find a Container with border when showPillBorder is true');
      });

      testWidgets('should not show border when showPillBorder is false',
          (tester) async {
        // ARRANGE & ACT
        await tester.pumpApp(
          ResizableDivider(
            isEnabled: true,
            showPillBorder: false,
            onDragUpdate: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        // ASSERT - The pill Container should not have a border
        final containers = tester.widgetList<Container>(find.byType(Container));

        // Check the inner container (pill) - should have no border
        bool foundBorderedPillContainer = false;
        for (final container in containers) {
          if (container.decoration is BoxDecoration) {
            final decoration = container.decoration as BoxDecoration;
            // Check if this is the pill container (has borderRadius)
            if (decoration.borderRadius != null && decoration.border != null) {
              foundBorderedPillContainer = true;
              break;
            }
          }
        }
        expect(foundBorderedPillContainer, isFalse,
            reason: 'Should not find pill Container with border when showPillBorder is false');
      });

      testWidgets('showPillBorder should default to false', (tester) async {
        // ARRANGE & ACT - Create without specifying showPillBorder
        await tester.pumpApp(
          ResizableDivider(
            isEnabled: true,
            onDragUpdate: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        // ASSERT - Behavior should be same as showPillBorder: false
        final containers = tester.widgetList<Container>(find.byType(Container));

        bool foundBorderedPillContainer = false;
        for (final container in containers) {
          if (container.decoration is BoxDecoration) {
            final decoration = container.decoration as BoxDecoration;
            if (decoration.borderRadius != null && decoration.border != null) {
              foundBorderedPillContainer = true;
              break;
            }
          }
        }
        expect(foundBorderedPillContainer, isFalse);
      });
    });

    group('Mouse cursor', () {
      testWidgets('should show resize cursor', (tester) async {
        // ARRANGE & ACT
        await tester.pumpApp(
          ResizableDivider(
            isEnabled: true,
            onDragUpdate: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        // ASSERT - MouseRegion within ResizableDivider should have resizeColumn cursor
        final mouseRegionFinder = find.descendant(
          of: find.byType(ResizableDivider),
          matching: find.byType(MouseRegion),
        );
        expect(mouseRegionFinder, findsOneWidget);

        final mouseRegion = tester.widget<MouseRegion>(mouseRegionFinder);
        expect(mouseRegion.cursor, equals(SystemMouseCursors.resizeColumn));
      });
    });

    group('Animation', () {
      testWidgets('should use AnimatedContainer for smooth transitions',
          (tester) async {
        // ARRANGE & ACT
        await tester.pumpApp(
          ResizableDivider(
            isEnabled: true,
            onDragUpdate: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        // ASSERT
        final animatedContainer = tester.widget<AnimatedContainer>(
            find.byType(AnimatedContainer));
        expect(animatedContainer.duration, equals(const Duration(milliseconds: 150)));
      });
    });
  });
}
