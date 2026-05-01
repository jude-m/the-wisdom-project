/// Generic key/value persistence interface used by repositories that need
/// simple local storage. Backed by SharedPreferences in production
/// (works on web via localStorage and on all native platforms).
///
/// Keep the surface small — this is intentionally not a full database
/// abstraction. Add typed convenience helpers (getJson/setJson, etc.) as
/// they become useful, but resist turning this into a query layer.
abstract class KeyValueStore {
  /// Read a raw string for [key], or null if absent.
  String? getString(String key);

  /// Write a raw string for [key].
  Future<void> setString(String key, String value);

  /// Read an int for [key], or null if absent / wrong type.
  int? getInt(String key);

  /// Write an int for [key].
  Future<void> setInt(String key, int value);

  /// Decode a JSON object stored under [key].
  /// Returns null if the key is absent or the stored value can't be parsed
  /// as a JSON object. On parse failure, the corrupted entry is removed
  /// (best-effort) so the next read starts clean.
  Map<String, dynamic>? getJsonObject(String key);

  /// Decode a JSON array stored under [key].
  /// Same null/cleanup semantics as [getJsonObject].
  List<dynamic>? getJsonList(String key);

  /// Encode [value] (any jsonEncode-compatible structure) and store it
  /// under [key].
  Future<void> setJson(String key, Object value);

  /// Remove the entry for [key].
  Future<void> remove(String key);
}
