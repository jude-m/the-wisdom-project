import 'package:test/test.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// Guards the shared dictionary SQL helpers. These run on BOTH the client and
/// the server, so a bug (especially a `?` out of step with its args) would
/// affect both.
void main() {
  group('appendDictionaryWordMatch', () {
    test('default is a prefix range: [word, word + U+10FFFF)', () {
      final buffer = StringBuffer('WHERE ');
      final args = <Object>[];

      appendDictionaryWordMatch(buffer, args, 'abc');

      expect(buffer.toString(), 'WHERE word >= ? AND word < ?');
      expect(args, ['abc', 'abc\u{10FFFF}']);
    });

    test('exactMatch is a plain equality', () {
      final buffer = StringBuffer('WHERE ');
      final args = <Object>[];

      appendDictionaryWordMatch(buffer, args, 'abc', exactMatch: true);

      expect(buffer.toString(), 'WHERE word = ?');
      expect(args, ['abc']);
    });

    test('empty word → the prefix range covers every headword', () {
      final buffer = StringBuffer();
      final args = <Object>[];

      appendDictionaryWordMatch(buffer, args, '');

      expect(args, ['', '\u{10FFFF}']);
    });

    test('% and _ are bound as plain text, not wildcards', () {
      // The word is a bound value, not a LIKE pattern, so nothing is escaped.
      final buffer = StringBuffer();
      final args = <Object>[];

      appendDictionaryWordMatch(buffer, args, '50%_off');

      expect(args, ['50%_off', '50%_off\u{10FFFF}']);
    });

    test('appends after earlier args, keeping ? and args in step', () {
      // The SELECT's `CASE WHEN word = ?` binds first, then the match.
      final buffer = StringBuffer('CASE WHEN word = ? ... WHERE ');
      final args = <Object>['abc'];

      appendDictionaryWordMatch(buffer, args, 'abc');

      expect('?'.allMatches(buffer.toString()).length, args.length);
      expect(args, ['abc', 'abc', 'abc\u{10FFFF}']);
    });
  });

  group('appendDictionaryFilter', () {
    test('empty id set → nothing appended, no args (means "all dictionaries")',
        () {
      final buffer = StringBuffer('WHERE word = ?');
      final args = <Object>['abc'];

      appendDictionaryFilter(buffer, args, <String>{});

      expect(buffer.toString(), 'WHERE word = ?');
      expect(args, ['abc']); // unchanged
    });

    test('non-empty set → IN clause with one placeholder per id, args appended',
        () {
      final buffer = StringBuffer();
      final args = <Object>[];

      // LinkedHashSet preserves insertion order, so placeholders and args align.
      appendDictionaryFilter(buffer, args, {'BUS', 'MS'});

      expect(buffer.toString(), ' AND dict_id IN (?, ?)');
      expect(args, ['BUS', 'MS']);
    });

    test('one ? per id ⇔ one bound arg per id (lock-step invariant)', () {
      final buffer = StringBuffer();
      final args = <Object>[];
      final ids = {'BUS', 'MS', 'PTS'};

      appendDictionaryFilter(buffer, args, ids);

      // The cardinal rule: placeholder count must equal bound-arg count, else
      // the prepared statement throws / silently misbinds.
      final placeholderCount = '?'.allMatches(buffer.toString()).length;
      expect(placeholderCount, ids.length);
      expect(args.length, ids.length);
      expect(args.toSet(), ids);
    });
  });
}
