import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/game/board/manna_controller.dart';

void main() {
  const config = EconomyConfig(
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
    rewardedAdMannaDailyCap: 5,
    rewardedAdDoubleRewardDailyCap: 3,
  );
  final t0 = DateTime(2040, 1, 1, 12, 0, 0);
  late DateTime now;

  MannaController make(int manna) =>
      MannaController(config: config, startingManna: manna, clock: () => now);

  setUp(() => now = t0);

  test('starts with the given Manna and a full countdown', () {
    final c = make(10);
    expect(c.manna, 10);
    expect(c.maxManna, 100);
    expect(c.secondsUntilNext, 120);
  });

  test('tick adds Manna as time passes and tells listeners', () {
    final c = make(10);
    var notified = 0;
    c.addListener(() => notified++);

    now = t0.add(const Duration(seconds: 60));
    c.tick();
    expect(c.manna, 10);
    expect(c.secondsUntilNext, 60);

    now = t0.add(const Duration(seconds: 250));
    c.tick();
    expect(c.manna, 12);
    expect(c.secondsUntilNext, 110);
    expect(notified, 2);
  });

  test('spending from a full bar starts the countdown from now', () {
    final c = make(100);
    expect(c.secondsUntilNext, isNull);
    now = t0.add(const Duration(minutes: 30));
    c.setAfterSpend(99);
    expect(c.manna, 99);
    expect(c.secondsUntilNext, 120);
  });

  test('spending below full keeps the countdown already running', () {
    final c = make(10);
    now = t0.add(const Duration(seconds: 90));
    c.setAfterSpend(9);
    expect(c.manna, 9);
    expect(c.secondsUntilNext, 30);
  });

  test('restoring with an old regen clock collects the Manna earned away', () {
    final c = MannaController(
      config: config,
      startingManna: 10,
      lastRegen: t0.subtract(const Duration(minutes: 21)),
      clock: () => now,
    );
    expect(c.manna, 10);
    c.tick();
    expect(c.manna, 20);
    expect(c.lastRegen, t0.subtract(const Duration(minutes: 1)));
    expect(c.secondsUntilNext, 60);
  });

  test('bought Manna is added, even above the bar, and regen then waits', () {
    final c = make(90);
    var notified = 0;
    c.addListener(() => notified++);
    c.add(100);
    expect(c.manna, 190);
    expect(notified, 1);
    expect(c.secondsUntilNext, isNull);
    now = t0.add(const Duration(hours: 1));
    c.tick();
    expect(c.manna, 190);
    c.add(0);
    c.add(-5);
    expect(c.manna, 190);
  });

  testWidgets('start ticks once a second, only one timer, dispose stops it', (
    tester,
  ) async {
    final c = make(10);
    var notified = 0;
    c.addListener(() => notified++);
    c
      ..start()
      ..start();
    await tester.pump(const Duration(seconds: 3));
    expect(notified, 3);
    c.dispose();
    await tester.pump(const Duration(seconds: 3));
    expect(notified, 3);
  });
}
