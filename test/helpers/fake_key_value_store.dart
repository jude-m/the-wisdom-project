import 'dart:convert';

import 'package:the_wisdom_project/core/storage/key_value_store.dart';

/// In-memory [KeyValueStore] for tests. Mirrors the JSON encode/decode
/// semantics of `SharedPreferencesKeyValueStore` so tests exercise the
/// same parsing paths as production.
class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore([Map<String, Object?>? initial])
      : _store = {...?initial};

  final Map<String, Object?> _store;

  @override
  String? getString(String key) {
    final v = _store[key];
    return v is String ? v : null;
  }

  @override
  Future<void> setString(String key, String value) async {
    _store[key] = value;
  }

  @override
  int? getInt(String key) {
    final v = _store[key];
    return v is int ? v : null;
  }

  @override
  Future<void> setInt(String key, int value) async {
    _store[key] = value;
  }

  @override
  bool? getBool(String key) {
    final v = _store[key];
    return v is bool ? v : null;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    _store[key] = value;
  }

  @override
  Map<String, dynamic>? getJsonObject(String key) {
    final raw = getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      _store.remove(key);
      return null;
    } on FormatException {
      _store.remove(key);
      return null;
    }
  }

  @override
  List<dynamic>? getJsonList(String key) {
    final raw = getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
      _store.remove(key);
      return null;
    } on FormatException {
      _store.remove(key);
      return null;
    }
  }

  @override
  Future<void> setJson(String key, Object value) async {
    _store[key] = jsonEncode(value);
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }
}
