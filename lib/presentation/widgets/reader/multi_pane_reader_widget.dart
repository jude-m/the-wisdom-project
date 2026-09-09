import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/l10n/app_localizations.dart';
import '../../models/reader_layout.dart';
import '../../models/in_page_search_state.dart';
import '../../../domain/entities/navigation/tipitaka_tree_node.dart';
import '../../../domain/entities/reader/document_slice.dart';
import '../../../domain/entities/reader/reader_unit.dart';
import '../../providers/document_provider.dart';
import '../../providers/dictionary_provider.dart'
    show
        selectedDictionaryWordProvider,
        dictionaryHighlightProvider,
        hasActiveSelectionProvider;
import '../../providers/in_page_search_provider.dart';
import '../../providers/tab_provider.dart'
    show
        activeTabIndexProvider,
        tabsProvider,
        activeReaderLayoutProvider,
        activeNodeKeyProvider;
import '../../providers/previous_sutta_provider.dart'
    show navigateToPreviousSuttaProvider;
import '../../providers/reader_unit_provider.dart'
    show ReaderStep, neighbourLeafProvider;
import '../../providers/fts_highlight_provider.dart';
import '../../providers/reader_scroll_provider.dart';
import 'entry_key_registry.dart';
import 'single_column_pane.dart';
import 'dual_column_pane.dart';
import 'stacked_pane.dart';
import 'reader_selection_handler.dart';
import 'in_page_search_bar.dart';
import 'reader_action_buttons.dart';
import '../dictionary/dictionary_bottom_sheet.dart';
import '../common/status_message_view.dart';
import '../../../core/utils/responsive_utils.dart';


class MultiPaneReaderWidget extends ConsumerStatefulWidget {
  const MultiPaneReaderWidget({super.key});

  @override
  ConsumerState<MultiPaneReaderWidget> createState() =>
      _MultiPaneReaderWidgetState();
}

