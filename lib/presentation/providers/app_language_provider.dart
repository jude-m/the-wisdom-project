import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_language.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/storage/key_value_store_provider.dart';
import '../../core/storage/storage_keys.dart';

/// The device/platform's *ordered* preferred locales, isolated behind a
/// provider so tests can override it (and so we don't touch `WidgetsBinding`
/// from inside the notifier). The order matters — index 0 is the user's top
/// choice — so we resolve over the whole list the way Flutter does, rather
/// than looking at the primary locale alone.
final deviceLocalesProvider = Provider<List<Locale>>(
  (ref) => WidgetsBinding.instance.platformDispatcher.locales,
);

/// The user's chosen UI language ("App Language").
///
/// Defaults to the device locale and is only persisted once the user explicitly
/// changes it — so "no saved value" keeps tracking the device. Drives
/// `MaterialApp.locale`.
final appLanguageProvider =
    StateNotifierProvider<AppLanguageNotifier, AppLanguage>((ref) {
  return AppLanguageNotifier(
    store: ref.watch(keyValueStoreProvider),
    deviceLocales: ref.watch(deviceLocalesProvider),
  );
});

/// Manages the App Language preference with persistence.
class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  AppLanguageNotifier({
    required KeyValueStore store,
    required List<Locale> deviceLocales,
  })  : _store = store,
        super(
          // A previously saved choice always wins; otherwise resolve the
          // device's ordered locale list the way Flutter would.
          AppLanguage.fromStorage(store.getString(StorageKeys.appLanguage)) ??
              AppLanguage.fromLocales(deviceLocales),
        );

  final KeyValueStore _store;

  /// Updates the language and persists it. Persisting only happens here (on an
  /// explicit user action), never for the device-derived default.
  ///
  /// Best-effort persistence: [state] already updated, so a failed write must
  /// not surface as an unhandled async error (call sites don't await this).
  Future<void> setLanguage(AppLanguage language) async {
    if (state == language) return;
    state = language;
    try {
      await _store.setString(StorageKeys.appLanguage, language.name);
    } catch (e) {
      debugPrint('Failed to save app language: $e');
    }
  }
}
