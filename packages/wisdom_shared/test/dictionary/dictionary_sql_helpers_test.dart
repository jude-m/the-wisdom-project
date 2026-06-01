import 'package:test/test.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// Guards the shared dictionary SQL helpers. These run on BOTH the client and
/// the server, so a bug (especially a LIKE-injection hole) would affect both.
void main() {
  group('buildDictionaryLikePattern', () {
    test('empty word → "%" (match all)', () {
      expect(buildDictionaryLikePattern(''), '%');
    });

    test('default is a prefix pattern (trailing %)', () {
      expect(buildDictionaryLikePattern('abc'), 'abc%');
    });

    test('exactMatch drops the trailing wildcard', () {
      expect(buildDictionaryLikePattern('abc', exactMatch: true), 'abc');
    });

    test('escapes LIKE wildcards % and _ in the user input', () {
      // The key case: a user word containing % or _ must NOT act as a LIKE
      // wildcard. Both are backslash-escaped; the trailing % (the prefix
      // wildcard WE add) stays live.
      expect(buildDictionaryLikePattern('50%_off'), r'50\%\_off%');
    });

    test('escapes wildcards even in exact mode (no trailing %)', () {
      expect(
        buildDictionaryLikePattern('50%_off', exactMatch: true),
        r'50\%\_off',
      );
    });
  });

  group('appendDictionaryFilter', () {
    test('empty id set → nothing appended, no args (means "all dictionaries")',
        () {
      final buffer = StringBuffer('WHERE word LIKE ?');
      final args = <Object>['abc%'];

      appendDictionaryFilter(buffer, args, <String>{});

      expect(buffer.toString(), 'WHERE word LIKE ?');
      expect(args, ['abc%']); // unchanged
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
