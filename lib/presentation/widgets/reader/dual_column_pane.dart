import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../domain/entities/bjt/bjt_page.dart';
import '../../models/in_page_search_state.dart';
import '../../providers/tab_provider.dart'
    show activeSplitRatioProvider, updateActiveTabSplitRatioProvider;
import '../common/resizable_divider.dart';
import 'entry_key_registry.dart';
import 'reader_entry_builder.dart';

/// Side-by-side Pali/Sinhala reader.
///
/// Each column has its own [SelectionArea] so a drag-select stays within
/// the column it started in. Pair alignment is restored by
/// [_PairHeightSync]: each side reports its rendered height; the shorter
/// side pads to match.
class DualColumnPane extends ConsumerStatefulWidget {
  const DualColumnPane({
    super.key,
    required this.scrollController,
    required this.pages,
    required this.entryStart,
    required this.absolutePageStart,
    required this.searchState,
    required this.entryKeyRegistry,
    required this.onTapEmpty,
    this.onWordTap,
    required this.onSelectionChanged,
    required this.contextMenuBuilder,
  });

  final ScrollController scrollController;
  final List<BJTPage> pages;
  final int entryStart;
  final int absolutePageStart;
  final InPageSearchState searchState;

  /// Registry for entry-level GlobalKeys. Used for layout-switch scroll
  /// sync AND in-page-search scroll-to-match. The registry key wraps the
  /// LEFT side only — `_PairHeightSync` keeps both sides on the same y,
  /// so scrolling to the left side reveals either-side matches.
  final EntryKeyRegistry entryKeyRegistry;
  final VoidCallback onTapEmpty;
  final void Function(String word)? onWordTap;
  final void Function(SelectedContent?) onSelectionChanged;
  final Widget Function(BuildContext, SelectableRegionState) contextMenuBuilder;

  @override
  ConsumerState<DualColumnPane> createState() => _DualColumnPaneState();
}

class _DualColumnPaneState extends ConsumerState<DualColumnPane> {
  late final _PairHeightSync _heightSync;

  @override
  void initState() {
    super.initState();
    _heightSync = _PairHeightSync();
  }

  @override
  void didUpdateWidget(DualColumnPane old) {
    super.didUpdateWidget(old);
    // Drop heights for entries no longer in the page slice; persisted
    // entries keep theirs to avoid re-measure churn.
    if (!identical(old.pages, widget.pages) ||
        old.absolutePageStart != widget.absolutePageStart ||
        old.entryStart != widget.entryStart) {
      _heightSync.prune(_liveIdSet());
    }
  }

  Set<(int, int)> _liveIdSet() {
    final live = <(int, int)>{};
    for (var p = 0; p < widget.pages.length; p++) {
      final absPage = widget.absolutePageStart + p;
      final start = p == 0 ? widget.entryStart : 0;
      final entryCount = widget.pages[p].paliSection.entries.length;
      for (var e = start; e < entryCount; e++) {
        live.add((absPage, e));
      }
    }
    return live;
  }

