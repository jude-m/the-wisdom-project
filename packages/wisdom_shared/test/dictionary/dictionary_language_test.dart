import 'package:test/test.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// Pins the magic dictionary-ID → target-language contract. BUS and MS are the
/// Sinhala-target dictionaries; everything else targets English.
void main() {
  group('inferTargetLanguage', () {
    test('BUS → si (Sinhala)', () {
      expect(inferTargetLanguage('BUS'), 'si');
    });

    test('MS → si (Sinhala)', () {
      expect(inferTargetLanguage('MS'), 'si');
    });

    test('any other dictionary id → en (English)', () {
      expect(inferTargetLanguage('PTS'), 'en');
      expect(inferTargetLanguage('DPPN'), 'en');
    });

    test('empty id → en (the default branch)', () {
      expect(inferTargetLanguage(''), 'en');
    });
  });
}
