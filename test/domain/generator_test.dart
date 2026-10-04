import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/models.dart';

// Deterministic mock random that always returns a fixed value.
class _FixedRandom implements Random {
  final double value;
  _FixedRandom(this.value);
  @override double nextDouble() => value;
  @override int nextInt(int max) => 0;
  @override bool nextBool() => false;
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
                    itemId: 'bakery_01', chainId: 'bakery',
                    tier: 1, name: '', asset: '')
                : null,
          ),
        ),
      );
      return BoardState(
        cells: cells, generators: [],
        manna: 10, maxManna: 100, talents: 0, pearls: 0, blessings: 0,
      );
    }

    test('empty board has space', () {
      expect(boardHasSpace(makeState(false)), isTrue);
    });

    test('full board has no space', () {
      expect(boardHasSpace(makeState(true)), isFalse);
    });
  });

  group('canAffordGenerator', () {
    final gen = GeneratorModel(
      generatorId: 'gen_pantry', chainId: 'bakery',
      level: 1, energyCost: 1, name: 'Pantry',
    );

    BoardState stateWithManna(int manna) => BoardState(
          cells: List.generate(BoardState.cols, (c) =>
              List.generate(BoardState.rows, (r) =>
                  BoardCell(col: c, row: r))),
          generators: [], manna: manna, maxManna: 100,
          talents: 0, pearls: 0, blessings: 0,
        );

    test('sufficient manna', () {
      expect(canAffordGenerator(stateWithManna(5), gen), isTrue);
    });

    test('zero manna cannot afford', () {
      expect(canAffordGenerator(stateWithManna(0), gen), isFalse);
    });
  });
}
