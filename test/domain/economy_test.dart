import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/models.dart';

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

  group('sellValue', () {
    ItemModel item(int sell) => ItemModel(
      itemId: 'bakery_01',
      chainId: 'bakery',
      tier: 1,
      name: '',
      asset: '',
      sell: sell,
    );
    test('uses the sell value from content', () {
      expect(sellValue(item(2)), 2);
      expect(sellValue(item(16)), 16);
    });
  });

  group('orderRewardTalents', () {
    test('two tier-4 items = 40 talents', () {
      expect(orderRewardTalents(config, [4, 4]), 40);
    });
    test('one tier-2 item = 10 talents', () {
      expect(orderRewardTalents(config, [2]), 10);
    });
    test('no items = 0 talents', () {
      expect(orderRewardTalents(config, []), 0);
    });
  });

  group('mannaRefillCost', () {
    test('first refill = 10 pearls', () {
      expect(mannaRefillCost(config, 0), 10);
    });
    test('second refill = 20 pearls', () {
      expect(mannaRefillCost(config, 1), 20);
    });
    test('third refill = 40 pearls', () {
      expect(mannaRefillCost(config, 2), 40);
    });
  });

  group('mannaRegenerated', () {
    final base = DateTime(2040, 1, 1, 12, 0, 0);

    test('no time elapsed = 0 manna', () {
      expect(mannaRegenerated(config, 50, base, base), 0);
    });

    test('120 seconds = 1 manna', () {
      expect(
        mannaRegenerated(
          config,
          50,
          base,
          base.add(const Duration(seconds: 120)),
        ),
        1,
      );
    });

    test('600 seconds = 5 manna', () {
      expect(
        mannaRegenerated(
          config,
          50,
          base,
          base.add(const Duration(seconds: 600)),
        ),
        5,
      );
    });

    test('does not exceed cap', () {
      // Already at 99, only 1 more possible even if lots of time passed.
      expect(
        mannaRegenerated(config, 99, base, base.add(const Duration(hours: 5))),
        1,
      );
    });

    test('full manna regenerates nothing', () {
      expect(
        mannaRegenerated(config, 100, base, base.add(const Duration(hours: 5))),
        0,
      );
    });
  });

  group('applyMannaRegen', () {
    final t0 = DateTime(2040, 1, 1, 12, 0, 0);
    MannaState at(int manna) => MannaState(manna: manna, lastRegen: t0);

    test('nothing is added before a full interval', () {
      final r = applyMannaRegen(
        config,
        at(5),
        t0.add(const Duration(seconds: 119)),
      );
      expect(r.manna, 5);
      expect(r.lastRegen, t0);
    });

    test('one interval adds 1 and keeps the leftover time', () {
      final r = applyMannaRegen(
        config,
        at(5),
        t0.add(const Duration(seconds: 150)),
      );
      expect(r.manna, 6);
      expect(r.lastRegen, t0.add(const Duration(seconds: 120)));
    });

    test('a long absence adds several', () {
      final r = applyMannaRegen(
        config,
        at(5),
        t0.add(const Duration(minutes: 21)),
      );
      expect(r.manna, 15);
      expect(r.lastRegen, t0.add(const Duration(minutes: 20)));
    });

    test('never goes past the maximum, and the clock resets when full', () {
      final now = t0.add(const Duration(days: 2));
      final r = applyMannaRegen(config, at(95), now);
      expect(r.manna, 100);
      expect(r.lastRegen, now);
    });

    test('a full bar gains nothing and keeps its clock current', () {
      final now = t0.add(const Duration(hours: 1));
      final r = applyMannaRegen(config, at(100), now);
      expect(r.manna, 100);
      expect(r.lastRegen, now);
    });
  });

  test(
    'applyMannaRegen restarts the clock if the device clock goes backwards',
    () {
      final t0 = DateTime(2040, 1, 1, 12, 0, 0);
      final earlier = t0.subtract(const Duration(hours: 3));
      final r = applyMannaRegen(
        config,
        MannaState(manna: 5, lastRegen: t0),
        earlier,
      );
      expect(r.manna, 5);
      expect(r.lastRegen, earlier);
      expect(secondsUntilNextManna(config, r, earlier), 120);
    },
  );

  group('secondsUntilNextManna', () {
    final t0 = DateTime(2040, 1, 1, 12, 0, 0);

    test('counts down from the regen interval', () {
      final state = MannaState(manna: 5, lastRegen: t0);
      expect(secondsUntilNextManna(config, state, t0), 120);
      expect(
        secondsUntilNextManna(
          config,
          state,
          t0.add(const Duration(seconds: 45)),
        ),
        75,
      );
    });

    test('never goes below zero', () {
      final state = MannaState(manna: 5, lastRegen: t0);
      expect(
        secondsUntilNextManna(
          config,
          state,
          t0.add(const Duration(seconds: 500)),
        ),
        0,
      );
    });

    test('is null when the bar is full', () {
      final state = MannaState(manna: 100, lastRegen: t0);
      expect(secondsUntilNextManna(config, state, t0), isNull);
    });
  });

  group('formatCountdown', () {
    test('shows minutes and two-digit seconds', () {
      expect(formatCountdown(120), '2:00');
      expect(formatCountdown(65), '1:05');
      expect(formatCountdown(9), '0:09');
      expect(formatCountdown(0), '0:00');
    });
  });
}