class _MultiPaneReaderWidgetState extends ConsumerState<MultiPaneReaderWidget>
    with ReaderSelectionHandler<MultiPaneReaderWidget> {
  // Single scroll controller for all modes
  final ScrollController _scrollController = ScrollController();

  // Registry for entry-level GlobalKeys used to sync scroll position
  // across layout switches AND to drive in-page-search scroll-to-match.
  // Shared with all pane widgets.
  final EntryKeyRegistry _entryKeyRegistry = EntryKeyRegistry();

  // Tracks whether the user has scrolled away from the top.
  // Updated in _onScroll; only calls setState when the value actually changes.
  bool _isScrolledDown = false;

  // When true, the layout change listener is suppressed. Set during tab
  // switches to prevent the layout listener from firing when the "change"
  // is just a side-effect of switching to a tab with a different layout.
  bool _suppressLayoutListener = false;

  // Debounces scroll-position writes into the active tab so a fast scroll
  // doesn't push hundreds of state mutations through Riverpod / disk.
  Timer? _scrollSaveDebounce;
  static const _scrollSaveDelay = Duration(milliseconds: 400);

  // When true, _onScroll skips the debounced auto-save. Toggled around
  // programmatic jumpTo() calls during scroll restoration so the clamped
  // jumpTo (when ListView's maxExtent is still small on cold load) can't
  // overwrite the genuinely saved offset on disk.
  bool _suppressScrollSave = false;

  // Bound on *stalled* restoration retries — see [_restoreScrollWithRetry].
  // Frames that grow the scroll extent are progress and cost nothing; this
  // only limits how long we keep re-jumping at an offset nothing is moving
  // toward (content shrunk, etc.).
  static const _restoreMaxRetries = 30;

  // Bound on scroll-to-entry retries — see [_ensureEntryVisible].
  // ~10 frames is enough for ListView.builder to lazy-build the page
  // holding the target, without spinning forever if it is unreachable.
  static const _entryScrollMaxRetries = 10;

  // The entry [_ensureEntryVisible] is currently reaching for, or null.
  // Only [DualColumnPane] reads it — it builds a window of the unit rather
  // than a lazy list, so it has to be told which page to open far enough to
  // include. See that class's doc.
  (int, int)? _revealTarget;

  // Emblem shown in the first-run "select a sutta" hint.
  static const _selectSuttaEmblemAsset = 'assets/icons/app_logo.png';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  /// Scroll listener for scroll-position tracking.
  void _onScroll() {
    if (_scrollController.hasClients) {
      final currentScroll = _scrollController.position.pixels;

      // Track whether the user has scrolled meaningfully from the top.
      // Small fixed threshold (not a full viewport) so Mode 2 kicks in
      // promptly once the user starts scrolling, while still ignoring
      // overscroll/bounce jitter near the top.
      const scrollAwayFromTopThreshold = 60.0;
      final scrolledDown = currentScroll > scrollAwayFromTopThreshold;
      if (scrolledDown != _isScrolledDown) {
        setState(() => _isScrolledDown = scrolledDown);
      }

      // Keep the app bar's "scrolled under" tint in sync with this scroll.
      _syncScrolledUnder();

      // Debounced persist of scroll position into the active tab. Without
      // this, a reload while parked in a tab (no tab switch) would lose
      // the position. TabsNotifier itself coalesces writes again before
      // hitting disk.
      //
      // Skip while a programmatic restore is in flight — otherwise the
      // jumpTo we just performed (possibly clamped to a small maxExtent
      // because pages haven't laid out yet) would clobber the real saved
      // offset on disk.
      if (!_suppressScrollSave) {
        _scrollSaveDebounce?.cancel();
        _scrollSaveDebounce = Timer(_scrollSaveDelay, _saveScrollPosition);
      }
    }
  }

  /// Publishes whether the reader content is scrolled away from the top into
  /// [readerScrolledUnderProvider], which drives the app bar's tint.
  ///
  /// Uses `extentBefore > 0` — the exact threshold Material 3's built-in
  /// scrolled-under detection uses — so the tint behaves identically, just
  /// reliably. Called from [_onScroll] (covers genuine scrolling and any
  /// `jumpTo` to a non-zero offset, both of which notify the controller) and
  /// explicitly after a tab-switch scroll restore — where a `jumpTo(0)` onto
  /// a freshly mounted, already-at-0 scroll view is a no-op and would
  /// otherwise leave the flag stale at the previous tab's value.
  void _syncScrolledUnder() {
    if (!_scrollController.hasClients) return;
    final scrolledUnder = _scrollController.position.extentBefore > 0;
    final notifier = ref.read(readerScrolledUnderProvider.notifier);
    if (notifier.state != scrolledUnder) {
      notifier.state = scrolledUnder;
    }
  }

  @override
  void dispose() {
    _scrollSaveDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _entryKeyRegistry.clear();
    super.dispose();
  }

  /// Persists the current scroll offset into the active tab's
  /// [ReaderTab.scrollOffset]. TabsNotifier debounces the disk write, so
  /// calling this often is cheap.
  void _saveScrollPosition([int? index]) {
    final int activeTabIndex = index ?? ref.read(activeTabIndexProvider);
    if (activeTabIndex >= 0 && _scrollController.hasClients) {
      ref
          .read(tabsProvider.notifier)
          .updateTabScrollOffset(activeTabIndex, _scrollController.offset);
    }
  }

  /// Scrolls to the beginning of the current unit.
  ///
  /// A plain jump now: the unit's first row is the first thing rendered, so
  /// there is no pagination to rewind — which is what it used to be doing.
  void _scrollToBeginning() {
    // Reset scroll-tracking state so the button transitions correctly
    // (from scroll-to-top to skip-previous once we're at the beginning).
    setState(() => _isScrolledDown = false);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  /// Navigates to the previous sutta.
  /// Delegates business logic to [navigateToPreviousSuttaProvider] and
  /// handles the widget-specific concern (scroll position).
  void _navigateToPreviousSutta(TipitakaTreeNode previousNode) {
    ref.read(navigateToPreviousSuttaProvider)(previousNode);

    // Jump to top — handles the same-file case, where the document does not
    // reload and nothing else would move the viewport.
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  /// Restores scroll position immediately (no extra frame delay).
  /// Must be called from within an [addPostFrameCallback] where the
  /// content has already been rebuilt — avoids the double-postFrameCallback
  /// that caused a visible glitch (title flash) when switching tabs.
  ///
  /// A tab that has never been scrolled lands on what it was opened *for*
  /// instead: the row a search hit or a `?e=` link named. That landing is
  /// consumed here — see [TabsNotifier.clearTabLanding] — so coming back to
  /// the tab later resumes where reading stopped rather than snapping to the
  /// hit again.
  ///
  /// On cold-load the document arrives before the pane has laid out enough of
  /// the unit — lazily in the one-column layouts, a window at a time in
  /// side-by-side — so `maxScrollExtent` is initially smaller than the saved
  /// offset. In that case we re-jump on subsequent frames until we either
  /// reach the saved offset or run out of retries. Throughout,
  /// [_suppressScrollSave] is held high so the jumpTo's own scroll
  /// notification can't trigger an auto-save that would overwrite the
  /// on-disk offset with a clamped one.
  void _restoreScrollPositionImmediate() {
    final activeTabIndex = ref.read(activeTabIndexProvider);
    final tabs = ref.read(tabsProvider);
    if (activeTabIndex < 0 || activeTabIndex >= tabs.length) return;

    if (tabs[activeTabIndex].scrollOffset == 0) {
      final landing = ref.read(activeLandingEntryProvider);
      if (landing != null) {
        _ensureEntryVisible(
          landing.$1,
          landing.$2,
          retriesLeft: _entryScrollMaxRetries,
          alignment: 0.0,
          animate: false,
        );
        // Spend it. The coordinates above are already captured as arguments,
        // so the retry chain is unaffected by clearing them here.
        ref.read(tabsProvider.notifier).clearTabLanding(activeTabIndex);
        _syncScrolledUnder();
        return;
      }
    }
    _restoreScrollWithRetry(retriesLeft: _restoreMaxRetries);
  }

  /// Re-jumps toward the saved offset across frames until it is reachable.
  ///
  /// [retriesLeft] is spent only on frames that made no progress: in
  /// side-by-side each clamped jump grows the pane's window one step, so the
  /// extent climbs a frame at a time and charging those frames would cap the
  /// restore at whatever 30 growths reach. Charging every *non-increase* is
  /// what bounds this — not a rising extent, which only side-by-side has: the
  /// lazy layouts estimate theirs from the average of the children laid out so
  /// far, and it falls when a jump realises shorter ones.
  void _restoreScrollWithRetry({
    required int retriesLeft,
    double? lastMaxExtent,
  }) {
    if (!mounted) return;
    final activeTabIndex = ref.read(activeTabIndexProvider);
    final tabs = ref.read(tabsProvider);
    if (activeTabIndex < 0 ||
        activeTabIndex >= tabs.length ||
        !_scrollController.hasClients) {
      return;
    }
    final saved = tabs[activeTabIndex].scrollOffset;
    final maxExtent = _scrollController.position.maxScrollExtent;

    _suppressScrollSave = true;
    _scrollController.jumpTo(saved.clamp(0.0, maxExtent));
    // Sync the app bar tint to the tab we just restored. A jumpTo(0) onto a
    // freshly mounted scroll view (already at 0) is a no-op and fires no
    // notification, so _onScroll won't run — sync explicitly here.
    _syncScrolledUnder();
    // The clamped jumpTo notifies _onScroll synchronously above; clear
    // the flag on the next frame so genuine user scrolls aren't missed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _suppressScrollSave = false;
    });

    // Saved offset still beyond what's laid out → try again on the next
    // frame, by which point the jump above has built more of the list.
    // Bounded by retriesLeft so a saved offset that can genuinely no longer
    // be reached (e.g. the unit got shorter) eventually settles.
    if (saved > maxExtent && retriesLeft > 0) {
      final progressed = lastMaxExtent == null || maxExtent > lastMaxExtent;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreScrollWithRetry(
          retriesLeft: progressed ? retriesLeft : retriesLeft - 1,
          lastMaxExtent: maxExtent,
        );
      });
    }
  }

  /// Scrolls to the current in-page search match.
  ///
  /// Every match is inside the rendered unit — that is what bounding the unit
  /// bought — so there is no range to expand first, only an entry to reveal.
  void _scrollToCurrentMatch(InPageSearchState searchState) {
    final currentMatch = searchState.currentMatch;
    if (currentMatch == null) return;
    _ensureEntryVisible(
      currentMatch.pageIndex,
      currentMatch.entryIndex,
      retriesLeft: _entryScrollMaxRetries,
    );
  }

  /// Reveals the entry at `(pageIndex, entryIndex)`, retrying on subsequent
  /// frames while its GlobalKey is unmounted.
  ///
  /// The page is always inside the rendered unit, so the only reason the key
  /// is missing is that [ListView.builder] has not lazy-built it: it sits
  /// outside the default cacheExtent (~250px). Growing anything is useless
  /// there — the page is already in the item list — so we step the controller
  /// by one viewport toward the target and let the next frame's cacheExtent
  /// cover the slab. Direction comes from [EntryKeyRegistry.findTopVisibleEntry].
  ///
  /// Bounded by [_entryScrollMaxRetries] so an unreachable target settles
  /// instead of spinning forever.
  void _ensureEntryVisible(
    int pageIndex,
    int entryIndex, {
    required int retriesLeft,
    double alignment = 0.3,
    bool animate = true,
  }) {
    if (!mounted) return;

    // Publish it before looking the key up: on the first attempt the window
    // pane may not have built that page yet, and this is what makes it.
    if (_revealTarget != (pageIndex, entryIndex)) {
      setState(() => _revealTarget = (pageIndex, entryIndex));
    }

    final key = _entryKeyRegistry.keyFor(pageIndex, entryIndex);
    final keyContext = key.currentContext;
    final renderObject = keyContext?.findRenderObject();
    if (renderObject != null && renderObject.attached) {
      Scrollable.ensureVisible(
        keyContext!,
        alignment: alignment,
        duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
        curve: Curves.easeInOut,
      );
      return;
    }

    if (retriesLeft <= 0) return;

    _stepViewportToward(pageIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureEntryVisible(
        pageIndex,
        entryIndex,
        retriesLeft: retriesLeft - 1,
        alignment: alignment,
        animate: animate,
      );
    });
  }

  /// Steps the scroll controller by one viewport toward the page holding the
  /// target so the next frame's [ListView.builder] cacheExtent covers the
  /// slab containing it. Direction is inferred from the currently top-visible
  /// entry; when the registry has nothing mounted yet (transitional frame),
  /// defaults to forward.
  ///
  /// Suppresses the debounced scroll-position auto-save: the intermediate
  /// clamped offsets aren't user-meaningful and shouldn't overwrite disk.
  /// Mirrors the suppression pattern in [_restoreScrollWithRetry].
  void _stepViewportToward(int pageIndex) {
    if (!_scrollController.hasClients) return;

    final pos = _scrollController.position;
    final topEntry = _entryKeyRegistry.findTopVisibleEntry(_scrollController);
    final scrollingDown = topEntry == null || pageIndex > topEntry.$1;
    final delta =
        scrollingDown ? pos.viewportDimension : -pos.viewportDimension;
    final target = (pos.pixels + delta).clamp(0.0, pos.maxScrollExtent);

    if (target == pos.pixels) return;

    _suppressScrollSave = true;
    _scrollController.jumpTo(target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _suppressScrollSave = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to active tab changes
    ref.listen<int>(activeTabIndexProvider, (previous, next) {
      if (previous != null && previous != next) {
        // Suppress the layout listener during tab switches. When tabs have
        // different layout settings, activeReaderLayoutProvider changes as a
        // side-effect. Without this guard, the layout listener would override
        // the scroll position restoration below.
        _suppressLayoutListener = true;

        // Save scroll position for the previous tab, but ONLY if:
        // - previous was a valid tab (>= 0)
        // - next is also a valid tab (>= 0) - meaning we're switching, not closing
        // This prevents saving the closed tab's scroll position to the wrong index
        if (previous >= 0 && next >= 0) {
          _saveScrollPosition(previous);
        }

        // Clear entry key registry — old tab's keys are stale
        _entryKeyRegistry.clear();

        // Layout is now per-tab and derived from activeReaderLayoutProvider
        // No need to override or reset - each tab remembers its own column mode

        // Restore the saved scroll position for the new tab after content renders.
        // We do NOT jumpTo(0) first — that would briefly flash the sutta title
        // before the restore fires, causing a visible glitch.
        if (next >= 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _suppressLayoutListener = false;
            _restoreScrollPositionImmediate();
          });
        } else {
          _suppressLayoutListener = false;
          // No active tab (all tabs closed) — the reader shows the empty
          // state, so the app bar must not stay tinted.
          ref.read(readerScrolledUnderProvider.notifier).state = false;
        }
      }
    });

    // Restore scroll position once the unit's pages are actually on screen.
    // Watches the slice rather than the document, because the document can
    // arrive before the page plan does and there is nothing to scroll within
    // until both are in.
    ref.listen<DocumentSlice?>(activeDocumentSliceProvider, (previous, next) {
      if (next != null && previous == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _restoreScrollPositionImmediate();
        });
      }
    });

    // Listen to layout changes — sync reading position by logical entry, not
    // pixels. Pixel offsets are meaningless across layouts (stacked is ~2x
    // taller than side-by-side per entry). Capture which entry is at the
    // viewport top, then reveal that same entry once the new layout has laid
    // out. [_ensureEntryVisible] retries across frames, which is what makes
    // this safe against the extent ListView.builder underestimates on a fresh
    // layout — the reason this used to reset pagination instead.
    ref.listen<ReaderLayout>(activeReaderLayoutProvider, (previous, next) {
      if (previous != null && previous != next && !_suppressLayoutListener) {
        // Capture top-visible entry from the OLD layout (still mounted)
        final topEntry =
            _entryKeyRegistry.findTopVisibleEntry(_scrollController);
        // Clear stale keys from old layout before rebuild
        _entryKeyRegistry.clear();

        // Match set is layout-scoped — refresh against the new layout.
        // Also covered by the suppression guard above: tab switches skip
        // this because each tab's matches already align with its own layout.
        ref
            .read(inPageSearchStatesProvider.notifier)
            .recomputeActiveTabMatches();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (topEntry == null) {
            if (_scrollController.hasClients) _scrollController.jumpTo(0);
            return;
          }
          _ensureEntryVisible(
            topEntry.$1,
            topEntry.$2,
            retriesLeft: _entryScrollMaxRetries,
            alignment: 0.0,
            animate: false,
          );
        });
      }
    });

    // Listen to in-page search state changes to trigger scroll-to-match
    ref.listen<InPageSearchState>(activeInPageSearchStateProvider,
        (previous, next) {
      if (next.currentMatchIndex >= 0 &&
          next.currentMatchIndex != (previous?.currentMatchIndex ?? -1)) {
        _scrollToCurrentMatch(next);
      }
    });

    // The unit resolves before its text does, so both are watched: the unit
    // says which file and which rows, the document supplies them.
    final unitAsync = ref.watch(activeReaderUnitProvider);
    final contentAsync = ref.watch(currentBJTDocumentProvider);
    final slice = ref.watch(activeDocumentSliceProvider);
    // Watch per-tab reader layout (each tab remembers its own setting)
    final readerLayout = ref.watch(activeReaderLayoutProvider);
    // Watch selected word to conditionally mount the dictionary sheet
    final selectedWord = ref.watch(selectedDictionaryWordProvider);

    // Watch in-page search state for the active tab
    final searchState = ref.watch(activeInPageSearchStateProvider);

    // Watch the sutta on the other side of this unit, for backward navigation.
    final nodeKey = ref.watch(activeNodeKeyProvider);
    final previousNode = nodeKey == null
        ? null
        : ref.watch(neighbourLeafProvider((nodeKey, ReaderStep.previous)));

    // Visibility flags for the two action button modes.
    // Computed once here so IgnorePointer, AnimatedOpacity, and AnimatedSlide
    // all reference the same boolean — avoids duplication and drift.
    //
    // The unit always renders from its own first row, so "past the beginning"
    // is now exactly "scrolled down" — including after a search hit, which
    // scrolls into the unit rather than starting partway through it.
    final hasContent = slice != null && !slice.isEmpty;
    final showMode1 =
        hasContent && !searchState.isVisible && !_isScrolledDown;
    final showMode2 = hasContent && !searchState.isVisible && _isScrolledDown;

    return Stack(
      children: [
        // Main content area
        Column(
          children: [
            Expanded(
              child: _buildBody(
                context,
                unitAsync: unitAsync,
                contentAsync: contentAsync,
                slice: slice,
                readerLayout: readerLayout,
                searchState: searchState,
              ),
            ),
          ],
        ),
        // In-page search bar (floating at top).
        // Mobile: full-width edge-to-edge. Tablet/desktop: right-anchored with
        // a capped width (Chrome/Safari/VS Code pattern — close button lands
        // where the eye expects it). Breakpoint comes from ResponsiveUtils so
        // it stays in sync with the rest of the app's layout decisions.
        // The inner ValueKey on InPageSearchBar (below) gives a fresh widget
        // instance per tab so the controller text resets; the outer key on the
        // Positioned is a separate concern — see its note.
        if (searchState.isVisible)
          Positioned(
            // Stable key so the Stack matches this child by identity. Without
            // it, inserting this child shifts the keyless Positioned wrappers
            // below by one slot, and the FAB's (opacity-1) AnimatedOpacity
            // element gets reused to render the Mode 1 pills for a frame —
            // making the top pills flash in on every open.
            key: const ValueKey('in-page-search-bar'),
            top: 8,
            right: 16,
            left: ResponsiveUtils.isMobile(context) ? 16 : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: InPageSearchBar.maxWidthOnLargeScreens,
              ),
              child: InPageSearchBar(
                key: ValueKey(
                  'search-bar-${ref.watch(activeTabIndexProvider)}',
                ),
              ),
            ),
          ),
        // Mode 1: Floating pills at top-right when at the unit's beginning.
        // Layout selector pill + action button pill in a row.
        // IgnorePointer disables taps on the invisible widget.
        if (hasContent)
          Positioned(
            // Keyed so reconciliation pins this to the Mode 1 element no matter
            // what conditional siblings appear/disappear above it (see the
            // search-bar key note above).
            key: const ValueKey('reader-actions-top'),
            top: 12,
            right: 16,
            child: IgnorePointer(
              ignoring: !showMode1,
              child: AnimatedOpacity(
                opacity: showMode1 ? 1.0 : 0.0,
                // Matches Mode 2's 200ms so the two modes cross-fade
                // symmetrically with no brief "neither visible" gap.
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ReaderLayoutPill(),
                    const SizedBox(width: 8),
                    ReaderActionButtonGroup(
                      onSearchTap: () => ref
                          .read(inPageSearchStatesProvider.notifier)
                          .openSearch(),
                      onScrollTap: previousNode != null
                          ? () => _navigateToPreviousSutta(previousNode)
                          : null,
                      scrollIcon:
                          previousNode != null ? Icons.skip_previous : null,
                      scrollTooltip: previousNode != null
                          ? AppLocalizations.of(context)
                              .goToPreviousSutta(previousNode.paliName)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Mode 2: Expandable FAB at bottom-right (scrolled down)
        // Contains layout selector + action buttons when expanded.
        if (hasContent)
          Positioned(
            // Keyed so reconciliation pins this to the Mode 2 (FAB) element —
            // see the search-bar key note above.
            key: const ValueKey('reader-actions-fab'),
            bottom: 24,
            right: 16,
            child: IgnorePointer(
              ignoring: !showMode2,
              child: AnimatedOpacity(
                opacity: showMode2 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: AnimatedSlide(
                  offset: showMode2
                      ? Offset.zero
                      : const Offset(0, 0.3),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: ReaderExpandableFab(
                    visible: showMode2,
                    onSearchTap: () => ref
                        .read(inPageSearchStatesProvider.notifier)
                        .openSearch(),
                    onScrollTap: _scrollToBeginning,
                    scrollTooltip:
                        AppLocalizations.of(context).scrollToBeginning,
                  ),
                ),
              ),
            ),
          ),
        // Non-modal dictionary bottom sheet overlay
        // Only mounted when a word is selected (conditional mounting for performance)
        if (selectedWord != null)
          const DictionaryBottomSheet(key: ValueKey('dictionary-sheet')),
      ],
    );
  }

  /// The reader's content area, across the states its two inputs can be in.
  ///
  /// Errors are reported from whichever half failed, and loading covers both:
  /// a unit with no text yet looks the same to a reader as text with no unit.
  Widget _buildBody(
    BuildContext context, {
    required AsyncValue<ReaderUnit?> unitAsync,
    required AsyncValue<Object?> contentAsync,
    required DocumentSlice? slice,
    required ReaderLayout readerLayout,
    required InPageSearchState searchState,
  }) {
    final failure = unitAsync.error ?? contentAsync.error;
    if (failure != null) {
      // No Retry / no widget-level logging:
      //   - BJTDataSource logs the raw error + stack trace at the catch site,
      //     so DevTools shows the real cause.
      //   - On web the user can refresh; on mobile the JSON is bundled in the
      //     app, so retry can't fix it.
      final variant = statusVariantForError(failure);
      final l10n = AppLocalizations.of(context);
      return StatusMessageView(
        variant: variant,
        title: variant == StatusVariant.offline
            ? l10n.statusOfflineTitle
            : l10n.errorLoadingContent,
        description: variant == StatusVariant.offline
            ? l10n.statusOfflineDescription
            : l10n.statusErrorDescription,
      );
    }

    // No tab, or a tab with no unit — the first-run hint.
    if (unitAsync.hasValue && unitAsync.value == null) {
      return StatusMessageView(
        variant: StatusVariant.info,
        imageAsset: _selectSuttaEmblemAsset,
        imageSize: 100,
        title: AppLocalizations.of(context).statusSelectSuttaToRead,
      );
    }

    if (slice == null) {
      return const StatusMessageView(variant: StatusVariant.loading);
    }

    if (slice.isEmpty) {
      return StatusMessageView(
        variant: StatusVariant.empty,
        // The user didn't search — search_off is wrong here.
        // menu_book_outlined matches the reader's vocabulary
        // (also used for the "select a sutta" info hint).
        iconOverride: Icons.menu_book_outlined,
        title: AppLocalizations.of(context).statusNoContentToDisplay,
      );
    }

    return _buildContentLayout(context, slice, readerLayout, searchState);
  }

  /// Clears all highlights and bottom sheet when tapping empty space.
  void _clearAllHighlights() {
    // Clear text selection if active
    if (ref.read(hasActiveSelectionProvider)) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    // Clear dictionary and FTS highlights (per-tab for FTS)
    ref.read(dictionaryHighlightProvider.notifier).state = null;
    ref.read(selectedDictionaryWordProvider.notifier).state = null;
    ref.read(ftsHighlightProvider.notifier).clearForActiveTab();
  }

  /// Handles word tap for dictionary lookup.
  /// If there's an active text selection, clears it instead of opening dictionary.
  void _handleWordTap(String word) {
    // If there's an active text selection, clear it and don't open dictionary
    if (ref.read(hasActiveSelectionProvider)) {
      FocusManager.instance.primaryFocus?.unfocus();
      // Clear the highlight that was set by TextEntryWidget before this callback
      ref.read(dictionaryHighlightProvider.notifier).state = null;
      return;
    }
    // Open dictionary lookup — pass word with conjuncts intact so the
    // dictionary bottom sheet displays proper bound letters in the text field.
    // The lookup itself strips ZWJ via computeEffectiveQuery/normalizeText.
    ref.read(selectedDictionaryWordProvider.notifier).state = word;
  }

  /// Delegates to the appropriate pane widget based on reader layout.
  Widget _buildContentLayout(
    BuildContext context,
    DocumentSlice slice,
    ReaderLayout readerLayout,
    InPageSearchState searchState,
  ) {
    switch (readerLayout) {
      case ReaderLayout.paliOnly:
        return SingleColumnPane(
          scrollController: _scrollController,
          slice: slice,
          searchState: searchState,
          languageCode: 'pi',
          enableDictionaryLookup: true,
          entryKeyRegistry: _entryKeyRegistry,
          onTapEmpty: _clearAllHighlights,
          onWordTap: _handleWordTap,
          onSelectionChanged: onSelectionChanged,
          contextMenuBuilder: buildSelectionContextMenu,
        );
      case ReaderLayout.sinhalaOnly:
        return SingleColumnPane(
          scrollController: _scrollController,
          slice: slice,
          searchState: searchState,
          languageCode: 'si',
          enableDictionaryLookup: false,
          entryKeyRegistry: _entryKeyRegistry,
          onTapEmpty: _clearAllHighlights,
          onWordTap: _handleWordTap,
          onSelectionChanged: onSelectionChanged,
          contextMenuBuilder: buildSelectionContextMenu,
        );
      case ReaderLayout.sideBySide:
        return DualColumnPane(
          scrollController: _scrollController,
          slice: slice,
          searchState: searchState,
          revealTarget: _revealTarget,
          entryKeyRegistry: _entryKeyRegistry,
          onTapEmpty: _clearAllHighlights,
          onWordTap: _handleWordTap,
          onSelectionChanged: onSelectionChanged,
          contextMenuBuilder: buildSelectionContextMenu,
        );
      case ReaderLayout.stacked:
        return StackedPane(
          scrollController: _scrollController,
          slice: slice,
          searchState: searchState,
          entryKeyRegistry: _entryKeyRegistry,
          onTapEmpty: _clearAllHighlights,
          onWordTap: _handleWordTap,
          onSelectionChanged: onSelectionChanged,
          contextMenuBuilder: buildSelectionContextMenu,
        );
    }
  }
}
