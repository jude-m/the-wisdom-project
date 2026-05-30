import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_typography.dart';
import '../../utils/content_icons.dart';
import '../../utils/content_text_formatter.dart';
import '../../../domain/entities/content/content_language.dart';
import '../../models/reader_tab.dart';
import '../../providers/content_language_provider.dart';
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

  // _pendingReveal : a reveal is pending or animating; also freezes chevron
  //                  updates while it runs (see _updateChevronVisibility).
  // _revealInFlight: a reveal animation chain is already running, so a new
  //                  reveal request must not start a second, racing one.
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
    // Ongoing chevron updates come from the ScrollController listener and the
    // ScrollMetricsNotification in _buildTabList; this post-frame check just
    // covers the very first layout.
    _scrollController.addListener(_updateChevronVisibility);
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
    // While a reveal is pending or animating, freeze the chevrons — otherwise
    // the right chevron blinks on then off as the animation crosses
    // maxScrollExtent. _endReveal does the one authoritative update once the
    // scroll has settled.
    if (_pendingReveal) return;

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

  // How far a single chevron tap nudges the tab strip.
  static const double _chevronScrollStep = 150;

  void _scrollLeft() => _scrollBy(-_chevronScrollStep);
  void _scrollRight() => _scrollBy(_chevronScrollStep);

  /// Animates the tab strip by [delta] pixels, clamped to the scroll range.
  void _scrollBy(double delta) {
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  /// Schedules a reveal of the active tab for after the current frame.
  ///
  /// Called from the `ref.listen` callbacks in [build] when a tab is added
  /// or the active tab changes. The post-frame delay lets the new layout
  /// settle — tab RenderBoxes and maxScrollExtent — before [_startReveal]
  /// measures against it.
  void _scheduleReveal() {
    // Set the flag synchronously — before any post-frame callback can run —
    // so the chevron freeze is already in effect when the reveal begins.
    _pendingReveal = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _startReveal());
  }

  /// Starts a reveal so the active tab is scrolled fully into view.
  void _startReveal() {
    if (!mounted) return;

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

  /// Ends the reveal: clears the flags and runs the one chevron update that
  /// was frozen while it ran (see [_updateChevronVisibility]).
  void _endReveal() {
    _pendingReveal = false;
    _revealInFlight = false;
    if (mounted) _updateChevronVisibility();
  }

  /// Scrolls the active tab fully into view, self-correcting until it is.
  ///
  /// Measures the active tab's geometry, scrolls to it, then re-checks once
  /// the scroll settles and corrects if anything shifted. Normally converges
  /// in a single pass; _revealAttempts bounds it.
  void _revealActiveTab() {
    if (!mounted || !_scrollController.hasClients || !_pendingReveal) {
      _endReveal();
      return;
    }
    // Cap the self-correcting loop so it can't spin if something keeps it
    // from settling — e.g. the user grabbing the strip mid-reveal.
    if (_revealAttempts++ >= 6) {
      _endReveal();
      return;
    }

    final tabsLen = ref.read(tabsProvider).length;
    final activeIndex = ref.read(activeTabIndexProvider);
    final pos = _scrollController.position;

    // Don't fight the user: if a drag or fling is in progress, abandon the
    // reveal rather than animating the strip against them.
    if (pos.userScrollDirection != ScrollDirection.idle) {
      _endReveal();
      return;
    }

    if (activeIndex < 0 || activeIndex >= tabsLen) {
      _endReveal();
      return;
    }

    final target = _targetOffsetFor(tabsLen, activeIndex, pos);

    // Either the active tab is not laid out (target == null) or it is
    // already where it needs to be — the reveal is complete.
    if (target == null || (target - pos.pixels).abs() <= _revealEpsilon) {
      _endReveal();
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
    final lo = math.min(atLeading, atTrailing);
    final hi = math.max(atLeading, atTrailing);

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
    return edge.clamp(0.0, pos.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ref.watch(tabsProvider);
    final activeTabIndex = ref.watch(activeTabIndexProvider);

    // Reveal the active tab when a tab is added or the active tab
    // changes. ref.listen fires only on a real change — not on every
    // rebuild — and must be called unconditionally, so it sits above the
    // isEmpty early-return.
    ref.listen(tabsProvider, (prev, next) {
      if (prev != null && next.length > prev.length) _scheduleReveal();
    });
    ref.listen(activeTabIndexProvider, (prev, next) {
      if (prev != next) _scheduleReveal();
    });

    if (tabs.isEmpty) {
      return const SizedBox.shrink();
    }

    // Drop GlobalKeys for tab slots that no longer exist, so _tabKeys does
    // not grow unbounded as tabs are opened and closed over a session.
    _tabKeys.removeWhere((index, _) => index >= tabs.length);

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
    return NotificationListener<ScrollMetricsNotification>(
      // Fires whenever the list's scroll metrics change without a scroll —
      // a viewport resize (pane divider), a tab added/removed, or tab labels
      // resized by a theme or text-scale change. The ScrollController
      // listener only sees pixel changes, so this is what keeps the chevrons
      // honest. Deferred to post-frame: the notification can arrive
      // mid-layout, and _updateChevronVisibility calls setState.
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _updateChevronVisibility(),
        );
        return false;
      },
      child: ScrollConfiguration(
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
              key: _tabKeys.putIfAbsent(index, () => GlobalKey()),
              tab: tab,
              isActive: isActive,
              onTap: () => ref.read(switchTabProvider)(index),
              onClose: () => ref.read(closeTabProvider)(index),
            );
          },
        ),
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
    final theme = Theme.of(context);
    final isRight = icon == Icons.chevron_right;
    final divider = BorderSide(
      color: theme.dividerColor,
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
            color: theme.colorScheme.surfaceContainer,
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
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ci = contentIcon(
      isCommentary: tab.isCommentary,
      isTreatise: tab.isTreatise,
      colorScheme: colors,
    );

    // Tab labels follow the Content Language setting. Fall back across the
    // tab's stored names (older persisted tabs may only carry `label`).
    final contentLanguage = ref.watch(effectiveContentLanguageProvider);
    final rawLabel = switch (contentLanguage) {
      ContentLanguage.pali => tab.paliName ?? tab.label,
      ContentLanguage.sinhala => tab.sinhalaName ?? tab.paliName ?? tab.label,
    };
    final displayLabel = formatContentLabel(rawLabel, contentLanguage);
    return Material(
      // Per-tab Material so this tab's hover/press ink is painted and
      // clipped here. Without it the ink lands on a distant ancestor
      // Material and bleeds past the ListView's clip when the tab is
      // partially scrolled under a floating chevron. animationDuration is
      // zeroed so the active/inactive colour change stays instant, matching
      // the bottom indicator.
      color: isActive
          ? colors.surfaceContainerHighest
          : colors.surfaceContainerLowest,
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
                color: theme.dividerColor,
                width: 1,
              ),
              bottom: isActive
                  ? BorderSide(
                      color: colors.primary,
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
                    ? colors.onSurface
                    : ci.color.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),

              // Tab label follows the Content Language setting (computed
              // above). The tooltip shows that same single Content Language
              // name — useful when a long name is ellipsized. Only one name
              // now: the Content Language wins, so no second Pali/Sinhala part.
              Expanded(
                child: Tooltip(
                  message: displayLabel,
                  child: Text(
                    displayLabel,
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
                    color: colors.onSurface.withValues(alpha: 0.6),
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
