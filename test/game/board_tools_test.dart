import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
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

ItemModel _item(String id, String chain, int tier, {ItemUse? use}) => ItemModel(
  itemId: id,
  chainId: chain,
  tier: tier,
  name: id,
  asset: '',
  use: use,
);

final _knife = _item('knife', 'knife', 1, use: const ItemUse(split: true));
final _thread = _item('thread', 'thread', 1, use: const ItemUse(wild: true));
final _b1 = _item('b1', 'bakery', 1);
final _b2 = _item('b2', 'bakery', 2);
final _b3 = _item('b3', 'bakery', 3);

void main() {
  late List<String> merged;

  Future<BoardGame> board() async {
    final game = BoardGame(
      itemCatalog: {
        for (final i in [_knife, _thread, _b1, _b2, _b3]) i.itemId: i,
      },
      chainData: const {
        'bakery': ChainTierData(
          chainId: 'bakery',
          maxTier: 3,
          itemTiers: {'b1': 1, 'b2': 2, 'b3': 3},
          tierToItemId: {'bakery_1': 'b1', 'bakery_2': 'b2', 'bakery_3': 'b3'},
        ),
      },
      generatorLevels: const {},
      generatorPlacements: const [],
      startingItems: const [],
      chainPlaceholderColors: const {},
      manna: MannaController(config: _economy, startingManna: 10),
      onOutOfManna: () {},
      gridCols: 3,
      gridRows: 3,
    )..onMerged = (item) => merged.add(item.itemId);
    game.onGameResize(Vector2(300, 300));
    await game.onLoad();
    game.update(0);
    return game;
  }

  ({int col, int row}) where(BoardGame game, String itemId) {
    final at = game.snapshotItems().firstWhere((i) => i.itemId == itemId);
    return (col: at.col, row: at.row);
  }

  setUp(() => merged = []);

  test('a knife on a third-tier item leaves two second-tier items and no '
      'knife', () async {
    final game = await board();
    game
      ..placeItem(_knife)
      ..placeItem(_b3);
    final knife = where(game, 'knife');
    final loaf = where(game, 'b3');
    expect(game.useToolOn(knife.col, knife.row, loaf.col, loaf.row), isTrue);
    expect(game.itemCounts(), {'b2': 2});
    // One where the item was, one where the knife was.
    final cells = {for (final i in game.snapshotItems()) (i.col, i.row)};
    expect(cells, {(knife.col, knife.row), (loaf.col, loaf.row)});
    // Splitting is not a merge.
    expect(merged, isEmpty);
  });

  test('a knife on a first-tier item is not used', () async {
    final game = await board();
    game
      ..placeItem(_knife)
      ..placeItem(_b1);
    final knife = where(game, 'knife');
    final grain = where(game, 'b1');
    expect(game.useToolOn(knife.col, knife.row, grain.col, grain.row), isFalse);
    expect(game.itemCounts(), {'knife': 1, 'b1': 1});
  });

  test('a Golden Thread raises an item one tier, is used up, and counts as '
      'a merge', () async {
    final game = await board();
    game
      ..placeItem(_thread)
      ..placeItem(_b1);
    final thread = where(game, 'thread');
    final grain = where(game, 'b1');
    expect(
      game.useToolOn(thread.col, thread.row, grain.col, grain.row),
      isTrue,
    );
    expect(game.itemCounts(), {'b2': 1});
    expect(where(game, 'b2'), grain);
    expect(merged, ['b2']);
  });

  test('a Golden Thread on a top-tier item, on nothing, on itself or off '
      'the board is not used', () async {
    final game = await board();
    game
      ..placeItem(_thread)
      ..placeItem(_b3);
    final thread = where(game, 'thread');
    final top = where(game, 'b3');
    expect(game.useToolOn(thread.col, thread.row, top.col, top.row), isFalse);
    expect(game.useToolOn(thread.col, thread.row, 2, 2), isFalse);
    expect(
      game.useToolOn(thread.col, thread.row, thread.col, thread.row),
      isFalse,
    );
    expect(game.useToolOn(thread.col, thread.row, 9, 9), isFalse);
    // An ordinary item is no tool.
    expect(game.useToolOn(top.col, top.row, thread.col, thread.row), isFalse);
    expect(game.itemCounts(), {'thread': 1, 'b3': 1});
    expect(merged, isEmpty);
  });
}
