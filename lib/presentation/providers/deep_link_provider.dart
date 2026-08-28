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

/// Which node a link actually opens: the vaṇṇanā an origin marker implies, the
/// fragment when the site really serves it from the path's page, otherwise the
/// page itself.
///
/// `/tipitaka/<page>#<leaf>` names the leaf, and the leaf is what opens. But
/// the codec is pure grammar — it cannot tell a folded sutta's key from a page
/// anchor like `#top`, which is the same shape — so something with knowledge of
/// the corpus has to decide.
///
/// **[SitePlan] is that something, not the tree.** "Is this a real node" is the
/// weaker question: it accepts any key that exists, so `/tipitaka/sn-2-3#an-1-1`
/// would open `an-1-1` while the site, finding no such section on that page,
/// shows `sn-2-3`. `plan.pageOf` asks the question the site answers — *is this
/// leaf served by that page* — from the same map the site's own HTML is written
/// from, so both surfaces resolve a link the same way.
///
/// Falls back to the tree if the plan cannot be built. Opening a link must not
/// become the one place a snapshot problem surfaces as a thrown exception:
/// before the plan existed this branch was a map lookup, and the tree still
/// answers well enough to open something.
Future<String> _resolveTarget(Ref ref, TipitakaLink link) async {
  // `#via_<canonKey>` names the door, not the room. Several suttas share one
  // vaṇṇanā, so the site cannot put the vaṇṇanā's own key in the fragment *and*
  // say which sutta the reader came from — and the vaṇṇanā is usually a folded
  // leaf, so the path names the chapter carrying it rather than the vaṇṇanā.
  // `crossLinkTargetKey` is the same function that built the link on the canon
  // side, run backwards, so the app lands where the browser's `:target` does.
  final originKey = link.originKey;
  if (originKey != null) {
    try {
      final tree = await ref.read(sharedTreeProvider.future);
      final vannana = crossLinkTargetKey(tree, originKey);
      if (vannana != null) return vannana;
    } catch (_) {
      // Fall through to the path. A tree that will not load is not a reason to
      // open nothing — the chapter is still the page the link names.
    }
  }

  // A link with no fragment names its own page, so the comparison below is
  // `pageOf(k)?.nodeKey == k` — true exactly when the target owns a page.
  final pageKey = link.pageKey ?? link.nodeKey;
  try {
    final plan = await ref.read(sitePlanProvider.future);
    return plan.pageOf(link.nodeKey)?.nodeKey == pageKey
        ? link.nodeKey
        : pageKey;
  } catch (_) {
    // Read through the index directly rather than `nodeByKeyProvider`: that one
    // is `autoDispose.family`, so a single lookup would create and tear down a
    // provider for this key.
    return ref.read(nodeIndexProvider).containsKey(link.nodeKey)
        ? link.nodeKey
        : pageKey;
  }
}
