import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/key_value_store.dart';
import '../../core/storage/key_value_store_provider.dart';
import '../../core/storage/storage_keys.dart';
import '../../domain/entities/research/research_mode.dart';

/// Remembers the [ResearchMode] (Fast / Thinking) the user last picked for the
/// Research section, so every question — and a restart — keeps that choice.
///
/// The mode is **global**, not per-chat: one setting across all chats, which
/// keeps the multi-chat storage scheme untouched (no per-transcript field).
/// [ResearchChatNotifier] reads it at send time and passes it to the backend.
///
/// Persistence is per-device via [KeyValueStore] (SharedPreferences /
/// localStorage). Stores the enum's `name` (e.g. `"thinking"`), matching
/// [LastReaderLayoutNotifier] and the theme/language notifiers.
class ResearchModeNotifier extends StateNotifier<ResearchMode> {
  ResearchModeNotifier(this._store) : super(_load(_store));

  final KeyValueStore _store;

  /// Reads the saved mode, defaulting to [ResearchMode.fast] when absent or
  /// unrecognized (an unknown value — e.g. a mode removed in a later version —
  /// degrades cleanly to the fast default rather than throwing).
  static ResearchMode _load(KeyValueStore store) {
    final saved = store.getString(StorageKeys.researchMode);
    for (final mode in ResearchMode.values) {
      if (mode.name == saved) return mode;
    }
    return ResearchMode.fast;
  }

  /// Records the user's choice and persists it (per device). No-op if unchanged
  /// so we don't churn a write on every menu open.
  void set(ResearchMode mode) {
    if (mode == state) return;
    state = mode;
    _store.setString(StorageKeys.researchMode, mode.name);
  }
}

/// App-wide provider for the Research Fast/Thinking mode.
///
/// Uses `ref.read` for [keyValueStoreProvider] (a singleton overridden once in
/// main.dart) and hydrates synchronously in the constructor, so the first read
/// already reflects what's on disk — no main.dart wiring required.
final researchModeProvider =
    StateNotifierProvider<ResearchModeNotifier, ResearchMode>((ref) {
  return ResearchModeNotifier(ref.read(keyValueStoreProvider));
});
