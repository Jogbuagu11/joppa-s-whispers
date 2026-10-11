// The season pass of an event (EXPANSION section 13): a free track everyone
// has, a Premium track of extra rewards, and Premium Plus, which adds bonus
// points and a reward track that goes on after the last milestone.
// Pure Dart, fully unit tested.
//
// Which tier a player HAS is decided by the server's purchase records (see
// passTier); what a tier gives as the player goes is worked out here.
import 'package:whispers_of_joppa/domain/purchases.dart';

enum PassTier { free, premium, plus }

/// What one step of a paid track gives.
class PassReward {
  final int pearls;
  final int manna;
  final int talents;
  final List<String> items;

  const PassReward({
    this.pearls = 0,
    this.manna = 0,
    this.talents = 0,
    this.items = const [],
  });

  /// Reads a reward; anything odd in it counts as nothing.
  factory PassReward.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return const PassReward();
    int amount(String key) => switch (json[key]) {
      final int n when n > 0 => n,
      _ => 0,
    };
    return PassReward(
      pearls: amount('pearls'),
      manna: amount('manna'),
      talents: amount('talents'),
      items: [
        if (json['items'] case final List<dynamic> ids)
          for (final id in ids)
            if (id is String) id,
      ],
    );
  }

  bool get isEmpty =>
      pearls == 0 && manna == 0 && talents == 0 && items.isEmpty;
}

/// An event's pass, from the event's own settings ("pass").
class SeasonPass {
  /// The Premium reward of each milestone, in the milestones' order.
  final List<PassReward> premium;

  /// Premium Plus: this many extra points for every hundred earned.
  final int plusBonusPercent;

  /// Premium Plus: past the last milestone, [endless] again for every this
  /// many points (0: no endless track).
  final int endlessEvery;
  final PassReward endless;

  const SeasonPass({
    required this.premium,
    this.plusBonusPercent = 0,
    this.endlessEvery = 0,
    this.endless = const PassReward(),
  });

  /// Null if the event has no pass.
  static SeasonPass? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final premium = [
      if (json['premium'] case final List<dynamic> list)
        for (final r in list) PassReward.fromJson(r),
    ];
    if (premium.isEmpty) return null;
    final plus = json['plus'];
    int amount(Object? value) => value is int && value > 0 ? value : 0;
    final endless = plus is Map<String, dynamic> ? plus['endless'] : null;
    return SeasonPass(
      premium: premium,
      plusBonusPercent: plus is Map<String, dynamic>
          ? amount(plus['bonus_percent'])
          : 0,
      endlessEvery: endless is Map<String, dynamic>
          ? amount(endless['every'])
          : 0,
      endless: PassReward.fromJson(endless),
    );
  }
}

/// A pass the server recorded a standing purchase of: which event it is
/// for, and whether it was the Plus product.
typedef PassPurchase = ({String eventId, bool plus});

/// The tier [purchases] give for [eventId]. Premium Plus is its own
/// product; a player who bought Premium twice for one event has paid as
/// much, and has Plus too.
PassTier passTier(Iterable<PassPurchase> purchases, String eventId) {
  var premiums = 0;
  for (final p in purchases) {
    if (p.eventId != eventId) continue;
    if (p.plus) return PassTier.plus;
    premiums++;
  }
  return premiums >= 2
      ? PassTier.plus
      : (premiums == 1 ? PassTier.premium : PassTier.free);
}

/// The points a player's [earned] points count as: Premium Plus adds its
/// bonus (also to points earned before it was bought).
int passPoints(int earned, PassTier tier, SeasonPass? pass) {
  if (earned <= 0) return 0;
  if (pass == null || tier != PassTier.plus) return earned;
  return earned + earned * pass.plusBonusPercent ~/ 100;
}

/// The Premium rewards now due: those of the milestones [reached] that
/// have not been paid ([alreadyPaid] of them have). Nothing without the
/// pass; bought late, everything reached so far is paid at once.
List<PassReward> premiumToPay(
  SeasonPass? pass,
  PassTier tier, {
  required int reached,
  required int alreadyPaid,
}) {
  if (pass == null || tier == PassTier.free) return const [];
  final upTo = reached < pass.premium.length ? reached : pass.premium.length;
  if (alreadyPaid < 0 || alreadyPaid >= upTo) return const [];
  return pass.premium.sublist(alreadyPaid, upTo);
}

/// How many steps of the endless track [points] have reached, past the
/// last milestone at [lastMilestone] points. Premium Plus only.
int endlessReached(
  SeasonPass? pass,
  PassTier tier, {
  required int points,
  required int lastMilestone,
}) {
  if (pass == null || tier != PassTier.plus) return 0;
  if (pass.endlessEvery <= 0 || pass.endless.isEmpty) return 0;
  final past = points - lastMilestone;
  return past <= 0 ? 0 : past ~/ pass.endlessEvery;
}

/// The store products that are a pass (content/offers.json, "season_pass"),
/// as products that can be bought again (one for each event) and give what
/// the server records.
Map<String, ProductModel> seasonPassProductsFrom(Object? offersJson) => {
  if (offersJson case {'season_pass': final Map<String, dynamic> pass})
    for (final key in const ['premium_product', 'plus_product'])
      if (pass[key] case final String id)
        id: ProductModel(id: id, consumable: true, reusable: true),
};

/// The passes among the server's records that stand (granted, not
/// refunded).
List<PassPurchase> standingPasses(Iterable<PurchaseRecord> fromServer) => [
  for (final record in fromServer)
    if (record.granted)
      if (record.grant?.passEventId case final String eventId)
        (eventId: eventId, plus: record.grant?.passPlus ?? false),
];
