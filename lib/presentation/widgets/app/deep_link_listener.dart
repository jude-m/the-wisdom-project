import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

import '../../providers/deep_link_provider.dart';

/// Receives incoming links and routes them into the reader.
///
/// Two sources, one sink (see `docs/todo/deep-linking-and-shareable-urls.md`):
///
/// - **Mobile/desktop**: the [AppLinks] stream delivers OS-handed URIs —
///   `sammaditthi://` (dev scheme) today, Universal/App Links (https) once the
///   production domain is live. Covers both cold start (initial link) and
///   links arriving while the app runs.
/// - **Web**: only the URL the app was opened with matters (`Uri.base`) — the
///   Dart server SPA-fallbacks `/tipitaka/*` to the app, and without a router the
///   address bar never changes afterwards.
///
/// Wraps the app (inside MaterialApp's builder) so MediaQuery is available for
/// the orientation-based layout seed. Non-link URIs are silently ignored.
class DeepLinkListener extends ConsumerStatefulWidget {
  const DeepLinkListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  StreamSubscription<Uri>? _subscription;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Post-frame so MediaQuery/providers are fully in place at cold start.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _handleUri(Uri.base));
    } else {
      // The stream includes the initial (cold-start) link on app_links ≥6.
      // onError: a platform-channel hiccup must never surface as an unhandled
      // stream error — same stance as malformed links: silently ignore.
      _subscription = AppLinks().uriLinkStream.listen(
        _handleUri,
        onError: (Object _) {},
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _handleUri(Uri uri) {
    final link = TipitakaLink.parse(uri);
    if (link == null || !mounted) return;

    final isPortrait =
        MediaQuery.maybeOf(context)?.orientation == Orientation.portrait;
    // Fire and forget: the opener awaits tree load internally and no-ops on
    // unknown node keys — a bad shared link must never surface an error here.
    unawaited(
      ref.read(openTipitakaLinkProvider)(link, isPortraitMode: isPortrait),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
