import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/key_value_store_provider.dart';
import '../../core/storage/storage_keys.dart';

/// Provider for navigator sidebar visibility state.
/// True = visible, False = collapsed.
///
/// Initial value hydrates from the [keyValueStoreProvider] so a reload
/// preserves the user's collapse state. Defaults to `true` when there's
/// nothing on disk yet (first launch). Stored as int 0/1 because the
/// underlying [KeyValueStore] doesn't expose a typed bool helper.
final navigatorVisibleProvider = StateProvider<bool>((ref) {
  final store = ref.read(keyValueStoreProvider);
  final stored = store.getInt(StorageKeys.navigatorVisible);
  if (stored == null) return true;
  return stored != 0;
});

/// Listens to [navigatorVisibleProvider] and writes every change to disk.
///
/// Must be instantiated once at app start (read it from main.dart) so the
/// listener is alive for the whole session. Save is fire-and-forget — the
/// underlying SharedPreferences write is fast and a missed write only
/// costs the user one stale toggle on the next launch.
///
/// Synchronous back-to-back changes (e.g. brief flip during UI plumbing)
/// are coalesced via a zero-duration timer so only the final value hits
/// disk per microtask batch.
final navigatorVisiblePersistenceProvider = Provider<void>((ref) {
  Timer? debounce;
  ref.listen<bool>(navigatorVisibleProvider, (_, next) {
    debounce?.cancel();
    debounce = Timer(Duration.zero, () {
      ref
          .read(keyValueStoreProvider)
          .setInt(StorageKeys.navigatorVisible, next ? 1 : 0);
    });
  });
  ref.onDispose(() => debounce?.cancel());
});
