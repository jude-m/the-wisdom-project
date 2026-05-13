import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/version/build_info.dart';
import '../../core/version/version_check_service.dart';

/// How often we poll `/healthz` once the app is up. Five minutes is the
/// industry-standard cadence for "we've deployed, please refresh" UX —
/// short enough that testers see the banner soon after a deploy, long
/// enough to be invisible on the network tab.
const Duration _pollInterval = Duration(minutes: 5);

/// Delay before the very first poll fires after launch. Lets the rest
/// of the app finish painting and warming caches before we hit the wire.
const Duration _initialDelay = Duration(seconds: 10);

/// State-holder for the "new version available" banner.
///
/// Emits a non-null [UpdateInfo] when the server's reported sha differs
/// from the sha this client was built with; emits `null` when there's
/// nothing to show or when the feature is disabled at compile time.
class VersionCheckNotifier extends StateNotifier<UpdateInfo?> {
  final VersionCheckService _service;
  Timer? _periodicTimer;
  Timer? _initialTimer;
  bool _dismissed = false;

  VersionCheckNotifier(this._service) : super(null) {
    // Feature gate: if the build wasn't tagged with a sha or the kill
    // switch is off, do nothing at all — no timers, no requests.
    if (!BuildInfo.canCheckForUpdates) return;

    _initialTimer = Timer(_initialDelay, () {
      _pollOnce();
      _periodicTimer = Timer.periodic(_pollInterval, (_) => _pollOnce());
    });
  }

  Future<void> _pollOnce() async {
    // The user already chose to ignore this update for now; don't keep
    // re-surfacing the banner mid-session. (A real refresh resets state.)
    if (_dismissed) return;
    final info = await _service.check();
    // StateNotifier may have been disposed while the await was in flight
    if (!mounted) return;
    if (info != state) state = info;
  }

  /// Let the user hide the banner without reloading. We stop polling so
  /// we don't pop it back up on the next tick. They'll see the new
  /// version naturally the next time they refresh or reopen the tab.
  void dismiss() {
    _dismissed = true;
    state = null;
    _periodicTimer?.cancel();
    _initialTimer?.cancel();
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _initialTimer?.cancel();
    _service.dispose();
    super.dispose();
  }
}

/// Global, app-lifetime provider. NOT autoDispose — we want the timer
/// to keep ticking as long as the app is open, even if the banner
/// happens to be off-screen at a given moment.
final versionCheckProvider =
    StateNotifierProvider<VersionCheckNotifier, UpdateInfo?>((ref) {
  return VersionCheckNotifier(VersionCheckService());
});
