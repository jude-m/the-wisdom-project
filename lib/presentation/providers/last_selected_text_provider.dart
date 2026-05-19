import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Most recently selected text from any reader `SelectionArea`.
///
/// Written by `ReaderSelectionHandler.onSelectionChanged` whenever the user
/// drag-selects text in a pane. Read by `SmartCopyAction` as the fallback
/// when no focused widget handles `CopySelectionTextIntent` natively —
/// rescues Ctrl+C on web where the focus tree sometimes leaves the
/// `SelectableRegion` unfocused even though there's a visible selection.
///
/// `null` means there's no current selection to copy.
final lastSelectedTextProvider = StateProvider<String?>((ref) => null);
