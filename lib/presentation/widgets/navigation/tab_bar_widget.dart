import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_typography.dart';
import '../../utils/content_icons.dart';
import '../../../core/utils/pali_conjunct_transformer.dart';
import '../../models/reader_tab.dart';
import '../../providers/tab_lifecycle_provider.dart';
import '../../providers/tab_provider.dart';

class TabBarWidget extends ConsumerStatefulWidget {
  const TabBarWidget({super.key});

  @override
  ConsumerState<TabBarWidget> createState() => _TabBarWidgetState();
}

class _TabBarWidgetState extends ConsumerState<TabBarWidget> {
  final ScrollController _scrollController = ScrollController();

  // One GlobalKey per tab slot (keyed by index). Lets the reveal logic
  // locate the active tab's real RenderBox and derive an exact scroll
  // offset from it — no estimated tab width.
  final Map<int, GlobalKey> _tabKeys = {};

  bool _showLeftChevron = false;
  bool _showRightChevron = false;

  // Previous tab-list state, so the post-frame callback can tell a genuine
  // "tab added / active tab changed" apart from an ordinary rebuild. Seeded
  // in initState so the first frame doesn't trigger a spurious scroll.
  int _prevTabsLen = 0;
  int _prevActiveIndex = -1;

  // _pendingReveal : the active tab still needs scrolling into view.
  // _revealInFlight: a reveal animation chain is already running, so the
  //                  post-frame callback must not start a second, racing one.
  // _revealAttempts: bounds the self-correcting reveal loop (see
  //                  _revealActiveTab).
  bool _pendingReveal = false;
  bool _revealInFlight = false;
  int _revealAttempts = 0;

