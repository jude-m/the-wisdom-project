/// Unit tests for [StatusMessageView] and the [statusVariantForError]
/// classifier.
///
/// These are pure widget/unit tests — they don't need a device or the
/// integration_test binding. The cross-panel integration coverage (real
/// provider trees, AsyncValue routing) lives in
/// `integration_test/status_message_view_integration_test.dart`.
library;

import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException, HandshakeException;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/domain/entities/failure.dart';
import 'package:the_wisdom_project/presentation/widgets/common/status_message_view.dart';

/// Pumps a widget inside a minimal MaterialApp (needed for Theme + the
/// AppTypography extension on BuildContext).
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 800, height: 600, child: child),
      ),
    ),
  );
}

void main() {
  // ===========================================================================
  // GROUP 1 — StatusMessageView itself: every variant, every override
  // ===========================================================================

  group('StatusMessageView — variant rendering', () {
    testWidgets('loading: renders 32px CircularProgressIndicator, no icon',
        (tester) async {
      await _pump(
        tester,
        const StatusMessageView(variant: StatusVariant.loading),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Default icons must NOT appear in loading mode.
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
      expect(find.byIcon(Icons.search_off), findsNothing);
    });

    testWidgets('loading + optional title: title is rendered', (tester) async {
      await _pump(
        tester,
        const StatusMessageView(
          variant: StatusVariant.loading,
          title: 'Hold on',
        ),
      );
      expect(find.text('Hold on'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('info: info_outline icon + title + optional description',
        (tester) async {
      await _pump(
        tester,
        const StatusMessageView(
          variant: StatusVariant.info,
          title: 'Hint',
          description: 'Try typing.',
        ),
      );
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.text('Hint'), findsOneWidget);
      expect(find.text('Try typing.'), findsOneWidget);
    });

    testWidgets('invalid: edit_note icon', (tester) async {
      await _pump(
        tester,
        const StatusMessageView(
          variant: StatusVariant.invalid,
          title: 'Bad query',
        ),
      );
      expect(find.byIcon(Icons.edit_note), findsOneWidget);
    });

    testWidgets('empty: search_off icon', (tester) async {
      await _pump(
        tester,
        const StatusMessageView(
          variant: StatusVariant.empty,
          title: 'Nothing here',
        ),
      );
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('error: error_outline icon, coloured with colorScheme.error',
        (tester) async {
      await _pump(
        tester,
        const StatusMessageView(
          variant: StatusVariant.error,
          title: 'Boom',
        ),
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      final theme = Theme.of(tester.element(find.byIcon(Icons.error_outline)));
      expect(iconWidget.color, theme.colorScheme.error);
      expect(iconWidget.size, 40);
    });

    testWidgets('offline: cloud_off icon, coloured with colorScheme.error',
        (tester) async {
      await _pump(
        tester,
        const StatusMessageView(
          variant: StatusVariant.offline,
          title: 'Server down',
        ),
      );
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
      final theme = Theme.of(tester.element(find.byIcon(Icons.cloud_off)));
      expect(iconWidget.color, theme.colorScheme.error);
      expect(iconWidget.size, 40);
    });

    testWidgets('iconOverride is honoured (info + book icon)', (tester) async {
      await _pump(
        tester,
        const StatusMessageView(
          variant: StatusVariant.info,
          iconOverride: Icons.menu_book_outlined,
          title: 'First-run hint',
        ),
      );
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsNothing);
    });

    testWidgets('action widget is rendered after the description',
        (tester) async {
      var tapped = false;
      await _pump(
        tester,
        StatusMessageView(
          variant: StatusVariant.error,
          title: 'Boom',
          description: 'Try again later.',
          action: TextButton(
            onPressed: () => tapped = true,
            child: const Text('Retry'),
          ),
        ),
      );
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(tapped, isTrue);
    });

    testWidgets('asserts that non-loading variants have a title',
        (tester) async {
      // Constructing without a title for a non-loading variant must trip
      // the constructor's `assert`. We catch the failure to verify it.
      expect(
        () => StatusMessageView(variant: StatusVariant.error),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // ===========================================================================
  // GROUP 2 — statusVariantForError: classification heuristic
  // ===========================================================================

  group('statusVariantForError — error classification', () {
    test('SocketException → offline', () {
      expect(
        statusVariantForError(const SocketException('boom')),
        StatusVariant.offline,
      );
    });

    test('TimeoutException → offline', () {
      expect(
        statusVariantForError(
            TimeoutException('slow', const Duration(seconds: 1))),
        StatusVariant.offline,
      );
    });

    test('HandshakeException → offline', () {
      expect(
        statusVariantForError(const HandshakeException('tls')),
        StatusVariant.offline,
      );
    });

    test('Web fetch failure (Chrome/Firefox prefix) → offline', () {
      expect(
        statusVariantForError(Exception('TypeError: Failed to fetch')),
        StatusVariant.offline,
      );
    });

    test('Web fetch failure (Safari prefix) → offline', () {
      expect(
        statusVariantForError(Exception('TypeError: Load failed')),
        StatusVariant.offline,
      );
    });

    test('Web XHR failure → offline', () {
      expect(
        statusVariantForError(Exception('XMLHttpRequest error.')),
        StatusVariant.offline,
      );
    });

    test('Connection refused → offline', () {
      expect(
        statusVariantForError(Exception('connection refused')),
        StatusVariant.offline,
      );
    });

    test('Failure wrapping a SocketException → offline (unwrap path)', () {
      const failure = Failure.dataLoadFailure(
        message: 'tree',
        error: SocketException('boom'),
      );
      expect(statusVariantForError(failure), StatusVariant.offline);
    });

    test('Failure wrapping a generic exception → error', () {
      const failure = Failure.dataParseFailure(
        message: 'bad json',
        error: FormatException('not json'),
      );
      expect(statusVariantForError(failure), StatusVariant.error);
    });

    test('Generic Exception with no network signal → error', () {
      expect(
        statusVariantForError(Exception('something exploded')),
        StatusVariant.error,
      );
    });

    test('FormatException → error', () {
      expect(
        statusVariantForError(const FormatException('not json')),
        StatusVariant.error,
      );
    });

    test('"JSON load failed" must NOT match (no typeerror prefix) → error',
        () {
      // Regression: bare 'load failed' used to match and falsely classify
      // parse errors as offline. We now require the "TypeError:" prefix.
      expect(
        statusVariantForError(Exception('JSON load failed at line 3')),
        StatusVariant.error,
      );
    });

    test('"cache timeout" must NOT match (bare timeout removed) → error', () {
      // Regression: bare 'timeout' used to match. TimeoutException is still
      // matched by its type name; loose substring matches are gone.
      expect(
        statusVariantForError(Exception('cache timeout exceeded')),
        StatusVariant.error,
      );
    });

    test('Object with no .error getter and unknown type → error', () {
      // Plain Object — falls through both type-name and message matching.
      expect(statusVariantForError(Object()), StatusVariant.error);
    });
  });
}
