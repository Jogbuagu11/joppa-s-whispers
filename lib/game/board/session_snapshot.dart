// Turns the live pieces of a play session into the state that gets saved.
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/features/orders/orders_controller.dart';
import 'package:whispers_of_joppa/features/story/story_controller.dart';
import 'package:whispers_of_joppa/features/story/tutorial_controller.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/manna_controller.dart';

/// Collects the saveable state from the pieces of a session.
SaveState buildSnapshot({
  required BoardGame game,
  required MannaController manna,
  required OrdersController orders,
  required StoryController story,
  required TutorialController tutorial,
  required Set<String> endingsSeen,
}) => SaveState(
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
  tutorialFreeTapsUsed: tutorial.freeTapsUsed,
  endingsSeen: endingsSeen.toList(),
  lastOrderSkip: orders.book.lastSkip,
);
