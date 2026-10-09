import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main_search_focus_provider.dart';
import 'search_provider.dart';

/// Below desktop width: true while the app bar is in search mode (a
/// full-width search field in place of the breadcrumb).
final searchModeProvider = StateProvider<bool>((ref) => false);

/// Closes search: releases the search field, hides the results panel and
/// leaves search mode. The field's back arrow, system back and Esc all use it.
final closeSearchProvider = Provider<void Function()>((ref) {
  return () {
    // Release focus first. A field that keeps focus never re-fires
    // onFocus(), so the panel would stay hidden when the user types again.
    ref.read(mainSearchFocusNodeProvider)?.unfocus();
    ref.read(searchStateProvider.notifier).dismissResultsPanel();
    ref.read(searchModeProvider.notifier).state = false;
  };
});
