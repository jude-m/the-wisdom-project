import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_installation.dart';

/// The install state of the databases the app cannot start without.
///
/// Only web installs anything: it downloads `bjt.db` and `dict.db` into the
/// browser on a first visit. On native [DatabaseInstallation] is ready from the
/// first frame, its change stream is empty and [retry] does nothing.
class DatabaseInstallNotifier extends StateNotifier<DatabaseInstallStatus> {
  DatabaseInstallNotifier(this._installation) : super(_installation.status) {
    _changes = _installation.changes.listen((status) {
      if (mounted) state = status;
    });
    unawaited(_installation.start());
  }

  final DatabaseInstallation _installation;
  late final StreamSubscription<DatabaseInstallStatus> _changes;

  /// Starts the install again after a failure. An unsupported browser is not
  /// retried.
  Future<void> retry() => _installation.retry();

  @override
  void dispose() {
    _changes.cancel();
    super.dispose();
  }
}

/// App-lifetime, and watched by [DatabaseInstallGate] from the first frame —
/// reading it is what starts the install.
final databaseInstallProvider =
    StateNotifierProvider<DatabaseInstallNotifier, DatabaseInstallStatus>(
  (ref) => DatabaseInstallNotifier(const DatabaseInstallation()),
);
