import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/economy.dart';

void main() {
  const config = EconomyConfig(
    maxManna: 100,
    mannaRegenSeconds: 120,
    generatorTapCost: 1,
    mannaRefillBasePearls: 10,
    basketSlotBasePearls: 10,
    orderSkipCooldownSeconds: 1800,
    rewardedAdMannaBonus: 20,
    rewardedAdMannaDailyCap: 5,
    rewardedAdDoubleRewardDailyCap: 3,
  );

  group('sellValue', () {
    test('tier 1 = 2 talents', () => expect(sellValue(1), 2));
    test('tier 4 = 8 talents', () => expect(sellValue(4), 8));
    test('tier 8 = 16 talents', () => expect(sellValue(8), 16));
  });

  group('orderRewardTalents', () {
    test('two tier-4 items = 40 talents', () {
      expect(orderRewardTalents([4, 4]), 40);
    });
    test('one tier-2 item = 10 talents', () {
      expect(orderRewardTalents([2]), 10);
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
}
