// Chooses and loads the content a play session runs on.
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/data/content_bundle.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';
import 'package:whispers_of_joppa/data/content_repository.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/orders.dart';
import 'package:whispers_of_joppa/domain/progression.dart';
import 'package:whispers_of_joppa/domain/save_repair.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/manna_controller.dart';

final _log = Logger('SessionContent');

/// Loads downloaded content if it is newer and sound, else the app's own.
/// Downloaded content that will not load can never lock the game: it is
/// dropped for good and the content that shipped with the app is used.
Future<({ContentBundle bundle, ContentLoader loader})> loadSessionContent(
  ContentRepository repository,
) async {
  final bundle = await repository.current();
  try {
    return (bundle: bundle, loader: ContentLoader()..loadFromBundle(bundle));
  } on Object catch (e) {
    _log.severe('Content v${bundle.version} failed to load: $e');
    await repository.discardDownloaded();
    final bundled = await repository.loadBundled();
    return (bundle: bundled, loader: ContentLoader()..loadFromBundle(bundled));
  }
}

/// The content version to write into saves, and whether the loaded game was
/// last played with NEWER content than is running now. Such a game has had
/// the parts this content does not know removed, so it is played from memory
/// only and never sent to the player's account; it keeps its higher version.
({int contentVersion, bool downgraded}) contentVersionFor(
  SaveState? loaded,
  ContentBundle bundle,
) {
  final saved = loaded?.contentVersion ?? 0;
  final downgraded = saved > bundle.version;
  if (downgraded) {
    _log.warning(
      'Save was made with content v$saved; running v${bundle.version}',
    );
  }
  return (
    contentVersion: downgraded ? saved : bundle.version,
    downgraded: downgraded,
  );
}

/// A saved game made safe for the content now running: anything that
/// content does not know, or that could not be on the board, is removed.
SaveState repairedSave(SaveState loaded, ContentLoader loader) => sanitizeSave(
  loaded,
  itemIds: loader.items.keys.toSet(),
  generatorIds: loader.generators.keys.toSet(),
  orderIds: {for (final o in loader.orders) o.id},
  taskIds: {
    for (final c in loader.chapters)
      for (final t in c.tasks) t.id,
  },
  cols: BoardState.cols,
  rows: BoardState.rows,
  maxManna: loader.economy.maxManna,
);

/// Which orders may be shown to a player who has done [completedTasks]:
/// those of the chapter the story has reached, and earlier ones.
OrderAvailable ordersOpenAt(ContentLoader loader, List<String> completedTasks) {
  final reached = chapterReached(loader.chapters, completedTasks.toSet());
  final chapterOf = {for (final o in loader.orders) o.id: o.chapter};
  return (id) => (chapterOf[id] ?? 1) <= reached;
}

/// The board for a session: the saved generators (with their clocks) and
/// items, on the content being played.
BoardGame buildSessionGame({
  required ContentLoader loader,
  required SaveState save,
  required SaveState fresh,
  required MannaController manna,
  required VoidCallback onOutOfManna,
}) {
  // A saved game that lost a generator gets it back from the start board.
  final saved = withMissingGenerators(save, fresh.generators);
  return BoardGame(
    itemCatalog: loader.items,
    chainData: loader.chains,
    generatorLevels: loader.generatorLevels,
    generatorPlacements: [
      for (final g in saved)
        if (loader.generators[g.generatorId] case final gen?)
          (gen: gen.atLevel(g.level), col: g.col, row: g.row),
    ],
    generatorTimers: {for (final g in saved) g.generatorId: ?g.timer},
    startingItems: [
      for (final i in save.items)
        if (loader.items[i.itemId] case final item?)
          (item: item, col: i.col, row: i.row),
    ],
    chainPlaceholderColors: loader.chainPlaceholderColors,
    manna: manna,
    onOutOfManna: onOutOfManna,
  );
}
