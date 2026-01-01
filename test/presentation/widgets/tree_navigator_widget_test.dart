import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:the_wisdom_project/presentation/widgets/tree_navigator_widget.dart';

import '../../helpers/mocks.mocks.dart';
import '../../helpers/test_data.dart';
import '../../helpers/pump_app.dart';

void main() {
  late MockTreeLocalDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockTreeLocalDataSource();
  });

  // ============================================================
  // Loading State Tests
  // ============================================================
  group('Loading state', () {
    testWidgets('should show CircularProgressIndicator while loading',
        (tester) async {
      // ARRANGE - Use a Completer to control when the future completes
      when(mockDataSource.loadNavigationTree()).thenAnswer(
        (_) async {
          // Return immediately but the FutureProvider will show loading first
          await Future.delayed(Duration.zero);
          return TestData.sampleTree;
        },
      );

      // ACT - Pump widget without settling
      await tester.pumpApp(
        const TreeNavigatorWidget(),
        overrides: [
          TestProviderOverrides.treeDataSource(mockDataSource),
        ],
      );

      // Just pump once to see loading state
      await tester.pump();

      // ASSERT - Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Clean up - let it complete
      await tester.pumpAndSettle();
    });
  });

  // ============================================================
  // Error State Tests
  // ============================================================
  group('Error state', () {
    testWidgets('should show error message when loading fails', (tester) async {
      // ARRANGE
      when(mockDataSource.loadNavigationTree())
          .thenThrow(Exception('Network error'));

      // ACT
      await tester.pumpApp(
        const TreeNavigatorWidget(),
        overrides: [
          TestProviderOverrides.treeDataSource(mockDataSource),
        ],
      );
      await tester.pumpAndSettle();

      // ASSERT
      expect(find.text('Error loading navigation tree'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  // ============================================================
  // Success State Tests
  // ============================================================
  group('Success state', () {
    testWidgets('should show tree nodes when loaded', (tester) async {
      // ARRANGE
      when(mockDataSource.loadNavigationTree())
          .thenAnswer((_) async => TestData.sampleTree);

      // ACT
      await tester.pumpApp(
        const TreeNavigatorWidget(),
        overrides: [
          TestProviderOverrides.treeDataSource(mockDataSource),
        ],
      );
      await tester.pumpAndSettle();

      // ASSERT - Should show root nodes (default is Sinhala)
      expect(
          find.text('සූත්‍ර පිටකය'), findsOneWidget); // Sutta Pitaka in Sinhala
      expect(
          find.text('විනය පිටකය'), findsOneWidget); // Vinaya Pitaka in Sinhala
    });

    testWidgets('should show "No content available" when tree is empty',
        (tester) async {
      // ARRANGE
      when(mockDataSource.loadNavigationTree()).thenAnswer((_) async => []);

      // ACT
      await tester.pumpApp(
        const TreeNavigatorWidget(),
        overrides: [
          TestProviderOverrides.treeDataSource(mockDataSource),
        ],
      );
      await tester.pumpAndSettle();

      // ASSERT
      expect(find.text('No content available'), findsOneWidget);
    });
  });

  // ============================================================
  // Language Toggle Tests
  // ============================================================

  // ============================================================
  // Node Expansion Tests
  // ============================================================
  group('Node expansion', () {
    testWidgets('should show expand icon for nodes with children',
        (tester) async {
      // ARRANGE
      when(mockDataSource.loadNavigationTree())
          .thenAnswer((_) async => TestData.sampleTree);

      // ACT
      await tester.pumpApp(
        const TreeNavigatorWidget(),
        overrides: [
          TestProviderOverrides.treeDataSource(mockDataSource),
        ],
      );
      await tester.pumpAndSettle();

      // ASSERT - Sutta Pitaka has children, should show chevron
      expect(find.byIcon(Icons.chevron_right), findsWidgets);
    });

    testWidgets('should expand node and show children when chevron tapped',
        (tester) async {
      // ARRANGE
      when(mockDataSource.loadNavigationTree())
          .thenAnswer((_) async => TestData.sampleTree);

      // ACT
      await tester.pumpApp(
        const TreeNavigatorWidget(),
        overrides: [
          TestProviderOverrides.treeDataSource(mockDataSource),
        ],
      );
      await tester.pumpAndSettle();

      // Sutta Pitaka is expanded by default, so its children are visible
      expect(find.text('දීඝ නිකාය'), findsOneWidget); // Digha Nikaya in Sinhala

      // Collapse Sutta Pitaka first by tapping its chevron
      final suttaPitakaChevron = find.byIcon(Icons.expand_more).first;
      await tester.tap(suttaPitakaChevron);
      await tester.pumpAndSettle();

      // Now child nodes should not be visible
      expect(find.text('දීඝ නිකාය'), findsNothing);

      // Re-expand by tapping the chevron icon
      final chevrons = find.byIcon(Icons.chevron_right);
      expect(chevrons, findsWidgets);

      await tester.tap(chevrons.first);
      await tester.pumpAndSettle();

      // ASSERT - Child should now be visible again
      expect(find.text('දීඝ නිකාය'), findsOneWidget);
    });

    testWidgets('should change icon to expand_more when expanded',
        (tester) async {
      // ARRANGE
      when(mockDataSource.loadNavigationTree())
          .thenAnswer((_) async => TestData.sampleTree);

      // ACT
      await tester.pumpApp(
        const TreeNavigatorWidget(),
        overrides: [
          TestProviderOverrides.treeDataSource(mockDataSource),
        ],
      );
      await tester.pumpAndSettle();

      // Expand first node
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pumpAndSettle();

      // ASSERT - Should show expand_more icon
      expect(find.byIcon(Icons.expand_more), findsWidgets);
    });
  });

  // ============================================================
  // Node Icons Tests
  // ============================================================
  group('Node icons', () {
    testWidgets('should show folder icon for container nodes', (tester) async {
      // ARRANGE
      when(mockDataSource.loadNavigationTree())
          .thenAnswer((_) async => TestData.sampleTree);

      // ACT
      await tester.pumpApp(
        const TreeNavigatorWidget(),
        overrides: [
          TestProviderOverrides.treeDataSource(mockDataSource),
        ],
      );
      await tester.pumpAndSettle();

      // ASSERT - Root nodes are containers, should show folder icon
      expect(find.byIcon(Icons.folder_outlined), findsWidgets);
    });
  });

  // ============================================================
  // Header Tests
  // ============================================================
}
