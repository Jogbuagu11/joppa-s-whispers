// Puts a play session together: loads content, restores the save (or starts
// a new game), and creates the board, Manna, orders and the auto-saver.
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/app/game_saver.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/domain/locations.dart';
import 'package:whispers_of_joppa/domain/orders.dart';
import 'package:whispers_of_joppa/domain/progression.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/domain/scenes.dart';
import 'package:whispers_of_joppa/domain/tutorial.dart';
import 'package:whispers_of_joppa/features/orders/orders_controller.dart';
import 'package:whispers_of_joppa/features/story/story_controller.dart';
import 'package:whispers_of_joppa/features/story/tutorial_controller.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/manna_controller.dart';

final _log = Logger('BoardSession');

class BoardSession {
  final BoardGame game;
  final MannaController manna;
  final OrdersController orders;
  final StoryController story;
  final TutorialController tutorial;

  /// chapter_id -> the message shown when that chapter is finished.
  final Map<String, ChapterEnding> endings;

  /// scene_id -> scene, for the scenes that tasks play.
  final Map<String, SceneModel> scenes;

  /// location_id -> location, for the restoration screen.
  final Map<String, LocationModel> locations;
  final GameSaver saver;
  final Map<String, String> characterNames;

  /// The scene to play before the board on a brand-new game, if any.
  final SceneModel? openingScene;

  /// Every bundled asset path (used to find portraits and backgrounds).
  final Set<String> assetPaths;

  BoardSession._({
    required this.game,
    required this.manna,
    required this.orders,
    required this.story,
    required this.tutorial,
    required this.endings,
    required this.scenes,
    required this.locations,
    required this.saver,
    required this.characterNames,
    required this.openingScene,
    required this.assetPaths,
  });

