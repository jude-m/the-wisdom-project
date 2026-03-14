/// Single entry point for all integration tests.
///
/// Flutter integration tests launch one app instance per test file.
/// Running multiple files separately causes the app to exit after the first
/// file, breaking subsequent files ("The log reader stopped unexpectedly").
///
/// Import all integration test files here and run with:
///   flutter test integration_test/all_tests.dart -d macos
///
/// Each imported file's main() is called, registering its testWidgets
/// with the framework — they all share a single app launch.
library;

import 'breadcrumb_navigation_test.dart' as breadcrumb;
import 'dictionary_editable_word_test.dart' as dictionary;
import 'dictionary_filter_flow_test.dart' as dictionary_filter;
import 'in_page_search_test.dart' as in_page_search;
import 'previous_sutta_navigation_test.dart' as previous_sutta;
import 'scroll_restoration_test.dart' as scroll_restoration;
import 'search_flow_integration_test.dart' as search_flow;
import 'search_tab_highlight_test.dart' as search_tab_highlight;

void main() {
  breadcrumb.main();
  dictionary.main();
  dictionary_filter.main();
  in_page_search.main();
  previous_sutta.main();
  scroll_restoration.main();
  search_flow.main();
  search_tab_highlight.main();
}
