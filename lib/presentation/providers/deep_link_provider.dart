import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

import 'app_section_provider.dart';
import 'navigation_tree_provider.dart';
import 'navigator_sync_provider.dart';
import 'tab_provider.dart';

/// Where shared links point: the web host that serves the `/tipitaka/*` pages
/// (static site in production, the Dart content server's SPA fallback in dev).
///
/// Defaults to the local dev server on :8080. Override at build/run time with
/// `--dart-define=LINK_BASE_URL=https://sammaditthi.app`.
/// See `docs/todo/deep-linking-and-shareable-urls.md` for the URL grammar.
final linkBaseUrlProvider = Provider<String>(
  (ref) => const String.fromEnvironment(
    'LINK_BASE_URL',
    defaultValue: 'http://localhost:8080',
  ),
);

/// Builds the canonical shareable URL for a [TipitakaLink]
/// (e.g. for "Copy link" actions).
final tipitakaLinkUrlBuilderProvider =
    Provider<Uri Function(TipitakaLink)>((ref) {
  final baseUrl = ref.watch(linkBaseUrlProvider);
  return (link) => link.toUri(baseUrl);
});

/// Opens a [TipitakaLink] in the reader. The single sink for every link source —
/// OS deep links, the web start URL, and in-app citation taps — so a tapped
/// citation behaves identically to a shared link.
///
/// Waits for the navigation tree first (a cold-start deep link can arrive
/// before the tree has loaded), then opens through the same tab machinery as
/// tree/search opens and syncs the navigator. Returns true when a tab opened.
final openTipitakaLinkProvider =
    Provider<Future<bool> Function(TipitakaLink, {bool isPortraitMode})>((ref) {
  return (TipitakaLink link, {bool isPortraitMode = false}) async {
    try {
      await ref.read(navigationTreeProvider.future);
    } catch (_) {
      return false; // Tree failed to load — nothing to open into.
    }

    // A page override without an entry means "start of that page" — never
    // fall back to the node's own entry, which pairs with the node's page.
    final entryStart =
        link.pageIndex != null ? (link.entryIndex ?? 0) : null;

    final newIndex = ref.read(openTabFromNodeKeyProvider)(
      link.nodeKey,
      isPortraitMode: isPortraitMode,
      pageIndex: link.pageIndex,
      entryStart: entryStart,
    );
    if (newIndex == -1) return false;

    // The tab opened into the Reader section — make that section visible,
    // whichever section (Home/Research/Notes) the link was opened from.
    ref.read(selectedAppSectionProvider.notifier).state = AppSection.reader;
    ref.read(syncNavigatorToActiveTabProvider)();
    return true;
  };
});
