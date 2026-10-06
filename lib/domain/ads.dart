// Rewarded-ad rules: how many a player may watch in a day. Pure Dart, fully
// unit tested.
import 'package:whispers_of_joppa/domain/economy.dart';

/// How many Manna ads were watched on one calendar day (the phone's own day).
class AdTally {
  /// The day counted, as yyyy-mm-dd, or empty if no ad was ever watched.
  final String day;
  final int mannaAds;

  const AdTally({this.day = '', this.mannaAds = 0});
}

/// The calendar day of [now] as yyyy-mm-dd.
String dayStamp(DateTime now) =>
    '${now.year.toString().padLeft(4, '0')}-'
    '${now.month.toString().padLeft(2, '0')}-'
    '${now.day.toString().padLeft(2, '0')}';

/// Manna ads already watched today. A tally from another day counts as none.
int mannaAdsWatchedToday(AdTally tally, DateTime now) =>
    tally.day == dayStamp(now) && tally.mannaAds > 0 ? tally.mannaAds : 0;

/// Manna ads still allowed today.
int mannaAdsLeftToday(EconomyConfig config, AdTally tally, DateTime now) {
  final left =
      config.rewardedAdMannaDailyCap - mannaAdsWatchedToday(tally, now);
  return left < 0 ? 0 : left;
}

/// Whether a Manna ad may be offered: never during the tutorial, and only
/// while today's allowance lasts.
bool canOfferMannaAd(
  EconomyConfig config,
  AdTally tally,
  DateTime now, {
  required bool tutorialOver,
}) =>
    tutorialOver &&
    config.rewardedAdMannaBonus > 0 &&
    mannaAdsLeftToday(config, tally, now) > 0;

/// The tally after one more Manna ad is watched at [now].
AdTally afterMannaAd(AdTally tally, DateTime now) =>
    AdTally(day: dayStamp(now), mannaAds: mannaAdsWatchedToday(tally, now) + 1);
