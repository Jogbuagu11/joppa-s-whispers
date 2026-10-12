// Giving things from the board away: food for Shadow, items for an order
// quest. Each takes the item off the board first, records what was given,
// and only then hands over anything earned.
import 'package:whispers_of_joppa/app/board_inventory.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/order_quests.dart';
import 'package:whispers_of_joppa/domain/pet.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';
import 'package:whispers_of_joppa/features/events/pet_screen.dart';
import 'package:whispers_of_joppa/features/orders/order_quests_screen.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

/// Feeds [item] to Shadow. Returns what to tell the player ('' if there
/// is nothing to tell, or the item was not on the board).
String petFeedItem({
  required Pet pet,
  required ItemModel item,
  required BoardInventory board,
  required SaveExtras extras,
  required void Function(PassReward reward) grant,
  required Map<String, String> text,
  required String Function(PassReward reward) rewardWords,
}) {
  if (!board.removeItems({item.itemId: 1})) return '';
  final fed = petAfterFeed(
    pet,
    PetState.fromJson(extras.read(petRecord)),
    item.tier,
  );
  // Recorded before any gift is handed over.
  extras.write(petRecord, fed.state.toJson());
  fed.gifts.forEach(grant);
  return [
    for (final gift in fed.gifts)
      (text['gift'] ?? '').replaceAll('{reward}', rewardWords(gift)),
    for (final look in fed.opened)
      (text['new_look'] ?? '').replaceAll('{name}', look.name),
  ].join('\n');
}

/// Gives one [itemId] from the board to [quest]. Returns what to tell the
/// player ('' if there is nothing to tell, or nothing was given).
String questGiveItem({
  required OrderQuest quest,
  required String itemId,
  required BoardInventory board,
  required SaveExtras extras,
  required void Function(PassReward reward) grant,
  required Map<String, String> text,
  required String Function(PassReward reward) rewardWords,
}) {
  final gave = questGive(
    quest,
    QuestsState.fromJson(extras.read(questsRecord)),
    itemId,
  );
  if (gave == null || !board.removeItems({itemId: 1})) return '';
  // Recorded before the reward is handed over.
  extras.write(questsRecord, gave.state.toJson());
  if (!gave.finished) return '';
  grant(quest.reward);
  return (text['finished'] ?? '').replaceAll(
    '{reward}',
    rewardWords(quest.reward),
  );
}

/// Pays any quest that needs nothing more but was never paid (its needs
/// were made smaller by newer content). Returns the quests paid.
List<OrderQuest> questsSettle({
  required List<OrderQuest> quests,
  required SaveExtras extras,
  required void Function(PassReward reward) grant,
}) {
  final state = QuestsState.fromJson(extras.read(questsRecord));
  final due = [
    for (final quest in quests)
      if (!questDone(quest, state) &&
          state.given.containsKey(quest.id) &&
          questLeft(quest, state).values.every((n) => n == 0))
        quest,
  ];
  if (due.isEmpty) return due;
  extras.write(
    questsRecord,
    QuestsState(
      given: state.given,
      paid: {...state.paid, for (final quest in due) quest.id},
    ).toJson(),
  );
  for (final quest in due) {
    grant(quest.reward);
  }
  return due;
}
