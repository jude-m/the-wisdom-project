import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n/app_localizations.dart';
import '../../providers/in_page_search_focus_provider.dart';
import '../../providers/in_page_search_provider.dart';

/// Chrome-style floating search bar for in-page search.
///
/// Layout: [TextField] [3 of 25] [Up] [Down] [X close]
/// Auto-focuses when opened and restores the previous query.
class InPageSearchBar extends ConsumerStatefulWidget {
  const InPageSearchBar({super.key});

  // Cap the bar's width on tablet/desktop. Wide enough for ~40 chars of query
  // plus the "199 / 1500" counter and the prev/next/close buttons without
  // crowding; narrow enough that it doesn't span the whole reading area.
  // Caller decides whether to enforce this (see multi_pane_reader_widget.dart).
  static const double maxWidthOnLargeScreens = 480.0;

  @override
  ConsumerState<InPageSearchBar> createState() => _InPageSearchBarState();
}

class _InPageSearchBarState extends ConsumerState<InPageSearchBar> {
  final _controller = TextEditingController();

  // Borrowed from inPageSearchFocusNodeProvider, not created here. The provider
  // owns the node's lifecycle (creation + disposal), so this widget never
  // creates, disposes, publishes, or clears it — it just attaches it to the
  // TextField and listens for focus changes. Captured once in initState so
  // dispose() can detach the listener without touching `ref` (using `ref`
  // after teardown throws).
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    // Borrow the session-lived focus node owned by the provider.
    _focusNode = ref.read(inPageSearchFocusNodeProvider);

    // Restore previous query text from state
    final searchState = ref.read(activeInPageSearchStateProvider);
    if (searchState.rawQuery.isNotEmpty) {
      _controller.text = searchState.rawQuery;
    }
    _focusNode.addListener(_onFocusChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Auto-focus the text field when the search bar opens.
      _focusNode.requestFocus();
    });
  }

  void _onFocusChange() {
    if (mounted) setState(() {});

    // Browser address-bar behaviour: when the bar gains focus and already has a
    // query, highlight it all so the next keystroke replaces it. Deferred to a
    // post-frame callback so it runs AFTER a tap places the caret — otherwise
    // that caret placement would collapse the selection.
    if (_focusNode.hasFocus && _controller.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_focusNode.hasFocus) return;
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      });
    }
  }

  @override
  void dispose() {
    // Detach only what we attached. The node itself is owned by
    // inPageSearchFocusNodeProvider, so we neither dispose it nor write to the
    // provider here — which is what previously re-entered Riverpod's scheduler
    // mid-teardown and crashed. We still own (and dispose) the controller.
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(activeInPageSearchStateProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Material(
      elevation: 4,
      color: colorScheme.surface,
      // Border lives on Material.shape; Material disallows passing
      // both `borderRadius` and `shape`.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _focusNode.hasFocus
              ? colorScheme.primary
              : colorScheme.outline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // Search text field
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: l10n.findInPage,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  border: InputBorder.none,
                  // Clear button inside text field
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: () {
                            _controller.clear();
                            ref
                                .read(inPageSearchStatesProvider.notifier)
                                .clearQuery();
                          },
                          tooltip: l10n.clear,
                        )
                      : null,
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
                onChanged: (value) {
                  ref
                      .read(inPageSearchStatesProvider.notifier)
                      .updateQuery(value);
                  // Trigger rebuild so the clear button shows/hides
                  setState(() {});
                },
                onSubmitted: (_) {
                  // Enter key -> go to next match
                  ref.read(inPageSearchStatesProvider.notifier).nextMatch();
                  _focusNode.requestFocus();
                },
              ),
            ),

            // Singlish conversion preview (shows converted text when Singlish detected)
            if (searchState.isSinglishConverted)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  searchState.effectiveQuery,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            // Match count display: "3 of 25"
            if (searchState.rawQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  searchState.hasMatches
                      ? '${searchState.currentMatchIndex + 1} / ${searchState.matchCount}'
                      : l10n.noInPageMatches,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

            // Previous match button
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: searchState.hasMatches
                  ? () => ref
                      .read(inPageSearchStatesProvider.notifier)
                      .previousMatch()
                  : null,
              tooltip: l10n.previousMatch,
            ),

            // Next match button
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: searchState.hasMatches
                  ? () =>
                      ref.read(inPageSearchStatesProvider.notifier).nextMatch()
                  : null,
              tooltip: l10n.nextMatch,
            ),

            // Close button
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () {
                ref.read(inPageSearchStatesProvider.notifier).closeSearch();
              },
              tooltip: l10n.close,
            ),
          ],
        ),
      ),
    );
  }
}
