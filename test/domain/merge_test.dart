import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';

void main() {
  final chains = <String, ChainTierData>{
    'bakery': ChainTierData(
      chainId: 'bakery',
      maxTier: 8,
      itemTiers: {
        'bakery_01': 1, 'bakery_02': 2, 'bakery_03': 3, 'bakery_04': 4,
        'bakery_05': 5, 'bakery_06': 6, 'bakery_07': 7, 'bakery_08': 8,
      },
      tierToItemId: {
        'bakery_2': 'bakery_02', 'bakery_3': 'bakery_03',
        'bakery_4': 'bakery_04', 'bakery_5': 'bakery_05',
        'bakery_6': 'bakery_06', 'bakery_7': 'bakery_07',
        'bakery_8': 'bakery_08',
      },
    ),
  };

  ItemModel item(String id, int tier) => ItemModel(
        itemId: id, chainId: 'bakery', tier: tier, name: '', asset: '');

  group('canMerge', () {
    test('identical items succeed', () {
      expect(
        canMerge(item('bakery_01', 1), item('bakery_01', 1), chains),
        MergeResult.success,
      );
    });

    test('different item IDs fail', () {
      expect(
        canMerge(item('bakery_01', 1), item('bakery_02', 2), chains),
        MergeResult.notMatching,
      );
    });

    test('top-tier items cannot merge', () {
      expect(
        canMerge(item('bakery_08', 8), item('bakery_08', 8), chains),
        MergeResult.noNextTier,
      );
    });
  });

  group('mergedItemId', () {
    test('bakery tier 1 + 1 = bakery_02', () {
      expect(mergedItemId(item('bakery_01', 1), chains), 'bakery_02');
    });

    test('bakery tier 3 + 3 = bakery_04', () {
      expect(mergedItemId(item('bakery_03', 3), chains), 'bakery_04');
    });
  });
}
