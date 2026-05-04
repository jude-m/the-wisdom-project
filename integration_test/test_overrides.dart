/// Shared Riverpod overrides for integration tests.
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
