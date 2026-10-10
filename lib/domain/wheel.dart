// The Blessing Wheel (EXPANSION 20.4): one free spin a day, more for an ad,
// more again for Pearls at a price that rises through the day. Pure Dart.
import 'package:whispers_of_joppa/domain/ads.dart';
import 'package:whispers_of_joppa/domain/chance.dart';

class WheelRules {
  final int freeSpinsPerDay;
  final int adSpinsPerDay;

  /// The price of the day's first Pearl spin, and how much each further
  /// one that day adds.
  final int pearlSpinBase;
  final int pearlSpinStep;
  final int pearlSpinsPerDay;
  final List<Prize> prizes;

  const WheelRules({
    required this.freeSpinsPerDay,
    required this.adSpinsPerDay,
    required this.pearlSpinBase,
    required this.pearlSpinStep,
    required this.pearlSpinsPerDay,
    required this.prizes,
  });

  factory WheelRules.fromJson(Map<String, dynamic> json) => WheelRules(
    freeSpinsPerDay: json['free_spins_per_day'] as int,
    adSpinsPerDay: json['ad_spins_per_day'] as int,
    pearlSpinBase: json['pearl_spin_base'] as int,
    pearlSpinStep: json['pearl_spin_step'] as int,
    pearlSpinsPerDay: json['pearl_spins_per_day'] as int,
    prizes: [
      for (final p in json['prizes'] as List<dynamic>)
        Prize.fromJson(p as Map<String, dynamic>),
    ],
  );
}

/// How a spin is paid for.
enum SpinKind { free, ad, pearls }

/// The spins taken on one day.
class WheelTally {
  final String day;
  final int free;
  final int ad;
  final int pearls;

  const WheelTally({
    this.day = '',
    this.free = 0,
    this.ad = 0,
    this.pearls = 0,
  });

  /// Reads what was saved; anything missing or odd counts as nothing.
  factory WheelTally.fromJson(Map<String, dynamic>? json) {
    int count(String key) => switch (json?[key]) {
      final int n when n > 0 => n,
      _ => 0,
    };
    return WheelTally(
      day: switch (json?['day']) {
        final String day => day,
        _ => '',
      },
      free: count('free'),
      ad: count('ad'),
      pearls: count('pearls'),
    );
  }

  Map<String, dynamic> toJson() => {
    'day': day,
    'free': free,
    'ad': ad,
    'pearls': pearls,
  };

  /// This tally as it stands on the day of [now]: a new day starts at
  /// nothing.
  WheelTally on(DateTime now) =>
      day == dayStamp(now) ? this : WheelTally(day: dayStamp(now));
}

int freeSpinsLeft(WheelRules rules, WheelTally tally, DateTime now) =>
    _left(rules.freeSpinsPerDay, tally.on(now).free);

int adSpinsLeft(WheelRules rules, WheelTally tally, DateTime now) =>
    _left(rules.adSpinsPerDay, tally.on(now).ad);

int pearlSpinsLeft(WheelRules rules, WheelTally tally, DateTime now) =>
    _left(rules.pearlSpinsPerDay, tally.on(now).pearls);

int _left(int allowed, int taken) => taken >= allowed ? 0 : allowed - taken;

/// The price in Pearls of the next Pearl spin today, or null if the day's
/// Pearl spins are used up.
int? pearlSpinCost(WheelRules rules, WheelTally tally, DateTime now) =>
    pearlSpinsLeft(rules, tally, now) == 0
    ? null
    : rules.pearlSpinBase + rules.pearlSpinStep * tally.on(now).pearls;

/// The tally after one more spin of [kind].
WheelTally afterSpin(WheelTally tally, SpinKind kind, DateTime now) {
  final today = tally.on(now);
  return WheelTally(
    day: today.day,
    free: today.free + (kind == SpinKind.free ? 1 : 0),
    ad: today.ad + (kind == SpinKind.ad ? 1 : 0),
    pearls: today.pearls + (kind == SpinKind.pearls ? 1 : 0),
  );
}
