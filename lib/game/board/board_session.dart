// Puts a play session together: loads content, restores the save (or starts
// a new game), and creates the board, Manna, orders and the auto-saver.
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/app/game_saver.dart';
import 'package:whispers_of_joppa/data/content_bundle.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';
import 'package:whispers_of_joppa/data/content_repository.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/domain/ads.dart';
import 'package:whispers_of_joppa/domain/letters.dart';
import 'package:whispers_of_joppa/domain/locations.dart';
import 'package:whispers_of_joppa/domain/orders.dart';
import 'package:whispers_of_joppa/domain/progression.dart';
import 'package:whispers_of_joppa/domain/save_repair.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/domain/scenes.dart';
import 'package:whispers_of_joppa/features/ads/ad_rewards_controller.dart';
import 'package:whispers_of_joppa/features/orders/orders_controller.dart';
import 'package:whispers_of_joppa/features/shop/purchases_controller.dart';
import 'package:whispers_of_joppa/features/story/endings_tracker.dart';
import 'package:whispers_of_joppa/features/story/story_controller.dart';
import 'package:whispers_of_joppa/features/story/tutorial_controller.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/chapter_wiring.dart';
import 'package:whispers_of_joppa/game/board/manna_controller.dart';
import 'package:whispers_of_joppa/game/board/new_game.dart';
import 'package:whispers_of_joppa/game/board/session_content.dart';
import 'package:whispers_of_joppa/game/board/session_snapshot.dart';

final _log = Logger('BoardSession');

class BoardSession {
  final BoardGame game;
  final MannaController manna;
  final OrdersController orders;
  final StoryController story;
  final TutorialController tutorial;

  /// Which chapters' closing messages have been shown.
  final EndingsTracker endings;

  /// The player's Pearls and applied purchases.
  final PurchasesController purchases;

  /// Optional rewarded ads and today's count of them.
  final AdRewardsController ads;

  /// scene_id -> scene, for the scenes that tasks play.
  final Map<String, SceneModel> scenes;

  /// The content this session is playing, for the background update check.
  final ContentBundle contentBundle;

  /// The content version written into saves (the newest this game has seen).
  final int savedContentVersion;

  /// True when the game was saved with newer content than is running now.
  bool get downgraded => savedContentVersion > contentBundle.version;

  /// Esther's letters, for the keepsake book.
  final List<LetterModel> letters;

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
    required this.purchases,
    required this.ads,
    required this.scenes,
    required this.locations,
    required this.letters,
    required this.contentBundle,
    required this.savedContentVersion,
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
    ContentRepository? content,
  }) async {
    // Downloaded content if it is newer and sound, else the app's own.
    final repository =
        content ?? ContentRepository(loadBundled: loadBundledContent);
    final (:bundle, :loader) = await loadSessionContent(repository);

    final loaded = await saveRepository.load();
    final fresh = newGameState(loader, startingMannaOverride);
    final save = loaded == null ? fresh : repairedSave(loaded, loader);
    _log.info(loaded == null ? 'Starting a new game' : 'Restored saved game');
    final (:contentVersion, :downgraded) = contentVersionFor(loaded, bundle);

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
              available: ordersOpenAt(loader, save.completedTasks),
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

    final endings = EndingsTracker(
      endings: loader.endings,
      seen: save.endingsSeen,
    );
    final purchases = PurchasesController(
      products: loader.products,
      addManna: manna.add,
      raiseGenerators: game.raiseGeneratorsTo,
      startingPearls: save.pearls,
      appliedTransactions: save.appliedTransactions,
      ownedProducts: save.ownedProducts,
    );

    final tutorial = TutorialController(
      steps: loader.tutorial,
      completedOrders: () => orders.completedOrders.toSet(),
      completedTasks: () => story.completedTasks.toSet(),
      freeTapsAllowed: loader.economy.tutorialFreeTaps,
      startIndex: playTutorial ? save.tutorialStep : tutorialFinished,
      freeTapsAlreadyUsed: save.tutorialFreeTapsUsed,
    );
    wireTutorial(game: game, orders: orders, story: story, tutorial: tutorial);
    wireChapters(
      game: game,
      orders: orders,
      story: story,
      boardGenerators: loader.startingBoard.generators,
      generators: loader.generators,
    );

    final ads = AdRewardsController(
      config: loader.economy,
      addManna: manna.add,
      tutorialOver: () => tutorial.isOver,
      startingTally: AdTally(day: save.adDay, mannaAds: save.adMannaWatched),
    );

    await game.loadArt();

    final saver = GameSaver(
      repository: saveRepository,
      snapshot: () => buildSnapshot(
        game: game,
        manna: manna,
        orders: orders,
        story: story,
        tutorial: tutorial,
        endings: endings,
        purchases: purchases,
        ads: ads,
        contentVersion: contentVersion,
      ),
      // Manna spends always come with a board change, so the per-second Manna
      // tick does not need to trigger a write.
      triggers: [
        game.boardChanged,
        orders,
        story,
        tutorial,
        endings,
        purchases,
        ads.tallyChanged,
      ],
    );
    // A game that has lost parts to older content is played from memory only:
    // the full game on disk is left untouched for when newer content is back.
    if (!downgraded) saver.start();

    return BoardSession._(
      game: game,
      manna: manna,
      orders: orders,
      story: story,
      tutorial: tutorial,
      endings: endings,
      purchases: purchases,
      ads: ads,
      scenes: loader.scenes,
      locations: loader.locations,
      letters: loader.letters,
      contentBundle: bundle,
      savedContentVersion: contentVersion,
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

  /// The game exactly as it is now, in the form that gets saved.
  SaveState snapshot() => saver.snapshot();

  /// The closing message of a finished chapter not yet shown, or null.
  ChapterEnding? get pendingEnding =>
      endings.pending(story.chapters, story.completedTasks.toSet());

  /// Stops everything WITHOUT writing: used when this game is being replaced
  /// by one from the player's account, so it must not save over it.
  Future<void> discard() async {
    await saver.cancel();
    _disposeParts();
  }

  void _disposeParts() {
    ads.dispose();
    purchases.dispose();
    endings.dispose();
    tutorial.dispose();
    story.dispose();
    orders.dispose();
    manna.dispose();
  }

  /// Writes any unsaved change and stops the timers.
  Future<void> dispose() async {
    await saver.dispose();
    _disposeParts();
  }
}
