import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import '../../../core/theme/app_typography.dart';
import '../../providers/main_search_focus_provider.dart';
import '../../providers/overlay_stack_provider.dart';
import '../../providers/search_mode_provider.dart';
import '../../providers/reader_scroll_provider.dart';
import '../../providers/search_provider.dart';
import '../../providers/singlish_preview_provider.dart';
import 'recent_search_overlay.dart';
import 'singlish_preview.dart';

/// Simple search bar for AppBar with dropdown overlay for recent searches
/// Results panel is shown separately once the query has text
class SearchBar extends ConsumerStatefulWidget {
  /// Box width; null fills the space given.
  final double? width;

  const SearchBar({
    super.key,
    this.width = 360,
  });

  /// Search mode below desktop width: fills the app bar, takes focus as it
  /// appears, and shows recent searches full width under the bar.
  const SearchBar.fullWidth({super.key}) : width = null;

  @override
  ConsumerState<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<SearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final OverlayPortalController _overlayController = OverlayPortalController();

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
      if (_isFullWidth) {
        // Opening search mode is asking to type. Not `autofocus`: Flutter
        // skips that when something else has focus, such as reader text
        // after a long press.
        _focusNode.requestFocus();
      } else {
        // The desktop box has no search mode. Clear one left on by widening
        // the window while search was open, or narrowing would reopen it.
        ref.read(searchModeProvider.notifier).state = false;
      }
    });
  }

  @override
  void dispose() {
    // Below desktop width this bar goes away with search mode. Riverpod
    // forbids changing a provider while the tree is torn down, so detach
    // after the frame.
    final focusController = _searchFocusController;
    final overlayStack = _overlayStack;
    final focusNode = _focusNode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Unpublish our node, or a late Ctrl/Cmd+Shift+F would focus a
      // disposed one. Identity check: a new SearchBar (desktop ↔ narrower
      // width) may have published its node already.
      if (focusController.mounted &&
          identical(focusController.state, focusNode)) {
        focusController.state = null;
      }
      // Drop the ESC-stack entry, or ESC would call into this disposed state.
      if (overlayStack.mounted) overlayStack.remove('recent-searches');
    });
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
      // Search mode may have closed while we waited.
      if (!mounted) return;

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
            // release search-bar focus. In search mode it leaves search mode.
            dismiss: _isFullWidth ? _closeSearch : _hideOverlay,
          ),
        );
  }

  bool get _isFullWidth => widget.width == null;

  /// Closes the panel, and search mode with this bar in it.
  void _closeSearch() => ref.read(closeSearchProvider)();

  /// Hide the dropdown without touching focus. Used when the user starts
  /// typing — query becomes non-empty, the FTS results panel takes over,
  /// but focus must stay on the search bar so they can keep typing.
  void _hideRecentOverlay() {
    if (!_overlayController.isShowing) return;
    _overlayController.hide();
    ref.read(overlayStackProvider.notifier).remove('recent-searches');
  }

  /// Full close: hide the dropdown and release search-bar focus.
  /// Wired to ESC (via the dismiss callback above) and tap-outside, so
  /// neither resets the filters.
  void _hideOverlay() {
    _hideRecentOverlay();
    _focusNode.unfocus();
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

    final rawQueryText =
        ref.watch(searchStateProvider.select((s) => s.rawQueryText));

    // Search is open: the back arrow at the field's start closes it. The one
    // close button at every width.
    final isSearchOpen = _isFullWidth || isResultsPanelVisible;

    // Sinhala preview for Singlish input (none for a reference like "SN 15.3").
    final singlishPreview = ref.watch(singlishPreviewProvider(rawQueryText));

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

    Widget searchBox(double width) => SizedBox(
          width: width,
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
                prefixIcon: isSearchOpen
                    ? BackButton(
                        onPressed: _closeSearch,
                        color: theme.colorScheme.onSurfaceVariant,
                        style: const ButtonStyle(
                          iconSize: WidgetStatePropertyAll(20),
                        ),
                      )
                    : Icon(
                        Icons.search,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                // Desktop's compact size on every platform, so the back
                // button and the ✕ fit the 40px box on phones too.
                prefixIconConstraints:
                    const BoxConstraints.tightFor(width: 40, height: 40),
                suffixIconConstraints:
                    const BoxConstraints(minWidth: 40, minHeight: 40),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (singlishPreview != null)
                      SinglishPreview(singlishPreview, fieldWidth: width),
                    // Clear button (only shown when text is present)
                    if (_controller.text.isNotEmpty)
                      SizedBox.square(
                        dimension: 40,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.clear,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          tooltip: l10n.clear,
                          onPressed: () {
                            // Empties the query only: filters and recent
                            // searches stay, so the recent list comes back.
                            _controller.clear();
                            ref
                                .read(searchStateProvider.notifier)
                                .updateQuery('');
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
        );

    // Positioned from layout info, not a CompositedTransformFollower: a
    // follower breaks tooltips inside the dropdown (they need the paint
    // transform during layout).
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _overlayController,
      overlayChildBuilder: (context, info) {
        // Don't render overlay when results panel is visible
        if (isResultsPanelVisible) {
          return const SizedBox.shrink();
        }

        // The search box's bottom-right corner, in overlay coordinates.
        final anchor = MatrixUtils.transformPoint(
          info.childPaintTransform,
          info.childSize.bottomRight(Offset.zero),
        );
        // 8px below the box; in search mode that is the app bar's bottom.
        final top = anchor.dy + 8;

        return Stack(
          children: [
            // Barrier for outside taps. In search mode it starts under the
            // app bar, so the field and its back arrow stay live.
            Positioned.fill(
              top: _isFullWidth ? top : 0,
              child: GestureDetector(
                onTap: _isFullWidth ? _closeSearch : _hideOverlay,
                behavior: HitTestBehavior.opaque,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            if (_isFullWidth)
              Positioned(
                top: top,
                left: 0,
                right: 0,
                child: RecentSearchOverlay(
                  onDismiss: _hideOverlay,
                  width: info.overlaySize.width,
                ),
              )
            else
              // Right edges aligned with the box
              Positioned(
                top: top,
                right: info.overlaySize.width - anchor.dx,
                child: RecentSearchOverlay(
                  onDismiss: _hideOverlay,
                ),
              ),
          ],
        );
      },
      child: _isFullWidth
          // The preview's 45% cap is a share of the field's real width.
          ? LayoutBuilder(
              builder: (context, constraints) =>
                  searchBox(constraints.maxWidth),
            )
          : searchBox(widget.width!),
    );
  }
}
