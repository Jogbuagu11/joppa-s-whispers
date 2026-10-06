import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/ads.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/features/ads/ad_rewards_controller.dart';

import '../support/ad_fakes.dart';

const _config = EconomyConfig(
  maxManna: 100,
  mannaRegenSeconds: 120,
  generatorTapCost: 1,
  orderTalentsPerTier: 5,
  orderSlots: 3,
  tutorialFreeTaps: 12,
  mannaRefillBasePearls: 10,
  basketSlotBasePearls: 10,
  orderSkipCooldownSeconds: 1800,
  rewardedAdMannaBonus: 20,
  rewardedAdMannaDailyCap: 2,
  rewardedAdDoubleRewardDailyCap: 3,
);

void main() {
  late FakeAdService service;
  late int manna;
  late bool tutorialOver;
  late DateTime now;

  AdRewardsController make({
    AdTally tally = const AdTally(),
    bool attach = true,
  }) {
    final c = AdRewardsController(
      config: _config,
      addManna: (n) => manna += n,
      tutorialOver: () => tutorialOver,
      startingTally: tally,
      clock: () => now,
    );
    if (attach) c.service = service;
    return c;
  }

  setUp(() {
    service = FakeAdService();
    manna = 0;
    tutorialOver = true;
    now = DateTime(2026, 10, 5, 12);
  });

  test('a watched ad gives the Manna and uses one of today\'s ads', () async {
    final c = make();
    expect(c.mannaAdOffered, isTrue);
    expect(await c.watchForManna(), isTrue);
    expect(manna, 20);
    expect(c.mannaAdsLeft, 1);
    expect(c.tally.day, '2026-10-05');
  });

  test('an ad closed early gives nothing and uses nothing', () async {
    service.watchedToEnd = false;
    final c = make();
    expect(await c.watchForManna(), isFalse);
    expect(manna, 0);
    expect(c.mannaAdsLeft, 2);
  });

  test(
    'stops being offered at the daily limit, and returns next day',
    () async {
      final c = make();
      await c.watchForManna();
      await c.watchForManna();
      expect(c.mannaAdOffered, isFalse);
      expect(await c.watchForManna(), isFalse);
      expect(manna, 40);
      expect(service.shown, 2);
      now = DateTime(2026, 10, 6, 8);
      expect(c.mannaAdOffered, isTrue);
    },
  );

  test('not offered when no ad is loaded', () async {
    service.isReady = false;
    final c = make();
    expect(c.mannaAdOffered, isFalse);
    expect(await c.watchForManna(), isFalse);
    expect(service.shown, 0);
  });

  test('not offered where ads are not set up', () async {
    final c = make(attach: false);
    expect(c.mannaAdOffered, isFalse);
    expect(await c.watchForManna(), isFalse);
  });

  test('not offered during the tutorial', () {
    tutorialOver = false;
    expect(make().mannaAdOffered, isFalse);
  });

  test('tells listeners when an ad becomes ready', () {
    service.isReady = false;
    final c = make();
    var told = 0;
    c.addListener(() => told++);
    service.isReady = true;
    expect(told, 1);
    expect(c.mannaAdOffered, isTrue);
  });

  test('an ad that breaks gives nothing and can be tried again', () async {
    service.throwOnShow = true;
    final c = make();
    expect(await c.watchForManna(), isFalse);
    expect(manna, 0);
    service.throwOnShow = false;
    expect(c.mannaAdOffered, isTrue);
    expect(await c.watchForManna(), isTrue);
  });

  test('attaching starts the service; the saved count is restored', () {
    final c = make(tally: const AdTally(day: '2026-10-05', mannaAds: 2));
    expect(service.starts, 1);
    expect(c.mannaAdsLeft, 0);
    expect(c.mannaAdOffered, isFalse);
  });

  test('a double tap shows one ad and gives one reward', () async {
    service.hold = Completer<void>();
    final c = make();
    final first = c.watchForManna();
    final second = c.watchForManna();
    expect(c.mannaAdOffered, isFalse);
    service.hold?.complete();
    expect(await first, isTrue);
    expect(await second, isFalse);
    expect(service.shown, 1);
    expect(manna, 20);
  });

  test(
    'a game closed while the ad plays gets nothing and does not crash',
    () async {
      service.hold = Completer<void>();
      final c = make();
      final watching = c.watchForManna();
      c.dispose();
      service.hold?.complete();
      expect(await watching, isFalse);
      expect(manna, 0);
    },
  );

  test('only a watched ad counts as a change worth saving', () async {
    service.isReady = false;
    final c = make();
    var changes = 0;
    c.tallyChanged.addListener(() => changes++);
    service.isReady = true;
    expect(changes, 0);
    service.watchedToEnd = false;
    await c.watchForManna();
    expect(changes, 0);
    service.watchedToEnd = true;
    await c.watchForManna();
    expect(changes, 1);
  });
}
