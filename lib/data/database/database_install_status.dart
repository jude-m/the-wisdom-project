/// What a first-visit screen shows, on any platform.
///
/// Only web installs anything — it downloads its databases into the browser
/// (`web_database_installer.dart`). Native copies them out of the app bundle as
/// it opens them, so its status is always [DatabaseInstallPhase.ready]. These
/// types are platform-neutral so the screen and its provider are too.
library;

/// How far the install has got.
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

/// The whole install at once: the app shows only when every database is in.
class DatabaseInstallStatus {
  const DatabaseInstallStatus({
    required this.phase,
    this.received = 0,
    this.total = 0,
    this.failure,
  });

  final DatabaseInstallPhase phase;

  /// Bytes so far and in all, over every database this start downloads.
  final int received;
  final int total;

  final DatabaseInstallFailure? failure;

  /// 0..1 through the download, or null before its size is known.
  double? get fraction => total == 0 ? null : received / total;
}
