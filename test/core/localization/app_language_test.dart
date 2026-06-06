import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/localization/app_language.dart';

// Test plan 1.2 — pure App Language resolution. The non-obvious behaviour is
// that `fromLocales` walks the device's *ordered* preferred-locale list and
// honours the user's ranking (not just the primary locale). `fromStorage`
// parses a saved choice or rejects junk so the caller can fall back to device.
void main() {
  group('AppLanguage.fromLocales -', () {
    test('honours the ordered device list, skipping unsupported locales', () {
      // Tamil is first but unsupported; Sinhala is the user's 2nd choice and is
      // supported — so we pick Sinhala, NOT English off the primary locale.
      final result = AppLanguage.fromLocales(
        const [Locale('ta'), Locale('si'), Locale('en')],
      );

      expect(result, equals(AppLanguage.sinhala));
    });

    test('respects ranking: English ahead of Sinhala resolves to English', () {
      final result =
          AppLanguage.fromLocales(const [Locale('en'), Locale('si')]);

      expect(result, equals(AppLanguage.english));
    });

    test('no supported locale in the list falls back to English', () {
      expect(
        AppLanguage.fromLocales(const [Locale('ta')]),
        equals(AppLanguage.english),
      );
    });

    test('empty list falls back to English', () {
      expect(
        AppLanguage.fromLocales(const []),
        equals(AppLanguage.english),
      );
    });
  });

  group('AppLanguage.fromStorage -', () {
    test('parses a valid persisted enum name', () {
      expect(AppLanguage.fromStorage('sinhala'), equals(AppLanguage.sinhala));
      expect(AppLanguage.fromStorage('english'), equals(AppLanguage.english));
    });

    test('returns null for null or unrecognised values (caller uses device)',
        () {
      expect(AppLanguage.fromStorage(null), isNull);
      expect(AppLanguage.fromStorage('klingon'), isNull);
    });
  });
}
