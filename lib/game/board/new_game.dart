// Builds the state of a brand-new game from content/starting_board.json.
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';

final _log = Logger('NewGame');

/// A brand-new game, laid out from content/starting_board.json.
SaveState newGameState(ContentLoader loader, int? mannaOverride) {
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
