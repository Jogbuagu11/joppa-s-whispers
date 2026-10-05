import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/content_validator.dart';

Object? _read(String name) =>
    jsonDecode(File('content/$name.json').readAsStringSync());

/// A small valid content set that each test breaks in one way.
Map<String, Object?> _valid() => {
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
    {'id': 'silas', 'name': 'Silas'},
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

List<String> _check(Map<String, Object?> c) => validateContent(
  chainsJson: c['chains'],
  generatorsJson: c['generators'],
  economyJson: c['economy'],
  startingBoardJson: c['board'],
  ordersJson: c['orders'],
  charactersJson: c['characters'],
);

Map<String, dynamic> _first(Map<String, Object?> c, String key) =>
    (c[key] as List<dynamic>).first as Map<String, dynamic>;

void main() {
  test('the real content files have no problems', () {
    final problems = validateContent(
      chainsJson: _read('chains'),
      generatorsJson: _read('generators'),
      economyJson: _read('economy'),
      startingBoardJson: _read('starting_board'),
      ordersJson: _read('orders'),
      charactersJson: _read('characters'),
    );
    expect(problems, isEmpty);
  });

  test('the small valid set has no problems', () {
    expect(_check(_valid()), isEmpty);
  });

  test('odds that do not add up to 1 are reported', () {
    final c = _valid();
    final levels = _first(c, 'generators')['levels'] as List<dynamic>;
    (levels[1] as Map<String, dynamic>)['odds'] = {'1': 0.9, '2': 0.2};
    expect(_check(c).single, contains('odds add up to'));
  });

  test('odds for a tier the chain does not have are reported', () {
    final c = _valid();
    final levels = _first(c, 'generators')['levels'] as List<dynamic>;
    (levels[1] as Map<String, dynamic>)['odds'] = {'1': 0.9, '3': 0.1};
    expect(_check(c).single, contains('is not in its chain'));
  });

  test('a generator pointing at an unknown chain is reported', () {
    final c = _valid();
    _first(c, 'generators')['chain_id'] = 'nope';
    expect(_check(c), contains(contains('unknown chain')));
  });

  test('a chain pointing at an unknown generator is reported', () {
    final c = _valid();
    _first(c, 'chains')['generator_id'] = 'gen_nope';
    expect(_check(c).single, contains('unknown generator'));
  });

  test('duplicate and badly formed ids are reported', () {
    final c = _valid();
    final tiers = _first(c, 'chains')['tiers'] as List<dynamic>;
    (tiers[1] as Map<String, dynamic>)['item_id'] = 'bakery_01';
    expect(_check(c), contains(contains('used more than once')));

    final d = _valid();
    _first(d, 'chains')['id'] = 'Bakery';
    expect(_check(d), contains(contains('lowercase snake_case')));
  });

  test('tiers out of order are reported', () {
    final c = _valid();
    final tiers = _first(c, 'chains')['tiers'] as List<dynamic>;
    (tiers[1] as Map<String, dynamic>)['tier'] = 3;
    expect(_check(c), contains(contains('tiers must count')));
  });

  test('a bad placeholder colour is reported', () {
    final c = _valid();
    _first(c, 'chains')['placeholder_color'] = 'orange';
    expect(_check(c).single, contains('placeholder_color'));
  });

  test('starting board problems are reported', () {
    final c = _valid();
    final board = c['board'] as Map<String, dynamic>;
    board['manna'] = 500;
    board['items'] = [
      {'item_id': 'bakery_99', 'col': 2, 'row': 8},
      {'item_id': 'bakery_01', 'col': 7, 'row': 0},
    ];
    final problems = _check(c);
    expect(problems, contains(contains('manna must be between')));
    expect(problems, contains(contains('unknown item "bakery_99"')));
    expect(problems, contains(contains('share cell (2, 8)')));
    expect(problems, contains(contains('off the board (7, 0)')));
  });

  test('a missing field is reported instead of crashing', () {
    final c = _valid();
    _first(c, 'chains').remove('tiers');
    expect(_check(c).single, contains('wrong shape'));
  });

  test('economy problems are reported', () {
    final c = _valid();
    final economy = c['economy'] as Map<String, dynamic>;
    economy.remove('manna_regen_seconds');
    economy['max_manna'] = -1;
    economy['generator_tap_cost'] = 1.5;
    final problems = _check(c);
    expect(problems, contains(contains('manna_regen_seconds is missing')));
    expect(problems, contains(contains('Economy max_manna')));
    expect(problems, contains(contains('Economy generator_tap_cost')));
  });

  test('a missing sell value or generator name is reported', () {
    final c = _valid();
    final tiers = _first(c, 'chains')['tiers'] as List<dynamic>;
    (tiers[0] as Map<String, dynamic>).remove('sell');
    _first(c, 'generators')['name'] = ' ';
    final problems = _check(c);
    expect(problems, contains(contains('sell must be')));
    expect(problems, contains(contains('missing name')));
  });

  test('the same generator placed twice is reported', () {
    final c = _valid();
    final board = c['board'] as Map<String, dynamic>;
    (board['generators'] as List<dynamic>).add({
      'generator_id': 'gen_pantry',
      'col': 3,
      'row': 8,
    });
    expect(_check(c).single, contains('placed more than once'));
  });

  test('zero max Manna or regen time is reported', () {
    final c = _valid();
    final economy = c['economy'] as Map<String, dynamic>;
    economy['manna_regen_seconds'] = 0;
    final problems = _check(c);
    expect(
      problems.single,
      contains('manna_regen_seconds: must be at least 1'),
    );
  });

  test('generator energy_cost is optional but must be valid if present', () {
    final c = _valid();
    _first(c, 'generators').remove('energy_cost');
    expect(_check(c), isEmpty);
    _first(c, 'generators')['energy_cost'] = -1;
    expect(_check(c).single, contains('energy_cost must be 0 or more'));
  });

  group('orders', () {
    Map<String, dynamic> order(Map<String, Object?> c) => _first(c, 'orders');

    test('wrong talents are reported with the right amount', () {
      final c = _valid();
      (order(c)['rewards'] as Map<String, dynamic>)['talents'] = 40;
      expect(_check(c).single, contains('talents should be 400'));
    });

    test('unknown character and unknown item are reported', () {
      final c = _valid();
      order(c)['character_id'] = 'nobody';
      (order(c)['items'] as List<dynamic>).add({
        'item_id': 'bakery_99',
        'count': 1,
      });
      final problems = _check(c);
      expect(problems, contains(contains('unknown character "nobody"')));
      expect(problems, contains(contains('unknown item "bakery_99"')));
    });

    test('text that is too long, bad kind and bad blessings are reported', () {
      final c = _valid();
      order(c)['text'] = 'x' * 141;
      order(c)['kind'] = 'other';
      (order(c)['rewards'] as Map<String, dynamic>)['blessings'] = 4;
      final problems = _check(c);
      expect(problems, contains(contains('over 140 characters')));
      expect(problems, contains(contains('kind must be')));
      expect(problems, contains(contains('blessings must be')));
    });

    test('an item from a chain not yet unlocked is reported', () {
      final c = _valid();
      _first(c, 'chains')['unlock_chapter'] = 2;
      expect(_check(c).single, contains('not unlocked until chapter 2'));
    });

    test(
      'duplicate order ids, zero counts and too many items are reported',
      () {
        final c = _valid();
        final orders = c['orders'] as List<dynamic>;
        orders.add(Map<String, dynamic>.of(order(c)));
        (order(c)['items'] as List<dynamic>).first['count'] = 0;
        final problems = _check(c);
        expect(problems, contains(contains('used more than once')));
        expect(problems, contains(contains('must be 1 or more')));
      },
    );

    test('an item listed twice and more than 3 items are reported', () {
      final c = _valid();
      final items = order(c)['items'] as List<dynamic>;
      for (var i = 0; i < 3; i++) {
        items.add({'item_id': 'bakery_02', 'count': 1});
      }
      final problems = _check(c);
      expect(problems, contains(contains('is listed twice')));
      expect(problems, contains(contains('1 to 3 different items')));
    });

    test('duplicate or nameless characters are reported', () {
      final c = _valid();
      (c['characters'] as List<dynamic>).add({'id': 'silas', 'name': ' '});
      final problems = _check(c);
      expect(problems, contains(contains('Character id "silas" is used more')));
      expect(problems, contains(contains('missing name')));
    });
  });
}
