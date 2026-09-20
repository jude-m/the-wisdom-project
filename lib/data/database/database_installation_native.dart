import 'database_install_status.dart';

/// Nothing to install: native copies each database out of the app bundle as it
/// opens it (`local_database_executor_native.dart`), with no screen and no
/// progress. Here so the first-visit screen and its provider never import a
/// web-only file.
class DatabaseInstallation {
  const DatabaseInstallation();

  DatabaseInstallStatus get status =>
      const DatabaseInstallStatus(phase: DatabaseInstallPhase.ready);

  Stream<DatabaseInstallStatus> get changes =>
      const Stream<DatabaseInstallStatus>.empty();

  Future<void> start() async {}

  Future<void> retry() async {}
}
