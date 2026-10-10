import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/bubbles.dart';
import 'package:whispers_of_joppa/domain/levels.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';

const _json = {
  'chance': 0.05,
  'higher_chance': 0.2,
  'seconds': 60,
  'pearls_per_tier': 2,
  'ad_max_tier': 3,
  'talents_per_tier': 3,
  'max_at_once': 2,
};
const _b2 = ItemModel(
  itemId: 'b2',
  chainId: 'bakery',
  tier: 2,
  name: 'B',
  asset: '',
);
const _b3 = ItemModel(
  itemId: 'b3',
  chainId: 'bakery',
  tier: 3,
  name: 'C',
  asset: '',
);
const _chains = {
  'bakery': ChainTierData(
    chainId: 'bakery',
    maxTier: 3,
    itemTiers: {'b1': 1, 'b2': 2, 'b3': 3},
    tierToItemId: {'bakery_1': 'b1', 'bakery_2': 'b2', 'bakery_3': 'b3'},
  ),
};

BubbleRules _rules({double chance = 0.05, double higher = 0.2}) => BubbleRules(
  chance: chance,
  higherChance: higher,
  seconds: 60,
  pearlsPerTier: 2,
  adMaxTier: 3,
  talentsPerTier: 3,
  maxAtOnce: 2,
);

void main() {
  test('the numbers are read from content; a missing one means no rules', () {
    final rules = BubbleRules.fromJson(_json);
    expect(rules?.chance, 0.05);
    expect(rules?.seconds, 60);
    expect(rules?.maxAtOnce, 2);
    expect(BubbleRules.fromJson(null), isNull);
    expect(BubbleRules.fromJson({..._json}..remove('seconds')), isNull);
  });

  test('the price rises with the tier; ads only for small items; Talents '
      'for one left alone', () {
    final rules = _rules();
    expect(rules.pearlsFor(1), 2);
    expect(rules.pearlsFor(5), 10);
    expect(rules.adAllowedFor(3), isTrue);
    expect(rules.adAllowedFor(4), isFalse);
    expect(rules.talentsFor(4), 12);
  });

  test('about one merge in twenty leaves a bubble', () {
    final random = Random(7);
    var bubbles = 0;
    for (var i = 0; i < 4000; i++) {
      if (bubbleAfterMerge(_b2, _rules(), _chains, random: random) != null) {
        bubbles++;
      }
    }
    expect(bubbles, inInclusiveRange(150, 250));
  });

  test('a bubble holds a copy, or now and then the next tier up', () {
    final random = Random(3);
    final held = <String, int>{};
    for (var i = 0; i < 1000; i++) {
      final id = bubbleAfterMerge(
        _b2,
        _rules(chance: 1),
        _chains,
        random: random,
      );
      held[id ?? 'none'] = (held[id ?? 'none'] ?? 0) + 1;
    }
    expect(held.keys.toSet(), {'b2', 'b3'});
    expect(held['b3'], inInclusiveRange(150, 250));
  });

  test('at the top of its chain a bubble always holds a copy', () {
    expect(bubbleAfterMerge(_b3, _rules(chance: 1, higher: 1), _chains), 'b3');
  });

  test('a chance of nothing never leaves a bubble', () {
    expect(bubbleAfterMerge(_b2, _rules(chance: 0), _chains), isNull);
  });

  test('faulty numbers are reported', () {
    List<String> check(Map<String, Object> changes) {
      final problems = <String>[];
      checkBubbleRules('Unlock', {..._json, ...changes}, problems);
      return problems;
    }

    expect(check({}), isEmpty);
    expect(check({'chance': 0}), isNotEmpty);
    expect(check({'chance': 0.9}), isNotEmpty);
    expect(check({'higher_chance': 2}), isNotEmpty);
    expect(check({'seconds': 5}), isNotEmpty);
    expect(check({'pearls_per_tier': 0}), isNotEmpty);
    expect(check({'talents_per_tier': -1}), isNotEmpty);
    expect(check({'max_at_once': 0}), isNotEmpty);
    expect(check({'seconds': 'long'}), isNotEmpty);
    final none = <String>[];
    checkBubbleRules('Unlock', null, none);
    expect(none, isEmpty);
  });

  test('bubbles are offered only once their unlock is available', () {
    LevelsConfig levels({required bool available}) => LevelsConfig.fromJson({
      'xp_per_task_by_chapter': <String, dynamic>{},
      'xp_per_task_default': 1,
      'levels': [
        {'level': 2, 'xp': 10},
      ],
      'unlocks': [
        {
          'level': 5,
          'feature': 'bubbles',
          'name': 'Bubbles',
          'available': available,
          'bubble': _json,
        },
      ],
    });
    expect(levels(available: false).bubbles, isNull);
    expect(levels(available: true).bubbles?.level, 5);
    expect(levels(available: true).bubbles?.bubble?.seconds, 60);
  });
}