  static Future<BoardSession> create({
    required SaveRepository saveRepository,
    required VoidCallback onOutOfManna,
    int? startingMannaOverride,
    bool playTutorial = true,
  }) async {
    final loader = ContentLoader();
    await loader.load();

    final loaded = await saveRepository.load();
    final fresh = _newGame(loader, startingMannaOverride);
    final save = loaded == null
        ? fresh
        : sanitizeSave(
            loaded,
            itemIds: loader.items.keys.toSet(),
            generatorIds: loader.generators.keys.toSet(),
            orderIds: {for (final o in loader.orders) o.id},
            taskIds: {
              for (final c in loader.chapters)
                for (final t in c.tasks) t.id,
            },
            cols: BoardGame.cols,
            rows: BoardGame.rows,
            maxManna: loader.economy.maxManna,
          );
    _log.info(loaded == null ? 'Starting a new game' : 'Restored saved game');

    final manna = MannaController(
      config: loader.economy,
      startingManna: save.manna,
      lastRegen: save.mannaLastRegen,
    );
    // Collect whatever regenerated while the app was closed, then keep ticking.
    manna
      ..tick()
      ..start();

    final game = BoardGame(
      itemCatalog: loader.items,
      chainData: loader.chains,
      generatorLevels: loader.generatorLevels,
      generatorPlacements: [
        // A saved game that lost a generator gets it back from the start board.
        for (final g in withMissingGenerators(save, fresh.generators))
          if (loader.generators[g.generatorId] case final gen?)
            (gen: gen.atLevel(g.level), col: g.col, row: g.row),
      ],
      startingItems: [
        for (final i in save.items)
          if (loader.items[i.itemId] case final item?)
            (item: item, col: i.col, row: i.row),
      ],
      chainPlaceholderColors: loader.chainPlaceholderColors,
      manna: manna,
      onOutOfManna: onOutOfManna,
    );

    final orders = OrdersController(
      config: loader.economy,
      board: game,
      orders: loader.orders,
      savedBook: loaded == null
          ? null
          : reconcileOrderBook(
              saved: OrderBook(
                active: save.activeOrders,
                pending: save.pendingOrders,
                lastSkip: save.lastOrderSkip,
              ),
              completed: save.completedOrders.toSet(),
              allOrderIds: [for (final o in loader.orders) o.id],
              slots: loader.economy.orderSlots,
            ),
      completedOrders: save.completedOrders,
      startingTalents: save.talents,
      startingBlessings: save.blessings,
    );

    final story = StoryController(
      chapters: loader.chapters,
      blessings: () => orders.blessings,
      spendBlessings: orders.spendBlessings,
      wallet: orders,
      completedTasks: save.completedTasks,
    );

    final tutorial = TutorialController(
      steps: loader.tutorial,
      completedOrders: () => orders.completedOrders.toSet(),
      completedTasks: () => story.completedTasks.toSet(),
      startIndex: playTutorial ? save.tutorialStep : tutorialFinished,
    );
    game
      ..freeGeneratorTaps = (() => tutorial.freeManna)
      ..onMerge = (() =>
          tutorial.handle(const TutorialEvent(TutorialTrigger.merge)))
      ..onGeneratorSpawn = (() =>
          tutorial.handle(const TutorialEvent(TutorialTrigger.generatorTap)));
    orders.onDelivered = (id) =>
        tutorial.handle(TutorialEvent(TutorialTrigger.orderDelivered, id));
    story.onTaskDone = (id) =>
        tutorial.handle(TutorialEvent(TutorialTrigger.taskDone, id));

    await game.loadArt();

    final saver = GameSaver(
      repository: saveRepository,
      snapshot: () => SaveState(
        items: game.snapshotItems(),
        generators: game.snapshotGenerators(),
        manna: manna.manna,
        mannaLastRegen: manna.lastRegen,
        talents: orders.talents,
        blessings: orders.blessings,
        activeOrders: orders.book.active,
        pendingOrders: orders.book.pending,
        completedOrders: orders.completedOrders,
        completedTasks: story.completedTasks,
        tutorialStep: tutorial.isOver ? tutorialFinished : tutorial.index,
        lastOrderSkip: orders.book.lastSkip,
      ),
      // Manna spends always come with a board change, so the per-second Manna
      // tick does not need to trigger a write.
      triggers: [game.boardChanged, orders, story, tutorial],
    )..start();

    return BoardSession._(
      game: game,
      manna: manna,
      orders: orders,
      story: story,
      tutorial: tutorial,
      endings: loader.endings,
      scenes: loader.scenes,
      locations: loader.locations,
      saver: saver,
      characterNames: loader.characterNames,
      openingScene: loaded == null
          ? loader.scenes[loader.startingBoard.openingScene]
          : null,
      assetPaths: (await AssetManifest.loadFromAssetBundle(
        rootBundle,
      )).listAssets().toSet(),
    );
  }

  /// A brand-new game, laid out from content/starting_board.json.
  static SaveState _newGame(ContentLoader loader, int? mannaOverride) {
    final start = loader.startingBoard;
    for (final g in start.generators) {
      if (!loader.generators.containsKey(g.generatorId)) {
        _log.severe('Starting board names unknown generator ${g.generatorId}');
      }
    }
    for (final i in start.items) {
      if (!loader.items.containsKey(i.itemId)) {
        _log.severe('Starting board names unknown item ${i.itemId}');
      }
    }
    return SaveState(
      items: [
        for (final i in start.items)
          SavedItem(itemId: i.itemId, col: i.col, row: i.row),
      ],
      generators: [
        for (final g in start.generators)
          SavedGenerator(
            generatorId: g.generatorId,
            level: loader.generators[g.generatorId]?.level ?? 1,
            col: g.col,
            row: g.row,
          ),
      ],
      manna: mannaOverride ?? start.manna,
      mannaLastRegen: DateTime.now(),
      talents: 0,
      blessings: 0,
      activeOrders: const [],
      pendingOrders: const [],
      completedOrders: const [],
      completedTasks: const [],
      tutorialStep: 0,
      lastOrderSkip: null,
    );
  }

  /// Writes any unsaved change and stops the timers.
  Future<void> dispose() async {
    await saver.dispose();
    tutorial.dispose();
    story.dispose();
    orders.dispose();
    manna.dispose();
  }
}
