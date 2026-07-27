/// The hydrated workspace island.
///
/// This is the crux of the prototype: the SAME component renders on the
/// server (into the initial HTML, so view-source shows the sutta text) and
/// hydrates on the client into the interactive multi-tab reader.
///
/// Hydration-without-flash contract: all @client params are primitives, and
/// the providers are seeded from them via ProviderScope overrides — so the
/// island's first client render is identical to what the server emitted.
/// The full document (the params only carry a 2-page SSR window) is fetched
/// AFTER hydration and only ever extends the DOM, never replaces it.
library;

import 'dart:async';
import 'dart:convert';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_riverpod/jaspr_riverpod.dart';

import '../domain/bjt_document_parser.dart';
import '../state/providers.dart';
import '../state/reader_tab.dart';
import 'nav_panel.dart';
import 'reader_view.dart';
import 'search_panel.dart';
import 'tab_bar.dart';

@client
class ReaderShell extends StatelessComponent {
  const ReaderShell({
    required this.fileId,
    required this.suttaName,
    required this.initialPageStart,
    required this.totalPages,
    required this.initialWindowJson,
    super.key,
  });

  /// Deep-linked content file — seeds the workspace's first tab.
  final String fileId;
  final String suttaName;
  final int initialPageStart;
  final int totalPages;

  /// JSON of the initially rendered page window (NOT the whole ~1MB file —
  /// just the pages the server rendered, so hydration can reproduce them).
  final String initialWindowJson;

  @override
  Component build(BuildContext context) {
    final windowDoc = BJTDocumentParser.parseDocument(
      fileId,
      jsonDecode(initialWindowJson) as Map<String, dynamic>,
    );
    final seedTab = ReaderTab.create(
      id: 0,
      name: suttaName,
      fileId: fileId,
      pageStart: initialPageStart,
    );

    return ProviderScope(
      overrides: [
        tabsProvider.overrideWith(() => TabsNotifier([seedTab])),
        activeTabIndexProvider.overrideWith(() => ActiveTabIndexNotifier(0)),
        mruTabsProvider.overrideWith(() => MruTabsNotifier([seedTab.id])),
        docCacheProvider.overrideWith(() => DocCacheNotifier({
              fileId: DocCacheEntry(
                doc: windowDoc,
                pagesOffset: initialPageStart,
                isComplete: false,
                totalPages: totalPages,
              ),
            })),
      ],
      child: const _ShellRoot(),
    );
  }
}

class _ShellRoot extends StatefulComponent {
  const _ShellRoot();

  @override
  State<_ShellRoot> createState() => _ShellRootState();
}

class _ShellRootState extends State<_ShellRoot> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Post-hydration: upgrade the SSR page window to the full document so
      // scrolling/pagination has the whole file. Deferred so hydration
      // completes against the seeded window first.
      Timer.run(() {
        final tabs = context.read(tabsProvider);
        final active = context.read(activeTabIndexProvider);
        if (active >= 0 && active < tabs.length) {
          context
              .read(docCacheProvider.notifier)
              .ensureLoaded(tabs[active].fileId);
        }
      });
    }
  }

  @override
  Component build(BuildContext context) {
    final tabs = context.watch(tabsProvider);
    final active = context.watch(activeTabIndexProvider);
    final mru = context.watch(mruTabsProvider);

    // Keep-alive policy (research question #1): the [keepAliveTabCount]
    // most-recently-used tabs stay mounted (inactive ones hidden via CSS,
    // scroll state intact in the registry); older tabs are UNMOUNTED from
    // the DOM entirely and rebuilt from state on re-activation.
    final keepIds = mru.take(keepAliveTabCount).toSet();

    return div(classes: 'shell', [
      aside(classes: 'sidebar', [
        header(classes: 'app-header', [
          h1([.text('The Wisdom Project')]),
          span(classes: 'app-sub', [.text('Jaspr prototype')]),
        ]),
        const NavPanel(),
        const SearchPanel(),
      ]),
      div(classes: 'content', [
        const ReaderTabBar(),
        div(classes: 'reader-area', [
          if (tabs.isEmpty)
            div(classes: 'reader-empty',
                [.text('Open a sutta from the list, or search.')])
          else
            for (final (index, tab) in tabs.indexed)
              if (index == active || keepIds.contains(tab.id))
                div(
                  key: ValueKey('tab-host-${tab.id}'),
                  classes:
                      index == active ? 'tab-host active' : 'tab-host hidden',
                  [ReaderView(tabIndex: index, key: ValueKey('view-${tab.id}'))],
                ),
        ]),
      ]),
    ]);
  }
}
