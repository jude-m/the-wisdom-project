/// The reader pane for one tab: renders the loaded page window of the tab's
/// document, in single-language or side-by-side layout (CSS grid — the web
/// answer to the app's dual_column_pane + _PairHeightSync).
///
/// One scroll container per tab:
/// - scroll offsets are continuously snapshotted into the non-reactive
///   [ScrollRegistry] (never triggers rebuilds),
/// - nearing the bottom extends the tab's page window (infinite scroll).
library;

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_riverpod/jaspr_riverpod.dart';

import '../dom_utils.dart';
import '../domain/bjt_document.dart';
import '../state/providers.dart';
import '../state/reader_tab.dart';
import 'entry_view.dart';

class ReaderView extends StatefulComponent {
  const ReaderView({required this.tabIndex, super.key});

  final int tabIndex;

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  @override
  Component build(BuildContext context) {
    final tabs = context.watch(tabsProvider);
    if (component.tabIndex < 0 || component.tabIndex >= tabs.length) {
      return div(classes: 'reader-empty', [.text('No tab')]);
    }
    final tab = tabs[component.tabIndex];
    final cache = context.watch(docCacheProvider)[tab.fileId];

    // A search-opened tab scrolls to its matched entry once content exists.
    // Both the scroll and the state clear are deferred — provider state must
    // not be mutated during build.
    if (tab.entryAnchor != null && cache != null) {
      final anchor = tab.entryAnchor!;
      final notifier = context.read(tabsProvider.notifier);
      final index = component.tabIndex;
      scheduleAnchorScroll(anchor);
      Timer.run(() => notifier.clearEntryAnchor(index));
    }

    return div(
      id: paneId(tab.id),
      classes: 'reader-pane',
      events: {'scroll': (event) => _onScroll(tab, cache)},
      [
        if (cache == null)
          div(classes: 'reader-loading', [.text('Loading…')])
        else
          ..._pages(tab, cache),
      ],
    );
  }

  void _onScroll(ReaderTab tab, DocCacheEntry? cache) {
    // Snapshot continuously — non-reactive on purpose (a reactive offset
    // would re-render the text DOM on every scroll tick).
    context
        .read(scrollRegistryProvider)
        .snapshot(tab.id, paneScrollTop(tab.id));

    if (cache != null && paneNearBottom(tab.id)) {
      context
          .read(tabsProvider.notifier)
          .extendPageEnd(component.tabIndex, cache.totalPages);
      // The window only grows into pages the client actually has — make
      // sure the full document is on its way.
      context.read(docCacheProvider.notifier).ensureLoaded(tab.fileId);
    }
  }

  List<Component> _pages(ReaderTab tab, DocCacheEntry cache) {
    final out = <Component>[];
    final end = tab.pageEnd.clamp(0, cache.totalPages);
    for (var pageIndex = tab.pageStart; pageIndex < end; pageIndex++) {
      final page = cache.pageAt(pageIndex);
      if (page == null) {
        // Page is inside the window but outside the SSR slice — the full
        // document fetch is in flight.
        out.add(div(classes: 'reader-loading', [.text('Loading…')]));
        break;
      }
      out.add(_page(tab, page, pageIndex));
    }
    if (end >= cache.totalPages && cache.isComplete) {
      out.add(div(classes: 'reader-end', [.text('— අවසානය —')]));
    }
    return out;
  }

  Component _page(ReaderTab tab, BJTPage page, int pageIndex) {
    Component section(BJTSection s, String lang) {
      return div(classes: 'page-col lang-$lang', [
        for (final (i, entry) in s.entries.indexed)
          entryView(entry, 'e-$pageIndex-$lang-$i'),
      ]);
    }

    final pageLabel = div(classes: 'page-num', [.text('${page.pageNumber}')]);

    switch (tab.layout) {
      case ReaderLayout.paliOnly:
        return div(classes: 'page single', [
          pageLabel,
          section(page.paliSection, 'pali'),
        ]);
      case ReaderLayout.sinhalaOnly:
        return div(classes: 'page single', [
          pageLabel,
          section(page.sinhalaSection, 'sinh'),
        ]);
      case ReaderLayout.sideBySide:
        // CSS grid replaces the app's manual pane splitting + height sync.
        return div(classes: 'page side-by-side', [
          pageLabel,
          div(classes: 'page-grid', [
            section(page.paliSection, 'pali'),
            section(page.sinhalaSection, 'sinh'),
          ]),
        ]);
    }
  }
}
