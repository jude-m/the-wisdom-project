import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import '../providers/search_provider.dart';
import 'recent_search_overlay.dart';

/// Simple search bar for AppBar with dropdown overlay for recent searches
/// Results panel is shown separately when query has 2+ characters
class SearchBar extends ConsumerStatefulWidget {
  final double width;

  const SearchBar({
    super.key,
    this.width = 280,
  });

  @override
  ConsumerState<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<SearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);

    // Sync controller with initial state if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final queryText = ref.read(searchStateProvider).queryText;
      if (queryText.isNotEmpty && _controller.text != queryText) {
        _controller.text = queryText;
      }
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() async {
    if (_focusNode.hasFocus) {
      // Load recent searches
      await ref.read(searchStateProvider.notifier).onFocus();

      // Only show overlay if query is empty
      // When query has any text, the results panel is shown instead
      final queryText = ref.read(searchStateProvider).queryText;
      if (queryText.trim().isEmpty) {
        _overlayController.show();
      }
    }
  }

  /// Hide the overlay
  void _hideOverlay() {
    _overlayController.hide();
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

    // Watch if results panel is visible (query is not empty)
    final isResultsPanelVisible =
        ref.watch(searchStateProvider.select((s) => s.isResultsPanelVisible));

    // Watch exact match state for toggle button
    final exactMatch =
        ref.watch(searchStateProvider.select((s) => s.exactMatch));

    // Listen to queryText changes and sync controller
    ref.listen(searchStateProvider.select((s) => s.queryText), (prev, next) {
      if (_controller.text != next) {
        _controller.text = next;
        // Move cursor to end
        _controller.selection = TextSelection.collapsed(offset: next.length);
      }

      // Hide overlay when query has any text (panel takes over)
      if (next.trim().isNotEmpty && _overlayController.isShowing) {
        _overlayController.hide();
      }
      // Show overlay when query becomes empty and focused
      else if (next.trim().isEmpty && _focusNode.hasFocus) {
        _overlayController.show();
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
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: exactMatch
                            ? theme.colorScheme.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.abc,
                          size: 20,
                          color: exactMatch
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        tooltip: l10n.exactMatchToggle,
                        onPressed: () {
                          ref
                              .read(searchStateProvider.notifier)
                              .toggleExactMatch();
                        },
                      ),
                    ),
                    // Clear button (only shown when text is present)
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          _controller.clear();
                          ref.read(searchStateProvider.notifier).clearSearch();
                          _focusNode.requestFocus();
                        },
                      ),
                  ],
                ),
              ),
              onChanged: (value) {
                ref.read(searchStateProvider.notifier).updateQuery(value);
                setState(() {});
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
