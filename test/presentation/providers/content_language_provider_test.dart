import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/storage/key_value_store_provider.dart';
import 'package:the_wisdom_project/core/storage/storage_keys.dart';
import 'package:the_wisdom_project/domain/entities/content/content_language.dart';
import 'package:the_wisdom_project/domain/entities/content/edition.dart';
import 'package:the_wisdom_project/presentation/providers/content_language_provider.dart';

import '../../helpers/fake_key_value_store.dart';

// Test plan 1.4 / 1.5 / 1.6 — the Content Language plumbing:
//   1.4 availableContentLanguagesProvider — edition-driven option set.
//   1.5 effectiveContentLanguageProvider — clamps an unsupported saved choice.
//   1.6 contentLanguageProvider          — persistence + best-effort writes.
void main() {
  // A stub edition for clamping tests — BJT supports both languages, so the
  // only way to exercise "saved choice not offered" is a narrower edition.
  const sinhalaOnlyEdition = Edition(
    editionId: 'stub-si',
    displayName: 'Sinhala Only',
    abbreviation: 'SI',
    type: EditionType.local,
    availableLanguages: ['si'],
  );

  group('availableContentLanguagesProvider (1.4) -', () {
    test('BJT offers [pali, sinhala] in declared order', () {
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(availableContentLanguagesProvider),
        equals(const [ContentLanguage.pali, ContentLanguage.sinhala]),
      );
    });

    test('unsupported ISO codes in an edition are filtered out', () {
      // A future/bad edition list with a junk code must not inject a language.
      const editionWithJunk = Edition(
        editionId: 'stub-junk',
        displayName: 'Junk',
        abbreviation: 'JNK',
        type: EditionType.local,
        availableLanguages: ['pi', 'xx', 'si'],
      );

      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          currentEditionProvider.overrideWithValue(editionWithJunk),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(availableContentLanguagesProvider),
        equals(const [ContentLanguage.pali, ContentLanguage.sinhala]),
      );
    });
  });

  group('effectiveContentLanguageProvider (1.5) -', () {
    test('a supported saved choice passes through unchanged', () {
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(
            InMemoryKeyValueStore({StorageKeys.contentLanguage: 'pali'}),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Pali IS offered by BJT, so effective == the saved raw value.
      expect(
        container.read(effectiveContentLanguageProvider),
        equals(ContentLanguage.pali),
      );
    });

    test('an unsupported saved choice clamps to the edition default', () {
      // Saved = Pali, but this edition only offers Sinhala → effective Sinhala.
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(
            InMemoryKeyValueStore({StorageKeys.contentLanguage: 'pali'}),
          ),
          currentEditionProvider.overrideWithValue(sinhalaOnlyEdition),
        ],
      );
      addTearDown(container.dispose);

      // Raw is still Pali...
      expect(
        container.read(contentLanguageProvider),
        equals(ContentLanguage.pali),
      );
      // ...but the user-facing effective value is clamped to what's offered.
      expect(
        container.read(effectiveContentLanguageProvider),
        equals(ContentLanguage.sinhala),
      );
    });
  });

  group('contentLanguageProvider persistence (1.6) -', () {
    test('setLanguage persists, and a fresh notifier over the same store '
        'restores it (relaunch round-trip)', () async {
      final store = InMemoryKeyValueStore();

      // First "launch": change the language.
      final container1 = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      await container1
          .read(contentLanguageProvider.notifier)
          .setLanguage(ContentLanguage.pali);

      // It was written under the documented key, as the enum name.
      expect(store.getString(StorageKeys.contentLanguage), equals('pali'));
      container1.dispose();

      // Second "launch" over the SAME store: state hydrates from disk.
      final container2 = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container2.dispose);

      expect(
        container2.read(contentLanguageProvider),
        equals(ContentLanguage.pali),
      );
    });

    test('a failing store write does not throw and state still flips '
        '(best-effort persistence)', () async {
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(_ThrowingStore()),
        ],
      );
      addTearDown(container.dispose);

      // Must complete normally — the rejected write is swallowed + logged.
      await container
          .read(contentLanguageProvider.notifier)
          .setLanguage(ContentLanguage.pali);

      // The in-memory state reflects the choice even though the write failed.
      expect(
        container.read(contentLanguageProvider),
        equals(ContentLanguage.pali),
      );
    });
  });
}

/// A store whose writes always fail — used to prove best-effort persistence.
/// getString returns null so the initial load is the Sinhala default.
class _ThrowingStore extends InMemoryKeyValueStore {
  @override
  Future<void> setString(String key, String value) async {
    throw Exception('simulated storage failure');
  }
}
