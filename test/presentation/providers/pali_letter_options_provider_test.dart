import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/storage/key_value_store_provider.dart';
import 'package:the_wisdom_project/core/storage/storage_keys.dart';
import 'package:the_wisdom_project/core/utils/pali_letter_options.dart';
import 'package:the_wisdom_project/presentation/providers/pali_letter_options_provider.dart';

import '../../helpers/fake_key_value_store.dart';

// Test plan §File 2 — Pali Letter Options provider plumbing:
//   1. Defaults  — empty store → paliLetterOptionsProvider == PaliLetterOptions.defaults
//   2. Relaunch round-trip  — flip specialConjuncts, dispose, new container
//                             over the same store → value restored
//   3. Best-effort write    — a store whose setBool throws → set() completes,
//                             state still flips (swallowed + logged, not rethrown)
//   4. Value equality       — equal flags ⇒ == and same hashCode;
//                             defaults != baseline (de-dupes no-op rebuilds)
void main() {
  // ---------------------------------------------------------------------------
  // 1. Defaults
  // ---------------------------------------------------------------------------
  //
  // With nothing in the store every BoolSettingNotifier falls back to its
  // declared default: standardLigatures=true, specialConjuncts=false, touching=true.
  // The combined paliLetterOptionsProvider must therefore equal PaliLetterOptions.defaults.
  group('Defaults (empty store) -', () {
    test('paliLetterOptionsProvider equals PaliLetterOptions.defaults', () {
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(paliLetterOptionsProvider),
        equals(PaliLetterOptions.defaults),
      );
    });

    test('individual providers reflect their declared defaults', () {
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        ],
      );
      addTearDown(container.dispose);

      // S3 on, S2 off, S1 on — per PaliLetterOptions.defaults docs.
      expect(container.read(standardLigaturesProvider), isTrue);
      expect(container.read(specialConjunctsProvider), isFalse);
      expect(container.read(touchingProvider), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Relaunch round-trip
  // ---------------------------------------------------------------------------
  //
  // Flip specialConjuncts via its notifier, assert the write landed under the
  // documented key, dispose the container (simulates app shutdown), then spin up
  // a fresh container over the SAME in-memory store — the value must be restored.
  group('Relaunch round-trip -', () {
    test('specialConjuncts persists and is restored across container restart',
        () async {
      final store = InMemoryKeyValueStore();

      // First "launch": set specialConjuncts to true.
      final container1 = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      await container1
          .read(specialConjunctsProvider.notifier)
          .set(true);

      // Assert the value was written under the documented storage key.
      expect(store.getBool(StorageKeys.paliSpecialConjuncts), isTrue);
      container1.dispose();

      // Second "launch" over the SAME store: state must hydrate from disk.
      final container2 = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container2.dispose);

      expect(container2.read(specialConjunctsProvider), isTrue);

      // The combined provider must also reflect the restored specialConjuncts flag.
      expect(
        container2.read(paliLetterOptionsProvider),
        equals(const PaliLetterOptions(
          standardLigatures: true,
          specialConjuncts: true,
          touching: true,
        )),
      );
    });

    test('standardLigatures persists under its declared key', () async {
      final store = InMemoryKeyValueStore();

      final container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      await container.read(standardLigaturesProvider.notifier).set(false);

      expect(store.getBool(StorageKeys.paliStandardLigatures), isFalse);
      container.dispose();

      final container2 = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container2.dispose);

      expect(container2.read(standardLigaturesProvider), isFalse);
    });

    test('touching persists under its declared key', () async {
      final store = InMemoryKeyValueStore();

      final container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      await container.read(touchingProvider.notifier).set(false);

      expect(store.getBool(StorageKeys.paliTouching), isFalse);
      container.dispose();

      final container2 = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container2.dispose);

      expect(container2.read(touchingProvider), isFalse);
    });

    test('set() is a no-op when the value is unchanged (state stays stable)',
        () async {
      final store = InMemoryKeyValueStore();

      final container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      // specialConjuncts starts false (default). Calling set(false) must not write.
      await container.read(specialConjunctsProvider.notifier).set(false);

      // The key should still be absent (no write occurred).
      expect(store.getBool(StorageKeys.paliSpecialConjuncts), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Best-effort write
  // ---------------------------------------------------------------------------
  //
  // A store whose setBool throws must not propagate the error to the caller.
  // The in-memory state must still flip (UI stays responsive even if disk fails).
  group('Best-effort write -', () {
    test('set() completes normally when the store write throws', () async {
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(_ThrowingBoolStore()),
        ],
      );
      addTearDown(container.dispose);

      // Must not throw, even though _ThrowingBoolStore.setBool throws.
      await expectLater(
        container.read(specialConjunctsProvider.notifier).set(true),
        completes,
      );
    });

    test('state flips despite the failed write', () async {
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(_ThrowingBoolStore()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(specialConjunctsProvider.notifier).set(true);

      // The in-memory state reflects the change even though the write failed.
      expect(container.read(specialConjunctsProvider), isTrue);

      // The combined provider also reflects the change.
      expect(container.read(paliLetterOptionsProvider).specialConjuncts, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Value equality
  // ---------------------------------------------------------------------------
  //
  // PaliLetterOptions.== is hand-written (not Freezed), so we pin it here.
  // Equal flags must produce == and equal hashCodes so the combined provider can
  // de-duplicate no-op rebuilds across every text-rendering surface.
  group('PaliLetterOptions value equality -', () {
    test('two instances with equal flags are == and share hashCode', () {
      const a = PaliLetterOptions(
        standardLigatures: true,
        specialConjuncts: false,
        touching: true,
      );
      const b = PaliLetterOptions(
        standardLigatures: true,
        specialConjuncts: false,
        touching: true,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('defaults and baseline are not equal', () {
      // Ensures the equality implementation distinguishes the two canonical singletons.
      expect(PaliLetterOptions.defaults, isNot(equals(PaliLetterOptions.baseline)));
    });

    test('any flag difference breaks equality', () {
      const base = PaliLetterOptions(
        standardLigatures: true,
        specialConjuncts: false,
        touching: true,
      );

      expect(
        base,
        isNot(equals(const PaliLetterOptions(
          standardLigatures: false, // flipped
          specialConjuncts: false,
          touching: true,
        ))),
      );
      expect(
        base,
        isNot(equals(const PaliLetterOptions(
          standardLigatures: true,
          specialConjuncts: true, // flipped
          touching: true,
        ))),
      );
      expect(
        base,
        isNot(equals(const PaliLetterOptions(
          standardLigatures: true,
          specialConjuncts: false,
          touching: false, // flipped
        ))),
      );
    });
  });
}

/// A store whose setBool always fails — proves best-effort persistence.
/// getBool returns null so every notifier starts at its declared fallback.
class _ThrowingBoolStore extends InMemoryKeyValueStore {
  @override
  Future<void> setBool(String key, bool value) async {
    throw Exception('simulated setBool storage failure');
  }
}
