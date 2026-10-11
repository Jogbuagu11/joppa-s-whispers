// A generator tap puts its item on the board BEFORE the spend is told to
// anyone: what a spend wins (an event reward that takes a square) must
// never take the square the item needed.
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/generator_component.dart';
import 'package:whispers_of_joppa/game/board/manna_controller.dart';

const _economy = EconomyConfig(
  maxManna: 100,
  mannaRegenSeconds: 120,
  generatorTapCost: 1,
  orderTalentsPerTier: 5,
  orderSlots: 3,
  tutorialFreeTaps: 12,
  mannaRefillBasePearls: 10,
  basketSlotBasePearls: 10,
  orderSkipCooldownSeconds: 1800,
  rewardedAdMannaBonus: 20,
  rewardedAdMannaDailyCap: 5,
  rewardedAdDoubleRewardDailyCap: 3,
);
const _items = {
  'g1': ItemModel(
    itemId: 'g1',
    chainId: 'grain',
    tier: 1,
    name: 'A',
    asset: '',
  ),
  'g2': ItemModel(
    itemId: 'g2',
    chainId: 'grain',
    tier: 2,
    name: 'B',
    asset: '',
  ),
  'g3': ItemModel(
    itemId: 'g3',
    chainId: 'grain',
    tier: 3,
    name: 'C',
    asset: '',
  ),
};
const _pantry = GeneratorModel(
  generatorId: 'pantry',
  chainId: 'grain',
  level: 1,
  energyCost: 1,
  name: 'Pantry',
);

void main() {
  test('the spawned item lands before the spend is announced', () async {
    final manna = MannaController(config: _economy, startingManna: 10);
    final game = BoardGame(
      itemCatalog: _items,
      chainData: const {
        'grain': ChainTierData(
          chainId: 'grain',
          maxTier: 3,
          itemTiers: {'g1': 1, 'g2': 2, 'g3': 3},
          tierToItemId: {'grain_1': 'g1', 'grain_2': 'g2', 'grain_3': 'g3'},
        ),
      },
      generatorLevels: const {
        'pantry': [
          GeneratorLevelData(level: 1, odds: {'1': 1.0}),
        ],
      },
      generatorPlacements: [(gen: _pantry, col: 1, row: 1)],
      startingItems: const [],
      chainPlaceholderColors: const {},
      manna: manna,
      onOutOfManna: () {},
      gridCols: 3,
      gridRows: 3,
    );
    game.onGameResize(Vector2(300, 300));
    await game.onLoad();
    game.update(0);
    // Every square but one is taken (the generator has the ninth).
    for (var i = 0; i < 7; i++) {
      game.placeItem(_items['g3'] ?? fail('no item'));
    }
    final spends = <(int, int)>[];
    manna.onSpent = (amount) {
      spends.add((amount, manna.manna));
      // A reward that wants a square, as an energy event's can.
      game.placeItem(_items['g2'] ?? fail('no item'));
    };
    game.children.whereType<GeneratorComponent>().single.onTapped('pantry');
    final onBoard = [for (final i in game.snapshotItems()) i.itemId];
    expect(onBoard.where((id) => id == 'g1'), hasLength(1));
    expect(onBoard.contains('g2'), isFalse);
    // Told once, with the amount, after the Manna was taken.
    expect(spends, [(1, 9)]);
  });
}
