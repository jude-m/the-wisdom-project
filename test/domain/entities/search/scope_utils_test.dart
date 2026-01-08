import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/constants/constants.dart';
import 'package:the_wisdom_project/domain/entities/search/scope_utils.dart';

void main() {
  group('ScopeUtils -', () {
    group('getAllChipNodeKeys', () {
      test('returns all node keys from predefined chips', () {
        // ACT
        final allKeys = ScopeUtils.getAllChipNodeKeys();

        // ASSERT - 7 keys: sp, vp, ap, atta-vp, atta-sp, atta-ap, anya
        expect(
          allKeys,
          containsAll([
            TipitakaNodeKeys.suttaPitaka,
            TipitakaNodeKeys.vinayaPitaka,
            TipitakaNodeKeys.abhidhammaPitaka,
            TipitakaNodeKeys.treatises,
          ]),
        );
        expect(
          allKeys,
          containsAll([
            TipitakaNodeKeys.vinayaAtthakatha,
            TipitakaNodeKeys.suttaAtthakatha,
            TipitakaNodeKeys.abhidhammaAtthakatha,
          ]),
        );
        expect(allKeys.length, equals(7));
      });
    });

    group('isAllSelected', () {
      test('returns true for empty scope', () {
        expect(ScopeUtils.isAllSelected({}), isTrue);
      });

      test('returns false for non-empty scope', () {
        expect(
          ScopeUtils.isAllSelected({TipitakaNodeKeys.suttaPitaka}),
          isFalse,
        );
      });
    });

    group('isChipSelectionOnly', () {
      test('returns true for empty scope', () {
        expect(ScopeUtils.isChipSelectionOnly({}), isTrue);
      });

      test('returns true when scope matches single chip', () {
        expect(
          ScopeUtils.isChipSelectionOnly({TipitakaNodeKeys.suttaPitaka}),
          isTrue,
        );
        expect(
          ScopeUtils.isChipSelectionOnly({TipitakaNodeKeys.vinayaPitaka}),
          isTrue,
        );
      });

      test('returns true when scope matches multiple chips', () {
        expect(
          ScopeUtils.isChipSelectionOnly({
            TipitakaNodeKeys.suttaPitaka,
            TipitakaNodeKeys.vinayaPitaka,
          }),
          isTrue,
        );
      });

      test('returns false when scope contains sub-node keys', () {
        // 'dn' is a sub-node of sp, not a chip's nodeKey
        expect(
          ScopeUtils.isChipSelectionOnly({TipitakaNodeKeys.dighaNikaya}),
          isFalse,
        );
        expect(
          ScopeUtils.isChipSelectionOnly({
            TipitakaNodeKeys.dighaNikaya,
            TipitakaNodeKeys.majjhimaNikaya,
          }),
          isFalse,
        );
      });
    });

    group('hasCustomSelections', () {
      test('returns false for chip-only selections', () {
        expect(ScopeUtils.hasCustomSelections({}), isFalse);
        expect(
          ScopeUtils.hasCustomSelections({
            TipitakaNodeKeys.suttaPitaka,
            TipitakaNodeKeys.vinayaPitaka,
          }),
          isFalse,
        );
      });

      test('returns true for sub-node selections', () {
        expect(
          ScopeUtils.hasCustomSelections({TipitakaNodeKeys.dighaNikaya}),
          isTrue,
        );
      });
    });

    group('normalize', () {
      test('returns empty scope unchanged', () {
        expect(ScopeUtils.normalize({}), isEmpty);
      });

      test('collapses to empty when all chip keys selected', () {
        // All 7 chip node keys - using TipitakaNodeKeys.allRoots
        expect(ScopeUtils.normalize(TipitakaNodeKeys.allRoots), isEmpty);
      });

      test('preserves partial selections', () {
        final partial = {
          TipitakaNodeKeys.suttaPitaka,
          TipitakaNodeKeys.vinayaPitaka,
        };
        expect(ScopeUtils.normalize(partial), equals(partial));
      });
    });
  });
}
