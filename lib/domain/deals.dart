// Daily deals in the shop (EXPANSION 21.1): each day one free gift and a
// few things for Pearls. Nothing here is left to chance: a deal says exactly
// what it gives. Pure Dart.
import 'package:whispers_of_joppa/domain/ads.dart';

/// One thing on offer for a day.
class DailyDeal {
  final String id;
  final String name;

  /// Its price in Pearls; 0 for the free gift.
  final int pearlPrice;
  final int manna;
  final int talents;
  final List<String> items;

  const DailyDeal({
    required this.id,
    required this.name,
    this.pearlPrice = 0,
    this.manna = 0,
    this.talents = 0,
    this.items = const [],
  });

  factory DailyDeal.fromJson(Map<String, dynamic> json) => DailyDeal(
    id: json['id'] as String,
    name: json['name'] as String,
    pearlPrice: json['pearl_price'] as int? ?? 0,
    manna: json['manna'] as int? ?? 0,
    talents: json['talents'] as int? ?? 0,
    items: List<String>.from(json['items'] as List<dynamic>? ?? const []),
  );

  bool get free => pearlPrice == 0;
}

class DealsConfig {
  /// The free gifts, one a day in turn.
  final List<DailyDeal> free;

  /// The Pearl deals, [pearlDealsPerDay] a day in turn.
  final List<DailyDeal> forPearls;
  final int pearlDealsPerDay;

  const DealsConfig({
    required this.free,
    required this.forPearls,
    required this.pearlDealsPerDay,
  });

  factory DealsConfig.fromJson(Map<String, dynamic> json) => DealsConfig(
    free: [
      for (final d in json['free'] as List<dynamic>)
        DailyDeal.fromJson(d as Map<String, dynamic>),
    ],
    forPearls: [
      for (final d in json['for_pearls'] as List<dynamic>)
        DailyDeal.fromJson(d as Map<String, dynamic>),
    ],
    pearlDealsPerDay: json['pearl_deals_per_day'] as int,
  );
}

/// The number of the day [now] falls on (the same all day, one more the
/// next), by the phone's own calendar.
int dayNumber(DateTime now) =>
    DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// The deals of the day of [now]: the free gift first, then the Pearl
/// deals. Each list is gone through in turn, day by day.
List<DailyDeal> dealsFor(DealsConfig config, DateTime now) {
  final day = dayNumber(now);
  final pearls = config.forPearls;
  final count = config.pearlDealsPerDay > pearls.length
      ? pearls.length
      : config.pearlDealsPerDay;
  return [
    if (config.free.isNotEmpty) config.free[day % config.free.length],
    for (var i = 0; i < count; i++)
      pearls[(day * config.pearlDealsPerDay + i) % pearls.length],
  ];
}

/// Which of a day's deals have been taken.
class DealsTally {
  final String day;
  final Set<String> taken;

  const DealsTally({this.day = '', this.taken = const {}});

  /// Reads what was saved; anything missing or odd counts as nothing.
  factory DealsTally.fromJson(Map<String, dynamic>? json) => DealsTally(
    day: switch (json?['day']) {
      final String day => day,
      _ => '',
    },
    taken: {
      if (json?['taken'] case final List<dynamic> ids)
        for (final id in ids)
          if (id is String) id,
    },
  );

  Map<String, dynamic> toJson() => {'day': day, 'taken': taken.toList()};

  /// This tally as it stands on the day of [now]: a new day starts empty.
  /// A clock set back to an earlier day does not: what was taken stays
  /// taken, so winding the phone's clock back and forth gives nothing.
  DealsTally on(DateTime now) =>
      dayStamp(now).compareTo(day) <= 0 ? this : DealsTally(day: dayStamp(now));

  bool hasTaken(DailyDeal deal, DateTime now) =>
      on(now).taken.contains(deal.id);

  /// The tally after [deal] is taken.
  DealsTally after(DailyDeal deal, DateTime now) {
    final today = on(now);
    return DealsTally(day: today.day, taken: {...today.taken, deal.id});
  }
}

/// Adds a line to [problems] for anything wrong with the daily deals.
void checkDeals(
  Object? json, {
  required Set<Object?> itemIds,
  required List<String> problems,
}) {
  if (json is! Map<String, dynamic>) {
    problems.add('Daily deals: missing or the wrong shape');
    return;
  }
  final perDay = json['pearl_deals_per_day'];
  if (perDay is! int || perDay < 0) {
    problems.add('Daily deals: pearl_deals_per_day must be 0 or more');
  }
  final seen = <Object?>{};
  for (final key in ['free', 'for_pearls']) {
    final deals = json[key];
    if (deals is! List<dynamic>) {
      problems.add('Daily deals: "$key" must be a list');
      continue;
    }
    for (final entry in deals) {
      final deal = entry as Map<String, dynamic>;
      final id = deal['id'];
      if (id is! String || id.isEmpty || !seen.add(id)) {
        problems.add('Daily deals: id "$id" is missing or used twice');
      }
      final name = deal['name'];
      if (name is! String || name.trim().isEmpty || name.length > 30) {
        problems.add('Daily deal $id: needs a name of 1 to 30 letters');
      }
      final price = deal['pearl_price'];
      if (key == 'free' ? price != null : (price is! int || price < 1)) {
        problems.add(
          key == 'free'
              ? 'Daily deal $id: a free gift has no price'
              : 'Daily deal $id: pearl_price must be 1 or more',
        );
      }
      var gives = 0;
      for (final amount in ['manna', 'talents']) {
        final value = deal[amount];
        if (value != null && (value is! int || value < 1)) {
          problems.add('Daily deal $id: $amount must be 1 or more');
        }
        if (value is int) gives += value;
      }
      for (final item in deal['items'] as List<dynamic>? ?? const []) {
        gives++;
        if (!itemIds.contains(item)) {
          problems.add('Daily deal $id: unknown item "$item"');
        }
      }
      if (gives == 0) problems.add('Daily deal $id: gives nothing');
    }
  }
}
