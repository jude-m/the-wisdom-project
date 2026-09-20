import 'database_install_status.dart';
import 'web_database_installer.dart';

/// The browser's install, behind a platform-neutral name.
///
/// [WebDatabaseInstaller] stays the implementation; this is what the
/// first-visit screen and its provider import, so nothing in `presentation/`
/// reaches into a web-only file.
class DatabaseInstallation {
  const DatabaseInstallation();

  DatabaseInstallStatus get status => WebDatabaseInstaller.instance.status;

  Stream<DatabaseInstallStatus> get changes =>
      WebDatabaseInstaller.instance.changes;

  Future<void> start() => WebDatabaseInstaller.instance.start();

  Future<void> retry() => WebDatabaseInstaller.instance.retry();
}
