import 'package:test/test.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// `parseCsvToSet` parses the `scope` / `editionIds` CSV query params at the
/// server's HTTP boundary, so its empty/malformed handling matters.
void main() {
  group('parseCsvToSet', () {
    test('null → empty set', () {
      expect(parseCsvToSet(null), isEmpty);
    });

    test('empty string → empty set', () {
      expect(parseCsvToSet(''), isEmpty);
    });

    test('comma-separated values → set', () {
      expect(parseCsvToSet('dn,mn'), {'dn', 'mn'});
    });

    test('trailing comma → empty segment is filtered out', () {
      expect(parseCsvToSet('dn,mn,'), {'dn', 'mn'});
    });

    test('duplicates collapse (it is a Set)', () {
      expect(parseCsvToSet('dn,dn,mn'), {'dn', 'mn'});
    });
  });
}
