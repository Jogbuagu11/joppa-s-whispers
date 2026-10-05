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
      'generator_id': 'gen_pantry',
      'placeholder_color': '#D4802A',
      'tiers': [
        {'tier': 1, 'item_id': 'bakery_01', 'name': 'Barley sheaf'},
        {'tier': 2, 'item_id': 'bakery_02', 'name': 'Flour'},
      ],
    },
  ],
  'generators': [
    {
      'id': 'gen_pantry',
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
  'economy': {'max_manna': 100},
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
);

Map<String, dynamic> _first(Map<String, Object?> c, String key) =>
    (c[key]! as List<dynamic>).first as Map<String, dynamic>;

void main() {
  test('the real content files have no problems', () {
    final problems = validateContent(
      chainsJson: _read('chains'),
      generatorsJson: _read('generators'),
      economyJson: _read('economy'),
      startingBoardJson: _read('starting_board'),
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
    expect(_check(c).single, contains('tiers must count'));
  });

  test('a bad placeholder colour is reported', () {
    final c = _valid();
    _first(c, 'chains')['placeholder_color'] = 'orange';
    expect(_check(c).single, contains('placeholder_color'));
  });

  test('starting board problems are reported', () {
    final c = _valid();
    final board = c['board']! as Map<String, dynamic>;
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
}