  // Sub-pixel tolerance when comparing scroll offsets.
  static const double _revealEpsilon = 1.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateChevronVisibility);
    // Seed tracking with current state so initial build is a no-op for
    // the auto-scroll path.
    _prevTabsLen = ref.read(tabsProvider).length;
    _prevActiveIndex = ref.read(activeTabIndexProvider);
    // Check initial state after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateChevronVisibility();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateChevronVisibility);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateChevronVisibility() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final showLeft = position.pixels > 0;
    final showRight = position.pixels < position.maxScrollExtent;

    if (showLeft != _showLeftChevron || showRight != _showRightChevron) {
      setState(() {
        _showLeftChevron = showLeft;
        _showRightChevron = showRight;
      });
    }
  }

  void _scrollLeft() {
    final newOffset = (_scrollController.offset - 150).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _scrollRight() {
    final newOffset = (_scrollController.offset + 150).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  /// Detects a "tab added" or "active tab changed" event and starts a
  /// reveal so the active tab is scrolled fully into view. Called from the
  /// post-frame callback, after chevron visibility has been updated.
  void _handleTabChange(int tabsLen, int activeIndex) {
    final changed = tabsLen > _prevTabsLen || activeIndex != _prevActiveIndex;
    _prevTabsLen = tabsLen;
    _prevActiveIndex = activeIndex;
    if (!changed) return;

    _pendingReveal = true;
    _revealAttempts = 0;
    // Only ever run one reveal chain at a time. An in-flight chain re-reads
    // the current tab state on every step, so it will also pick up this
    // change — no need to start a second, racing chain.
    if (!_revealInFlight) {
      _revealInFlight = true;
      _revealActiveTab();
    }
  }

  /// Scrolls the active tab fully into view, self-correcting until it is.
  ///
  /// Measures the active tab's real geometry, scrolls to it, then re-checks
  /// once the scroll settles and corrects if anything shifted. The floating
  /// chevrons do not consume the list's width, so the viewport is constant
  /// and this normally converges in a single pass; _revealAttempts bounds it.
  void _revealActiveTab() {
    if (!mounted || !_scrollController.hasClients || !_pendingReveal) {
      _pendingReveal = false;
      _revealInFlight = false;
      return;
    }
    // Safety net: this normally settles in a single pass (the viewport is
    // constant and the measurement is exact); the cap just bounds it if
    // something — e.g. the user grabbing the strip mid-reveal — keeps it
    // from settling.
    if (_revealAttempts++ >= 6) {
      _pendingReveal = false;
      _revealInFlight = false;
      return;
    }

    final tabsLen = ref.read(tabsProvider).length;
    final activeIndex = ref.read(activeTabIndexProvider);
    final pos = _scrollController.position;

    // Don't fight the user: if a drag or fling is in progress, abandon the
    // reveal rather than animating the strip against them.
    if (pos.userScrollDirection != ScrollDirection.idle) {
      _pendingReveal = false;
      _revealInFlight = false;
      return;
    }

    if (activeIndex < 0 || activeIndex >= tabsLen) {
      _pendingReveal = false;
      _revealInFlight = false;
      return;
    }

    final target = _targetOffsetFor(tabsLen, activeIndex, pos);

    // Either the active tab is not laid out (target == null) or it is
    // already where it needs to be — the reveal is complete.
    if (target == null || (target - pos.pixels).abs() <= _revealEpsilon) {
      _pendingReveal = false;
      _revealInFlight = false;
      return;
    }

    _scrollController
        .animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        )
        .then((_) {
      // Verify against the settled layout once the scroll ends. With the
      // constant floating-chevron viewport this is normally a no-op
      // confirmation; it also corrects if the tab list changed mid-scroll.
      _revealActiveTab();
    });
  }

  /// Resolves the scroll offset that makes the active tab fully visible.
  ///
  /// Returns null when the offset cannot be resolved (the tab is not
  /// currently laid out), or the current offset when the tab is already
  /// fully visible.
  double? _targetOffsetFor(int tabsLen, int activeIndex, ScrollPosition pos) {
    // Last tab: its trailing edge IS the content's trailing edge, so the
    // exact resting offset is maxScrollExtent. No per-tab measurement is
    // needed and this works even before the tab itself is laid out.
    if (activeIndex == tabsLen - 1) {
      return pos.maxScrollExtent;
    }

    // Any other tab: derive the offset from its actual rendered box.
    //
    // KNOWN LIMITATION: ListView.builder only builds tabs within the
    // viewport plus a small cacheExtent, so a tab scrolled far off-screen
    // has no RenderBox to measure and this returns null — the reveal then
    // gives up. Currently unreachable: every tab activation is either a
    // newly-added last tab (handled above, needs no RenderBox) or a tap on
    // an already-visible tab. It only becomes relevant if a future feature
    // switches to an existing, possibly off-screen tab — handle it then
    // (an iterative jump toward the tab, or ScrollablePositionedList).
    final box = _tabKeys[activeIndex]?.currentContext?.findRenderObject();
    if (box is! RenderBox) return null;

    final viewport = RenderAbstractViewport.of(box);
    final atLeading = viewport.getOffsetToReveal(box, 0.0).offset;
    final atTrailing = viewport.getOffsetToReveal(box, 1.0).offset;
    final lo = atLeading < atTrailing ? atLeading : atTrailing;
    final hi = atLeading < atTrailing ? atTrailing : atLeading;

    // Already fully inside the viewport — stay put.
    if (pos.pixels >= lo - _revealEpsilon &&
        pos.pixels <= hi + _revealEpsilon) {
      return pos.pixels;
    }
    // Otherwise scroll the minimum amount: to the nearer edge of the band
    // of offsets for which the tab is fully visible.
    //
    // KNOWN LIMITATION: this aligns the tab flush to the viewport edge, but
    // the floating chevrons overlay the outer ~28px of that edge — so a
    // mid-list reveal can leave ~28px of the tab under a visible chevron.
    // The common paths are unaffected: the last tab reveals to
    // maxScrollExtent (right chevron hidden) and the first to 0 (left
    // chevron hidden). A small manual scroll recovers it; not worth the
    // fragile chevron-width padding to correct.
    final edge = pos.pixels < lo ? lo : hi;
    return edge.clamp(0.0, pos.maxScrollExtent).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ref.watch(tabsProvider);
    final activeTabIndex = ref.watch(activeTabIndexProvider);

    if (tabs.isEmpty) {
      return const SizedBox.shrink();
    }

    // Drop GlobalKeys for tab slots that no longer exist, so _tabKeys does
    // not grow unbounded as tabs are opened and closed over a session.
    _tabKeys.removeWhere((index, _) => index >= tabs.length);

    // After the frame is laid out, refresh chevron visibility and, when a
    // tab was added or the active tab changed, scroll it fully into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateChevronVisibility();
      _handleTabChange(tabs.length, activeTabIndex);
    });

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      // The tab list spans the full width; the scroll chevrons float on
      // top in a Stack, so the list's viewport never changes when a chevron
      // appears — the chevrons simply overlap the edge tabs.
      child: Stack(
        children: [
          Positioned.fill(child: _buildTabList(tabs, activeTabIndex)),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: _ScrollChevron(
              icon: Icons.chevron_left,
              visible: _showLeftChevron,
              onTap: _scrollLeft,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _ScrollChevron(
              icon: Icons.chevron_right,
              visible: _showRightChevron,
              onTap: _scrollRight,
            ),
          ),
        ],
      ),
    );
  }

  /// The horizontal, scrollable list of tabs.
  Widget _buildTabList(List<ReaderTab> tabs, int activeTabIndex) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
        scrollbars: false, // Hide scrollbar, we have chevrons
      ),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isActive = index == activeTabIndex;

          return _TabItem(
            // Stable per-index key so _revealActiveTab can locate
            // this tab's RenderBox.
            key: _tabKeys.putIfAbsent(index, () => GlobalKey()),
            tab: tab,
            isActive: isActive,
            onTap: () => ref.read(switchTabProvider)(index),
            onClose: () => ref.read(closeTabProvider)(index),
          );
        },
      ),
    );
  }
}

