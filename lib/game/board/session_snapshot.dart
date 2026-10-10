// Turns the live pieces of a play session into the state that gets saved.
import 'package:whispers_of_joppa/app/game_saver.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/domain/tutorial.dart';
import 'package:whispers_of_joppa/features/ads/ad_rewards_controller.dart';
import 'package:whispers_of_joppa/features/levels/level_controller.dart';
import 'package:whispers_of_joppa/features/orders/orders_controller.dart';
import 'package:whispers_of_joppa/features/shop/purchases_controller.dart';
import 'package:whispers_of_joppa/features/story/endings_tracker.dart';
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
  required EndingsTracker endings,
  required PurchasesController purchases,
  required AdRewardsController ads,
  required LevelController levels,
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
  endingsSeen: endings.seen,
  pearls: purchases.pearls,
  appliedTransactions: purchases.appliedTransactions,
  ownedProducts: purchases.ownedProducts,
  contentVersion: contentVersion,
  lastOrderSkip: orders.book.lastSkip,
  adDay: ads.tally.day,
  adMannaWatched: ads.tally.mannaAds,
  levelRewarded: levels.rewardedLevel,
);

/// The saver for a session: what it writes, and what makes it write.
GameSaver buildSaver({
  required SaveRepository repository,
  required BoardGame game,
  required MannaController manna,
  required OrdersController orders,
  required StoryController story,
  required TutorialController tutorial,
  required EndingsTracker endings,
  required PurchasesController purchases,
  required AdRewardsController ads,
  required LevelController levels,
  required int contentVersion,
}) => GameSaver(
  repository: repository,
  snapshot: () => buildSnapshot(
    game: game,
    manna: manna,
    orders: orders,
    story: story,
    tutorial: tutorial,
    endings: endings,
    purchases: purchases,
    ads: ads,
    levels: levels,
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
    levels,
  ],
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
