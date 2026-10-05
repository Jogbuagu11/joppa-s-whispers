import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';

// Deterministic mock random that always returns a fixed value.
class _FixedRandom implements Random {
  final double value;
  _FixedRandom(this.value);
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

void main() {
  final level1 = GeneratorLevelData(level: 1, odds: {'1': 1.0});
  final level2 = GeneratorLevelData(level: 2, odds: {'1': 0.9, '2': 0.1});

  group('spawnTier', () {
    test('level 1 always returns tier 1', () {
      expect(spawnTier(level1, random: _FixedRandom(0.0)), 1);
      expect(spawnTier(level1, random: _FixedRandom(0.99)), 1);
    });

    test('level 2 returns tier 1 when roll < 0.9', () {
      expect(spawnTier(level2, random: _FixedRandom(0.5)), 1);
    });

    test('level 2 returns tier 2 when roll >= 0.9', () {
      expect(spawnTier(level2, random: _FixedRandom(0.95)), 2);
    });
  });

  group('boardHasSpace', () {
    BoardState makeState(bool allFull) {
      final cells = List.generate(
        BoardState.cols,
        (c) => List.generate(
          BoardState.rows,
          (r) => BoardCell(
            col: c,
            row: r,
            item: allFull
                ? const ItemModel(
                    itemId: 'bakery_01',
                    chainId: 'bakery',
                    tier: 1,
                    name: '',
                    asset: '',
                  )
                : null,
          ),
        ),
      );
      return BoardState(
        cells: cells,
        generators: [],
        manna: 10,
        maxManna: 100,
        talents: 0,
        pearls: 0,
        blessings: 0,
      );
    }

    test('empty board has space', () {
      expect(boardHasSpace(makeState(false)), isTrue);
    });

    test('full board has no space', () {
      expect(boardHasSpace(makeState(true)), isFalse);
    });
  });

  group('resolveSpawnedItemId', () {
    final chains = {
      'bakery': ChainTierData(
        chainId: 'bakery',
        maxTier: 3,
        itemTiers: {'bakery_01': 1, 'bakery_02': 2, 'bakery_03': 3},
        tierToItemId: {
          'bakery_1': 'bakery_01',
          'bakery_2': 'bakery_02',
          'bakery_3': 'bakery_03',
        },
      ),
    };

    test('tier 1 resolves to bakery_01', () {
      expect(resolveSpawnedItemId('bakery', 1, chains), 'bakery_01');
    });

    test('tier 3 resolves to bakery_03', () {
      expect(resolveSpawnedItemId('bakery', 3, chains), 'bakery_03');
    });

    test('unknown chain returns null', () {
      expect(resolveSpawnedItemId('nonexistent', 1, chains), isNull);
    });

    test('tier beyond max returns null', () {
      expect(resolveSpawnedItemId('bakery', 99, chains), isNull);
    });
  });

  group('canAffordGenerator', () {
    final gen = GeneratorModel(
      generatorId: 'gen_pantry',
      chainId: 'bakery',
      level: 1,
      energyCost: 1,
      name: 'Pantry',
    );

    BoardState stateWithManna(int manna) => BoardState(
      cells: List.generate(
        BoardState.cols,
        (c) => List.generate(BoardState.rows, (r) => BoardCell(col: c, row: r)),
      ),
      generators: [],
      manna: manna,
      maxManna: 100,
      talents: 0,
      pearls: 0,
      blessings: 0,
    );

    test('sufficient manna', () {
      expect(canAffordGenerator(stateWithManna(5), gen), isTrue);
    });

    test('zero manna cannot afford', () {
      expect(canAffordGenerator(stateWithManna(0), gen), isFalse);
    });
  });

  group('spawnTier with three tiers', () {
    final level4 = GeneratorLevelData(
      level: 4,
      odds: {'1': 0.7, '2': 0.25, '3': 0.05},
    );

    test('roll just under 0.70 gives tier 1', () {
      expect(spawnTier(level4, random: _FixedRandom(0.69)), 1);
    });

    test('roll of 0.70 gives tier 2', () {
      expect(spawnTier(level4, random: _FixedRandom(0.70)), 2);
    });

    test('roll of 0.96 gives tier 3', () {
      expect(spawnTier(level4, random: _FixedRandom(0.96)), 3);
    });
  });

  group('content/generators.json', () {
    test('every level has odds that add up to 100%', () {
      final list =
          jsonDecode(File('content/generators.json').readAsStringSync())
              as List<dynamic>;
      expect(list, isNotEmpty);
      for (final g in list) {
        final gen = g as Map<String, dynamic>;
        for (final l in gen['levels'] as List<dynamic>) {
          final level = l as Map<String, dynamic>;
          final odds = level['odds'] as Map<String, dynamic>;
          final sum = odds.values.fold<double>(
            0,
            (total, v) => total + (v as num).toDouble(),
          );
          expect(
            sum,
            closeTo(1.0, 1e-9),
            reason: '${gen['id']} level ${level['level']}',
          );
        }
      }
    });
  });

  group('resolveGeneratorTap', () {
    final chains = {
      'bakery': ChainTierData(
        chainId: 'bakery',
        maxTier: 2,
        itemTiers: {'bakery_01': 1, 'bakery_02': 2},
        tierToItemId: {'bakery_1': 'bakery_01', 'bakery_2': 'bakery_02'},
      ),
    };
    final levels = [
      GeneratorLevelData(level: 1, odds: {'1': 1.0}),
      GeneratorLevelData(level: 2, odds: {'1': 0.9, '2': 0.1}),
    ];
    GeneratorModel gen({int level = 1, String chain = 'bakery'}) =>
        GeneratorModel(
          generatorId: 'gen_pantry',
          chainId: chain,
          level: level,
          energyCost: 1,
          name: 'Pantry',
        );

    GeneratorTapResult tap({
      GeneratorModel? g,
      int manna = 10,
      bool hasFreeCell = true,
      List<GeneratorLevelData>? lv,
      bool noLevels = false,
      double roll = 0.0,
    }) => resolveGeneratorTap(
      gen: g ?? gen(),
      manna: manna,
      hasFreeCell: hasFreeCell,
      levels: noLevels ? null : (lv ?? levels),
      chains: chains,
      random: _FixedRandom(roll),
    );

    test('spawns a tier-1 item and spends 1 Manna', () {
      final r = tap();
      expect(r.spawned, isTrue);
      expect(r.itemId, 'bakery_01');
      expect(r.tier, 1);
      expect(r.mannaAfter, 9);
    });

    test('level 2 generator can spawn tier 2', () {
      final r = tap(g: gen(level: 2), roll: 0.95);
      expect(r.itemId, 'bakery_02');
    });

    test('unknown level falls back to the first level', () {
      final r = tap(g: gen(level: 5), roll: 0.95);
      expect(r.itemId, 'bakery_01');
    });

    test('not enough Manna: refused, nothing spent', () {
      final r = tap(manna: 0);
      expect(r.refusal, GeneratorTapRefusal.notEnoughManna);
      expect(r.mannaAfter, 0);
      expect(r.itemId, isNull);
    });

    test('board full: refused, nothing spent', () {
      final r = tap(hasFreeCell: false);
      expect(r.refusal, GeneratorTapRefusal.boardFull);
      expect(r.mannaAfter, 10);
    });

    test('missing or empty level data: refused, nothing spent', () {
      expect(tap(noLevels: true).refusal, GeneratorTapRefusal.noLevelData);
      expect(tap(lv: []).refusal, GeneratorTapRefusal.noLevelData);
      expect(tap(noLevels: true).mannaAfter, 10);
    });

    test('chain with no matching item: refused, nothing spent', () {
      final r = tap(g: gen(chain: 'nonexistent'));
      expect(r.refusal, GeneratorTapRefusal.noItem);
      expect(r.mannaAfter, 10);
    });
  });

  test('GeneratorModel.atLevel changes only the level', () {
    const gen = GeneratorModel(
      generatorId: 'gen_pantry',
      chainId: 'bakery',
      level: 1,
      energyCost: 1,
      name: 'Pantry',
    );
    final up = gen.atLevel(3);
    expect(up.level, 3);
    expect(up.generatorId, 'gen_pantry');
    expect(up.chainId, 'bakery');
    expect(up.energyCost, 1);
    expect(up.name, 'Pantry');
  });
}
