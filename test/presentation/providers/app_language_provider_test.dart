import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/localization/app_language.dart';
import 'package:the_wisdom_project/core/storage/key_value_store_provider.dart';
import 'package:the_wisdom_project/core/storage/storage_keys.dart';
import 'package:the_wisdom_project/presentation/providers/app_language_provider.dart';

import '../../helpers/fake_key_value_store.dart';

// Test plan 1.7 — App Language defaulting & persistence. The subtle rule: with
// no saved value the app *tracks* the device locale, and that device-derived
// default must NOT be written to storage — only an explicit user choice is
// persisted (otherwise we'd freeze the language on first launch).
void main() {
  // Helper: build a container with a given device locale list and store.
  ProviderContainer makeContainer({
    required List<Locale> deviceLocales,
    InMemoryKeyValueStore? store,
  }) {
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store ?? InMemoryKeyValueStore()),
        deviceLocalesProvider.overrideWithValue(deviceLocales),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('appLanguageProvider defaulting (1.7) -', () {
    test('no saved value → derives from the device locale (si)', () {
      final container = makeContainer(deviceLocales: const [Locale('si')]);

      expect(container.read(appLanguageProvider), equals(AppLanguage.sinhala));
    });

    // Only one device-derived case is needed here: this layer proves the
    // provider *delegates* to the device locale. The en/si correctness of that
    // resolution is owned by `AppLanguage.fromLocales` in app_language_test.dart
    // (1.2) — re-testing both locales here would re-litigate that seam.
    test('a saved value wins over the device locale', () {
      // Device says Sinhala, but the user previously chose English.
      final store =
          InMemoryKeyValueStore({StorageKeys.appLanguage: 'english'});
      final container =
          makeContainer(deviceLocales: const [Locale('si')], store: store);

      expect(container.read(appLanguageProvider), equals(AppLanguage.english));
    });
  });

  group('appLanguageProvider persistence (1.7) -', () {
    test('the device-derived default is NOT persisted', () {
      final store = InMemoryKeyValueStore();
      final container =
          makeContainer(deviceLocales: const [Locale('si')], store: store);

      // Reading resolves to Sinhala from the device...
      expect(container.read(appLanguageProvider), equals(AppLanguage.sinhala));
      // ...but nothing was written — we're only tracking the device.
      expect(store.getString(StorageKeys.appLanguage), isNull);
    });

    test('an explicit setLanguage persists the choice', () async {
      final store = InMemoryKeyValueStore();
      final container =
          makeContainer(deviceLocales: const [Locale('si')], store: store);

      await container
          .read(appLanguageProvider.notifier)
          .setLanguage(AppLanguage.english);

      expect(container.read(appLanguageProvider), equals(AppLanguage.english));
      expect(store.getString(StorageKeys.appLanguage), equals('english'));
    });
  });
}