class _ScrollChevron extends StatelessWidget {
  final IconData icon;
  final bool visible;
  final VoidCallback onTap;

  const _ScrollChevron({
    required this.icon,
    required this.visible,
    required this.onTap,
  });

  static const double _width = 28;

  @override
  Widget build(BuildContext context) {
    final isRight = icon == Icons.chevron_right;
    final divider = BorderSide(
      color: Theme.of(context).dividerColor,
      width: 1,
    );

    // IgnorePointer stops a faded-out chevron from intercepting taps meant
    // for the tab beneath it — the chevron keeps its width while invisible,
    // since it only floats over the list rather than sitting in its layout.
    return IgnorePointer(
      ignoring: !visible,
      // Fade in/out instead of appearing/vanishing abruptly.
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: SizedBox(
          width: _width,
          // Own Material so the chevron's hover/press ink is painted and
          // clipped here, instead of bleeding onto a distant ancestor.
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: InkWell(
              onTap: onTap,
              child: Container(
                height: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    left: isRight ? divider : BorderSide.none,
                    right: isRight ? BorderSide.none : divider,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final ReaderTab tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabItem({
    super.key,
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final ci = contentIcon(
      isCommentary: tab.isCommentary,
      isTreatise: tab.isTreatise,
      colorScheme: Theme.of(context).colorScheme,
    );
    return Material(
      // Per-tab Material so this tab's hover/press ink is painted and
      // clipped here. Without it the ink lands on a distant ancestor
      // Material and bleeds past the ListView's clip when the tab is
      // partially scrolled under a floating chevron. animationDuration is
      // zeroed so the active/inactive colour change stays instant, matching
      // the bottom indicator.
      color: isActive
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : Theme.of(context).colorScheme.surfaceContainerLowest,
      animationDuration: Duration.zero,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 120,
            maxWidth: 200,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
              bottom: isActive
                  ? BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              // Tab icon: matches navigator tree icons
              Icon(
                ci.icon,
                size: 18,
                weight: 600,
                color: isActive
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : ci.color.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),

              // Tab label — apply Pali conjunct transformation for bound
              // letters. Tab labels are always derived from paliName (see
              // ReaderTab.fromNode), so the transformation always applies.
              Expanded(
                child: Tooltip(
                  message: tab.paliName != null
                      ? '${tab.paliName!.withPaliConjuncts} / ${tab.sinhalaName ?? ''}'
                      : tab.fullName,
                  child: Text(
                    tab.label.withPaliConjuncts,
                    style: isActive
                        ? context.typography.tabLabelActive
                        : context.typography.tabLabelInactive,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // Close button
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
