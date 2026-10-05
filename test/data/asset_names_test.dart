import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/asset_names.dart';

void main() {
  group('itemAssetBaseName', () {
    test('accepts a clean name', () {
      expect(itemAssetBaseName('item_bakery_04.png'), 'item_bakery_04');
    });
    test('ignores doubled or odd endings and capitals', () {
      expect(itemAssetBaseName('item_fruit_10.png.jpeg'), 'item_fruit_10');
      expect(itemAssetBaseName('item_loom_02..jpeg'), 'item_loom_02');
      expect(itemAssetBaseName('Item_Armor_01.JPG'), 'item_armor_01');
    });
    test('rejects names that do not follow the pattern', () {
      expect(itemAssetBaseName('bakery_04.png'), isNull);
      expect(itemAssetBaseName('item_bakery_4.png'), isNull);
      expect(itemAssetBaseName('char_naomi_happy.png'), isNull);
    });
  });

  test('expectedItemAssetBaseName pads the tier to two digits', () {
    expect(expectedItemAssetBaseName('bakery', 4), 'item_bakery_04');
    expect(expectedItemAssetBaseName('fruit', 10), 'item_fruit_10');
  });

  test('itemsMissingArt lists items without a picture', () {
    final chains = [
      {
        'id': 'bakery',
        'tiers': [
          {'tier': 1, 'item_id': 'bakery_01'},
          {'tier': 2, 'item_id': 'bakery_02'},
        ],
      },
    ];
    expect(itemsMissingArt(chains, {'item_bakery_01'}), ['bakery_02']);
    expect(
      itemsMissingArt(chains, {'item_bakery_01', 'item_bakery_02'}),
      isEmpty,
    );
  });
}
