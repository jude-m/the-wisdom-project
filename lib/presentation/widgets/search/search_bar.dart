import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import '../../../core/theme/app_typography.dart';
import '../../providers/main_search_focus_provider.dart';
import '../../providers/overlay_stack_provider.dart';
import '../../providers/reader_scroll_provider.dart';
import '../../providers/search_provider.dart';
import '../common/circular_toggle_button.dart';
import 'proximity_dialog.dart';
import 'recent_search_overlay.dart';

/// Simple search bar for AppBar with dropdown overlay for recent searches
/// Results panel is shown separately when query has 2+ characters
class SearchBar extends ConsumerStatefulWidget {
  final double width;

  const SearchBar({
    super.key,
    this.width = 360,
  });

  @override
  ConsumerState<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<SearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();

  // Provider handles captured once in initState. dispose() detaches through
  // these instead of `ref`: using `ref` after the ConsumerStatefulElement is
  // disposed throws "Cannot use ref after the widget was disposed", which
  // happens whenever the SearchBar is unmounted during widget-tree teardown.
  // The providers outlive this widget (they live on the ProviderScope), so
  // holding and using the notifiers directly is safe.
  late final StateController<FocusNode?> _searchFocusController;
  late final OverlayStackNotifier _overlayStack;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);

    // Capture provider notifiers now, while `ref` is valid.
    _searchFocusController = ref.read(mainSearchFocusNodeProvider.notifier);
    _overlayStack = ref.read(overlayStackProvider.notifier);

    // Sync controller with initial state if needed, and publish our focus
    // node so OpenMainSearchAction (Ctrl/Cmd+Shift+F) can request focus on
    // this exact node from anywhere in the app.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusController.state = _focusNode;
      final queryText = ref.read(searchStateProvider).rawQueryText;
      if (queryText.isNotEmpty && _controller.text != queryText) {
        _controller.text = queryText;
      }
    });
  }

  @override
  void dispose() {
    // Detach from the provider before tearing down our node — otherwise a
    // late Ctrl/Cmd+Shift+F could call requestFocus on a disposed node.
    // Identity check guards against a freshly-mounted SearchBar already
    // having published a new node while we were still in flight.
    if (identical(_searchFocusController.state, _focusNode)) {
      _searchFocusController.state = null;
    }
    // Drop any lingering ESC-stack registration before our state is gone,
    // otherwise DismissTopOverlayAction could invoke _hideOverlay on a
    // disposed _focusNode / _overlayController.
    _overlayStack.remove('recent-searches');
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() async {
    // Rebuild so fill + focus outline track focus, not just typed text.
    if (mounted) setState(() {});

    if (_focusNode.hasFocus) {
      // Browser address-bar behaviour: when the bar gains focus and already
      // has a query, highlight the whole thing so the next keystroke replaces
      // it. Deferred to a post-frame callback so it runs AFTER a tap places the
      // caret — otherwise that caret placement would collapse the selection.
      // (Clicking a second time while already focused doesn't re-fire this, so
      // the cursor still places normally on subsequent clicks.)
      if (_controller.text.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_focusNode.hasFocus) return;
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        });
      }

      // Load recent searches
      await ref.read(searchStateProvider.notifier).onFocus();

      // Only show overlay if query is empty
      // When query has any text, the results panel is shown instead
      final queryText = ref.read(searchStateProvider).rawQueryText;
      if (queryText.trim().isEmpty) {
        _openRecentOverlay();
      }
    }
  }

  /// Show the recent-searches dropdown and register it with the global ESC
  /// stack so Ctrl+Esc / Esc dismissal goes through the same LIFO path as
  /// every other overlay in the app.
  void _openRecentOverlay() {
    if (_overlayController.isShowing) return;
    _overlayController.show();
    ref.read(overlayStackProvider.notifier).push(
          DismissibleOverlay(
            id: 'recent-searches',
            // ESC mirrors the tap-outside flow: drop the dropdown AND
            // release search-bar focus.
            dismiss: _hideOverlay,
          ),
        );
  }

  /// Hide the dropdown without touching focus. Used when the user starts
  /// typing — query becomes non-empty, the FTS results panel takes over,
  /// but focus must stay on the search bar so they can keep typing.
  void _hideRecentOverlay() {
    if (!_overlayController.isShowing) return;
    _overlayController.hide();
    ref.read(overlayStackProvider.notifier).remove('recent-searches');
  }

  /// Full close: hide the dropdown and release search-bar focus.
  /// Wired to ESC (via the dismiss callback above), tap-outside, and as
  /// the closing half of [_closeAndClear].
  void _hideOverlay() {
    _hideRecentOverlay();
    _focusNode.unfocus();
  }

  /// Close overlay and clear all search state (for dismissal)
  void _closeAndClear() {
    _hideOverlay();
    _controller.clear();
    ref.read(searchStateProvider.notifier).clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final inputStyle = context.typography.searchInput;
    final hintStyle = inputStyle.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    // Watch if results panel is visible (query is not empty)
    // When query has any text, the results panel is shown instead
    final isResultsPanelVisible =
        ref.watch(searchStateProvider.select((s) => s.isResultsPanelVisible));

    // Same scroll signal the AppBar uses, so the pill's fill stays aligned.
    final scrolledUnder = ref.watch(readerScrolledUnderProvider);

    // Watch exact match state for toggle button
    final isExactMatch =
        ref.watch(searchStateProvider.select((s) => s.isExactMatch));

    // Watch proximity state for toggle button
    // Active when: not using default settings (phrase search with proximity 10)
    final isPhraseSearch =
        ref.watch(searchStateProvider.select((s) => s.isPhraseSearch));
    final isAnywhereInText =
        ref.watch(searchStateProvider.select((s) => s.isAnywhereInText));
    final proximityDistance =
        ref.watch(searchStateProvider.select((s) => s.proximityDistance));

    // Proximity button is active when NOT using default phrase search
    // OR when using non-default proximity settings
    final isProximityActive =
        !isPhraseSearch || isAnywhereInText || proximityDistance != 10;

    // Show proximity button only when user has started typing a second word
    // (i.e., there's a space followed by at least one non-space character)
    final rawQueryText =
        ref.watch(searchStateProvider.select((s) => s.rawQueryText));
    final showProximityButton = RegExp(r'\s\S').hasMatch(rawQueryText);

    // Listen to queryText changes and sync controller
    ref.listen(searchStateProvider.select((s) => s.rawQueryText), (prev, next) {
      if (_controller.text != next) {
        _controller.text = next;
        // Move cursor to end
        _controller.selection = TextSelection.collapsed(offset: next.length);
      }

      // Hide overlay when query has any text (panel takes over).
      // Use the helper so the LIFO stack registration is dropped too —
      // otherwise a stale 'recent-searches' entry would shadow the
      // FTS panel and Esc would close the wrong thing.
      if (next.trim().isNotEmpty && _overlayController.isShowing) {
        _hideRecentOverlay();
      }
      // Show overlay when query becomes empty and focused
      else if (next.trim().isEmpty && _focusNode.hasFocus) {
        _openRecentOverlay();
      }
    });

    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (context) {
        // Don't render overlay when results panel is visible
        if (isResultsPanelVisible) {
          return const SizedBox.shrink();
        }

        return Stack(
          children: [
            // Full-screen barrier for outside taps
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeAndClear,
                behavior: HitTestBehavior.opaque,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            // Dropdown content
            CompositedTransformFollower(
              link: _layerLink,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              child: RecentSearchOverlay(
                onDismiss: _hideOverlay,
              ),
            ),
          ],
        );
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: SizedBox(
          width: widget.width,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              // Tri-state fill: idle / scrolled (merges with AppBar) / focused.
              color: _focusNode.hasFocus
                  ? theme.colorScheme.surfaceContainerHighest
                  : (scrolledUnder
                    ? theme.colorScheme.surfaceContainer
                    : theme.colorScheme.surfaceContainerHigh),
              borderRadius: BorderRadius.circular(20),
              // Always 1px (transparent when unfocused) so focus change
              // doesn't reflow inner content by the stroke width.
              border: Border.all(
                color: _focusNode.hasFocus
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: inputStyle,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                hintStyle: hintStyle,
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Exact match toggle button with clear visual state
                    CircularToggleButton(
                      isActive: isExactMatch,
                      icon: Icons.abc,
                      iconSize: 24,
                      tooltip: l10n.isExactMatchToggle,
                      onPressed: () {
                        ref
                            .read(searchStateProvider.notifier)
                            .toggleExactMatch();
                      },
                    ),
                    // Proximity toggle button - opens proximity dialog
                    // Only visible when user starts typing a second word
                    if (showProximityButton)
                      CircularToggleButton(
                        isActive: isProximityActive,
                        icon: Icons.space_bar,
                        iconSize: 24,
                        tooltip: l10n.wordProximity,
                        onPressed: () => ProximityDialog.show(context),
                      ),
                    // Clear button (only shown when text is present)
                    if (_controller.text.isNotEmpty)
                      Container(
                        height: 30,
                        width: 30,
                        margin: const EdgeInsets.only(left: 4, right: 4),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.clear,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: () {
                            _controller.clear();
                            ref
                                .read(searchStateProvider.notifier)
                                .clearSearch();
                            _focusNode.requestFocus();
                          },
                        ),
                      ),
                  ],
                ),
              ),
              onChanged: (value) {
                ref.read(searchStateProvider.notifier).updateQuery(value);
              },
              onSubmitted: (value) {
                // Dismiss keyboard on mobile when user presses Enter
                // Note: Search happens automatically via debounced updateQuery
                // Recent searches are saved when user clicks a result
                _focusNode.unfocus();
              },
            ),
          ),
        ),
      ),
    );
  }
}
