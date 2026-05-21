import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the active reader content is scrolled away from the top.
///
/// Drives the reader screen's app bar "scrolled under" tint. We maintain
/// this explicitly instead of relying on Material 3's built-in scrolled-under
/// detection.
///
/// The built-in detection is driven by `ScrollUpdateNotification`s. All
/// reader tabs share one vertical scroll controller, and switching tabs
/// restores the new tab's saved offset with a `jumpTo`. When that offset is 0
/// and the scroll view was just re-mounted (already at 0), the `jumpTo` is a
/// no-op — no notification fires — so the built-in detection keeps the
/// *previous* tab's tint. Publishing the state through this provider keeps
/// the app bar correct after every tab switch.
///
/// Written by [MultiPaneReaderWidget]; read by the reader screen's `AppBar`.
final readerScrolledUnderProvider = StateProvider<bool>((ref) => false);
