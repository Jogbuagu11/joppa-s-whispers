// The season pass: which tier purchases give, and what each tier pays.
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';

const _json = <String, dynamic>{
  'premium': [
    {'manna': 20},
    {
      'pearls': 5,
      'items': ['thread_01', 7],
    },
    {'talents': -4},
  ],
  'plus': {
    'bonus_percent': 20,
    'endless': {'every': 100, 'talents': 40},
  },
};

void main() {
  final pass = SeasonPass.fromJson(_json);

  test('the pass is read from the event; an event may have none', () {
    expect(pass?.premium.length, 3);
    expect(pass?.premium[0].manna, 20);
    expect(pass?.premium[1].pearls, 5);
    expect(pass?.premium[1].items, ['thread_01']);
    expect(pass?.premium[2].isEmpty, isTrue);
    expect(pass?.plusBonusPercent, 20);
    expect(pass?.endlessEvery, 100);
    expect(pass?.endless.talents, 40);
    expect(SeasonPass.fromJson(null), isNull);
    expect(SeasonPass.fromJson({'premium': <dynamic>[]}), isNull);
    final plain = SeasonPass.fromJson({
      'premium': [
        {'manna': 5},
      ],
    });
    expect(plain?.plusBonusPercent, 0);
    expect(plain?.endlessEvery, 0);
  });

  test('the tier comes from standing purchases for that event', () {
    expect(passTier(const [], 'boat'), PassTier.free);
    expect(
      passTier([(eventId: 'boat', plus: false)], 'boat'),
      PassTier.premium,
    );
    expect(passTier([(eventId: 'boat', plus: true)], 'boat'), PassTier.plus);
    // Another event's pass is no use here.
    expect(passTier([(eventId: 'feast', plus: true)], 'boat'), PassTier.free);
    // Premium bought twice costs what Plus costs.
    expect(
      passTier([
        (eventId: 'boat', plus: false),
        (eventId: 'boat', plus: false),
      ], 'boat'),
      PassTier.plus,
    );
  });

  test('Premium Plus adds its bonus to points; the others do not', () {
    expect(passPoints(250, PassTier.free, pass), 250);
    expect(passPoints(250, PassTier.premium, pass), 250);
    expect(passPoints(250, PassTier.plus, pass), 300);
    expect(passPoints(4, PassTier.plus, pass), 4);
    expect(passPoints(-3, PassTier.plus, pass), 0);
    expect(passPoints(250, PassTier.plus, null), 250);
  });

  test('Premium rewards are paid for milestones reached, each once; a pass '
      'bought late pays all of them', () {
    expect(
      premiumToPay(pass, PassTier.free, reached: 2, alreadyPaid: 0),
      isEmpty,
    );
    final late = premiumToPay(
      pass,
      PassTier.premium,
      reached: 2,
      alreadyPaid: 0,
    );
    expect(late.map((r) => r.manna + r.pearls), [20, 5]);
    expect(
      premiumToPay(
        pass,
        PassTier.plus,
        reached: 2,
        alreadyPaid: 1,
      ).single.pearls,
      5,
    );
    expect(
      premiumToPay(pass, PassTier.premium, reached: 2, alreadyPaid: 2),
      isEmpty,
    );
    // More milestones than Premium rewards: only those there are.
    expect(
      premiumToPay(pass, PassTier.premium, reached: 9, alreadyPaid: 0).length,
      3,
    );
    expect(
      premiumToPay(null, PassTier.premium, reached: 2, alreadyPaid: 0),
      isEmpty,
    );
    expect(
      premiumToPay(pass, PassTier.premium, reached: 2, alreadyPaid: -1),
      isEmpty,
    );
  });

  test('the endless track is for Premium Plus, past the last milestone', () {
    int steps(PassTier tier, int points) =>
        endlessReached(pass, tier, points: points, lastMilestone: 500);
    expect(steps(PassTier.premium, 900), 0);
    expect(steps(PassTier.plus, 500), 0);
    expect(steps(PassTier.plus, 599), 0);
    expect(steps(PassTier.plus, 600), 1);
    expect(steps(PassTier.plus, 925), 4);
    expect(steps(PassTier.plus, 100), 0);
    final none = SeasonPass.fromJson({
      'premium': [
        {'manna': 5},
      ],
    });
    expect(
      endlessReached(none, PassTier.plus, points: 900, lastMilestone: 500),
      0,
    );
  });
}
