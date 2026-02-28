import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/dictionary_provider.dart'
    show
        selectedDictionaryWordProvider,
        dictionaryHighlightProvider,
        hasActiveSelectionProvider;

/// Mixin that handles text selection and context menu in the reader.
///
/// Provides:
/// - [onSelectionChanged] — tracks selected text, manages selection state
/// - [buildSelectionContextMenu] — builds Copy/More context menu
/// - [currentSelectedText] — the currently selected text (if any)
mixin ReaderSelectionHandler<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// Tracks the currently selected text for the context menu.
  /// Updated via [onSelectionChanged] callback.
  /// Internal to the mixin — not intended for use outside the reader.
  @protected
  String? currentSelectedText;

  /// Handles text selection changes.
  /// - Stores selected text for copy functionality
  /// - Clears dictionary highlight and hides bottom sheet to prevent visual conflict
  /// - Tracks selection state to prevent dictionary from opening during selection gestures
  void onSelectionChanged(SelectedContent? selection) {
    if (selection != null && selection.plainText.isNotEmpty) {
      // Store selected text for the copy action
      currentSelectedText = selection.plainText;
      // Mark that selection is active - prevents dictionary from opening on taps
      ref.read(hasActiveSelectionProvider.notifier).state = true;
      // Clear dictionary highlight when user starts selecting text
      ref.read(dictionaryHighlightProvider.notifier).state = null;
      // Hide dictionary bottom sheet when selection starts
      ref.read(selectedDictionaryWordProvider.notifier).state = null;
    } else {
      currentSelectedText = null;
      // Use post-frame callback to clear selection state AFTER tap handlers run.
      // This allows tap handler to see hasActiveSelection=true and skip dictionary,
      // then this callback clears it for subsequent taps.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(hasActiveSelectionProvider.notifier).state = false;
        }
      });
    }
  }

  /// Builds the custom context menu for text selection.
  /// Provides "Copy" (functional) and "More" (UI placeholder) actions.
  /// Returns empty widget if no text is selected (e.g., long-press on empty space).
  Widget buildSelectionContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    // Don't show context menu if nothing is selected
    if (currentSelectedText == null || currentSelectedText!.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<ContextMenuButtonItem> buttonItems = [
      // Copy button - copies selected text to clipboard
      ContextMenuButtonItem(
        label: 'Copy',
        onPressed: () {
          // Copy the currently selected text to clipboard
          if (currentSelectedText != null &&
              currentSelectedText!.isNotEmpty) {
            Clipboard.setData(ClipboardData(text: currentSelectedText!));
          }
          // Hide the context menu and clear selection
          selectableRegionState.hideToolbar();
        },
      ),
      // More button - UI placeholder for future features (Highlight, Share, etc.)
      ContextMenuButtonItem(
        label: 'More',
        onPressed: () {
          // TODO: Implement more options (Highlight, Share, etc.)
          // For now, just hide the menu
          selectableRegionState.hideToolbar();
          // Show a snackbar as placeholder feedback
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('More options coming soon'),
              duration: Duration(seconds: 1),
            ),
          );
        },
      ),
    ];

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }
}
