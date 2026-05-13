/// Compile-time build metadata baked into the binary by the deploy
/// pipeline.
///
/// Values are supplied via `--dart-define` flags during
/// `flutter build web` (see `scripts/web/deploy.sh`). When the app is run
/// locally with `flutter run`, both values fall back to safe defaults
/// that disable the update-banner feature.
///
/// Read via `String.fromEnvironment` / `bool.fromEnvironment`, both of
/// which are evaluated at compile time and tree-shake away unused code
/// when the flag is `false`.
class BuildInfo {
  /// Short git SHA captured at the moment of `flutter build web`.
  ///
  /// Empty for local debug builds. The update-banner machinery uses this
  /// to detect a mismatch against the sha reported by `/healthz`.
  static const String buildSha = String.fromEnvironment('BUILD_SHA');

  /// Master kill-switch for the update-available banner.
  ///
  /// Default `false` so local debug builds never show the banner. The
  /// deploy script flips this on by passing
  /// `--dart-define=VERSION_CHECK_ENABLED=true`. Set it back to `false`
  /// once the public release stabilises and you no longer want the
  /// banner — no other code change required.
  static const bool versionCheckEnabled =
      bool.fromEnvironment('VERSION_CHECK_ENABLED', defaultValue: false);

  /// True when there is enough metadata to perform a meaningful
  /// version check against `/healthz`. A build without a `BUILD_SHA`
  /// can't compare itself to anything, so the feature stays dormant.
  static bool get canCheckForUpdates =>
      versionCheckEnabled && buildSha.isNotEmpty;
}
