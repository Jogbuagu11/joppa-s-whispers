import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/chance_validator.dart';
import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/lucky.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';

dynamic _read(String name) =>
    jsonDecode(File('content/$name.json').readAsStringSync());

const _chains = {
  'bakery': ChainTierData(
    chainId: 'bakery',
    maxTier: 3,
    itemTiers: {'b1': 1, 'b2': 2, 'b3': 3},
    tierToItemId: {'bakery_1': 'b1', 'bakery_2': 'b2', 'bakery_3': 'b3'},
  ),
};
const _b1 = ItemModel(
  itemId: 'b1',
  chainId: 'bakery',
  tier: 1,
  name: 'A',
  asset: '',
);
const _b3 = ItemModel(
  itemId: 'b3',
  chainId: 'bakery',
  tier: 3,
  name: 'C',
  asset: '',
);

void main() {
  final lucky = LuckyBoost.fromJson({
    'steps': [
      {'times': 1, 'weight': 8},
      {'times': 2, 'weight': 1},
      {'times': 5, 'weight': 1},
    ],
  });
  final mystery = MysteryBubble.fromJson({
    'share': 0.25,
    'lifts': [
      {'tiers': 0, 'weight': 1},
      {'tiers': 2, 'weight': 1},
    ],
  });

  test('the lucky boost is drawn as often as its list says', () {
    final odds = lucky.odds((times) => 'x$times');
    expect([for (final o in odds) o.prize.name], ['x1', 'x2', 'x5']);
    expect(odds.map((o) => o.chance), [0.8, 0.1, 0.1]);
    final random = Random(4);
    final counts = <int, int>{};
    for (var i = 0; i < 20000; i++) {
      final times = lucky.draw(random: random);
      counts[times] = (counts[times] ?? 0) + 1;
    }
    expect(counts.keys.toSet(), {1, 2, 5});
    expect((counts[1] ?? 0) / 20000, closeTo(0.8, 0.015));
    expect((counts[5] ?? 0) / 20000, closeTo(0.1, 0.015));
  });

  test('luck multiplies the lift, never the price; no boost, no luck', () {
    const two = GeneratorBoost(mannaTimes: 2, tierBonus: 1);
    final lifted = LuckyBoost.lifted(two, 3);
    expect(lifted.mannaTimes, 2);
    expect(lifted.tierBonus, 3);
    expect(LuckyBoost.lifted(two, 1).tierBonus, 1);
    expect(LuckyBoost.lifted(GeneratorBoost.none, 5).tierBonus, 0);
  });

  test('a mystery bubble is drawn by its list', () {
    expect(mystery.share, 0.25);
    final odds = mystery.odds((tiers) => '+$tiers');
    expect([for (final o in odds) o.prize.name], ['+0', '+2']);
    final random = Random(8);
    final drawn = {for (var i = 0; i < 200; i++) mystery.draw(random: random)};
    expect(drawn, {0, 2});
  });

  test('a lift stops at the top of the chain', () {
    expect(liftedItemId(_b1, 0, _chains), 'b1');
    expect(liftedItemId(_b1, 1, _chains), 'b2');
    expect(liftedItemId(_b1, 2, _chains), 'b3');
    expect(liftedItemId(_b1, 9, _chains), 'b3');
    expect(liftedItemId(_b3, 2, _chains), 'b3');
    expect(liftedItemId(_b1, -1, _chains), 'b1');
  });

  group('the real game', () {
    final chance = _read('chance') as Map<String, dynamic>;

    test('both lists are sound and usually give the plain outcome', () {
      final boost = LuckyBoost.fromJson(
        chance['lucky_boost'] as Map<String, dynamic>,
      );
      final odds = boost.odds((times) => '$times');
      expect(odds.first.prize.name, '1');
      expect(odds.first.chance, greaterThan(0.5));
      final bubble = MysteryBubble.fromJson(
        chance['mystery_bubble'] as Map<String, dynamic>,
      );
      expect(bubble.share, inInclusiveRange(0, 1));
      expect(bubble.odds((tiers) => '$tiers').first.prize.name, '0');
    });

    test('the checker reports faulty lists', () {
      List<String> check(void Function(Map<String, dynamic> chance) change) {
        final copy = jsonDecode(jsonEncode(chance)) as Map<String, dynamic>;
        change(copy);
        return chanceProblems(
          copy,
          chainsJson: _read('chains'),
          generatorsJson: _read('generators'),
        );
      }

      List<dynamic> steps(Map<String, dynamic> c) =>
          (c['lucky_boost'] as Map<String, dynamic>)['steps'] as List<dynamic>;
      Map<String, dynamic> bubble(Map<String, dynamic> c) =>
          c['mystery_bubble'] as Map<String, dynamic>;
      expect(check((c) {}), isEmpty);
      expect(check((c) => steps(c).clear()), isNotEmpty);
      expect(check((c) => steps(c).removeAt(0)), isNotEmpty);
      expect(
        check((c) => (steps(c)[1] as Map<String, dynamic>)['weight'] = 0),
        isNotEmpty,
      );
      expect(
        check((c) => (steps(c)[1] as Map<String, dynamic>)['times'] = 1),
        isNotEmpty,
      );
      expect(check((c) => bubble(c)['share'] = 2), isNotEmpty);
      expect(check((c) => bubble(c)['lifts'] = <dynamic>[]), isNotEmpty);
      expect(check((c) => c.remove('lucky_boost')), isNotEmpty);
    });
  });
}
