import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/presentation/widgets/resizable_divider.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('ResizableDivider -', () {
    group('Disabled state', () {
      testWidgets('should render nothing when disabled', (tester) async {
        // ARRANGE & ACT
        await tester.pumpApp(
          ResizableDivider(
            isEnabled: false,
            onDragUpdate: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        // ASSERT - Should not render any interactive components
        expect(find.byType(AnimatedContainer), findsNothing);
        expect(find.byType(Center), findsNothing);
        expect(
          find.descendant(
            of: find.byType(ResizableDivider),
            matching: find.byType(MouseRegion),
          ),
          findsNothing,
        );
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
      testWidgets('should render full structure when enabled', (tester) async {
        // ARRANGE & ACT
        await tester.pumpApp(
          ResizableDivider(
            isEnabled: true,
            onDragUpdate: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        // ASSERT - Should render all interactive components
        // Pill indicator structure
        expect(find.byType(Center), findsOneWidget);
        expect(find.byType(Container), findsWidgets);

        // AnimatedContainer with correct width
        final animatedContainer =
            tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
        expect(animatedContainer.constraints?.maxWidth, equals(8.0));

        // Interactive components
        expect(
          find.descendant(
            of: find.byType(ResizableDivider),
            matching: find.byType(MouseRegion),
          ),
          findsOneWidget,
        );
        expect(find.byType(GestureDetector), findsOneWidget);
      });

      testWidgets('should show resize cursor', (tester) async {
        // ARRANGE & ACT
        await tester.pumpApp(
          ResizableDivider(
            isEnabled: true,
            onDragUpdate: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        // ASSERT - MouseRegion should have resizeColumn cursor
        final mouseRegionFinder = find.descendant(
          of: find.byType(ResizableDivider),
          matching: find.byType(MouseRegion),
        );
        final mouseRegion = tester.widget<MouseRegion>(mouseRegionFinder);
        expect(mouseRegion.cursor, equals(SystemMouseCursors.resizeColumn));
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
    });

    group('showPillBorder option', () {
      testWidgets('should handle showPillBorder parameter', (tester) async {
        // Test showPillBorder: true
        await tester.pumpApp(
          ResizableDivider(
            isEnabled: true,
            showPillBorder: true,
            onDragUpdate: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        // ASSERT - Should have a border
        var containers = tester.widgetList<Container>(find.byType(Container));
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
            reason:
                'Should find a Container with border when showPillBorder is true');

        // Test showPillBorder: false (default)
        await tester.pumpApp(
          ResizableDivider(
            isEnabled: true,
            showPillBorder: false,
            onDragUpdate: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        // ASSERT - Should not have a border
        containers = tester.widgetList<Container>(find.byType(Container));
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
            reason:
                'Should not find pill Container with border when showPillBorder is false');
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
