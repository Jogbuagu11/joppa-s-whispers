import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/content_validator.dart';

import 'validator_fixture.dart';

Object? _read(String name) =>
    jsonDecode(File('content/$name.json').readAsStringSync());

void main() {
  test('the real content files have no problems', () {
    final problems = validateContent(
      chainsJson: _read('chains'),
      generatorsJson: _read('generators'),
      economyJson: _read('economy'),
      startingBoardJson: _read('starting_board'),
      ordersJson: _read('orders'),
      charactersJson: _read('characters'),
      scenesJson: _read('scenes'),
    );
    expect(problems, isEmpty);
  });

  test('the small valid set has no problems', () {
    expect(checkContent(validContent()), isEmpty);
  });

  test('odds that do not add up to 1 are reported', () {
    final c = validContent();
    final levels = firstOf(c, 'generators')['levels'] as List<dynamic>;
    (levels[1] as Map<String, dynamic>)['odds'] = {'1': 0.9, '2': 0.2};
    expect(checkContent(c).single, contains('odds add up to'));
  });

  test('odds for a tier the chain does not have are reported', () {
    final c = validContent();
    final levels = firstOf(c, 'generators')['levels'] as List<dynamic>;
    (levels[1] as Map<String, dynamic>)['odds'] = {'1': 0.9, '3': 0.1};
    expect(checkContent(c).single, contains('is not in its chain'));
  });

  test('a generator pointing at an unknown chain is reported', () {
    final c = validContent();
    firstOf(c, 'generators')['chain_id'] = 'nope';
    expect(checkContent(c), contains(contains('unknown chain')));
  });

  test('a chain pointing at an unknown generator is reported', () {
    final c = validContent();
    firstOf(c, 'chains')['generator_id'] = 'gen_nope';
    expect(checkContent(c).single, contains('unknown generator'));
  });

  test('duplicate and badly formed ids are reported', () {
    final c = validContent();
    final tiers = firstOf(c, 'chains')['tiers'] as List<dynamic>;
    (tiers[1] as Map<String, dynamic>)['item_id'] = 'bakery_01';
    expect(checkContent(c), contains(contains('used more than once')));

    final d = validContent();
    firstOf(d, 'chains')['id'] = 'Bakery';
    expect(checkContent(d), contains(contains('lowercase snake_case')));
  });

  test('tiers out of order are reported', () {
    final c = validContent();
    final tiers = firstOf(c, 'chains')['tiers'] as List<dynamic>;
    (tiers[1] as Map<String, dynamic>)['tier'] = 3;
    expect(checkContent(c), contains(contains('tiers must count')));
  });

  test('a bad placeholder colour is reported', () {
    final c = validContent();
    firstOf(c, 'chains')['placeholder_color'] = 'orange';
    expect(checkContent(c).single, contains('placeholder_color'));
  });

  test('starting board problems are reported', () {
    final c = validContent();
    final board = c['board'] as Map<String, dynamic>;
    board['manna'] = 500;
    board['items'] = [
      {'item_id': 'bakery_99', 'col': 2, 'row': 8},
      {'item_id': 'bakery_01', 'col': 7, 'row': 0},
    ];
    final problems = checkContent(c);
    expect(problems, contains(contains('manna must be between')));
    expect(problems, contains(contains('unknown item "bakery_99"')));
    expect(problems, contains(contains('share cell (2, 8)')));
    expect(problems, contains(contains('off the board (7, 0)')));
  });

  test('a missing field is reported instead of crashing', () {
    final c = validContent();
    firstOf(c, 'chains').remove('tiers');
    expect(checkContent(c).single, contains('wrong shape'));
  });

  test('economy problems are reported', () {
    final c = validContent();
    final economy = c['economy'] as Map<String, dynamic>;
    economy.remove('manna_regen_seconds');
    economy['max_manna'] = -1;
    economy['generator_tap_cost'] = 1.5;
    final problems = checkContent(c);
    expect(problems, contains(contains('manna_regen_seconds is missing')));
    expect(problems, contains(contains('Economy max_manna')));
    expect(problems, contains(contains('Economy generator_tap_cost')));
  });

  test('a missing sell value or generator name is reported', () {
    final c = validContent();
    final tiers = firstOf(c, 'chains')['tiers'] as List<dynamic>;
    (tiers[0] as Map<String, dynamic>).remove('sell');
    firstOf(c, 'generators')['name'] = ' ';
    final problems = checkContent(c);
    expect(problems, contains(contains('sell must be')));
    expect(problems, contains(contains('missing name')));
  });

  test('the same generator placed twice is reported', () {
    final c = validContent();
    final board = c['board'] as Map<String, dynamic>;
    (board['generators'] as List<dynamic>).add({
      'generator_id': 'gen_pantry',
      'col': 3,
      'row': 8,
    });
    expect(checkContent(c).single, contains('placed more than once'));
  });

  test('zero max Manna or regen time is reported', () {
    final c = validContent();
    final economy = c['economy'] as Map<String, dynamic>;
    economy['manna_regen_seconds'] = 0;
    final problems = checkContent(c);
    expect(
      problems.single,
      contains('manna_regen_seconds: must be at least 1'),
    );
  });

  test('generator energy_cost is optional but must be valid if present', () {
    final c = validContent();
    firstOf(c, 'generators').remove('energy_cost');
    expect(checkContent(c), isEmpty);
    firstOf(c, 'generators')['energy_cost'] = -1;
    expect(checkContent(c).single, contains('energy_cost must be 0 or more'));
  });
}
