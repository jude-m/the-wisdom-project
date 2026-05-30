import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/key_value_store.dart';
import '../../core/storage/key_value_store_provider.dart';
import '../../core/storage/storage_keys.dart';
import '../models/reader_layout.dart';

/// Remembers the [ReaderLayout] the user last selected so newly opened tabs
/// can start in that layout ("seed") instead of always using the
/// orientation-based default.
///
/// State is nullable on purpose: `null` means the user has never picked a
/// layout on this device, in which case callers fall back to the orientation
/// default (see `openTabFromNodeKeyProvider` / `openTabFromSearchResultProvider`).
///
/// Persistence is per-device — [KeyValueStore] is backed by SharedPreferences
/// (localStorage on web), which is local to the device/browser origin and not
/// synced across devices.
///
/// Stores the enum's `name` (e.g. `"stacked"`), matching the convention used by
/// `ThemeNotifier` and `NavigationLanguageNotifier`. Writes happen inline on
/// each [set] (no debounce) because layout changes are rare user actions.
class LastReaderLayoutNotifier extends StateNotifier<ReaderLayout?> {
  LastReaderLayoutNotifier(this._store) : super(_load(_store));

  final KeyValueStore _store;

  /// Reads the persisted layout, or null if absent / unrecognized. An unknown
  /// value (e.g. a layout removed in a future version) is treated as "unset"
  /// so we cleanly fall back to the orientation default.
  static ReaderLayout? _load(KeyValueStore store) {
    final saved = store.getString(StorageKeys.lastReaderLayout);
    if (saved == null) return null;
    for (final layout in ReaderLayout.values) {
      if (layout.name == saved) return layout;
    }
    return null;
  }

  /// Records the user's layout choice and persists it (per device).
  void set(ReaderLayout layout) {
    state = layout;
    _store.setString(StorageKeys.lastReaderLayout, layout.name);
  }
}

/// App-wide provider for the last-selected reader layout.
///
/// Uses `ref.read` for [keyValueStoreProvider] (not `watch`) — the store is a
/// service-like singleton overridden once in main.dart and never replaced.
/// The notifier hydrates synchronously in its constructor from the already-
/// initialized store, so the first read (at tab creation or layout change)
/// already reflects what's on disk; no main.dart wiring is required.
final lastReaderLayoutProvider =
    StateNotifierProvider<LastReaderLayoutNotifier, ReaderLayout?>((ref) {
  return LastReaderLayoutNotifier(ref.read(keyValueStoreProvider));
});

/// Resolves the layout a newly opened tab should start in.
///
/// Returns the user's last-selected layout when one is saved; otherwise falls
/// back to the orientation default — [ReaderLayout.stacked] in portrait,
/// [ReaderLayout.sideBySide] in landscape.
///
/// This is the single source of truth for the seed rule shared by every
/// tab-creation path (tree, breadcrumb, search, and commentary/root-text), so
/// the fallback policy only ever lives in one place.
///
/// [isPortraitMode] is passed in by callers (derived from BuildContext via
/// `ResponsiveUtils.shouldDefaultToSingleColumn`) since providers can't read
/// context themselves; it's only consulted when nothing is saved yet.
ReaderLayout resolveSeedLayout(Ref ref, {required bool isPortraitMode}) {
  final saved = ref.read(lastReaderLayoutProvider);
  return saved ??
      (isPortraitMode ? ReaderLayout.stacked : ReaderLayout.sideBySide);
}
