import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/storage/key_value_store_provider.dart';
import '../../core/storage/storage_keys.dart';
import '../../core/utils/pali_letter_options.dart';

/// A single persisted boolean setting backed by [KeyValueStore].
///
/// Loads synchronously in its constructor (the store is ready by provider build
/// time) and persists best-effort: [state] changes immediately so the UI
/// updates even if the write fails (e.g. storage quota on web); we swallow + log
/// rather than let a rejected Future escape as an unhandled async error. Same
/// shape as `ContentLanguageNotifier`.
class BoolSettingNotifier extends StateNotifier<bool> {
  BoolSettingNotifier(this._store, this._key, {required bool fallback})
      : super(_store.getBool(_key) ?? fallback);

  final KeyValueStore _store;
  final String _key;

  /// Sets the value and persists it. No-op when unchanged.
  Future<void> set(bool value) async {
    if (state == value) return;
    state = value;
    try {
      await _store.setBool(_key, value);
    } catch (e) {
      debugPrint('Failed to save $_key: $e');
    }
  }

  /// Flips the value — used by the settings switches.
  Future<void> toggle() => set(!state);
}

/// Switch 3 — standard ligatures (rakaransaya + yansaya + repaya + common 8).
/// Default ON.
final standardLigaturesProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
  return BoolSettingNotifier(
    ref.watch(keyValueStoreProvider),
    StorageKeys.paliStandardLigatures,
    fallback: true,
  );
});

/// Switch 2 — special / rare old-Pali ligatures (7). Default OFF.
final specialConjunctsProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
  return BoolSettingNotifier(
    ref.watch(keyValueStoreProvider),
    StorageKeys.paliSpecialConjuncts,
    fallback: false,
  );
});

/// Switch 1 — touching + vowel shortening. Default ON.
final touchingProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
  return BoolSettingNotifier(
    ref.watch(keyValueStoreProvider),
    StorageKeys.paliTouching,
    fallback: true,
  );
});

/// The combined options every text-rendering seam watches. Rebuilds (and
/// re-renders all those surfaces) the instant any one switch flips. Value
/// equality on [PaliLetterOptions] de-dupes no-op rebuilds.
final paliLetterOptionsProvider = Provider<PaliLetterOptions>((ref) {
  return PaliLetterOptions(
    standardLigatures: ref.watch(standardLigaturesProvider),
    specialConjuncts: ref.watch(specialConjunctsProvider),
    touching: ref.watch(touchingProvider),
  );
});
