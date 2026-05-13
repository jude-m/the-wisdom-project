import 'dart:convert';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:http/http.dart' as http;

import 'build_info.dart';

/// What the running client decided after talking to `/healthz`.
///
/// `null` everywhere in the codebase means "no update needed (yet)". An
/// instance with a non-empty `remoteSha` that differs from
/// [BuildInfo.buildSha] means a fresher deploy is live on the server and
/// the banner should show.
class UpdateInfo {
  /// Short git SHA the server is currently serving.
  final String remoteSha;

  /// Bullet points pulled from `RELEASE_NOTES.md` at deploy time.
  /// May be empty — banner falls back to a generic message.
  final List<String> notes;

  const UpdateInfo({required this.remoteSha, required this.notes});

  /// Value-equality so Riverpod doesn't rebuild listeners on every poll
  /// when nothing actually changed. Defers to Flutter's `listEquals`
  /// for the element-wise list comparison.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateInfo &&
          remoteSha == other.remoteSha &&
          listEquals(notes, other.notes);

  @override
  int get hashCode => Object.hash(remoteSha, Object.hashAll(notes));
}

/// Thin wrapper around the `/healthz` endpoint.
///
/// Lives outside the data/ layer because version checking is a platform
/// concern, not a domain feature — it has no entity, no repository, and
/// no Either<Failure, T> contract. Failures are logged silently; the
/// caller treats "no info" the same as "no update available".
///
/// ----------------------------------------------------------------------
/// EXTENDING TO iOS / ANDROID (and any other shipping channel)
/// ----------------------------------------------------------------------
/// The surrounding pieces — [UpdateInfo], [BuildInfo], `versionCheckProvider`
/// and `UpdateAvailableBanner` — are deliberately platform-agnostic so
/// adding native store-based update checks is an **additive** change, not
/// a rewrite. The two web-specific concerns to swap out are:
///
///   1. SOURCE OF TRUTH — what tells you a newer version exists.
///        Web: this class polls `/healthz` every 5 min while the tab is open.
///        iOS: hit the App Store Lookup API on launch
///             (`https://itunes.apple.com/lookup?bundleId=<id>`) and compare
///             its `version` against the running build's version. Once per
///             launch is enough; mobile apps reopen far more often than
///             web tabs are refreshed.
///        Android: there's an official Play Core "in-app updates" SDK
///             (`package:in_app_update`) that surfaces the same info plus
///             an immediate / flexible update flow. Using that ends up
///             nicer than a Play Store URL scrape.
///
///      Recommended shape when that day comes: extract an
///      `abstract class VersionCheckSource { Future<UpdateInfo?> check(); }`
///      and provide three impls — `HealthzVersionCheckSource` (this code),
///      `IosAppStoreVersionCheckSource`, `AndroidInAppUpdateSource`. The
///      provider picks one based on `kIsWeb` / `defaultTargetPlatform`.
///
///   2. ACTION — what the banner's primary button does.
///        Web: `reloadPage()` → `window.location.reload()` (already isolated
///             behind a conditional-import in `core/version/web_reload.dart`).
///        Mobile: launch the relevant store page (`url_launcher` to
///             `itms-apps://` / `market://details?id=...`), or trigger the
///             Play Core flexible-update flow.
///
///      Same conditional-import pattern as `web_reload.dart` works: add a
///      `store_launcher.dart` with `_io.dart` / `_web.dart` siblings, and
///      have the banner call a single `triggerUpdate()` that does the
///      right thing per platform.
///
/// Naming is already generic: [UpdateInfo.remoteSha] holds whatever the
/// platform considers a version identifier (a git sha today, an App Store
/// `version` string tomorrow). The banner UI never reads the sha — it
/// only renders `notes` — so cross-platform reuse is essentially free.
/// ----------------------------------------------------------------------
class VersionCheckService {
  /// Same-origin relative URL; the Flutter web bundle is served by the
  /// same Dart shelf process that exposes `/healthz`.
  static const String _healthzPath = '/healthz';

  final http.Client _client;

  VersionCheckService({http.Client? client})
      : _client = client ?? http.Client();

  /// Hits `/healthz` and returns an [UpdateInfo] when the remote sha
  /// differs from [BuildInfo.buildSha]. Returns `null` when:
  ///   - the request fails for any reason (network, parse error, 5xx)
  ///   - the remote sha matches our build (so no update is needed)
  ///   - the response is missing a sha (an older/partially-deployed server)
  Future<UpdateInfo?> check() async {
    try {
      final response = await _client
          .get(Uri.parse(_healthzPath))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final body = json.decode(response.body) as Map<String, dynamic>;
      final remoteSha = body['sha'] as String?;
      if (remoteSha == null || remoteSha.isEmpty) return null;

      // Nothing changed since this client was built — nothing to show.
      if (remoteSha == BuildInfo.buildSha) return null;

      final rawNotes = body['notes'];
      final notes = rawNotes is List
          ? rawNotes.whereType<String>().toList(growable: false)
          : const <String>[];

      return UpdateInfo(remoteSha: remoteSha, notes: notes);
    } catch (_) {
      // Swallow everything — the banner is a nice-to-have, not load-
      // bearing. The next poll will try again in a few minutes.
      return null;
    }
  }

  void dispose() => _client.close();
}
