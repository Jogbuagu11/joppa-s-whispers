// What the event screen needs for the season pass: the passes the player
// holds, the shop to buy one from, and how to hand over what a pass pays.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';
import 'package:whispers_of_joppa/features/events/season_pass_ledger.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

class EventPass {
  EventPass({
    required SaveExtras extras,
    required this.shop,
    required this.prices,
    required this.text,
    required this.premiumProduct,
    required this.plusProduct,
    required this.earnPearls,
    required this.giveItems,
    required this.itemName,
    this.onBuy,
  }) : ledger = SeasonPassLedger(extras),
       changes = extras;

  /// What reads the passes held out of each list of purchases the server
  /// sends, into the save's [extras].
  static void Function(List<PurchaseRecord> fromServer) reader(
    SaveExtras extras,
  ) => SeasonPassLedger(extras).serverRecords;

  final SeasonPassLedger ledger;

  /// Fires when the passes held may have changed (a purchase arrived).
  final Listenable changes;
  final PurchaseCoordinator? shop;

  /// The store's prices for the pass products (empty if it cannot be asked).
  final Future<Map<String, String>> Function() prices;

  /// The pass's words (content/offers.json, "season_pass").
  final Map<String, String> text;
  final String premiumProduct;
  final String plusProduct;
  final void Function(int amount) earnPearls;
  final void Function(List<String> itemIds) giveItems;
  final String Function(String itemId) itemName;
  final void Function(String productId)? onBuy;

  /// A reward in the game's own words ("5 Pearls + Hourglass").
  String words(PassReward reward) {
    String say(String key, int n) => (text[key] ?? '').replaceAll('{n}', '$n');
    return [
      if (reward.pearls > 0) say('pearls', reward.pearls),
      if (reward.manna > 0) say('manna', reward.manna),
      if (reward.talents > 0) say('talents', reward.talents),
      for (final id in reward.items) itemName(id),
    ].join(' + ');
  }

  /// Says what a pass has just paid, in the pass's own words.
  void announce(BuildContext context, List<PassReward> paid) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('event_pass_reward'),
          content: Text(paid.map(words).join('  ')),
          duration: const Duration(seconds: 3),
        ),
      );
}