  @override
  void dispose() {
    _heightSync.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTabletOrDesktop = ResponsiveUtils.isTabletOrDesktop(context);

    // Build sides ONCE per parent build. These references are captured by
    // the inner Consumer's closure — across drag frames the Consumer hands
    // back the same Widget instance to each SizedBox's `child` slot, so
    // Flutter's element diff keeps the entry subtree mounted and only
    // re-lays out the changed widths. No `_buildColumnEntries` re-run, no
    // GlobalKey reattachment, no `_AlignedEntry` state loss.
    final leftSide = _buildSideContent(context, isLeft: true);
    final rightSide = _buildSideContent(context, isLeft: false);

    return GestureDetector(
      onTap: widget.onTapEmpty,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          SingleChildScrollView(
            controller: widget.scrollController,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dividerWidth = isTabletOrDesktop
                      ? PaneWidthConstants.dividerWidth
                      : 24.0;
                  final availableWidth = constraints.maxWidth - dividerWidth;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                          height: PaneWidthConstants
                              .readerActionButtonGroupHeight),
                      // Watch splitRatio scoped to just the Row so drag
                      // frames don't rebuild the parent or the side trees.
                      Consumer(
                        builder: (context, ref, _) {
                          final splitRatio =
                              ref.watch(activeSplitRatioProvider);
                          final leftWidth = availableWidth * splitRatio;
                          final rightWidth = availableWidth * (1 - splitRatio);
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: leftWidth, child: leftSide),
                              SizedBox(width: dividerWidth),
                              SizedBox(width: rightWidth, child: rightSide),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (isTabletOrDesktop)
            // Overlay also watches splitRatio in its own Consumer — it's a
            // tiny widget, cheap to rebuild on drag.
            Consumer(
              builder: (context, ref, _) {
                final splitRatio = ref.watch(activeSplitRatioProvider);
                return _buildDividerOverlay(context, ref, splitRatio);
              },
            ),
        ],
      ),
    );
  }

  /// One column: SelectionArea wrapped in a RepaintBoundary so paint in
  /// one column doesn't dirty the other.
  Widget _buildSideContent(BuildContext context, {required bool isLeft}) {
    return RepaintBoundary(
      child: SelectionArea(
        onSelectionChanged: widget.onSelectionChanged,
        contextMenuBuilder: widget.contextMenuBuilder,
        child: Padding(
          padding: EdgeInsets.only(
            left: isLeft ? 0 : 12.0,
            right: isLeft ? 12.0 : 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildColumnEntries(context, isLeft: isLeft),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildColumnEntries(
    BuildContext context, {
    required bool isLeft,
  }) {
    final pages = widget.pages;
    final entryStart = widget.entryStart;
    final absolutePageStart = widget.absolutePageStart;
    final searchState = widget.searchState;
    final currentMatch = searchState.currentMatch;
    final effectiveQuery = searchState.effectiveQuery;
    final hasQuery = searchState.hasActiveQuery;

    final widgets = <Widget>[];

    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final page = pages[pageIndex];
      final absolutePageIndex = absolutePageStart + pageIndex;
      final startEntry = pageIndex == 0 ? entryStart : 0;

      // Page number row — same on both sides, no sync needed.
      widgets.add(ReaderEntryBuilder.buildPageNumber(context, page.pageNumber));
      widgets.add(const SizedBox(height: 16));

      final entryCount = page.paliSection.entries.length - startEntry;
      for (var i = 0; i < entryCount; i++) {
        final entryIndex = i + startEntry;
        final paliEntry = page.paliSection.entries[entryIndex];
        final sinhalaEntry = entryIndex < page.sinhalaSection.entries.length
            ? page.sinhalaSection.entries[entryIndex]
            : null;

        final isPaliCurrentMatch = currentMatch != null &&
            currentMatch.pageIndex == absolutePageIndex &&
            currentMatch.entryIndex == entryIndex &&
            currentMatch.languageCode == 'pi';
        final isSinhalaCurrentMatch = currentMatch != null &&
            currentMatch.pageIndex == absolutePageIndex &&
            currentMatch.entryIndex == entryIndex &&
            currentMatch.languageCode == 'si';

        final Widget innerEntry;
        if (isLeft) {
          final paliHasMatch = hasQuery &&
              searchState.hasMatchInEntry(absolutePageIndex, entryIndex, 'pi');
          innerEntry = ReaderEntryBuilder.buildEntry(
            context,
            paliEntry,
            enableDictionaryLookup: true,
            inPageSearchQuery: paliHasMatch ? effectiveQuery : null,
            currentMatchIndexInEntry:
                isPaliCurrentMatch ? currentMatch.matchIndexInEntry : null,
            onWordTap: widget.onWordTap,
          );
        } else if (sinhalaEntry != null) {
          final sinhalaHasMatch = hasQuery &&
              searchState.hasMatchInEntry(absolutePageIndex, entryIndex, 'si');
          innerEntry = ReaderEntryBuilder.buildEntry(
            context,
            sinhalaEntry,
            enableDictionaryLookup: false,
            inPageSearchQuery: sinhalaHasMatch ? effectiveQuery : null,
            currentMatchIndexInEntry:
                isSinhalaCurrentMatch ? currentMatch.matchIndexInEntry : null,
            onWordTap: widget.onWordTap,
          );
        } else {
          innerEntry = const SizedBox.shrink();
        }

        final id = (absolutePageIndex, entryIndex);

        Widget side = _AlignedEntry(
          key: ValueKey((absolutePageIndex, entryIndex, isLeft)),
          id: id,
          isLeft: isLeft,
          sync: _heightSync,
          child: innerEntry,
        );

        Widget row = Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: side,
        );

        // Registry key on LEFT only — duplicate GlobalKeys would crash.
        // Both sides share the same y after height-sync converges, so the
        // left-side key is sufficient for scroll-to-match on either side.
        if (isLeft) {
          row = KeyedSubtree(
            key: widget.entryKeyRegistry.keyFor(absolutePageIndex, entryIndex),
            child: row,
          );
        }

        widgets.add(row);
      }

      widgets.add(const SizedBox(height: 32));
    }

    return widgets;
  }

  Widget _buildDividerOverlay(
      BuildContext context, WidgetRef ref, double splitRatio) {
    const horizontalPadding = 24.0;

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth - (horizontalPadding * 2);
          final dividerLeft = horizontalPadding +
              (contentWidth * splitRatio) -
              (PaneWidthConstants.dividerWidth / 2);

          return Padding(
            padding: EdgeInsets.only(left: dividerLeft),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ResizableDivider(
                hideWhenIdle: true,
                onDragUpdate: (delta) {
                  final ratioChange = delta / contentWidth;
                  final currentRatio = ref.read(activeSplitRatioProvider);
                  ref.read(updateActiveTabSplitRatioProvider)(
                      currentRatio + ratioChange);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Per-pair height sync
// =============================================================================

/// Per-(pair, side) [ValueNotifier]s for bottom-pad. Each [_AlignedEntry]
/// listens to its own notifier via [ValueListenableBuilder], so a height
/// report rebuilds only the affected Padding — no parent setState, no
/// cascade across siblings.
class _PairHeightSync {
  final Map<(int, int), double> _leftH = {};
  final Map<(int, int), double> _rightH = {};
  final Map<(int, int, bool), ValueNotifier<double>> _pads = {};

  ValueNotifier<double> padNotifierFor((int, int) id, bool isLeft) {
    final key = (id.$1, id.$2, isLeft);
    return _pads.putIfAbsent(
      key,
      () => ValueNotifier<double>(_computePad(id, isLeft)),
    );
  }

  double _computePad((int, int) id, bool isLeft) {
    final l = _leftH[id] ?? 0;
    final r = _rightH[id] ?? 0;
    final mine = isLeft ? l : r;
    return math.max(l, r) - mine;
  }

  void report((int, int) id, bool isLeft, double height) {
    final map = isLeft ? _leftH : _rightH;
    if (map[id] == height) return;
    map[id] = height;
    final l = _leftH[id] ?? 0;
    final r = _rightH[id] ?? 0;
    final maxH = math.max(l, r);
    _pads[(id.$1, id.$2, true)]?.value = maxH - l;
    _pads[(id.$1, id.$2, false)]?.value = maxH - r;
  }

  /// Drops stale ids. Notifiers aren't disposed here — listeners may still
  /// be attached to soon-to-unmount widgets; orphaned notifiers GC after
  /// listeners detach. ValueNotifier holds no resources beyond its
  /// listener list, so this is leak-free.
  void prune(Set<(int, int)> live) {
    _leftH.removeWhere((k, _) => !live.contains(k));
    _rightH.removeWhere((k, _) => !live.contains(k));
    _pads.removeWhere((k, _) => !live.contains((k.$1, k.$2)));
  }

  void dispose() {
    for (final n in _pads.values) {
      n.dispose();
    }
    _pads.clear();
    _leftH.clear();
    _rightH.clear();
  }
}

/// Wraps one entry, measures its height, and pads the bottom to match
/// its partner.
///
/// Initial-frame caveat: both sides start at `pad = 0` until the first
/// postframe measurement runs. One-frame transient on first paint.
class _AlignedEntry extends StatefulWidget {
  const _AlignedEntry({
    super.key,
    required this.id,
    required this.isLeft,
    required this.sync,
    required this.child,
  });

  final (int, int) id;
  final bool isLeft;
  final _PairHeightSync sync;
  final Widget child;

  @override
  State<_AlignedEntry> createState() => _AlignedEntryState();
}

class _AlignedEntryState extends State<_AlignedEntry> {
  final _measureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // SizeChangedLayoutNotifier doesn't fire on first layout — bootstrap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measureAndReport();
    });
  }

  void _measureAndReport() {
    if (!mounted) return;
    final ctx = _measureKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    widget.sync.report(widget.id, widget.isLeft, box.size.height);
  }

  @override
  Widget build(BuildContext context) {
    final padNotifier = widget.sync.padNotifierFor(widget.id, widget.isLeft);

    // NotificationListener MUST be the ancestor of SizeChangedLayoutNotifier
    // — SCN dispatches up from its own context, so a listener placed inside
    // it never fires and width-change re-measurement silently breaks.
    return ValueListenableBuilder<double>(
      valueListenable: padNotifier,
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          // Defer — notification dispatches mid-layout; mutating a
          // notifier during layout is unsafe.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _measureAndReport();
          });
          return true;
        },
        child: SizeChangedLayoutNotifier(
          child: KeyedSubtree(key: _measureKey, child: widget.child),
        ),
      ),
      builder: (context, pad, child) {
        return Padding(
          padding: EdgeInsets.only(bottom: pad),
          child: child,
        );
      },
    );
  }
}
