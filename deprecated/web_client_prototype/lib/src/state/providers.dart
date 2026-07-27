/// State model ported from lib/presentation/providers/tab_provider.dart.
///
/// Differences from the Flutter original (each is a prototype finding, see
/// docs/todo/jaspr-prototype-findings.md):
/// - riverpod 3 `Notifier` API instead of StateNotifier (jaspr_riverpod
///   doesn't ship the legacy API).
/// - No KeyValueStore persistence — tab restore across reloads is out of
///   prototype scope (deep links seed the workspace instead).
/// - Scroll offsets live in a NON-reactive [ScrollRegistry], not in tab
///   state: in the DOM a reactive scroll offset would rebuild the rendered
///   text on every scroll tick. Flutter tolerates that (widget diffing);
///   HTML re-rendering must not. Offsets are snapshotted continuously and
///   read back only on tab activation.
library;

import 'package:jaspr_riverpod/jaspr_riverpod.dart';

import '../data/api_client.dart';
import '../domain/bjt_document.dart';
import 'reader_tab.dart';

final apiClientProvider = Provider<WisdomApiClient>((ref) => WisdomApiClient());

// ---------------------------------------------------------------------------
// Tabs
// ---------------------------------------------------------------------------

class TabsNotifier extends Notifier<List<ReaderTab>> {
  TabsNotifier([this._seed = const []]);

  final List<ReaderTab> _seed;
  int _nextId = 0;

  @override
  List<ReaderTab> build() {
    _nextId = _seed.isEmpty
        ? 0
        : _seed.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;
    return _seed;
  }

  /// Adds a new tab and returns its index.
  int addTab({
    required String name,
    required String fileId,
    int pageStart = 0,
    String? entryAnchor,
    ReaderLayout layout = ReaderLayout.sideBySide,
  }) {
    state = [
      ...state,
      ReaderTab.create(
        id: _nextId++,
        name: name,
        fileId: fileId,
        pageStart: pageStart,
        entryAnchor: entryAnchor,
        layout: layout,
      ),
    ];
    return state.length - 1;
  }

  void removeTab(int index) {
    if (index < 0 || index >= state.length) return;
    state = [...state.sublist(0, index), ...state.sublist(index + 1)];
  }

  void updateTab(int index, ReaderTab tab) {
    if (index < 0 || index >= state.length) return;
    state = [...state.sublist(0, index), tab, ...state.sublist(index + 1)];
  }

  /// Extends the loaded page window of a tab (infinite scroll).
  void extendPageEnd(int index, int maxPages) {
    if (index < 0 || index >= state.length) return;
    final tab = state[index];
    if (tab.pageEnd >= maxPages) return;
    updateTab(index, tab.copyWith(pageEnd: tab.pageEnd + 1));
  }

  void setLayout(int index, ReaderLayout layout) {
    if (index < 0 || index >= state.length) return;
    updateTab(index, state[index].copyWith(layout: layout));
  }

  void clearEntryAnchor(int index) {
    if (index < 0 || index >= state.length) return;
    updateTab(index, state[index].copyWith(clearEntryAnchor: true));
  }
}

final tabsProvider =
    NotifierProvider<TabsNotifier, List<ReaderTab>>(TabsNotifier.new);

// ---------------------------------------------------------------------------
// Active tab + keep-alive MRU
// ---------------------------------------------------------------------------

class ActiveTabIndexNotifier extends Notifier<int> {
  ActiveTabIndexNotifier([this._initial = -1]);

  final int _initial;

  @override
  int build() => _initial;

  void set(int index) => state = index;
}

final activeTabIndexProvider =
    NotifierProvider<ActiveTabIndexNotifier, int>(ActiveTabIndexNotifier.new);

/// Most-recently-used tab IDs (most recent first). Drives the keep-alive
/// policy: the top [keepAliveTabCount] stay mounted in the DOM (hidden),
/// everything else is unmounted and restored from state on re-activation.
class MruTabsNotifier extends Notifier<List<int>> {
  MruTabsNotifier([this._seed = const []]);

  final List<int> _seed;

  @override
  List<int> build() => _seed;

  void touch(int tabId) {
    state = [tabId, ...state.where((id) => id != tabId)];
  }

  void remove(int tabId) {
    state = state.where((id) => id != tabId).toList();
  }
}

final mruTabsProvider =
    NotifierProvider<MruTabsNotifier, List<int>>(MruTabsNotifier.new);

/// Keep-alive research question: how many tabs stay mounted. Tune and
/// re-measure on a throttled device (see findings doc).
const keepAliveTabCount = 3;

// ---------------------------------------------------------------------------
// Scroll registry (deliberately non-reactive — see library doc)
// ---------------------------------------------------------------------------

class ScrollRegistry {
  final Map<int, double> _offsets = {};

  double offsetFor(int tabId) => _offsets[tabId] ?? 0.0;
  void snapshot(int tabId, double offset) => _offsets[tabId] = offset;
  void forget(int tabId) => _offsets.remove(tabId);
}

final scrollRegistryProvider = Provider<ScrollRegistry>((ref) => ScrollRegistry());

// ---------------------------------------------------------------------------
// Document cache
// ---------------------------------------------------------------------------

/// A cached document. [pagesOffset] supports the SSR seed: the server embeds
/// only the initially rendered page window, whose pages[0] is really global
/// page index [pagesOffset]. Once the client fetches the full file from the
/// API the entry is replaced with offset 0 / complete = true.
class DocCacheEntry {
  const DocCacheEntry({
    required this.doc,
    this.pagesOffset = 0,
    this.isComplete = true,
    this.totalPages = 0,
  });

  final BJTDocument doc;
  final int pagesOffset;
  final bool isComplete;

  /// Total pages in the full file (known even when only a window is loaded).
  final int totalPages;

  /// Maps a global page index to a page in [doc], or null if not loaded.
  BJTPage? pageAt(int globalIndex) {
    final local = globalIndex - pagesOffset;
    if (local < 0 || local >= doc.pages.length) return null;
    return doc.pages[local];
  }
}

class DocCacheNotifier extends Notifier<Map<String, DocCacheEntry>> {
  DocCacheNotifier([this._seed = const {}]);

  final Map<String, DocCacheEntry> _seed;
  final Set<String> _inflight = {};

  @override
  Map<String, DocCacheEntry> build() => Map.of(_seed);

  /// Fetches the full document from the API unless already complete.
  /// Replaces a partial (SSR-window) entry when it lands.
  Future<void> ensureLoaded(String fileId) async {
    final existing = state[fileId];
    if (existing != null && existing.isComplete) return;
    if (_inflight.contains(fileId)) return;
    _inflight.add(fileId);
    try {
      final doc = await ref.read(apiClientProvider).fetchDocument(fileId);
      state = {
        ...state,
        fileId: DocCacheEntry(doc: doc, totalPages: doc.pageCount),
      };
    } finally {
      _inflight.remove(fileId);
    }
  }
}

final docCacheProvider =
    NotifierProvider<DocCacheNotifier, Map<String, DocCacheEntry>>(
        DocCacheNotifier.new);
