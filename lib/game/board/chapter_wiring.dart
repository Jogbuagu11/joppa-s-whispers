// Keeps the board in step with the story: when a new chapter is reached its
// orders open up and its generators arrive on the board.
import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/progression.dart';
import 'package:whispers_of_joppa/domain/unlocks.dart';
import 'package:whispers_of_joppa/features/orders/orders_controller.dart';
import 'package:whispers_of_joppa/features/story/story_controller.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';

/// Connects the story's progress to the orders and the board. Runs at once
/// (so a loaded game is brought up to date) and again whenever a task
/// is done. A generator that finds no free cell is tried again each time the
/// board changes.
void wireChapters({
  required BoardGame game,
  required OrdersController orders,
  required StoryController story,
  required List<StartingGenerator> boardGenerators,
  required Map<String, GeneratorModel> generators,

  /// The player's level, and what announces a change in it.
  required int Function() level,
  required Listenable levelChanged,
}) {
  int reached() => chapterReached(story.chapters, story.completedTasks.toSet());
  var waiting = false;

  void sync() {
    final owed = generatorsOwed(
      boardGenerators,
      {for (final p in game.generatorPlacements) p.gen.generatorId},
      reached(),
      level: level(),
    );
    waiting = false;
    for (final g in owed) {
      final gen = generators[g.generatorId];
      if (gen == null) continue;
      // It arrives at the level the player's other generators have all
      // reached (a purchase may have raised them), never behind them.
      final startAt = lowestLevel([
        for (final p in game.generatorPlacements) p.gen.level,
      ]);
      if (!game.addGenerator(gen.atLevel(startAt), g.col, g.row)) {
        waiting = true;
      }
    }
    orders.refill();
  }

  orders.chapterReached = reached;
  story.addListener(sync);
  levelChanged.addListener(sync);
  game.boardChanged.addListener(() {
    if (waiting) sync();
  });
  sync();
}
