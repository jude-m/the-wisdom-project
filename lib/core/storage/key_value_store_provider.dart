import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'key_value_store.dart';

/// App-wide [KeyValueStore] provider.
///
/// Must be overridden in main.dart with a SharedPreferences-backed
/// instance — reading without an override will throw, which is
/// intentional (we never want a silent, in-memory fake to ship to
/// production).
///
/// Lives in `lib/core/storage/` because it's generic infrastructure: any
/// feature that needs lightweight key/value persistence imports it from
/// here. Hosting it inside a feature-specific provider file would
/// couple every consumer to that feature.
final keyValueStoreProvider = Provider<KeyValueStore>((ref) {
  throw UnimplementedError(
    'keyValueStoreProvider must be overridden in main.dart',
  );
});
