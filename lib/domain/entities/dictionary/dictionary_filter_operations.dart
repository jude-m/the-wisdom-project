import 'package:flutter/foundation.dart';

import 'dictionary_info.dart';

/// Pure-function operations for dictionary filter state.
///
/// Mirrors [ScopeOperations] pattern: both quick filter chips and the
/// refine dialog share a single `Set<String>` of dictionary IDs as the
/// source of truth.
///
/// Convention: empty set = "All" (no filter applied).
class DictionaryFilterOperations {
  DictionaryFilterOperations._();

  /// Sinhala dictionary IDs, derived from [DictionaryInfo.all].
  static final Set<String> sinhalaIds = DictionaryInfo.all.entries
      .where((e) => e.value.targetLanguage == 'si')
      .map((e) => e.key)
      .toSet();

  /// English dictionary IDs, derived from [DictionaryInfo.all].
  static final Set<String> englishIds = DictionaryInfo.all.entries
      .where((e) => e.value.targetLanguage == 'en')
      .map((e) => e.key)
      .toSet();

  /// All dictionary IDs.
  static final Set<String> allIds = DictionaryInfo.all.keys.toSet();

  /// Chip groupings: each set represents one quick filter chip's dictionary IDs.
  static final List<Set<String>> chipKeyGroups = [sinhalaIds, englishIds];

  /// Whether "All" is effectively selected (empty set = no filter).
  static bool isAllSelected(Set<String> ids) => ids.isEmpty;

  /// Normalize: if all dictionaries are selected, collapse to empty set ("All").
  static Set<String> normalize(Set<String> ids) =>
      ids.length >= allIds.length && ids.containsAll(allIds) ? const {} : ids;

  /// Whether [ids] contains all keys in [keys].
  /// Used to detect if a quick chip is selected.
  static bool containsAllKeys(Set<String> ids, Set<String> keys) =>
      ids.isNotEmpty && keys.every(ids.contains);

  /// Whether the selection is a custom (non-chip) selection that the
  /// quick filter chips cannot represent — i.e. the Refine chip should
  /// highlight.
  static bool hasCustomSelections(Set<String> ids) {
    if (ids.isEmpty) return false;
    // Check if the selection exactly matches any chip group
    for (final group in chipKeyGroups) {
      if (setEquals(ids, group)) return false;
    }
    return true;
  }

  /// Toggle a group of keys in/out of the current selection.
  ///
  /// - If all [keysToToggle] are already in [current]: removes them
  /// - Otherwise: adds them all
  /// - Auto-normalizes (all selected → empty = "All")
  static Set<String> toggleKeys(
    Set<String> current,
    Set<String> keysToToggle,
  ) {
    final Set<String> result;
    if (keysToToggle.every(current.contains)) {
      // All keys present → remove them
      result = {...current}..removeAll(keysToToggle);
    } else {
      // Some missing → add all
      result = {...current}..addAll(keysToToggle);
    }
    return normalize(result);
  }
}
