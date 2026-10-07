import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/comfort.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/features/orders/orders_controller.dart';
import 'package:whispers_of_joppa/features/story/story_controller.dart';
import 'package:whispers_of_joppa/game/board/board_feedback.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/manna_controller.dart';

import '../support/comfort_fakes.dart';

const _config = EconomyConfig(
  maxManna: 100,
  mannaRegenSeconds: 120,
  generatorTapCost: 1,
  orderTalentsPerTier: 5,
  orderSlots: 3,
  tutorialFreeTaps: 12,
  mannaRefillBasePearls: 10,
  basketSlotBasePearls: 10,
  orderSkipCooldownSeconds: 1800,
  rewardedAdMannaBonus: 20,
  rewardedAdMannaDailyCap: 5,
  rewardedAdDoubleRewardDailyCap: 3,
);
const _bread = ItemModel(
  itemId: 'bakery_02',
  chainId: 'bakery',
  tier: 2,
  name: 'Dough',
  asset: '',
);

BoardGame _game() => BoardGame(
  itemCatalog: const {},
  chainData: const {},
  generatorLevels: const {},
  generatorPlacements: const [],
  startingItems: const [],
  chainPlaceholderColors: const {},
  manna: MannaController(config: _config, startingManna: 10),
  onOutOfManna: () {},
);

void main() {
  late FakeFeedbackPlayer player;

  setUp(() => player = FakeFeedbackPlayer());

  test('a merge and a generator tap each make their own sound', () {
    final game = _game();
    attachFeedback(fakeComfort(player), game);
    game.onMerged?.call(_bread);
    game.onGeneratorSpawn?.call(wasFree: false);
    expect(player.sounds, [GameCue.merge, GameCue.spawn]);
    expect(player.haptics, [HapticStrength.medium, HapticStrength.light]);
  });

  test('hooks already on the board keep working, and run first', () {
    final game = _game();
    final seen = <String>[];
    game.onMerged = (item) => seen.add('merged ${item.itemId}');
    game.onGeneratorSpawn = ({required bool wasFree}) =>
        seen.add('spawn ${player.sounds.length}');
    attachFeedback(fakeComfort(player), game);
    game.onMerged?.call(_bread);
    game.onGeneratorSpawn?.call(wasFree: true);
    // The earlier spawn hook ran before the spawn sound was asked for.
    expect(seen, ['merged bakery_02', 'spawn 1']);
    expect(player.sounds, hasLength(2));
  });

  test('a reward chimes until the board is closed', () {
    final game = _game();
    final rewards = ValueNotifier<int>(0);
    final quiet = attachFeedback(fakeComfort(player), game, rewards: rewards);
    rewards.value = 1;
    expect(player.sounds, [GameCue.reward]);
    quiet();
    rewards.value = 2;
    expect(player.sounds, [GameCue.reward]);
  });

  test('tier numbers follow the switch until the board is closed', () async {
    final game = _game();
    final comfort = fakeComfort(player);
    final quiet = attachFeedback(comfort, game);
    expect(game.showTierNumbers, isFalse);
    await comfort.setTierNumbers(true);
    expect(game.showTierNumbers, isTrue);
    quiet();
    await comfort.setTierNumbers(false);
    expect(game.showTierNumbers, isTrue);
  });

  test('a board opened with tier numbers on starts with them on', () async {
    final comfort = fakeComfort(player);
    await comfort.setTierNumbers(true);
    final game = _game();
    attachFeedback(comfort, game);
    expect(game.showTierNumbers, isTrue);
  });

  test('a merge that wins a reward plays the reward alone', () {
    final game = _game();
    final rewards = ValueNotifier<int>(0);
    game.onMerged = (item) {
      if (item.tier == 2) rewards.value++;
    };
    attachFeedback(fakeComfort(player), game, rewards: rewards);
    game.onMerged?.call(_bread);
    expect(player.sounds, [GameCue.reward]);
    // The next, ordinary merge sounds like a merge again.
    game.onMerged?.call(
      const ItemModel(
        itemId: 'bakery_03',
        chainId: 'bakery',
        tier: 3,
        name: 'Loaf',
        asset: '',
      ),
    );
    expect(player.sounds, [GameCue.reward, GameCue.merge]);
  });

  test('a delivered order and a finished task each have their sound', () {
    final game = _game();
    final orders = OrdersController(
      config: _config,
      board: game,
      orders: const [],
    );
    final story = StoryController(
      chapters: const [],
      blessings: () => 0,
      spendBlessings: (_) => true,
      wallet: ValueNotifier<int>(0),
    );
    final seen = <String>[];
    orders.onDelivered = seen.add;
    attachFeedback(fakeComfort(player), game, orders: orders, story: story);
    orders.onDelivered?.call('order_1');
    story.onTaskDone?.call('task_1');
    expect(seen, ['order_1']);
    expect(player.sounds, [GameCue.deliver, GameCue.task]);
    expect(player.haptics, [HapticStrength.heavy, HapticStrength.heavy]);
  });
}
