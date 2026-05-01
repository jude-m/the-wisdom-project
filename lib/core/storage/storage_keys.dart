/// Centralised string constants for keys used in the local KeyValueStore.
///
/// New keys should land here so we have a single place to audit what the
/// app persists. Suffix new keys with `_v1` so a future schema break can
/// move to `_v2` without a migration step (old data is simply ignored).
class StorageKeys {
  const StorageKeys._();

  /// JSON list of [ReaderTab] objects currently open in the reader.
  static const openTabs = 'open_tabs_v1';

  /// Int — the index of the active tab when the app last saved state.
  /// `-1` means "no tab focused".
  static const activeTabIndex = 'active_tab_index_v1';

  /// Bool (stored as int 0/1) — whether the left-hand tree navigator is
  /// visible. Persisted so a reload preserves the user's collapse state.
  static const navigatorVisible = 'navigator_visible_v1';
}
