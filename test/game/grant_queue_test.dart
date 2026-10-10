import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/content_bundle.dart';
import 'package:whispers_of_joppa/data/generator_type_validator.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/generator_types.dart';
import 'package:whispers_of_joppa/domain/levels.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
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
      bool Function()? use;
      game.onUsableItemTapped = (item, doIt) {
        asked.add(item.itemId);
        use = doIt;
      };
      // Every cell reports a tap the same way; only the jar's leads anywhere.
      for (final cell in game.children.whereType<CellComponent>()) {
        cell.onItemTapped?.call(cell.col, cell.row);
      }
      expect(asked, ['jar']);
      expect(manna.manna, 95);
      expect(use?.call(), isTrue);
      expect(manna.manna, 110);
    },
  );

  test('what an item does is read from content, and checked', () {
    expect(ItemUse.fromJson(null), isNull);
    expect(ItemUse.fromJson({'manna': 15})?.givesManna, isTrue);
    expect(ItemUse.fromJson({'skip_seconds': 900})?.skipsTime, isTrue);
    expect(ItemUse.fromJson({'skip_all': true})?.skipAll, isTrue);
    expect(ItemUse.fromJson(<String, dynamic>{}), isNull);
    List<String> check(Object? use) {
      final problems = <String>[];
      checkItemUse('Item', use, problems);
      return problems;
    }

    expect(check(null), isEmpty);
    expect(check({'manna': 5}), isEmpty);
    expect(check({'skip_all': true}), isEmpty);
    expect(check({'manna': 0}), isNotEmpty);
    expect(check({'manna': 5, 'skip_seconds': 60}), isNotEmpty);
    expect(check(<String, dynamic>{}), isNotEmpty);
    expect(check('lots'), isNotEmpty);
  });

  test('a level can give items and a temporary generator, each once', () {
    const config = LevelsConfig(
      xpPerTaskByChapter: {},
      xpPerTaskDefault: 10,
      steps: [
        LevelStep(level: 2, xp: 10, items: ['jar']),
        LevelStep(level: 3, xp: 20, items: ['glass'], generator: 'boat'),
      ],
    );
    final up = levelUpOwed(config, rewarded: 1, current: 3);
    expect(up?.items, ['jar', 'glass']);
    expect(up?.generators, ['boat']);
    expect(levelUpOwed(config, rewarded: 2, current: 3)?.items, ['glass']);
    final read = LevelsConfig.fromJson({
      'xp_per_task_by_chapter': <String, dynamic>{},
      'xp_per_task_default': 10,
      'levels': [
        {
          'level': 2,
          'xp': 10,
          'talents': 5,
          'items': ['jar'],
          'generator': 'boat',
        },
      ],
    });
    expect(read.steps.single.items, ['jar']);
    expect(read.steps.single.generator, 'boat');
  });

  test('waiting gifts are saved with the game; older saves have none', () {
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
      pendingGrants: const ['item:jar', 'gen:boat'],
    );
    final json = save.toJson();
    expect(SaveState.fromJson(json).pendingGrants, ['item:jar', 'gen:boat']);
    expect(
      SaveState.fromJson(json..remove('pending_grants')).pendingGrants,
      isEmpty,
    );
  });

  test('the board wording must be complete', () {
    expect(boardTextProblems(null), isNotEmpty);
    expect(
      boardTextProblems({for (final k in boardTextKeys) k: 'words'}),
      isEmpty,
    );
    expect(
      boardTextProblems({
        for (final k in boardTextKeys.skip(1)) k: 'words',
      }).single,
      contains(boardTextKeys.first),
    );
  });
}
