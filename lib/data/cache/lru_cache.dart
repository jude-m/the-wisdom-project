import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Generic LRU (Least Recently Used) cache.
///
/// No TTL — designed for the immutable Tipitaka corpus where cached results
/// never go stale. Capacity bounds memory; LRU eviction handles cold entries.
///
/// Implementation notes:
/// - Uses [LinkedHashMap], which preserves insertion order.
/// - On hit, the entry is removed and re-inserted at the end so it becomes
///   "most recently used."
/// - On overflow, the first entry (least recently used) is evicted.
class LRUCache<K, V> {
  final int capacity;
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();

  // Aggregated stats. Useful for ad-hoc diagnostics; cheap to maintain.
  int _hits = 0;
  int _misses = 0;

  LRUCache(this.capacity);

  /// Returns the value for [key], or `null` if not present.
  /// Updates LRU position on hit.
  V? get(K key) {
    if (!_map.containsKey(key)) {
      _misses++;
      return null;
    }
    // LRU touch: remove and re-insert at the end so this becomes MRU.
    final value = _map.remove(key) as V;
    _map[key] = value;
    _hits++;
    return value;
  }

  /// Stores [value] under [key]. Evicts the LRU entry if at capacity.
  void put(K key, V value) {
    if (_map.containsKey(key)) {
      // Existing key: remove first, will be re-added at the end (MRU).
      _map.remove(key);
    } else if (_map.length >= capacity) {
      // At capacity: evict the first (least recently used) entry.
      _map.remove(_map.keys.first);
    }
    _map[key] = value;
  }

  /// Empties the cache and resets all counters.
  void clear() {
    _map.clear();
    _hits = 0;
    _misses = 0;
  }

  /// Logs cache statistics in debug mode only.
  void logStats(String cacheName) {
    if (kDebugMode) {
      debugPrint('[$cacheName] $stats');
    }
  }

  /// Current number of entries.
  int get size => _map.length;

  /// Immutable snapshot of current cache statistics.
  CacheStats get stats => CacheStats(
        size: _map.length,
        maxSize: capacity,
        hits: _hits,
        misses: _misses,
      );
}

/// Immutable snapshot of cache statistics for diagnostics.
class CacheStats {
  final int size;
  final int maxSize;
  final int hits;
  final int misses;

  const CacheStats({
    required this.size,
    required this.maxSize,
    required this.hits,
    required this.misses,
  });

  /// hits / (hits + misses); 0 when the cache has not been queried yet.
  double get hitRate => (hits + misses) > 0 ? hits / (hits + misses) : 0.0;

  @override
  String toString() {
    final rate = (hitRate * 100).toStringAsFixed(1);
    return 'size=$size/$maxSize hits=$hits misses=$misses rate=$rate%';
  }
}
