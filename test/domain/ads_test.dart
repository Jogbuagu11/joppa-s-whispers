import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/ads.dart';
import 'package:whispers_of_joppa/domain/economy.dart';

EconomyConfig _config({int cap = 5, int bonus = 20}) => EconomyConfig(
  maxManna: 100,
  mannaRegenSeconds: 120,
  generatorTapCost: 1,
  orderTalentsPerTier: 5,
  orderSlots: 3,
  tutorialFreeTaps: 12,
  mannaRefillBasePearls: 10,
  basketSlotBasePearls: 10,
  orderSkipCooldownSeconds: 1800,
  rewardedAdMannaBonus: bonus,
  rewardedAdMannaDailyCap: cap,
  rewardedAdDoubleRewardDailyCap: 3,
);

void main() {
  final noon = DateTime(2026, 10, 5, 12);
  final lateNight = DateTime(2026, 10, 5, 23, 59);
  final nextDay = DateTime(2026, 10, 6, 0, 1);

  test('dayStamp is the calendar day, zero padded', () {
    expect(dayStamp(DateTime(2026, 3, 7, 9)), '2026-03-07');
    expect(dayStamp(noon), dayStamp(lateNight));
    expect(dayStamp(noon), isNot(dayStamp(nextDay)));
  });

  test('a new player has the whole allowance', () {
    expect(mannaAdsLeftToday(_config(), const AdTally(), noon), 5);
  });

  test('each ad watched uses one of the day\'s allowance', () {
    var tally = const AdTally();
    for (var i = 1; i <= 5; i++) {
      tally = afterMannaAd(tally, noon);
      expect(mannaAdsWatchedToday(tally, noon), i);
      expect(mannaAdsLeftToday(_config(), tally, noon), 5 - i);
    }
    expect(
      canOfferMannaAd(_config(), tally, lateNight, tutorialOver: true),
      isFalse,
    );
  });

  test('the allowance comes back the next day', () {
    var tally = const AdTally();
    for (var i = 0; i < 5; i++) {
      tally = afterMannaAd(tally, noon);
    }
    expect(mannaAdsLeftToday(_config(), tally, nextDay), 5);
    expect(
      canOfferMannaAd(_config(), tally, nextDay, tutorialOver: true),
      isTrue,
    );
    // The first ad of the new day starts a fresh count.
    final fresh = afterMannaAd(tally, nextDay);
    expect(fresh.day, '2026-10-06');
    expect(fresh.mannaAds, 1);
  });

  test('never offered during the tutorial', () {
    expect(
      canOfferMannaAd(_config(), const AdTally(), noon, tutorialOver: false),
      isFalse,
    );
    expect(
      canOfferMannaAd(_config(), const AdTally(), noon, tutorialOver: true),
      isTrue,
    );
  });

  test('never offered when content turns ads off', () {
    expect(
      canOfferMannaAd(
        _config(cap: 0),
        const AdTally(),
        noon,
        tutorialOver: true,
      ),
      isFalse,
    );
    expect(
      canOfferMannaAd(
        _config(bonus: 0),
        const AdTally(),
        noon,
        tutorialOver: true,
      ),
      isFalse,
    );
  });

  test('a nonsense tally never gives extra ads or goes negative', () {
    const tooMany = AdTally(day: '2026-10-05', mannaAds: 99);
    expect(mannaAdsLeftToday(_config(), tooMany, noon), 0);
    const negative = AdTally(day: '2026-10-05', mannaAds: -4);
    expect(mannaAdsLeftToday(_config(), negative, noon), 5);
  });
}
