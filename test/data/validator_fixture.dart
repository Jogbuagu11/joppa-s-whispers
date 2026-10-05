// A small valid content set shared by the validator tests.
import 'package:whispers_of_joppa/data/content_validator.dart';

/// A small valid content set that each test breaks in one way.
Map<String, Object?> validContent() => {
  'chains': [
    {
      'id': 'bakery',
      'unlock_chapter': 1,
      'generator_id': 'gen_pantry',
      'placeholder_color': '#D4802A',
      'tiers': [
        {'tier': 1, 'item_id': 'bakery_01', 'name': 'Barley sheaf', 'sell': 2},
        {'tier': 2, 'item_id': 'bakery_02', 'name': 'Flour', 'sell': 4},
      ],
    },
  ],
  'generators': [
    {
      'id': 'gen_pantry',
      'name': 'Pantry',
      'chain_id': 'bakery',
      'energy_cost': 1,
      'levels': [
        {
          'level': 1,
          'odds': {'1': 1.0},
        },
        {
          'level': 2,
          'odds': {'1': 0.9, '2': 0.1},
        },
      ],
    },
  ],
  'economy': <String, Object?>{for (final key in requiredEconomyKeys) key: 100},
  'characters': [
    {
      'id': 'silas',
      'name': 'Silas',
      'expressions': ['neutral', 'happy'],
    },
  ],
  'tutorial': [
    {
      'id': 'tut_merge',
      'speaker': 'silas',
      'text': 'Join them.',
      'done_when': {'type': 'merge'},
      'free_manna': true,
    },
    {
      'id': 'tut_order',
      'speaker': 'silas',
      'text': 'Deliver.',
      'done_when': {'type': 'order_delivered', 'id': 'ch1_o_001'},
    },
  ],
  'endings': [
    {
      'chapter_id': 'ch1',
      'title': 'Done',
      'body': 'More soon.',
      'button': 'OK',
    },
  ],
  'locations': [
    {
      'id': 'bakehouse',
      'name': 'Bakehouse',
      'areas': [
        {'id': 'bakehouse_door', 'name': 'Door', 'before': 'b', 'after': 'a'},
      ],
    },
  ],
  'letters': [
    {'id': 'letter_01', 'title': 'T', 'body': 'B', 'reference': 'R'},
  ],
  'chapters': [
    {
      'id': 'ch1',
      'number': 1,
      'title': 'Homecoming',
      'location_id': 'bakehouse',
      'unlocks_chains': ['bakery'],
      'tasks': [
        {
          'id': 'ch1_t_01',
          'beat': 2,
          'title': 'Clear the doorway',
          'cost_blessings': 1,
          'scene_id': 'ch1_s_01',
          'restores_area': 'bakehouse_door',
          'letter_id': 'letter_01',
        },
      ],
    },
  ],
  'scenes': [
    {
      'id': 'ch1_s_01',
      'background': 'loc_harbor_dusk',
      'lines': [
        for (final text in ['Little loaf.', 'You came.', 'Sit.', 'Eat.'])
          {'speaker': 'silas', 'expression': 'happy', 'text': text},
      ],
    },
  ],
  'orders': [
    {
      'id': 'ch1_o_001',
      'chapter': 1,
      'character_id': 'silas',
      'kind': 'literal',
      'items': [
        {'item_id': 'bakery_02', 'count': 2},
      ],
      // The fixture economy sets every value, including talents per tier, to 100.
      'rewards': {'talents': 400, 'blessings': 1},
      'text': 'Two sacks of flour, little loaf?',
      'scene_id': null,
    },
  ],
  'board': {
    'manna': 10,
    'generators': [
      {'generator_id': 'gen_pantry', 'col': 2, 'row': 8},
    ],
    'items': [
      {'item_id': 'bakery_01', 'col': 0, 'row': 0},
    ],
  },
};

List<String> checkContent(Map<String, Object?> c) => validateContent(
  chainsJson: c['chains'],
  generatorsJson: c['generators'],
  economyJson: c['economy'],
  startingBoardJson: c['board'],
  ordersJson: c['orders'],
  charactersJson: c['characters'],
  scenesJson: c['scenes'],
  chaptersJson: c['chapters'],
  locationsJson: c['locations'],
  lettersJson: c['letters'],
  tutorialJson: c['tutorial'],
  endingsJson: c['endings'],
);

Map<String, dynamic> firstOf(Map<String, Object?> c, String key) =>
    (c[key] as List<dynamic>).first as Map<String, dynamic>;
