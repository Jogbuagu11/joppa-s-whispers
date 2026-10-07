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

  group('characterAssetBaseName', () {
    test('accepts a clean name', () {
      expect(
        characterAssetBaseName('char_naomi_happy.png'),
        'char_naomi_happy',
      );
    });
    test('fixes known misspellings and odd endings', () {
      expect(
        characterAssetBaseName('char_amos_suprised.jpeg'),
        'char_amos_surprised',
      );
      expect(
        characterAssetBaseName('char_amos_mad.png.jpeg'),
        'char_amos_angry',
      );
      expect(
        characterAssetBaseName('char_silas_nuetral.png.jpeg'),
        'char_silas_neutral',
      );
      expect(
        characterAssetBaseName('char_naiomi_neutral.png.jpeg'),
        'char_naomi_neutral',
      );
      expect(
        characterAssetBaseName('char_tabitha_happy..jpeg'),
        'char_tabitha_happy',
      );
    });
    test('rejects unknown expressions and other files', () {
      expect(characterAssetBaseName('char_naomi_winking.png'), isNull);
      expect(characterAssetBaseName('item_bakery_01.png'), isNull);
      expect(characterAssetBaseName('naomi_happy.png'), isNull);
    });
  });

  test('portraitBaseName builds the expected file name', () {
    expect(portraitBaseName('silas', 'happy'), 'char_silas_happy');
  });

  group('locationAssetBaseName', () {
    const names = {
      'loc_well_lip_after_20261006115228': 'loc_well_lip_before',
      'loc_well_bucketstone_before': 'loc_well_stone_before',
      'Town_well_in_Joppa': 'loc_well_morning',
    };

    test(
      'a well-named picture keeps its name, without date or copy number',
      () {
        expect(
          locationAssetBaseName(
            'loc_well_rope_after_20261006115840.jpg',
            names,
          ),
          'loc_well_rope_after',
        );
        expect(
          locationAssetBaseName('loc_well_rope_before_20261006 2.jpg', names),
          'loc_well_rope_before',
        );
      },
    );

    test('a listed picture takes the listed name', () {
      expect(
        locationAssetBaseName('Town_well_in_Joppa_20261006120414.jpg', names),
        'loc_well_morning',
      );
      expect(
        locationAssetBaseName('loc_well_bucketstone_before_2026.jpg', names),
        'loc_well_stone_before',
      );
    });

    test('the longest listed beginning wins over the name itself', () {
      // Named "after" by mistake; the list says it is the "before" picture.
      expect(
        locationAssetBaseName('loc_well_lip_after_20261006115228 2.jpg', names),
        'loc_well_lip_before',
      );
      expect(
        locationAssetBaseName('loc_well_lip_after_20261006114922.jpg', names),
        'loc_well_lip_after',
      );
    });

    test('anything else is not a location picture', () {
      expect(locationAssetBaseName('holiday.jpg', names), isNull);
      expect(locationAssetBaseName('loc_well.jpg', names), isNull);
    });
  });

  group('generator pictures', () {
    test('a well-named picture keeps its generator and level', () {
      expect(generatorAssetBaseName('gen_pantry_l2.jpg'), 'gen_pantry_l2');
      expect(generatorAssetBaseName('GEN_Tree_L5.png.jpeg'), 'gen_tree_l5');
    });

    test('another name for a generator is turned into its real id', () {
      expect(
        generatorAssetBaseName('gen_desk_l3.jpg', {'gen_desk': 'gen_scribe'}),
        'gen_scribe_l3',
      );
    });

    test('anything else is not a generator picture', () {
      expect(generatorAssetBaseName('gen_pantry.jpg'), isNull);
      expect(generatorAssetBaseName('gen_pantry_l0.jpg'), isNull);
      expect(generatorAssetBaseName('item_bakery_01.jpg'), isNull);
      expect(generatorAssetBaseName('gen_pantry_level2.jpg'), isNull);
    });

    test('the game looks for a generator\'s picture by id and level', () {
      expect(
        generatorArtPath('gen_chest', 3),
        'assets/generators/gen_chest_l3.jpg',
      );
    });
  });

  test('a character id may end in a digit', () {
    expect(
      characterAssetBaseName('char_dockworker2_neutral.png'),
      'char_dockworker2_neutral',
    );
    expect(characterAssetBaseName('char_2pac_neutral.png'), isNull);
  });
}
