import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/generator_types.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/cell_component.dart';
import 'package:whispers_of_joppa/game/board/grant_queue.dart';
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
const _jar = ItemModel(
  itemId: 'jar',
  chainId: 'manna_jar',
  tier: 1,
  name: 'Cup of Manna',
  asset: '',
  use: ItemUse(manna: 15),
);
const _glass = ItemModel(
  itemId: 'glass',
  chainId: 'hourglass',
  tier: 1,
  name: 'Small hourglass',
  asset: '',
  use: ItemUse(skipSeconds: 900),
);
const _boat = GeneratorModel(
  generatorId: 'boat',
  chainId: 'fruit',
  level: 1,
  energyCost: 0,
  name: 'Boat',
  rules: GeneratorRules(kind: GeneratorKind.temporary, taps: 1),
);
const _items = {'fruit_1': _fig, 'jar': _jar, 'glass': _glass};

void main() {
  late MannaController manna;

  Future<BoardGame> board({int cols = 2, int rows = 2}) async {
    manna = MannaController(config: _economy, startingManna: 95);
    final game = BoardGame(
      itemCatalog: _items,
      chainData: const {
        'fruit': ChainTierData(
          chainId: 'fruit',
          itemTiers: {'fruit_1': 1},
          tierToItemId: {'fruit_1': 'fruit_1'},
          maxTier: 1,
        ),
      },
      generatorLevels: const {
        'boat': [
          GeneratorLevelData(level: 1, odds: {'1': 1.0}),
        ],
      },
      generatorPlacements: [],
      startingItems: const [],
      chainPlaceholderColors: const {},
      manna: manna,
      onOutOfManna: () {},
      gridCols: cols,
      gridRows: rows,
    );
    game.onGameResize(Vector2(200, 200));
    await game.onLoad();
    game.update(0);
    return game;
  }

  GrantQueue queue(BoardGame game, {List<String> waiting = const []}) =>
      GrantQueue(
        game: game,
        items: _items,
        generators: const {'boat': _boat},
        waiting: waiting,
      );

  test('a gift goes straight onto a board with room', () async {
    final game = await board();
    final q = queue(game)..give(itemIds: ['glass', 'jar']);
    expect([for (final i in game.snapshotItems()) i.itemId], ['glass', 'jar']);
    expect(q.waiting, isEmpty);
  });

  test('on a full board the gift waits, is saved, and arrives when there is '
      'room', () async {
    final game = await board();
    for (var i = 0; i < 4; i++) {
      game.placeItem(_fig);
    }
    final q = queue(game);
    var told = 0;
    q.addListener(() => told++);
    q.give(itemIds: ['jar']);
    expect(q.waiting, ['item:jar']);
    expect(told, 1);
    expect(game.snapshotItems(), hasLength(4));

    // A cell opens: the board says so, and the jar is placed.
    expect(game.removeItems({'fruit_1': 1}), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(q.waiting, isEmpty);
    expect(game.itemCounts()['jar'], 1);
  });

  test(
    'gifts waiting in a saved game are placed when the game opens',
    () async {
      final game = await board();
      final q = queue(game, waiting: ['item:glass', 'gen:boat', 'item:gone']);
      q.place();
      // The hourglass and the boat arrive; the unknown gift is dropped.
      expect(q.waiting, isEmpty);
      expect(game.itemCounts()['glass'], 1);
      expect(game.generatorPlacements.single.gen.generatorId, 'boat');
    },
  );

  test(
    'a second temporary generator waits until the first is used up',
    () async {
      final game = await board(cols: 3, rows: 3);
      final q = queue(game)..give(generatorIds: ['boat', 'boat']);
      expect(game.generatorPlacements, hasLength(1));
      expect(q.waiting, ['gen:boat']);
      game.removeGenerator('boat');
      await Future<void>.delayed(Duration.zero);
      expect(game.generatorPlacements, hasLength(1));
      expect(q.waiting, isEmpty);
    },
  );

  test('nothing is placed before the board is drawn', () {
    manna = MannaController(config: _economy, startingManna: 1);
    final game = BoardGame(
      itemCatalog: _items,
      chainData: const {},
      generatorLevels: const {},
      generatorPlacements: [],
      startingItems: const [],
      chainPlaceholderColors: const {},
      manna: manna,
      onOutOfManna: () {},
    );
    final q = queue(game)..give(itemIds: ['jar']);
    expect(q.waiting, ['item:jar']);
  });

  test('a Manna jar is used from the board, even over the bar; other items '
      'are not', () async {
    final game = await board();
    game
      ..placeItem(_jar)
      ..placeItem(_fig)
      ..placeItem(_glass);
    final at = {for (final i in game.snapshotItems()) i.itemId: i};
    final jar = at['jar'];
    final fig = at['fruit_1'];
    final glass = at['glass'];
    expect(game.useItemAt(fig?.col ?? -1, fig?.row ?? -1), isFalse);
    // An hourglass is not "used" by tapping: it is dropped on a generator.
    expect(game.useItemAt(glass?.col ?? -1, glass?.row ?? -1), isFalse);
    expect(game.useItemAt(9, 9), isFalse);
    expect(manna.manna, 95);
    expect(game.useItemAt(jar?.col ?? -1, jar?.row ?? -1), isTrue);
    expect(manna.manna, 110);
    expect(game.itemCounts()['jar'], isNull);
    // It is gone: it cannot be used twice.
    expect(game.useItemAt(jar?.col ?? -1, jar?.row ?? -1), isFalse);
    expect(manna.manna, 110);
  });

  test(
    'tapping a usable item asks first; an ordinary item asks nothing',
    () async {
      final game = await board();
      game
        ..placeItem(_jar)
        ..placeItem(_fig);
      final asked = <String>[];
      bool Function()? doUse;
      game.onItemAsked = (item, {use, sell}) {
        asked.add(item.itemId);
        doUse = use;
        // Nothing here has a selling price.
        expect(sell, isNull);
      };
      // Every cell reports a tap the same way; only the jar's leads anywhere.
      for (final cell in game.children.whereType<CellComponent>()) {
        cell.onItemTapped?.call(cell.col, cell.row);
      }
      expect(asked, ['jar']);
      expect(manna.manna, 95);
      expect(doUse?.call(), isTrue);
      expect(manna.manna, 110);
    },
  );

  test('a gifted generator arrives at the level the player has paid for, '
      'and never holds later arrivals back', () async {
    final game = await board(cols: 3, rows: 3);
    const pantry = GeneratorModel(
      generatorId: 'pantry',
      chainId: 'fruit',
      level: 3,
      energyCost: 1,
      name: 'Pantry',
    );
    expect(game.addGenerator(pantry, 0, 0), isTrue);
    expect(game.lowestLastingLevel, 3);
    queue(game).give(generatorIds: ['boat']);
    final boat = game.generatorPlacements
        .firstWhere((p) => p.gen.generatorId == 'boat')
        .gen;
    expect(boat.level, 3);
    // Even a temporary generator that somehow sat at level 1 would not
    // count: the next lasting generator still starts at 3.
    game.removeGenerator('boat');
    expect(game.addGenerator(_boat, 2, 2), isTrue);
    expect(game.lowestLastingLevel, 3);
  });
}
