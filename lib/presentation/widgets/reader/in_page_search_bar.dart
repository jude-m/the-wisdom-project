import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n/app_localizations.dart';
import '../../providers/in_page_search_provider.dart';

/// Chrome-style floating search bar for in-page search.
///
/// Layout: [TextField] [3 of 25] [Up] [Down] [X close]
/// Auto-focuses when opened and restores the previous query.
class InPageSearchBar extends ConsumerStatefulWidget {
  const InPageSearchBar({super.key});

  @override
  ConsumerState<InPageSearchBar> createState() => _InPageSearchBarState();
}

class _InPageSearchBarState extends ConsumerState<InPageSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Restore previous query text from state
    final searchState = ref.read(activeInPageSearchStateProvider);
    if (searchState.rawQuery.isNotEmpty) {
      _controller.text = searchState.rawQuery;
    }
    // Auto-focus the text field when search bar opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(activeInPageSearchStateProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: colorScheme.surfaceContainerHigh,
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
