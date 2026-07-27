/// Browser-only side effects (URL bar, scroll positions), written against
/// package:universal_web so this file also compiles in the SSR server build.
/// Every function is a no-op on the server (guarded by [kIsWeb]).
library;

import 'dart:async';

import 'package:jaspr/jaspr.dart' show kIsWeb;
import 'package:universal_web/web.dart' as web;

/// Tab ↔ URL research question: the address bar reflects the active tab.
/// Uses replaceState (not pushState) so tab switching does NOT grow the
/// back-button history — see the findings doc for how this feels.
void replaceUrl(String path) {
  if (!kIsWeb) return;
  web.window.history.replaceState(null, '', path);
}

/// DOM id of the scrollable pane for a tab.
String paneId(int tabId) => 'pane-$tabId';

/// Restores a pane's scroll position. Deferred with [Timer.run] so it runs
/// after the current build's DOM mutations have been applied.
void schedulePaneScroll(int tabId, double offset) {
  if (!kIsWeb) return;
  Timer.run(() {
    final el = web.document.getElementById(paneId(tabId));
    if (el != null) el.scrollTop = offset.round();
  });
}

/// Scrolls an entry anchor (id `e-<page>-<lang>-<entry>`) into view —
/// used when a tab was opened from a search match.
void scheduleAnchorScroll(String anchorId) {
  if (!kIsWeb) return;
  Timer.run(() {
    web.document.getElementById(anchorId)?.scrollIntoView();
  });
}

/// Reads the current scroll offset of a pane (0 when absent / on server).
double paneScrollTop(int tabId) {
  if (!kIsWeb) return 0;
  return web.document.getElementById(paneId(tabId))?.scrollTop.toDouble() ?? 0;
}

/// Whether a pane is scrolled close enough to its bottom to load more pages.
bool paneNearBottom(int tabId, {int thresholdPx = 1200}) {
  if (!kIsWeb) return false;
  final el = web.document.getElementById(paneId(tabId));
  if (el == null) return false;
  return el.scrollTop + el.clientHeight >= el.scrollHeight - thresholdPx;
}
