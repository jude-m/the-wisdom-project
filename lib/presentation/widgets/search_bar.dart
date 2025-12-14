import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../providers/search_provider.dart';
import '../providers/search_mode.dart';
import '../../domain/entities/search/search_result.dart';
import 'search_overlay.dart';

/// Simple search bar for AppBar with dropdown overlay
class SearchBar extends ConsumerStatefulWidget {
  final void Function(SearchResult result)? onResultTap;
  final double width;

  const SearchBar({
    super.key,
    this.onResultTap,
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
      // Call onFocus and get the resulting mode
      final mode = await ref.read(searchStateProvider.notifier).onFocus();

      // Only show overlay if NOT going to fullResults mode
      // (fullResults mode will show the side panel instead via ReaderScreen)
      if (mode != SearchMode.fullResults) {
        _overlayController.show();
      }
    }
  }

  /// Hide the overlay without clearing search state (for navigation)
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

    // Watch search mode to decide if overlay should render
    final searchMode = ref.watch(searchStateProvider.select((s) => s.mode));

    // Listen to queryText changes and sync controller
    ref.listen(searchStateProvider.select((s) => s.queryText), (prev, next) {
      if (_controller.text != next) {
        _controller.text = next;
        // Move cursor to end
        _controller.selection = TextSelection.collapsed(offset: next.length);
      }
    });

    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (context) {
        // Don't render overlay when in fullResults mode (panel is shown instead)
        // This ensures overlay and panel are decoupled
        if (searchMode == SearchMode.fullResults) {
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
              child: SearchOverlayContent(
                onDismiss: _hideOverlay,
                onResultTap: (result) {
                  _hideOverlay();
                  widget.onResultTap?.call(result);
                },
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
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant),
                        onPressed: () {
                          _controller.clear();
                          ref.read(searchStateProvider.notifier).clearSearch();
                          _focusNode.requestFocus();
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                ref.read(searchStateProvider.notifier).updateQuery(value);
                setState(() {});
              },
              onSubmitted: (value) {
                if (value.trim().length >= 2) {
                  ref.read(searchStateProvider.notifier).submitQuery();
                  _hideOverlay();
                  // Panel opens automatically via ReaderScreen watching searchStateProvider
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
