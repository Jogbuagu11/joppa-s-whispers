// Chance rewards (EXPANSION 20.4): prizes with published odds. The odds a
// player is shown and the odds a prize is drawn with come from the same
// table, by the same sum, so they cannot differ. Pure Dart.
import 'dart:math';

/// One thing that can be won.
class Prize {
  final String id;
  final String name;

  /// Its share of the draw: a prize of weight 2 comes twice as often as one
  /// of weight 1.
  final int weight;
  final int manna;
  final int talents;
  final int pearls;
  final List<String> items;
  final List<String> generators;

  /// True for a prize that is never given for a paid try. Pearls are only
  /// ever won on free tries: nobody stakes Pearls to win Pearls.
  final bool freeOnly;

  const Prize({
    required this.id,
    required this.name,
    required this.weight,
    this.manna = 0,
    this.talents = 0,
    this.pearls = 0,
    this.items = const [],
    this.generators = const [],
    this.freeOnly = false,
  });

  factory Prize.fromJson(Map<String, dynamic> json) => Prize(
    id: json['id'] as String,
    name: json['name'] as String,
    weight: json['weight'] as int,
    manna: json['manna'] as int? ?? 0,
    talents: json['talents'] as int? ?? 0,
    pearls: json['pearls'] as int? ?? 0,
    items: List<String>.from(json['items'] as List<dynamic>? ?? const []),
    generators: List<String>.from(
      json['generators'] as List<dynamic>? ?? const [],
    ),
    freeOnly: json['free_only'] as bool? ?? false,
  );

  bool get givesSomething =>
      manna > 0 ||
      talents > 0 ||
      pearls > 0 ||
      items.isNotEmpty ||
      generators.isNotEmpty;
}

/// A prize and the chance (0 to 1) of drawing it.
typedef PrizeOdds = ({Prize prize, double chance});

/// The prizes that can come on a try, each with its chance. A paid try
/// leaves out the free-only prizes; the chances always add up to 1.
List<PrizeOdds> oddsFor(List<Prize> prizes, {required bool paid}) {
  final open = [
    for (final p in prizes)
      if (p.weight > 0 && !(paid && p.freeOnly)) p,
  ];
  final total = open.fold<int>(0, (sum, p) => sum + p.weight);
  if (total <= 0) return const [];
  return [for (final p in open) (prize: p, chance: p.weight / total)];
}

/// Draws one prize by the odds of [oddsFor]; null if there is none to draw.
Prize? drawPrize(List<Prize> prizes, {required bool paid, Random? random}) {
  final odds = oddsFor(prizes, paid: paid);
  if (odds.isEmpty) return null;
  var roll = (random ?? Random()).nextDouble();
  for (final entry in odds) {
    roll -= entry.chance;
    if (roll < 0) return entry.prize;
  }
  // Only reachable through rounding at the very top of the range.
  return odds.last.prize;
}

/// A chance as the player reads it: "12.5%", "3%", "0.4%".
String formatChance(double chance) {
  final percent = chance * 100;
  final whole = percent == percent.roundToDouble();
  final text = percent.toStringAsFixed(whole ? 0 : (percent < 1 ? 2 : 1));
  return '$text%';
}

/// Whether random rewards may be bought (with Pearls) where the player is.
/// [countryCode] is the two-letter country of the phone's region setting;
/// [blocked] the countries whose law forbids paid random items.
bool paidChanceAllowed(String? countryCode, Set<String> blocked) =>
    countryCode == null || !blocked.contains(countryCode.toUpperCase());
