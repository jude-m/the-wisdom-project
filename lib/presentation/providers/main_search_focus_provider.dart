import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the `FocusNode` belonging to the main FTS search bar in the app bar.
///
/// `SearchBar` registers its node here in `initState` and clears it in
/// `dispose`. `OpenMainSearchAction` reads the node and calls
/// `requestFocus()` so Ctrl/Cmd+Shift+F always jumps focus to the search
/// bar — even from inside another text field.
///
/// `null` while no search bar is mounted (e.g. before first build).
final mainSearchFocusNodeProvider = StateProvider<FocusNode?>((ref) => null);
