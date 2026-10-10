import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/generator_type_validator.dart';
import 'package:whispers_of_joppa/data/level_validator.dart';
import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/levels.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';

const _pantry = GeneratorModel(
  generatorId: 'pantry',
  chainId: 'bakery',
  level: 1,
  energyCost: 1,
  name: 'Pantry',
);
const _chains = {
  'bakery': ChainTierData(
    chainId: 'bakery',
    maxTier: 3,
    itemTiers: {'b1': 1, 'b2': 2, 'b3': 3},
    tierToItemId: {'bakery_1': 'b1', 'bakery_2': 'b2', 'bakery_3': 'b3'},
  ),
  'honey': ChainTierData(
    chainId: 'honey',
    maxTier: 2,
    itemTiers: {'h1': 1, 'h2': 2},
    tierToItemId: {'honey_1': 'h1', 'honey_2': 'h2'},
  ),
};
const _tierOne = [
  GeneratorLevelData(level: 1, odds: {'1': 1.0}),
];
const _tierThree = [
  GeneratorLevelData(level: 1, odds: {'3': 1.0}),
];
const _two = GeneratorBoost(mannaTimes: 2, tierBonus: 1);
const _four = GeneratorBoost(mannaTimes: 4, tierBonus: 2);

GeneratorTapResult _tap({
  int manna = 10,
  GeneratorBoost boost = GeneratorBoost.none,
  RareDrop? rare,
  List<GeneratorLevelData> levels = _tierOne,
  int? costOverride,
  Random? random,
}) => resolveGeneratorTap(
  gen: _pantry,
  manna: manna,
  hasFreeCell: true,
  levels: levels,
  chains: _chains,
  boost: boost,
  rare: rare,
  costOverride: costOverride,
  random: random ?? Random(1),
);

void main() {
  test('with no boost a tap costs 1 Manna and gives the usual item', () {
    final r = _tap();
    expect(r.itemId, 'b1');
    expect(r.mannaAfter, 9);
  });

  test('2x costs twice the Manna and gives the item one tier higher', () {
    final r = _tap(boost: _two);
    expect(r.itemId, 'b2');
    expect(r.tier, 2);
    expect(r.mannaAfter, 8);
  });

  test('4x costs four times the Manna and gives two tiers higher', () {
    final r = _tap(boost: _four);
    expect(r.itemId, 'b3');
    expect(r.mannaAfter, 6);
  });

  test('a boosted item never goes past the top of its chain', () {
    final r = _tap(boost: _four, levels: _tierThree);
    expect(r.itemId, 'b3');
    expect(r.tier, 3);
  });

  test('a boosted tap the player cannot afford gives nothing and costs '
      'nothing', () {
    final r = _tap(manna: 3, boost: _four);
    expect(r.spawned, isFalse);
    expect(r.refusal, GeneratorTapRefusal.notEnoughManna);
    expect(r.mannaAfter, 3);
    // The same Manna is enough without the boost.
    expect(_tap(manna: 3).spawned, isTrue);
  });

  test('a free tap stays free whatever the boost', () {
    expect(_tap(boost: _two, costOverride: 0).mannaAfter, 10);
  });

  test('a rare chain comes about as often as its chance says, at its first '
      'tier, for the same Manna', () {
    const rare = RareDrop(chainId: 'honey', chance: 0.1);
    final random = Random(42);
    var rareCount = 0;
    for (var i = 0; i < 2000; i++) {
      final r = _tap(rare: rare, random: random);
      expect(r.mannaAfter, 9);
      if (r.itemId == 'h1') {
        rareCount++;
      } else {
        expect(r.itemId, 'b1');
      }
    }
    expect(rareCount, inInclusiveRange(150, 250));
  });

  test(
    'a certain rare drop always comes; an unknown rare chain never does',
    () {
      expect(
        _tap(rare: const RareDrop(chainId: 'honey', chance: 1)).itemId,
        'h1',
      );
      expect(
        _tap(rare: const RareDrop(chainId: 'nothing', chance: 1)).itemId,
        'b1',
      );
    },
  );

  test('rare drops are read from content, and checked', () {
    expect(RareDrop.fromJson(null), isNull);
    expect(RareDrop.fromJson({'chain_id': 'honey'}), isNull);
    final rare = RareDrop.fromJson({'chain_id': 'honey', 'chance': 0.1});
    expect(rare?.chainId, 'honey');
    expect(rare?.chance, 0.1);
    List<String> check(Object? rare) {
      final problems = <String>[];
      checkRareDrop('g', {'rare': rare}, {'honey'}, problems);
      return problems;
    }

    expect(check(null), isEmpty);
    expect(check({'chain_id': 'honey', 'chance': 0.1}), isEmpty);
    expect(check({'chain_id': 'gold', 'chance': 0.1}), isNotEmpty);
    expect(check({'chain_id': 'honey', 'chance': 0}), isNotEmpty);
    expect(check({'chain_id': 'honey', 'chance': 0.9}), isNotEmpty);
    expect(check('often'), isNotEmpty);
  });

  test('the real game: 2x opens at level 15 and 4x at level 40; three '
      'generators have a rare chain', () {
    final levels = LevelsConfig.fromJson(
      jsonDecode(File('content/levels.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final boosts = levels.boosts;
    expect([for (final b in boosts) b.level], [15, 40]);
    expect(boosts.first.boost?.mannaTimes, 2);
    expect(boosts.first.boost?.tierBonus, 1);
    expect(boosts.last.boost?.mannaTimes, 4);
    expect(boosts.last.boost?.tierBonus, 2);
    // Now that it exists, reaching the level announces it.
    expect(
      levelUpOwed(
        levels,
        rewarded: 14,
        current: 15,
      )?.unlocked.map((u) => u.feature),
      contains('boost_2x'),
    );
    final generators =
        (jsonDecode(File('content/generators.json').readAsStringSync())
                as List<dynamic>)
            .cast<Map<String, dynamic>>();
    expect(
      {
        for (final g in generators)
          if (g['rare'] case {'chain_id': final String chain}) g['id']: chain,
      },
      {'gen_pantry': 'honey', 'gen_loom': 'dye', 'gen_press': 'golden'},
    );
  });

  test('a boost in the levels file must say what it does', () {
    final json =
        jsonDecode(File('content/levels.json').readAsStringSync())
            as Map<String, dynamic>;
    final unlock = (json['unlocks'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((u) => u['feature'] == 'boost_2x');
    unlock['boost'] = {'manna_times': 1, 'tier_bonus': 1};
    final problems = <String>[];
    checkLevels(json, chapterNumbers: {1, 2, 3, 4, 5, 6}, problems: problems);
    expect(problems.join('\n'), contains('a boost needs manna_times'));
  });

  test('the boost switched on is saved with the game', () {
    final save = SaveState(
      items: const [],
      generators: const [],
      manna: 1,
      mannaLastRegen: DateTime.utc(2026, 10, 10),
      talents: 0,
      blessings: 0,
      activeOrders: const [],
      pendingOrders: const [],
      completedOrders: const [],
      completedTasks: const [],
      tutorialStep: 0,
      lastOrderSkip: null,
      boost: 2,
    );
    expect(SaveState.fromJson(save.toJson()).boost, 2);
    // A save from before boosts has none switched on.
    expect(SaveState.fromJson(save.toJson()..remove('boost')).boost, 0);
  });
}
