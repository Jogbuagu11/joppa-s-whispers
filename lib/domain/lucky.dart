// The two small chance rules of the board (EXPANSION 20.4): the lucky boost
// (a boosted tap now and then lifts its item further) and the mystery bubble
// (a bubble whose item is only seen once it is kept). Both are drawn from
// the same lists the player is shown. Pure Dart.
import 'dart:math';

import 'package:whispers_of_joppa/domain/chance.dart';
import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';

/// One outcome and its share of the draw.
typedef _Step = ({int amount, int weight});

List<_Step> _steps(Object? json, String key) => [
  for (final step in json as List<dynamic>)
    (
      amount: (step as Map<String, dynamic>)[key] as int,
      weight: step['weight'] as int,
    ),
];

/// The outcomes as prizes named by [name], so they are listed and drawn
/// exactly like any other chance.
List<Prize> _asPrizes(List<_Step> steps, String Function(int amount) name) => [
  for (final step in steps)
    Prize(
      id: 'step_${step.amount}',
      name: name(step.amount),
      weight: step.weight,
    ),
];

int _draw(List<_Step> steps, Random? random) {
  final prizes = _asPrizes(steps, (amount) => '$amount');
  final drawn = drawPrize(prizes, paid: false, random: random);
  final at = drawn == null ? -1 : prizes.indexOf(drawn);
  return at < 0 ? steps.first.amount : steps[at].amount;
}

/// The lucky boost: with a boost on, a tap's lift is multiplied by a number
/// drawn from this list (usually 1: no luck).
class LuckyBoost {
  final List<_Step> _times;

  LuckyBoost.fromJson(Map<String, dynamic> json)
    : _times = _steps(json['steps'], 'times');

  /// How many times the lift this tap gets.
  int draw({Random? random}) => _draw(_times, random);

  /// Every outcome with its chance, each named by [name].
  List<PrizeOdds> odds(String Function(int times) name) =>
      oddsFor(_asPrizes(_times, name), paid: false);

  /// [boost] with its lift multiplied [times] over.
  static GeneratorBoost lifted(GeneratorBoost boost, int times) =>
      times <= 1 || boost.tierBonus <= 0
      ? boost
      : GeneratorBoost(
          mannaTimes: boost.mannaTimes,
          tierBonus: boost.tierBonus * times,
        );
}

/// Mystery bubbles: some bubbles hide their item, which is the merged item
/// lifted by a number of tiers drawn from this list when it is kept.
class MysteryBubble {
  /// The share (0 to 1) of bubbles that are mystery ones.
  final double share;
  final List<_Step> _lifts;

  MysteryBubble.fromJson(Map<String, dynamic> json)
    : share = (json['share'] as num).toDouble(),
      _lifts = _steps(json['lifts'], 'tiers');

  /// The most tiers a mystery bubble can lift its item.
  int get largestLift => _lifts.fold<int>(
    0,
    (most, step) => step.amount > most ? step.amount : most,
  );

  /// How many tiers above the merged item the hidden item is.
  int draw({Random? random}) => _draw(_lifts, random);

  /// Every outcome with its chance, each named by [name].
  List<PrizeOdds> odds(String Function(int tiers) name) =>
      oddsFor(_asPrizes(_lifts, name), paid: false);
}

/// The item [tiers] above [item] in its chain, or the top of the chain if
/// that is nearer.
String liftedItemId(
  ItemModel item,
  int tiers,
  Map<String, ChainTierData> chains,
) {
  for (
    var tier = item.tier + (tiers < 0 ? 0 : tiers);
    tier > item.tier;
    tier--
  ) {
    final id = resolveSpawnedItemId(item.chainId, tier, chains);
    if (id != null) return id;
  }
  return item.itemId;
}
