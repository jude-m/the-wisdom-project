/// What a first-visit screen shows, on any platform.
///
/// Only web installs anything — it downloads its databases into the browser
/// (`web_database_installer.dart`). Native copies them out of the app bundle as
/// it opens them, so its status is always [DatabaseInstallPhase.ready]. These
/// types are platform-neutral so the screen and its provider are too.
library;

/// How far one database has got.
enum DatabaseInstallPhase { checking, installing, ready, failed }

/// Why an install stopped. The kind decides what the screen offers: a retry
/// button, a "free some space" message, or a plain "use Chrome".
enum DatabaseInstallFailureKind {
  unsupportedBrowser,
  outOfSpace,
  download,
  other,
}

class DatabaseInstallFailure implements Exception {
  const DatabaseInstallFailure(this.kind, this.message);

  final DatabaseInstallFailureKind kind;
  final String message;

  @override
  String toString() => message;
}

class DatabaseInstallStatus {
  const DatabaseInstallStatus({
    required this.phase,
    this.database,
    this.blocking = true,
    this.received = 0,
    this.total = 0,
    this.allTotal = 0,
    this.failure,
  });

  final DatabaseInstallPhase phase;

  /// Which database this is about, e.g. `bjt.db`; null when the status covers
  /// all of them, as the browser check and native's always-ready do.
  final String? database;

  /// Whether the app can run at all without this database. Only the first one
  /// blocks: every book in the tree opens its text from `bjt.db`, while the
  /// dictionary waits for `dict.db` on its own. So a first-visit screen covers
  /// the app while a blocking database is unready, and a failed dictionary is
  /// the dictionary's problem alone.
  final bool blocking;

  final int received;
  final int total;

  /// Every database a first visit installs, added up — what the whole thing
  /// costs, which is more than the [total] the bar is tracking. 0 until the
  /// manifest is read, and on native, which downloads nothing.
  final int allTotal;

  final DatabaseInstallFailure? failure;

  /// 0..1 through the current download, or null before its size is known.
  double? get fraction => total == 0 ? null : received / total;
}
