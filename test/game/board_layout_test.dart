import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/generator_types.dart';
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
const _fig = ItemModel(
  itemId: 'fruit_1',
  chainId: 'fruit',
  tier: 1,
  name: 'Fig',
  asset: '',
);

GeneratorModel _gen(String id, GeneratorRules rules) => GeneratorModel(
  generatorId: id,
  chainId: 'fruit',
  level: 1,
  energyCost: rules.costsManna ? 1 : 0,
  name: id,
  rules: rules,
);

void main() {
  late DateTime now;
  late MannaController manna;

  Future<BoardGame> board(
    GeneratorModel gen, {
    int col = 1,
    int row = 1,
    Map<String, GeneratorTimer>? timers,
    int startingManna = 10,
  }) async {
    manna = MannaController(
      config: _economy,
      startingManna: startingManna,
      clock: () => now,
    );
    final game = BoardGame(
      itemCatalog: const {'fruit_1': _fig},
      chainData: const {
        'fruit': ChainTierData(
          chainId: 'fruit',
          itemTiers: {'fruit_1': 1},
          tierToItemId: {'fruit_1': 'fruit_1'},
          maxTier: 1,
        ),
      },
      generatorLevels: {
        gen.generatorId: const [
          GeneratorLevelData(level: 1, odds: {'1': 1.0}),
        ],
      },
      generatorPlacements: [(gen: gen, col: col, row: row)],
      startingItems: const [],
      chainPlaceholderColors: const {},
      manna: manna,
      onOutOfManna: () {},
      gridCols: 3,
      gridRows: 3,
      generatorTimers: timers,
      clock: () => now,
    );
    game.onGameResize(Vector2(300, 300));
    await game.onLoad();
    // Let the cells and the generator tile take their places.
    game.update(0);
    return game;
  }

  void tap(BoardGame game, String id) => game.children
      .whereType<GeneratorComponent>()
      .firstWhere((c) => c.generator.generatorId == id)
      .onTapped(id);

  setUp(() => now = DateTime.utc(2026, 10, 10, 12));

  test('the board re-fits itself when it is given a different amount of '
      'room', () async {
    final gen = _gen('pantry', GeneratorRules.standard);
    final game = await board(gen);
    game.placeItem(_fig);
    // 300 x 300 for a 3 x 3 board: cells of 98, centred.
    final tile = game.children.whereType<GeneratorComponent>().single;
    expect(tile.size.x, 98);
    expect(tile.position.x, 3 + 98);

    // A hint above the board goes away: it gets taller and wider.
    game.onGameResize(Vector2(420, 420));
    expect(tile.size.x, 138);
    expect(tile.position.x, 3 + 138);
    expect(tile.position.y, 3 + 138);
    // What is on the board has not changed, and it still works.
    expect(game.snapshotItems(), hasLength(1));
    tap(game, 'pantry');
    expect(game.snapshotItems(), hasLength(2));

    // And smaller again (a banner arrives).
    game.onGameResize(Vector2(240, 300));
    expect(tile.size.x, 78);
    expect(tile.position.y, (300 - 3 * 78) / 2 + 78);
  });
}
