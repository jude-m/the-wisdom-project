/// Tab workspace actions — the Jaspr equivalent of the app's
/// switchTabProvider / openTabFrom*Provider / closeTabProvider chokepoints.
/// All side effects of a tab change (MRU touch, URL bar, scroll restore,
/// document fetch) funnel through here.
library;

import 'package:jaspr/jaspr.dart';
import 'package:jaspr_riverpod/jaspr_riverpod.dart';

import '../dom_utils.dart';
import 'providers.dart';
import 'reader_tab.dart';

/// Switches to the tab at [index]: updates active index + MRU, reflects the
/// file in the URL bar, restores the tab's snapshotted scroll position, and
/// kicks off the full-document fetch if only the SSR window is cached.
void activateTab(BuildContext context, int index) {
  final tabs = context.read(tabsProvider);
  if (index < 0 || index >= tabs.length) return;
  final tab = tabs[index];

  context.read(activeTabIndexProvider.notifier).set(index);
  context.read(mruTabsProvider.notifier).touch(tab.id);
  replaceUrl('/sutta/${tab.fileId}');

  // Restore after the DOM has been patched (also covers tabs that were
  // unmounted by the keep-alive policy and just got re-mounted).
  schedulePaneScroll(tab.id, context.read(scrollRegistryProvider).offsetFor(tab.id));

  context.read(docCacheProvider.notifier).ensureLoaded(tab.fileId);
}

/// Opens a new tab and makes it active. Returns the new tab index.
int openTab(
  BuildContext context, {
  required String name,
  required String fileId,
  int pageStart = 0,
  String? entryAnchor,
  ReaderLayout layout = ReaderLayout.sideBySide,
}) {
  final index = context.read(tabsProvider.notifier).addTab(
        name: name,
        fileId: fileId,
        pageStart: pageStart,
        entryAnchor: entryAnchor,
        layout: layout,
      );
  activateTab(context, index);
  return index;
}

/// Closes the tab at [index], keeping the active selection sensible
/// (same behaviour as the app: closing the active tab activates its
/// left neighbour; closing a tab before the active one shifts the index).
void closeTab(BuildContext context, int index) {
  final tabs = context.read(tabsProvider);
  if (index < 0 || index >= tabs.length) return;
  final closedId = tabs[index].id;
  final active = context.read(activeTabIndexProvider);

  context.read(scrollRegistryProvider).forget(closedId);
  context.read(mruTabsProvider.notifier).remove(closedId);
  context.read(tabsProvider.notifier).removeTab(index);

  final remaining = context.read(tabsProvider);
  if (remaining.isEmpty) {
    context.read(activeTabIndexProvider.notifier).set(-1);
    replaceUrl('/');
    return;
  }

  int newActive = active;
  if (index < active) {
    newActive = active - 1;
  } else if (index == active) {
    newActive = (active - 1).clamp(0, remaining.length - 1);
  }
  activateTab(context, newActive);
}
