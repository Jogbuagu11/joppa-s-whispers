// Economy rules — pure Dart, fully unit tested.
import 'package:whispers_of_joppa/domain/models.dart';

/// All economy parameters loaded from content/economy.json.
class EconomyConfig {
  final int maxManna;
  final int mannaRegenSeconds;
  final int generatorTapCost;
  final int orderTalentsPerTier;
  final int orderSlots;
  final int tutorialFreeTaps;
  final int mannaRefillBasePearls;
  final int basketSlotBasePearls;
  final int orderSkipCooldownSeconds;
  final int rewardedAdMannaBonus;
  final int rewardedAdMannaDailyCap;
  final int rewardedAdDoubleRewardDailyCap;

  const EconomyConfig({
    required this.maxManna,
    required this.mannaRegenSeconds,
    required this.generatorTapCost,
    required this.orderTalentsPerTier,
    required this.orderSlots,
    required this.tutorialFreeTaps,
    required this.mannaRefillBasePearls,
    required this.basketSlotBasePearls,
    required this.orderSkipCooldownSeconds,
    required this.rewardedAdMannaBonus,
    required this.rewardedAdMannaDailyCap,
    required this.rewardedAdDoubleRewardDailyCap,
  });

  factory EconomyConfig.fromJson(Map<String, dynamic> json) => EconomyConfig(
    maxManna: json['max_manna'] as int,
    mannaRegenSeconds: json['manna_regen_seconds'] as int,
    generatorTapCost: json['generator_tap_cost'] as int,
    orderTalentsPerTier: json['order_talents_per_tier'] as int,
    orderSlots: json['order_slots'] as int,
    tutorialFreeTaps: json['tutorial_free_taps'] as int,
    mannaRefillBasePearls: json['manna_refill_base_pearls'] as int,
    basketSlotBasePearls: json['basket_slot_base_pearls'] as int,
    orderSkipCooldownSeconds: json['order_skip_cooldown_seconds'] as int,
    rewardedAdMannaBonus: json['rewarded_ad_manna_bonus'] as int,
    rewardedAdMannaDailyCap: json['rewarded_ad_manna_daily_cap'] as int,
    rewardedAdDoubleRewardDailyCap:
        json['rewarded_ad_double_reward_daily_cap'] as int,
  );
}

/// Talents earned for selling an item (set per item in content/chains.json).
int sellValue(ItemModel item) => item.sell;

/// Order reward in talents: sum of item tiers × the multiplier from content.
int orderRewardTalents(EconomyConfig config, List<int> itemTiers) =>
    itemTiers.fold(0, (sum, t) => sum + t) * config.orderTalentsPerTier;

/// Pearl cost for the Nth Manna refill today (0-indexed refill count).
int mannaRefillCost(EconomyConfig config, int refillsToday) {
  // Cost doubles each refill: 10, 20, 40, ...
  return config.mannaRefillBasePearls * (1 << refillsToday);
}

/// Manna regenerated since [lastRegenTime].
int mannaRegenerated(
  EconomyConfig config,
  int currentManna,
  DateTime lastRegenTime,
  DateTime now,
) {
  if (currentManna >= config.maxManna) return 0;
  final elapsed = now.difference(lastRegenTime).inSeconds;
  return (elapsed ~/ config.mannaRegenSeconds).clamp(
    0,
    config.maxManna - currentManna,
  );
}

/// Manna and the moment its regen clock last ticked.
class MannaState {
  final int manna;
  final DateTime lastRegen;

  const MannaState({required this.manna, required this.lastRegen});
}

/// Adds any Manna earned between [state.lastRegen] and [now].
/// Time left over towards the next Manna is kept; a full bar resets the clock.
MannaState applyMannaRegen(
  EconomyConfig config,
  MannaState state,
  DateTime now,
) {
  // A full bar, or a device clock that moved backwards, restarts the clock.
  if (state.manna >= config.maxManna || now.isBefore(state.lastRegen)) {
    return MannaState(manna: state.manna, lastRegen: now);
  }
  final gained = mannaRegenerated(config, state.manna, state.lastRegen, now);
  final manna = state.manna + gained;
  if (manna >= config.maxManna) return MannaState(manna: manna, lastRegen: now);
  return MannaState(
    manna: manna,
    lastRegen: state.lastRegen.add(
      Duration(seconds: gained * config.mannaRegenSeconds),
    ),
  );
}

/// Seconds until the next Manna arrives, or null when the bar is full.
int? secondsUntilNextManna(
  EconomyConfig config,
  MannaState state,
  DateTime now,
) {
  if (state.manna >= config.maxManna) return null;
  final elapsed = now.difference(state.lastRegen).inSeconds;
  return (config.mannaRegenSeconds - elapsed).clamp(
    0,
    config.mannaRegenSeconds,
  );
}

/// Formats a countdown as m:ss (for example 1:05).
String formatCountdown(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
