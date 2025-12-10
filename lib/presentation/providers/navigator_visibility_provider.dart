import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for navigator sidebar visibility state
/// True = visible, False = collapsed
final navigatorVisibleProvider = StateProvider<bool>((ref) => true);
