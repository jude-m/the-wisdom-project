/// Widget tests for the first-visit database screen and the gate around it.
///
/// The install itself is web-only and unreachable from the VM (see
/// `docs/todo/retiring-dart-server/web-database-installer-tests.md`); what is
/// testable here is what a reader sees for a given [DatabaseInstallStatus].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/data/database/database_installation.dart';
import 'package:the_wisdom_project/presentation/providers/database_install_provider.dart';
import 'package:the_wisdom_project/presentation/screens/database_install_screen.dart';

import '../../helpers/pump_app.dart';

/// Lets a test drive the status the gate reads. The native
/// [DatabaseInstallation] underneath is ready and does nothing, so nothing
/// else moves the state.
class _FakeInstallNotifier extends DatabaseInstallNotifier {
  _FakeInstallNotifier() : super(const DatabaseInstallation());

  void emit(DatabaseInstallStatus status) => state = status;
}

/// Longer than the screen's quiet start, so the wait is over.
const Duration _pastQuietStart = Duration(milliseconds: 500);

Future<void> _pumpScreen(
  WidgetTester tester,
  DatabaseInstallStatus status, {
  VoidCallback? onRetry,
}) async {
  await tester.pumpApp(
    DatabaseInstallScreen(status: status, onRetry: onRetry ?? () {}),
  );
}

void main() {
  group('DatabaseInstallScreen', () {
    testWidgets('says nothing during the quiet start, then asks for a moment',
        (tester) async {
      await _pumpScreen(
        tester,
        const DatabaseInstallStatus(phase: DatabaseInstallPhase.checking),
      );

      // A reload is usually past `checking` by now, so the screen is blank.
      expect(find.text('Getting ready…'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pump(_pastQuietStart);

      expect(find.text('Getting ready…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows the download at once, with megabytes and a fraction',
        (tester) async {
      await _pumpScreen(
        tester,
        const DatabaseInstallStatus(
          phase: DatabaseInstallPhase.installing,
          database: 'bjt.db',
          received: 42000000,
          total: 179093504,
        ),
      );

      // No quiet start for a download: it has already begun.
      expect(find.text('Downloading the texts'), findsOneWidget);
      expect(find.text('42 MB of 179 MB'), findsOneWidget);

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(42000000 / 179093504, 0.0001));
    });

    testWidgets('leaves the bar indeterminate until the size is known',
        (tester) async {
      await _pumpScreen(
        tester,
        const DatabaseInstallStatus(
          phase: DatabaseInstallPhase.installing,
          database: 'bjt.db',
        ),
      );

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, isNull);
      // Nothing to count yet, so no "0 MB of 0 MB".
      expect(find.textContaining('MB of'), findsNothing);
    });

    testWidgets('a stopped download offers to try again, and says what failed',
        (tester) async {
      var retries = 0;
      await _pumpScreen(
        tester,
        const DatabaseInstallStatus(
          phase: DatabaseInstallPhase.failed,
          database: 'bjt.db',
          failure: DatabaseInstallFailure(
            DatabaseInstallFailureKind.download,
            'GET bjt.db returned 404 Not Found',
          ),
        ),
        onRetry: () => retries++,
      );

      expect(find.text('The download did not finish'), findsOneWidget);
      expect(find.text('Check your connection and try again.'), findsOneWidget);
      expect(find.text('GET bjt.db returned 404 Not Found'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('an unsupported browser gets no button and no detail',
        (tester) async {
      await _pumpScreen(
        tester,
        const DatabaseInstallStatus(
          phase: DatabaseInstallPhase.failed,
          failure: DatabaseInstallFailure(
            DatabaseInstallFailureKind.unsupportedBrowser,
            'This browser is missing OPFS with synchronous locks.',
          ),
        ),
      );

      expect(
        find.text('This browser cannot store the texts'),
        findsOneWidget,
      );
      expect(find.text('Chrome and Edge are supported today.'), findsOneWidget);
      // Nothing would change on a second try.
      expect(find.text('Try again'), findsNothing);
      expect(
        find.text('This browser is missing OPFS with synchronous locks.'),
        findsNothing,
      );
    });

    testWidgets('a full device says so, and can be tried again',
        (tester) async {
      await _pumpScreen(
        tester,
        const DatabaseInstallStatus(
          phase: DatabaseInstallPhase.failed,
          database: 'bjt.db',
          failure: DatabaseInstallFailure(
            DatabaseInstallFailureKind.outOfSpace,
            'There is not enough space on this device for the texts.',
          ),
        ),
      );

      expect(find.text('Not enough space'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('DatabaseInstallGate', () {
    testWidgets('shows the app when the database is ready — native always is',
        (tester) async {
      await tester.pumpApp(
        const DatabaseInstallGate(child: Text('the app')),
      );

      expect(find.text('the app'), findsOneWidget);
      expect(find.byType(DatabaseInstallScreen), findsNothing);
    });

    testWidgets('covers the app while the database is installing, and lifts',
        (tester) async {
      final notifier = _FakeInstallNotifier();
      await tester.pumpApp(
        const DatabaseInstallGate(child: Text('the app')),
        overrides: [databaseInstallProvider.overrideWith((ref) => notifier)],
      );

      notifier.emit(
        const DatabaseInstallStatus(
          phase: DatabaseInstallPhase.installing,
          database: 'bjt.db',
          received: 1000000,
          total: 179093504,
        ),
      );
      await tester.pump();

      expect(find.text('the app'), findsNothing);
      expect(find.text('Downloading the texts'), findsOneWidget);

      notifier.emit(
        const DatabaseInstallStatus(
          phase: DatabaseInstallPhase.ready,
          database: 'bjt.db',
        ),
      );
      await tester.pump();

      expect(find.text('the app'), findsOneWidget);
      expect(find.byType(DatabaseInstallScreen), findsNothing);
    });
  });
}
