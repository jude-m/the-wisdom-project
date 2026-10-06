import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/search_query_utils.dart';

/// [singlishPreviewText] for one raw query, computed once per query string.
///
/// The conversion is costly, and the search boxes and the recent list rebuild
/// far more often than the query changes.
final singlishPreviewProvider = Provider.autoDispose.family<String?, String>(
  (ref, rawQuery) => singlishPreviewText(rawQuery),
);
