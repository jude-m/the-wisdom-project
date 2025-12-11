import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../providers/search_provider.dart';
import '../screens/search_results_screen.dart';
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
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      ref.read(searchStateProvider.notifier).onFocus();
      _overlayController.show();
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

    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (context) => Stack(
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
              onDismiss: _closeAndClear,
              onResultTap: (result) {
                _hideOverlay();
                widget.onResultTap?.call(result);
              },
            ),
          ),
        ],
      ),
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
                hintText: l10n?.searchHint ?? 'Search',
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
                  _hideOverlay(); // Don't clear state - SearchResultsScreen needs it
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SearchResultsScreen(onResultTap: widget.onResultTap),
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
