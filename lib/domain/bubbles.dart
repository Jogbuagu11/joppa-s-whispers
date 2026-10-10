// Bubbles (EXPANSION 20.1): now and then a merge leaves a bubble holding a
// copy of the item just made. Pure Dart.
import 'dart:math';

import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';

/// The numbers bubbles go by, from content/levels.json.
class BubbleRules {
  /// The chance (0 to 1) that a merge leaves a bubble.
  final double chance;

  /// The chance that a bubble holds the next tier up instead of a copy.
  final double higherChance;

  /// How long a bubble floats before it pops by itself.
  final int seconds;

  /// Pearls to keep the item, per tier of the item.
  final int pearlsPerTier;

  /// The highest tier that may be kept by watching an ad instead.
  final int adMaxTier;

  /// Talents given, per tier, when a bubble pops by itself.
  final int talentsPerTier;

  /// The most bubbles afloat at once.
  final int maxAtOnce;

  const BubbleRules({
    required this.chance,
    required this.higherChance,
    required this.seconds,
    required this.pearlsPerTier,
    required this.adMaxTier,
    required this.talentsPerTier,
    required this.maxAtOnce,
  });

  /// Null unless [json] holds every number.
  static BubbleRules? fromJson(Object? json) => switch (json) {
    {
      'chance': final num chance,
      'higher_chance': final num higher,
      'seconds': final int seconds,
      'pearls_per_tier': final int pearls,
      'ad_max_tier': final int adMaxTier,
      'talents_per_tier': final int talents,
      'max_at_once': final int most,
    } =>
      BubbleRules(
        chance: chance.toDouble(),
        higherChance: higher.toDouble(),
        seconds: seconds,
        pearlsPerTier: pearls,
        adMaxTier: adMaxTier,
        talentsPerTier: talents,
        maxAtOnce: most,
      ),
    _ => null,
  };

  int pearlsFor(int tier) => pearlsPerTier * tier;
  int talentsFor(int tier) => talentsPerTier * tier;
  bool adAllowedFor(int tier) => tier <= adMaxTier;
}

/// The item a bubble holds after [merged] was made, or null if this merge
/// leaves no bubble. Usually a copy; now and then the next tier up (never
/// past the top of the chain).
String? bubbleAfterMerge(
  ItemModel merged,
  BubbleRules rules,
  Map<String, ChainTierData> chains, {
  Random? random,
}) {
  final rng = random ?? Random();
  if (rng.nextDouble() >= rules.chance) return null;
  if (rng.nextDouble() < rules.higherChance) {
    final higher = resolveSpawnedItemId(
      merged.chainId,
      merged.tier + 1,
      chains,
    );
    if (higher != null) return higher;
  }
  return merged.itemId;
}

/// Adds a line to [problems] for anything wrong with a level unlock's
/// `bubble` record.
void checkBubbleRules(String what, Object? json, List<String> problems) {
  if (json == null) return;
  final rules = BubbleRules.fromJson(json);
  if (rules == null) {
    problems.add(
      '$what: a bubble needs chance, higher_chance, seconds, '
      'pearls_per_tier, ad_max_tier, talents_per_tier and max_at_once',
    );
    return;
  }
  if (rules.chance <= 0 || rules.chance > 0.5) {
    problems.add('$what: bubble chance must be above 0 and at most 0.5');
  }
  if (rules.higherChance < 0 || rules.higherChance > 1) {
    problems.add('$what: bubble higher_chance must be between 0 and 1');
  }
  if (rules.seconds < 10) {
    problems.add('$what: a bubble must float for at least 10 seconds');
  }
  if (rules.pearlsPerTier < 1) {
    problems.add('$what: bubble pearls_per_tier must be 1 or more');
  }
  if (rules.adMaxTier < 0 || rules.talentsPerTier < 0) {
    problems.add(
      '$what: bubble ad_max_tier and talents_per_tier cannot be '
      'below 0',
    );
  }
  if (rules.maxAtOnce < 1) {
    problems.add('$what: bubble max_at_once must be 1 or more');
  }
}
