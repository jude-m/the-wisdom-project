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
///
/// **Addressed the way the site serves it**, not the way the app holds it. A
/// short sutta has no page of its own on the site — it is a section of a
/// chapter — so a link naming it directly points at a URL that was never
/// written, and the reader who follows it gets a 404 rather than the sutta.
/// [SitePlan.servingLink] fills in the page, and the fragment still names the
/// sutta, so the link opens on the right text on both surfaces.
///
/// Async because the plan is built on first use; the tree it walks is already
/// in memory by the time any UI can offer a copy button.
///
/// Never throws. Building a URL used to be pure string work that could not
/// fail, and its callers are written that way — a copy button hands the result
/// straight to the clipboard. If the plan is unavailable, the target's own URL
/// is the answer the app gave before the plan existed: wrong only for a folded
/// leaf, and only until the P5 stub gate makes bare leaf URLs resolve. A link
/// that is right in most cases beats a button that silently does nothing.
final tipitakaLinkUrlBuilderProvider =
    Provider<Future<Uri> Function(TipitakaLink)>((ref) {
  final baseUrl = ref.watch(linkBaseUrlProvider);
  return (link) async {
    try {
      final plan = await ref.read(sitePlanProvider.future);
      return plan.servingLink(link).toUri(baseUrl);
    } catch (_) {
      return link.toUri(baseUrl);
    }
  };
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
      await _resolveTarget(ref, link),
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

/// Which node a link opens, with the plan loaded and not trusted to load.
///
/// The rule is [SitePlan.resolveTarget], which lives beside the one that writes
/// a URL so `verify_corpus_invariants.dart` can assert the round trip over the
/// whole corpus. What is left here is the app's own half: getting the plan, and
/// answering anyway when it will not load.
///
/// One load, not two — the plan carries the tree it was planned from, so the
/// rule is never asked with half its inputs. A plan that fails leaves no map at
/// all, and the flat node index answers as the app did before the plan existed:
/// weaker for a folded leaf, and weaker in the right direction, since it opens
/// the text the path names. Opening a link must not become the one place a
/// snapshot problem surfaces as a throw.
Future<String> _resolveTarget(Ref ref, TipitakaLink link) async {
  try {
    final plan = await ref.read(sitePlanProvider.future);
    return plan.resolveTarget(link);
  } catch (_) {
    // Read through the index directly rather than `nodeByKeyProvider`: that one
    // is `autoDispose.family`, so a single lookup would create and tear down a
    // provider for this key.
    return ref.read(nodeIndexProvider).containsKey(link.nodeKey)
        ? link.nodeKey
        : link.pageKey ?? link.nodeKey;
  }
}
