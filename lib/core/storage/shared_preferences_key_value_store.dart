import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'key_value_store.dart';

/// SharedPreferences-backed [KeyValueStore].
///
/// Works on every platform Flutter supports (web uses localStorage under
/// the hood). The wrapped [SharedPreferences] instance is expected to
/// already be initialized — we hand it in from main.dart so the rest of
/// the app stays synchronous on read.
class SharedPreferencesKeyValueStore implements KeyValueStore {
  SharedPreferencesKeyValueStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  int? getInt(String key) => _prefs.getInt(key);

  @override
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  @override
  Map<String, dynamic>? getJsonObject(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      // Wrong shape — clear so we don't keep failing on the same garbage.
      _prefs.remove(key);
      return null;
    } on FormatException {
      _prefs.remove(key);
      return null;
    }
  }

  @override
  List<dynamic>? getJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
      _prefs.remove(key);
      return null;
    } on FormatException {
      _prefs.remove(key);
      return null;
    }
  }

  @override
  Future<void> setJson(String key, Object value) =>
      _prefs.setString(key, jsonEncode(value));

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}
