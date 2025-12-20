import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/utils/singlish_transliterator.dart';

void main() {
  group('SinglishTransliterator', () {
    late SinglishTransliterator transliterator;

    setUp(() {
      transliterator = SinglishTransliterator.instance;
    });

    group('convert()', () {
      test('empty string returns empty', () {
        expect(transliterator.convert(''), '');
      });

      test('Sinhala text returns as-is', () {
        expect(transliterator.convert('සති'), 'සති');
        expect(transliterator.convert('ධර්ම'), 'ධර්ම');
      });

      test('basic consonant + vowel combinations', () {
        final cases = {
          'ka': 'ක',
          'ki': 'කි',
          'ku': 'කු',
          'ko': 'කො',
          'ke': 'කෙ',
          'kaa': 'කා',
          'kii': 'කී',
          'kuu': 'කූ',
        };
        for (final entry in cases.entries) {
          expect(transliterator.convert(entry.key), entry.value,
              reason: '${entry.key} should convert to ${entry.value}');
        }
      });

      test('case-sensitive consonant disambiguation', () {
        final cases = {
          'ta': 'ට', // lowercase t = retroflex
          'tha': 'ත', // lowercase th = dental
          'Ta': 'ඨ', // uppercase T = retroflex aspirated
          'Tha': 'ථ', // uppercase Th = dental aspirated
          'da': 'ඩ', // lowercase d = retroflex
          'dha': 'ද', // lowercase dh = dental
          'Da': 'ඪ', // uppercase D = retroflex aspirated
          'Dha': 'ධ', // uppercase Dh = dental aspirated
        };
        for (final entry in cases.entries) {
          expect(transliterator.convert(entry.key), entry.value,
              reason: '${entry.key} should convert to ${entry.value}');
        }
      });

      group('critical search words', () {
        test('sathi (mindfulness) with th -> ත', () {
          expect(transliterator.convert('sathi'), 'සති');
        });

        test('saThi (different) with Th -> ථ', () {
          expect(transliterator.convert('saThi'), 'සථි');
        });

        test('dharma with dh -> ද', () {
          expect(transliterator.convert('dharma'), 'දර්ම');
        });

        test('Dharma with Dh -> ධ (aspirated)', () {
          expect(transliterator.convert('Dharma'), 'ධර්ම');
        });

        test('buddha contains බු', () {
          final result = transliterator.convert('buddha');
          expect(result.contains('බු'), true);
        });

        test('nibbana starts with නි', () {
          final result = transliterator.convert('nibbana');
          expect(result.startsWith('නි'), true);
        });
      });

      test('standalone vowels', () {
        final cases = {
          'a': 'අ',
          'i': 'ඉ',
          'u': 'උ',
          'e': 'එ',
          'o': 'ඔ',
        };
        for (final entry in cases.entries) {
          expect(transliterator.convert(entry.key), entry.value,
              reason: '${entry.key} should convert to ${entry.value}');
        }
      });

      test('trailing consonant gets hal', () {
        expect(transliterator.convert('sat'), 'සට්');
      });

      test('other consonants (sh, Sh, ch, Ch)', () {
        final cases = {
          'sha': 'ශ',
          'Sha': 'ෂ',
          'cha': 'ච',
          'Cha': 'ඡ',
        };
        for (final entry in cases.entries) {
          expect(transliterator.convert(entry.key), entry.value,
              reason: '${entry.key} should convert to ${entry.value}');
        }
      });

      test('rakaransha patterns', () {
        expect(transliterator.convert('kra'), 'ක්‍ර');
        expect(transliterator.convert('pra'), 'ප්‍ර');
        expect(transliterator.convert('kri'), 'ක්‍රි');
        expect(transliterator.convert('kree'), 'ක්‍රී');
      });

      test('special modifiers (ru/ruu)', () {
        expect(transliterator.convert('kru'), 'කෘ');
        expect(transliterator.convert('kruu'), 'කෲ');
      });

      group('multi-word and mixed input', () {
        test('multi-word input', () {
          final result = transliterator.convert('sathi pattana');
          expect(result, contains('සති'));
        });

        test('preserves numbers', () {
          expect(transliterator.convert('sathi 123'), contains('123'));
          expect(transliterator.convert('12345'), '12345');
        });

        test('preserves punctuation', () {
          expect(transliterator.convert('sathi, dharma.'), contains(','));
          expect(transliterator.convert('sathi, dharma.'), contains('.'));
        });
      });

      group('special Pali characters', () {
        test('anusvara (~n → ං)', () {
          final result = transliterator.convert('sa~nga');
          expect(result, contains('ං'));
        });

        test('visarga (~h → ඃ)', () {
          final result = transliterator.convert('du~hkha');
          expect(result, contains('ඃ'));
        });

        test('standalone special chars', () {
          expect(transliterator.convert('~n'), 'ං');
          expect(transliterator.convert('~h'), 'ඃ');
        });
      });
    });

    group('isSinglishQuery()', () {
      test('returns true for ASCII letters', () {
        expect(transliterator.isSinglishQuery('hello'), true);
        expect(transliterator.isSinglishQuery('sathi'), true);
        expect(transliterator.isSinglishQuery('Dharma'), true);
      });

      test('returns false for Sinhala text', () {
        expect(transliterator.isSinglishQuery('සති'), false);
        expect(transliterator.isSinglishQuery('ධර්ම'), false);
      });

      test('returns true for mixed text', () {
        expect(transliterator.isSinglishQuery('සති sathi'), true);
      });
    });

    group('getPossibleMatches()', () {
      test('returns single-element list with converted result', () {
        final matches = transliterator.getPossibleMatches('sathi');
        expect(matches.length, 1);
        expect(matches[0], 'සති');
      });

      test('returns empty list for empty input', () {
        expect(transliterator.getPossibleMatches(''), []);
      });

      test('returns input as-is for Sinhala text', () {
        final matches = transliterator.getPossibleMatches('සති');
        expect(matches.length, 1);
        expect(matches[0], 'සති');
      });
    });
  });
}
