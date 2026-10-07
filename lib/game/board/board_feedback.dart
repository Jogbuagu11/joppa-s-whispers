// Watches a running board and asks for a sound and a vibration when
// something happens on it. It only listens: nothing here changes the game.
import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/domain/comfort.dart';
import 'package:whispers_of_joppa/features/orders/orders_controller.dart';
import 'package:whispers_of_joppa/features/settings/comfort_controller.dart';
import 'package:whispers_of_joppa/features/story/story_controller.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';

/// Starts sounds and vibrations for [game] (the main board or an event
/// board), and keeps its tier numbers in step with the player's choice.
/// Hooks already on the game keep working: each is called first. Call the
/// returned function when the board closes.
VoidCallback attachFeedback(
  ComfortController comfort,
  BoardGame game, {
  OrdersController? orders,
  StoryController? story,
  Listenable? rewards,
}) {
  // A merge that wins a reward (on an event board) plays the reward alone,
  // not two sounds on top of each other.
  var rewarded = false;
  final onMerged = game.onMerged;
  game.onMerged = (item) {
    rewarded = false;
    onMerged?.call(item);
    if (!rewarded) comfort.cue(GameCue.merge);
  };
  final onSpawn = game.onGeneratorSpawn;
  game.onGeneratorSpawn = ({required bool wasFree}) {
    onSpawn?.call(wasFree: wasFree);
    comfort.cue(GameCue.spawn);
  };
  if (orders != null) {
    final onDelivered = orders.onDelivered;
    orders.onDelivered = (id) {
      onDelivered?.call(id);
      comfort.cue(GameCue.deliver);
    };
  }
  if (story != null) {
    final onTaskDone = story.onTaskDone;
    story.onTaskDone = (id) {
      onTaskDone?.call(id);
      comfort.cue(GameCue.task);
    };
  }

  void onReward() {
    rewarded = true;
    comfort.cue(GameCue.reward);
  }

  void onPrefs() => game.showTierNumbers = comfort.prefs.tierNumbers;
  onPrefs();
  comfort.addListener(onPrefs);
  rewards?.addListener(onReward);
  return () {
    comfort.removeListener(onPrefs);
    rewards?.removeListener(onReward);
  };
}
