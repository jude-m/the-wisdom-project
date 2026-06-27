import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';

/// Loads the committed SuttaCentral→BJT concordance asset into a plain map.
///
/// The concordance is tiny (a few KB), loaded once and kept in memory — the same
/// idiom as the navigation tree / file-map, and deliberately **not** a SQLite
/// table (see the resolver plan's "SQLite strategy" section). The pure
/// [SuttaCentralRefResolver] (in `wisdom_shared`) wraps the returned map.
abstract class SuttaCentralConcordanceDataSource {
  /// SuttaCentral uid → BJT node key. Empty map if the asset is missing/empty.
  Future<Map<String, String>> load();
}

class SuttaCentralConcordanceDataSourceImpl
    implements SuttaCentralConcordanceDataSource {
  static const String _assetPath = 'assets/data/sc-to-bjt.json';

  @override
  Future<Map<String, String>> load() async {
    try {
      final jsonString = await rootBundle.loadString(_assetPath);
      final decoded = json.decode(jsonString) as Map<String, dynamic>;
      // The asset wraps the pairs under "map" alongside metadata
      // (description/count), mirroring tools/mahamevnawa_map/.
      final rawMap = (decoded['map'] as Map<String, dynamic>?) ?? const {};
      return rawMap.map((key, value) => MapEntry(key, value as String));
    } catch (e, stack) {
      // Non-fatal: a failed load just means no reference-jump capability; FTS
      // is unaffected. Log and rethrow so the FutureProvider surfaces an error
      // state that the reference provider treats as "no resolver".
      developer.log('Failed to load SC↔BJT concordance',
          name: 'SCConcordance', error: e, stackTrace: stack);
      rethrow;
    }
  }
}
