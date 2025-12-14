import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/utils/responsive_utils.dart';

void main() {
  group('ResponsiveUtils -', () {
    group('isMobile', () {
      testWidgets('returns true for width < 768', (tester) async {
        // ARRANGE - Set screen size to mobile
        tester.view.physicalSize = const Size(600, 800);
        tester.view.devicePixelRatio = 1.0;

        late bool isMobile;
        late bool isTablet;
        late bool isDesktop;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                isMobile = ResponsiveUtils.isMobile(context);
                isTablet = ResponsiveUtils.isTablet(context);
                isDesktop = ResponsiveUtils.isDesktop(context);
                return const SizedBox();
              },
            ),
          ),
        );

        // ASSERT
        expect(isMobile, isTrue);
        expect(isTablet, isFalse);
        expect(isDesktop, isFalse);

        // Reset view
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('returns false for width >= 768', (tester) async {
        // ARRANGE - Set screen size to tablet
        tester.view.physicalSize = const Size(768, 1024);
        tester.view.devicePixelRatio = 1.0;

        late bool isMobile;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                isMobile = ResponsiveUtils.isMobile(context);
                return const SizedBox();
              },
            ),
          ),
        );

        // ASSERT
        expect(isMobile, isFalse);

        // Reset view
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('isTablet', () {
      testWidgets('returns true for 768 <= width < 1024', (tester) async {
        // ARRANGE
        tester.view.physicalSize = const Size(900, 1200);
        tester.view.devicePixelRatio = 1.0;

        late bool isMobile;
        late bool isTablet;
        late bool isDesktop;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                isMobile = ResponsiveUtils.isMobile(context);
                isTablet = ResponsiveUtils.isTablet(context);
                isDesktop = ResponsiveUtils.isDesktop(context);
                return const SizedBox();
              },
            ),
          ),
        );

        // ASSERT
        expect(isTablet, isTrue);
        expect(isMobile, isFalse);
        expect(isDesktop, isFalse);

        // Reset view
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('isDesktop', () {
      testWidgets('returns true for width >= 1024', (tester) async {
        // ARRANGE
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;

        late bool isMobile;
        late bool isTablet;
        late bool isDesktop;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                isMobile = ResponsiveUtils.isMobile(context);
                isTablet = ResponsiveUtils.isTablet(context);
                isDesktop = ResponsiveUtils.isDesktop(context);
                return const SizedBox();
              },
            ),
          ),
        );

        // ASSERT
        expect(isDesktop, isTrue);
        expect(isMobile, isFalse);
        expect(isTablet, isFalse);

        // Reset view
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('isTabletOrDesktop', () {
      testWidgets('returns true for width >= 768', (tester) async {
        // ARRANGE
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;

        late bool isTabletOrDesktop;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                isTabletOrDesktop = ResponsiveUtils.isTabletOrDesktop(context);
                return const SizedBox();
              },
            ),
          ),
        );

        // ASSERT
        expect(isTabletOrDesktop, isTrue);

        // Reset view
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('returns false for width < 768', (tester) async {
        // ARRANGE
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;

        late bool isTabletOrDesktop;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                isTabletOrDesktop = ResponsiveUtils.isTabletOrDesktop(context);
                return const SizedBox();
              },
            ),
          ),
        );

        // ASSERT
        expect(isTabletOrDesktop, isFalse);

        // Reset view
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('screenWidth', () {
      testWidgets('returns correct screen width', (tester) async {
        // ARRANGE
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;

        late double screenWidth;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                screenWidth = ResponsiveUtils.screenWidth(context);
                return const SizedBox();
              },
            ),
          ),
        );

        // ASSERT
        expect(screenWidth, equals(1200.0));

        // Reset view
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
