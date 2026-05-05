import 'package:flutter/foundation.dart';

/// Configuration for the search-results cache.
///
/// Memory budget varies by platform. There is no TTL: the Tipitaka corpus
/// is immutable, so cached results never go stale.
class CacheConfig {
  /// Maximum number of entries each LRUCache can hold before evicting.
  final int maxEntries;

  /// When false, the decorator passes every call straight through to the
  /// underlying repository (no allocation, no key generation).
  final bool enabled;

  const CacheConfig({
    required this.maxEntries,
    required this.enabled,
  });

  /// Builds a configuration sized for the running platform.
  ///
  /// | Platform | Max Entries |
  /// |----------|-------------|
  /// | Mobile   | 20          |
  /// | Web      | 30          |
  /// | Desktop  | 50          |
  ///
  /// Uses [kIsWeb] and [defaultTargetPlatform] from `flutter/foundation.dart`
  /// rather than `dart:io`'s `Platform` so this file compiles cleanly on web.
  factory CacheConfig.forPlatform({bool enabled = true}) {
    if (kIsWeb) {
      return CacheConfig(maxEntries: 30, enabled: enabled);
    }
    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS) {
      // Reduce to 10 if OOM issues surface on older devices.
      return CacheConfig(maxEntries: 20, enabled: enabled);
    }
    // Desktop: macOS, Windows, Linux (and Fuchsia, falls into desktop bucket).
    return CacheConfig(maxEntries: 50, enabled: enabled);
  }

  /// Disabled configuration — every cache call becomes a pass-through.
  factory CacheConfig.disabled() =>
      const CacheConfig(maxEntries: 0, enabled: false);
}
