// Economy rules — pure Dart, fully unit tested.

/// All economy parameters loaded from content/economy.json.
class EconomyConfig {
  final int maxManna;
  final int mannaRegenSeconds;
  final int generatorTapCost;
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
        mannaRefillBasePearls: json['manna_refill_base_pearls'] as int,
        basketSlotBasePearls: json['basket_slot_base_pearls'] as int,
        orderSkipCooldownSeconds: json['order_skip_cooldown_seconds'] as int,
        rewardedAdMannaBonus: json['rewarded_ad_manna_bonus'] as int,
        rewardedAdMannaDailyCap: json['rewarded_ad_manna_daily_cap'] as int,
        rewardedAdDoubleRewardDailyCap:
            json['rewarded_ad_double_reward_daily_cap'] as int,
      );
}

/// Sell value for an item of a given tier.
int sellValue(int tier) => tier * 2;

/// Order reward in talents (sum of item tiers × 5).
int orderRewardTalents(List<int> itemTiers) =>
    itemTiers.fold(0, (sum, t) => sum + t) * 5;

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
  return (elapsed ~/ config.mannaRegenSeconds)
      .clamp(0, config.maxManna - currentManna);
}
