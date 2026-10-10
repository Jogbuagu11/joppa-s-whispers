import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/chance.dart';
import 'package:whispers_of_joppa/domain/wheel.dart';
import 'package:whispers_of_joppa/features/wheel/wheel_controller.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

const _rules = WheelRules(
  freeSpinsPerDay: 1,
  adSpinsPerDay: 1,
  pearlSpinBase: 5,
  pearlSpinStep: 5,
  pearlSpinsPerDay: 2,
  prizes: [
    Prize(id: 'pearls', name: '3 Pearls', weight: 1, pearls: 3, freeOnly: true),
    Prize(id: 'manna', name: '20 Manna', weight: 1, manna: 20),
  ],
);

/// Luck that always lands at the very start of the wheel.
class _First implements Random {
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0;
  @override
  int nextInt(int max) => 0;
}

void main() {
  late SaveExtras extras;
  late int pearls;
  late List<String> given;
  late bool adReady;
  late bool adWatched;
  late DateTime now;

  WheelController wheel({bool paidAllowed = true}) => WheelController(
    rules: _rules,
    extras: extras,
    paidAllowed: paidAllowed,
    pearls: () => pearls,
    spendPearls: (n) {
      if (n > pearls) return false;
      pearls -= n;
      return true;
    },
    grant: (prize) => given.add(prize.id),
    adReady: () => adReady,
    watchAd: () async => adWatched,
    random: _First(),
    clock: () => now,
  );

  setUp(() {
    extras = SaveExtras();
    pearls = 12;
    given = [];
    adReady = true;
    adWatched = true;
    now = DateTime(2026, 10, 10, 9);
  });

  test('the free spin gives a prize once a day, and is remembered', () async {
    final w = wheel();
    expect(w.freeSpins, 1);
    final prize = await w.spin(SpinKind.free);
    // The first slice of a free spin is the Pearls.
    expect(prize?.id, 'pearls');
    expect(given, ['pearls']);
    expect(w.freeSpins, 0);
    expect(await w.spin(SpinKind.free), isNull);
    expect(given, hasLength(1));
    // Saved: another wheel on the same save knows.
    expect(wheel().freeSpins, 0);
    now = now.add(const Duration(days: 1));
    expect(w.freeSpins, 1);
    w.dispose();
  });

  test('an ad spin needs an ad watched to the end', () async {
    final w = wheel();
    adWatched = false;
    expect(await w.spin(SpinKind.ad), isNull);
    expect(given, isEmpty);
    // Not watched: the day's ad spin is still there.
    expect(w.adSpins, 1);
    adWatched = true;
    expect((await w.spin(SpinKind.ad))?.id, 'pearls');
    expect(w.adSpins, 0);
    expect(w.adSpinOffered, isFalse);
    w.dispose();
  });

  test('no ad spin is offered while no ad is ready', () async {
    adReady = false;
    final w = wheel();
    expect(w.adSpinOffered, isFalse);
    expect(await w.spin(SpinKind.ad), isNull);
    expect(w.adSpins, 1);
    w.dispose();
  });

  test('a Pearl spin takes its rising price and never gives Pearls', () async {
    final w = wheel();
    expect(w.pearlSpinPrice, 5);
    expect((await w.spin(SpinKind.pearls))?.id, 'manna');
    expect(pearls, 7);
    expect(w.pearlSpinPrice, 10);
    // Not enough Pearls: nothing is taken, nothing given, nothing counted.
    expect(await w.spin(SpinKind.pearls), isNull);
    expect(pearls, 7);
    expect(given, ['manna']);
    expect(w.pearlSpinPrice, 10);
    pearls = 10;
    expect((await w.spin(SpinKind.pearls))?.id, 'manna');
    expect(pearls, 0);
    // The day's Pearl spins are used up.
    expect(w.pearlSpinPrice, isNull);
    expect(await w.spin(SpinKind.pearls), isNull);
    w.dispose();
  });

  test(
    'where paid chance is forbidden there are no Pearl spins at all',
    () async {
      final w = wheel(paidAllowed: false);
      expect(w.pearlSpinPrice, isNull);
      expect(await w.spin(SpinKind.pearls), isNull);
      expect(pearls, 12);
      expect(given, isEmpty);
      // Free and ad spins are as everywhere.
      expect(w.freeSpins, 1);
      expect(w.adSpinOffered, isTrue);
      w.dispose();
    },
  );

  test(
    'only one spin at a time: a second while an ad plays does nothing',
    () async {
      final gate = Completer<bool>();
      final w = WheelController(
        rules: _rules,
        extras: extras,
        paidAllowed: true,
        pearls: () => pearls,
        spendPearls: (n) => true,
        grant: (prize) => given.add(prize.id),
        adReady: () => true,
        watchAd: () => gate.future,
        random: _First(),
        clock: () => now,
      );
      final first = w.spin(SpinKind.ad);
      expect(w.busy, isTrue);
      expect(await w.spin(SpinKind.free), isNull);
      gate.complete(true);
      expect((await first)?.id, 'pearls');
      expect(given, hasLength(1));
      expect(w.busy, isFalse);
      w.dispose();
    },
  );

  test('closed while an ad plays: nothing is given afterwards', () async {
    final gate = Completer<bool>();
    final w = WheelController(
      rules: _rules,
      extras: extras,
      paidAllowed: true,
      pearls: () => pearls,
      spendPearls: (n) => true,
      grant: (prize) => given.add(prize.id),
      adReady: () => true,
      watchAd: () => gate.future,
      clock: () => now,
    );
    final spin = w.spin(SpinKind.ad);
    w.dispose();
    gate.complete(true);
    expect(await spin, isNull);
    expect(given, isEmpty);
    expect(extras.read(wheelRecord), isNull);
  });

  test('the odds shown are the odds drawn from', () {
    final w = wheel();
    expect([for (final o in w.freeOdds) o.prize.id], ['pearls', 'manna']);
    expect([for (final o in w.paidOdds) o.prize.id], ['manna']);
    expect(w.paidOdds.single.chance, 1);
    w.dispose();
  });
}
