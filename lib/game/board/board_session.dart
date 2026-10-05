// Puts a play session together: loads content, restores the save (or starts
// a new game), and creates the board, Manna, orders and the auto-saver.
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/app/game_saver.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/domain/orders.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/features/orders/orders_controller.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/manna_controller.dart';

final _log = Logger('BoardSession');

class BoardSession {
  final BoardGame game;
  final MannaController manna;
  final OrdersController orders;
  final GameSaver saver;
  final Map<String, String> characterNames;

  BoardSession._({
    required this.game,
    required this.manna,
    required this.orders,
    required this.saver,
    required this.characterNames,
  });

  static Future<BoardSession> create({
    required SaveRepository saveRepository,
    required VoidCallback onOutOfManna,
    int? startingMannaOverride,
  }) async {
    final loader = ContentLoader();
    await loader.load();

    final loaded = await saveRepository.load();
    final save = loaded == null
        ? _newGame(loader, startingMannaOverride)
        : sanitizeSave(
            loaded,
            itemIds: loader.items.keys.toSet(),
            generatorIds: loader.generators.keys.toSet(),
            orderIds: {for (final o in loader.orders) o.id},
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
        for (final g in save.generators)
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
          : OrderBook(
              active: save.activeOrders,
              pending: save.pendingOrders,
              lastSkip: save.lastOrderSkip,
            ),
      startingTalents: save.talents,
      startingBlessings: save.blessings,
    );

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
        lastOrderSkip: orders.book.lastSkip,
      ),
      // Manna spends always come with a board change, so the per-second Manna
      // tick does not need to trigger a write.
      triggers: [game.boardChanged, orders],
    )..start();

    return BoardSession._(
      game: game,
      manna: manna,
      orders: orders,
      saver: saver,
      characterNames: loader.characterNames,
    );
  }

  /// A brand-new game, laid out from content/starting_board.json.
  static SaveState _newGame(ContentLoader loader, int? mannaOverride) {
    final start = loader.startingBoard;
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
      lastOrderSkip: null,
    );
  }

  /// Writes any unsaved change and stops the timers.
  Future<void> dispose() async {
    await saver.dispose();
    orders.dispose();
    manna.dispose();
  }
}
