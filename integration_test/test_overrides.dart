/// Shared Riverpod overrides and pump helpers for integration tests.
///
/// The reader-side providers (tabs, active tab index, navigator visibility)
/// hydrate from [KeyValueStore] on construction and throw if no override is
/// provided — main.dart wires the production SharedPreferences-backed
/// implementation. Tests need a quick stand-in so they don't have to spin up
/// SharedPreferences just to satisfy a hydration call.
///
/// [InMemoryKeyValueStore] stores everything in a single map. Each test that
/// uses [keyValueStoreOverride] gets a fresh instance, so state never leaks
/// between tests.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/storage/key_value_store.dart';
import 'package:the_wisdom_project/core/storage/key_value_store_provider.dart';

class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, Object> _values = {};

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  int? getInt(String key) => _values[key] as int?;

  @override
  Future<void> setInt(String key, int value) async {
    _values[key] = value;
  }

  @override
  Map<String, dynamic>? getJsonObject(String key) {
    final raw = _values[key] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      // Wrong shape — drop it so we mirror production's self-heal behaviour
      // and don't keep failing on the same garbage.
      _values.remove(key);
      return null;
    } on FormatException {
      _values.remove(key);
      return null;
    }
  }

  @override
  List<dynamic>? getJsonList(String key) {
    final raw = _values[key] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
      _values.remove(key);
      return null;
    } on FormatException {
      _values.remove(key);
      return null;
    }
  }

  @override
  Future<void> setJson(String key, Object value) async {
    _values[key] = jsonEncode(value);
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}

/// Returns a fresh [keyValueStoreProvider] override backed by an in-memory
/// store. Add this to the `overrides` list of any [ProviderScope] that builds
/// widgets transitively touching tabs / navigator visibility.
Override keyValueStoreOverride() => keyValueStoreProvider.overrideWithValue(
      InMemoryKeyValueStore(),
    );

/// How long [pumpForSettle] waits before giving up. Comfortably longer than the
/// ~10-second database-lock window we observe in the combined suite — so a
/// transient lock still lets the test finish and PASS — but far shorter than
/// pumpAndSettle's 10-minute default that otherwise hangs the whole run.
const _settleTimeout = Duration(seconds: 15);

/// A bounded, non-throwing stand-in for [WidgetTester.pumpAndSettle].
///
/// `pumpAndSettle` pumps frames until the framework stops scheduling them, but
/// THROWS if frames are still scheduled after its timeout (10 minutes by
/// default). In this integration suite, when the shared SQLite database is
/// under contention, a perpetual [CircularProgressIndicator] (the dictionary
/// sheet's loading state) or the reader's self-rescheduling page-load loop can
/// keep scheduling frames indefinitely — so the real `pumpAndSettle` hangs for
/// the full 10 minutes and then fails the run with a confusing
/// "pumpAndSettle timed out".
///
/// This wrapper behaves IDENTICALLY to `pumpAndSettle` when the tree settles
/// normally: it forwards [step] unchanged, so debounce timers (e.g. the
/// dictionary edit's 300 ms debounce, crossed by a 1-second step) still fire.
/// It only differs in the stuck case — it caps the wait at [_settleTimeout]
/// and SWALLOWS the timeout instead of throwing. Tests assert on
/// provider/widget state immediately afterwards, so a genuine stall surfaces
/// as a fast, readable assertion failure rather than a 10-minute hang.
///
/// Pass [step] exactly as you would the first positional argument to
/// `pumpAndSettle` (defaults to 100 ms, matching `pumpAndSettle`'s default).
Future<void> pumpForSettle(
  WidgetTester tester, [
  Duration step = const Duration(milliseconds: 100),
]) async {
  try {
    await tester.pumpAndSettle(
      step,
      EnginePhase.sendSemanticsUpdate,
      _settleTimeout,
    );
  } on FlutterError catch (error) {
    // Only swallow the settle timeout. Real build/layout errors are also
    // FlutterErrors, so rethrow anything that isn't the timeout — otherwise we
    // would hide genuine failures.
    if (!error.message.contains('pumpAndSettle timed out')) rethrow;
  }
}
