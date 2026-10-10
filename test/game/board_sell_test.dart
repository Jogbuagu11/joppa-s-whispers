import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/cell_component.dart';
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

ItemModel _item(String id, String chain, int tier, int sell) => ItemModel(
  itemId: id,
  chainId: chain,
  tier: tier,
  name: id,
  asset: '',
  sell: sell,
);

final _grain1 = _item('g1', 'grain', 1, 2);
final _grain2 = _item('g2', 'grain', 2, 6);
final _honey1 = _item('h1', 'honey', 1, 12);
final _honey2 = _item('h2', 'honey', 2, 30);
final _crumb = _item('c1', 'crumb', 1, 0);
const _pantry = GeneratorModel(
  generatorId: 'pantry',
  chainId: 'grain',
  level: 1,
  energyCost: 1,
  name: 'Pantry',
  rareChainId: 'honey',
  rareChance: 1,
);

void main() {
  late bool tutorialOver;
  late List<ItemModel> sold;

  Future<BoardGame> board() async {
    final game =
        BoardGame(
            itemCatalog: {
              for (final i in [_grain1, _grain2, _honey1, _honey2, _crumb])
                i.itemId: i,
            },
            chainData: const {
              'grain': ChainTierData(
                chainId: 'grain',
                maxTier: 2,
                itemTiers: {'g1': 1, 'g2': 2},
                tierToItemId: {'grain_1': 'g1', 'grain_2': 'g2'},
              ),
              'honey': ChainTierData(
                chainId: 'honey',
                maxTier: 2,
                itemTiers: {'h1': 1, 'h2': 2},
                tierToItemId: {'honey_1': 'h1', 'honey_2': 'h2'},
              ),
              'crumb': ChainTierData(
                chainId: 'crumb',
                maxTier: 1,
                itemTiers: {'c1': 1},
                tierToItemId: {'crumb_1': 'c1'},
              ),
            },
            generatorLevels: const {
              'pantry': [
                GeneratorLevelData(level: 1, odds: {'1': 1.0}),
              ],
            },
            generatorPlacements: [(gen: _pantry, col: 0, row: 0)],
            startingItems: const [],
            chainPlaceholderColors: const {},
            manna: MannaController(config: _economy, startingManna: 10),
            onOutOfManna: () {},
            gridCols: 3,
            gridRows: 3,
          )
          ..sideChains = {'honey'}
          ..rareDrops = (() => tutorialOver)
          ..onSold = sold.add;
    game.onGameResize(Vector2(300, 300));
    await game.onLoad();
    game.update(0);
    return game;
  }

  ({int col, int row}) where(BoardGame game, String itemId) {
    final at = game.snapshotItems().firstWhere((i) => i.itemId == itemId);
    return (col: at.col, row: at.row);
  }

  setUp(() {
    tutorialOver = true;
    sold = [];
  });

  test('what can be sold: rare finds and gifts at any tier, and anything '
      'at the top of its chain, if it has a price', () async {
    final game = await board();
    expect(game.canSell(_honey1), isTrue);
    expect(game.canSell(_honey2), isTrue);
    expect(game.canSell(_grain2), isTrue);
    // It can still be merged, so it is not for sale.
    expect(game.canSell(_grain1), isFalse);
    // Top of its chain, but worth nothing.
    expect(game.canSell(_crumb), isFalse);
  });

  test('selling takes the item off the board and pays for it once', () async {
    final game = await board();
    game
      ..placeItem(_honey1)
      ..placeItem(_grain1);
    final honey = where(game, 'h1');
    final grain = where(game, 'g1');
    expect(game.sellItemAt(grain.col, grain.row), isFalse);
    expect(game.sellItemAt(9, 9), isFalse);
    expect(sold, isEmpty);
    expect(game.sellItemAt(honey.col, honey.row), isTrue);
    expect([for (final i in sold) i.itemId], ['h1']);
    expect(game.itemCounts()['h1'], isNull);
    expect(game.itemCounts()['g1'], 1);
    // It is gone: it cannot be sold twice.
    expect(game.sellItemAt(honey.col, honey.row), isFalse);
    expect(sold, hasLength(1));
  });

  test('an item an order on show is asking for is not for sale', () async {
    final game = await board();
    game
      ..wantedByOrder = ((id) => id == 'g2')
      ..placeItem(_grain2)
      ..placeItem(_honey1);
    expect(game.canSell(_grain2), isFalse);
    final grain = where(game, 'g2');
    expect(game.sellItemAt(grain.col, grain.row), isFalse);
    expect(game.itemCounts()['g2'], 1);
    // Anything else still is.
    expect(game.canSell(_honey1), isTrue);
  });

  test('with nobody to pay for it, nothing is sold', () async {
    final game = await board();
    game
      ..onSold = null
      ..placeItem(_honey1);
    final honey = where(game, 'h1');
    expect(game.canSell(_honey1), isFalse);
    expect(game.sellItemAt(honey.col, honey.row), isFalse);
    expect(game.itemCounts()['h1'], 1);
  });

  test('a sale agreed for one item never takes another that has since '
      'come to be in its cell', () async {
    final game = await board();
    game.placeItem(_honey1);
    final cell = where(game, 'h1');
    expect(game.sellItemAt(cell.col, cell.row, only: _honey2), isFalse);
    expect(sold, isEmpty);
    // The very item that was asked about: sold.
    expect(game.sellItemAt(cell.col, cell.row, only: _honey1), isTrue);
    expect(sold, hasLength(1));
  });

  test('tapping an item that can be sold asks first, and offers only what '
      'is possible', () async {
    final game = await board();
    game
      ..placeItem(_honey1)
      ..placeItem(_grain1);
    final asked = <String>[];
    bool Function()? doSell;
    game.onItemAsked = (item, {use, sell}) {
      asked.add(item.itemId);
      expect(use, isNull);
      doSell = sell;
    };
    for (final cell in game.children.whereType<CellComponent>()) {
      cell.onItemTapped?.call(cell.col, cell.row);
    }
    expect(asked, ['h1']);
    // Asking alone sells nothing.
    expect(sold, isEmpty);
    expect(doSell?.call(), isTrue);
    expect(sold, hasLength(1));
  });

  test('no rare finds until the tutorial is over', () async {
    tutorialOver = false;
    final game = await board();
    void tap() =>
        game.children.whereType<GeneratorComponent>().single.onTapped('pantry');
    tap();
    expect(game.itemCounts(), {'g1': 1});
    tutorialOver = true;
    tap();
    expect(game.itemCounts(), {'g1': 1, 'h1': 1});
  });
}
