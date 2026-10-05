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

    test('a cost override of 0 makes the tap free, even with no Manna', () {
      final r = resolveGeneratorTap(
        gen: gen(),
        manna: 0,
        hasFreeCell: true,
        levels: levels,
        chains: chains,
        random: _FixedRandom(0),
        costOverride: 0,
      );
      expect(r.spawned, isTrue);
      expect(r.mannaAfter, 0);
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
