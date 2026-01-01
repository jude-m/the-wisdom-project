import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';

/// Provider for Navigator pane width (left sidebar)
final navigatorWidthProvider = StateProvider<double>((ref) {
  return PaneWidthConstants.navigatorDefault;
});

/// Provider for Search Results panel width (right overlay)
final searchPanelWidthProvider = StateProvider<double>((ref) {
  return PaneWidthConstants.searchDefault;
});
