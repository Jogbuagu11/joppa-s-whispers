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

/// Whether the banner under the board may be shown: never during the
/// tutorial, never to a player who has bought anything, and not in a game
/// played from memory only.
bool bannerAllowed({
  required bool tutorialOver,
  required bool hasPaid,
  required bool downgraded,
}) => tutorialOver && !hasPaid && !downgraded;

/// The height kept for the banner (a standard 320 by 50 one).
const bannerHeight = 50.0;

/// Empty room kept between the board and the banner, so a move on the
/// board's bottom row is not a tap on an ad by mistake.
const bannerGap = 6.0;

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
