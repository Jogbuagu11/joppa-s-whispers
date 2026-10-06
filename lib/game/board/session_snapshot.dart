// Turns the live pieces of a play session into the state that gets saved.
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/domain/tutorial.dart';
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
  required int contentVersion,
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
  contentVersion: contentVersion,
  lastOrderSkip: orders.book.lastSkip,
);

/// Connects the tutorial to everything it watches: merges, generator taps,
/// orders delivered and tasks done. It also makes early taps free and keeps
/// the tutorial's orders from being skipped.
void wireTutorial({
  required BoardGame game,
  required OrdersController orders,
  required StoryController story,
  required TutorialController tutorial,
}) {
  game
    ..freeGeneratorTaps = (() => tutorial.freeManna)
    ..onMerge = (() =>
        tutorial.handle(const TutorialEvent(TutorialTrigger.merge)))
    ..onGeneratorSpawn = ({required bool wasFree}) {
      if (wasFree) tutorial.noteFreeTap();
      tutorial.handle(const TutorialEvent(TutorialTrigger.generatorTap));
    };
  orders
    ..skipAllowed = (() => tutorial.isOver)
    ..onDelivered = (id) =>
        tutorial.handle(TutorialEvent(TutorialTrigger.orderDelivered, id));
  story.onTaskDone = (id) =>
      tutorial.handle(TutorialEvent(TutorialTrigger.taskDone, id));
}
