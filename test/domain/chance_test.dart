import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/chance_validator.dart';
import 'package:whispers_of_joppa/domain/chance.dart';
import 'package:whispers_of_joppa/domain/wheel.dart';

const _prizes = [
  Prize(id: 'manna', name: 'Manna', weight: 6, manna: 20),
  Prize(id: 'talents', name: 'Talents', weight: 3, talents: 30),
  Prize(id: 'pearls', name: 'Pearls', weight: 1, pearls: 3, freeOnly: true),
];

dynamic _read(String name) =>
    jsonDecode(File('content/$name.json').readAsStringSync());

void main() {
  test('the odds shown add up to 1 and follow the weights', () {
    final free = oddsFor(_prizes, paid: false);
    expect([for (final o in free) o.prize.id], ['manna', 'talents', 'pearls']);
    expect(free.map((o) => o.chance), [0.6, 0.3, 0.1]);
    expect(free.fold<double>(0, (sum, o) => sum + o.chance), closeTo(1, 1e-9));
  });

  test('a paid try never offers Pearls, and its odds still add up to 1', () {
    final paid = oddsFor(_prizes, paid: true);
    expect([for (final o in paid) o.prize.id], ['manna', 'talents']);
    expect(paid.first.chance, closeTo(6 / 9, 1e-9));
    expect(paid.fold<double>(0, (sum, o) => sum + o.chance), closeTo(1, 1e-9));
  });

  test('prizes are drawn as often as the odds shown say', () {
    final random = Random(11);
    final counts = <String, int>{};
    for (var i = 0; i < 20000; i++) {
      final id = drawPrize(_prizes, paid: false, random: random)?.id ?? '';
      counts[id] = (counts[id] ?? 0) + 1;
    }
    for (final entry in oddsFor(_prizes, paid: false)) {
      expect(
        (counts[entry.prize.id] ?? 0) / 20000,
        closeTo(entry.chance, 0.015),
        reason: entry.prize.id,
      );
    }
  });

  test('ten thousand paid draws never give Pearls', () {
    final random = Random(5);
    for (var i = 0; i < 10000; i++) {
      expect(drawPrize(_prizes, paid: true, random: random)?.pearls, 0);
    }
  });

  test('nothing to draw gives nothing', () {
    expect(drawPrize(const [], paid: false), isNull);
    expect(oddsFor(const [], paid: true), isEmpty);
    // Only a free-only prize: a paid try has nothing to give.
    expect(drawPrize([_prizes.last], paid: true), isNull);
  });

  test('chances read naturally', () {
    expect(formatChance(0.25), '25%');
    expect(formatChance(0.125), '12.5%');
    expect(formatChance(0.03), '3%');
    expect(formatChance(0.004), '0.40%');
    expect(formatChance(2 / 3), '66.7%');
    // Sums that do not come out even are still written evenly.
    expect(formatChance(0.07), '7%');
    expect(formatChance(0.28), '28%');
    expect(formatChance(1 / 101), '0.99%');
    expect(formatChance(1), '100%');
    // Never written as nothing.
    expect(formatChance(0.00001), 'under 0.01%');
  });

  test('paid chance is off only in the countries listed', () {
    expect(paidChanceAllowed('BE', {'BE'}), isFalse);
    expect(paidChanceAllowed('be', {'BE'}), isFalse);
    expect(paidChanceAllowed('US', {'BE'}), isTrue);
    // A phone that does not say where it is gets the careful answer.
    expect(paidChanceAllowed(null, {'BE'}), isFalse);
    expect(paidChanceAllowed('', {'BE'}), isFalse);
  });

  group('the wheel', () {
    const rules = WheelRules(
      freeSpinsPerDay: 1,
      adSpinsPerDay: 1,
      pearlSpinBase: 5,
      pearlSpinStep: 5,
      pearlSpinsPerDay: 3,
      prizes: _prizes,
    );
    final today = DateTime(2026, 10, 10, 9);
    final tomorrow = DateTime(2026, 10, 11, 0, 5);

    test('one free spin and one ad spin a day', () {
      var tally = const WheelTally();
      expect(freeSpinsLeft(rules, tally, today), 1);
      expect(adSpinsLeft(rules, tally, today), 1);
      tally = afterSpin(tally, SpinKind.free, today);
      expect(freeSpinsLeft(rules, tally, today), 0);
      expect(adSpinsLeft(rules, tally, today), 1);
      tally = afterSpin(tally, SpinKind.ad, today);
      expect(adSpinsLeft(rules, tally, today), 0);
    });

    test('Pearl spins cost more each time, up to the day\'s limit', () {
      var tally = const WheelTally();
      final costs = <int?>[];
      for (var i = 0; i < 4; i++) {
        costs.add(pearlSpinCost(rules, tally, today));
        tally = afterSpin(tally, SpinKind.pearls, today);
      }
      expect(costs, [5, 10, 15, null]);
      expect(pearlSpinsLeft(rules, tally, today), 0);
    });

    test('a new day starts everything again', () {
      var tally = const WheelTally();
      for (final kind in SpinKind.values) {
        tally = afterSpin(tally, kind, today);
      }
      expect(freeSpinsLeft(rules, tally, tomorrow), 1);
      expect(adSpinsLeft(rules, tally, tomorrow), 1);
      expect(pearlSpinCost(rules, tally, tomorrow), 5);
      final next = afterSpin(tally, SpinKind.free, tomorrow);
      expect(next.day, '2026-10-11');
      expect((next.free, next.ad, next.pearls), (1, 0, 0));
    });

    test('the tally survives the save file; damage counts as nothing', () {
      final tally = afterSpin(const WheelTally(), SpinKind.pearls, today);
      final back = WheelTally.fromJson(tally.toJson());
      expect(
        (back.day, back.free, back.ad, back.pearls),
        ('2026-10-10', 0, 0, 1),
      );
      final odd = WheelTally.fromJson({'day': 7, 'free': -2, 'ad': 'x'});
      expect((odd.day, odd.free, odd.ad, odd.pearls), ('', 0, 0, 0));
      expect(WheelTally.fromJson(null).day, '');
    });
  });

  group('the real game', () {
    final chance = _read('chance') as Map<String, dynamic>;
    final rules = WheelRules.fromJson(chance['wheel'] as Map<String, dynamic>);

    test('the chance file is sound', () {
      expect(
        chanceProblems(
          chance,
          chainsJson: _read('chains'),
          generatorsJson: _read('generators'),
        ),
        isEmpty,
      );
    });

    test('the wheel has prizes for both kinds of spin, and Pearls only on '
        'free ones', () {
      expect(oddsFor(rules.prizes, paid: false), isNotEmpty);
      final paid = oddsFor(rules.prizes, paid: true);
      expect(paid, isNotEmpty);
      expect(paid.every((o) => o.prize.pearls == 0), isTrue);
      expect(rules.prizes.every((p) => p.givesSomething), isTrue);
      // The chances come out as round numbers a player can check.
      expect(rules.prizes.fold<int>(0, (sum, p) => sum + p.weight), 100);
    });
  });

  group('the checker', () {
    Map<String, dynamic> copy() =>
        jsonDecode(jsonEncode(_read('chance'))) as Map<String, dynamic>;
    List<String> check(void Function(Map<String, dynamic> chance) change) {
      final chance = copy();
      change(chance);
      return chanceProblems(
        chance,
        chainsJson: _read('chains'),
        generatorsJson: _read('generators'),
      );
    }

    List<dynamic> prizes(Map<String, dynamic> chance) =>
        (chance['wheel'] as Map<String, dynamic>)['prizes'] as List<dynamic>;
    Map<String, dynamic> first(Map<String, dynamic> chance) =>
        prizes(chance).first as Map<String, dynamic>;

    test('reports what is wrong', () {
      expect(check((c) {}), isEmpty);
      expect(
        check((c) => c['paid_blocked_countries'] = ['Belgium']),
        isNotEmpty,
      );
      expect(check((c) => c.remove('wheel')), isNotEmpty);
      expect(check((c) => prizes(c).clear()), isNotEmpty);
      expect(check((c) => first(c)['weight'] = 0), isNotEmpty);
      expect(check((c) => first(c)['name'] = ''), isNotEmpty);
      expect(check((c) => first(c)['id'] = prizes(c)[1]['id']), isNotEmpty);
      expect(check((c) => first(c)['items'] = ['no_such_item']), isNotEmpty);
      // A lasting generator is no prize: it would wait for ever.
      expect(check((c) => first(c)['generators'] = ['gen_pantry']), isNotEmpty);
      expect(check((c) => first(c).remove('manna')), isNotEmpty);
      expect(
        check(
          (c) => (c['wheel'] as Map<String, dynamic>)['pearl_spin_base'] = 0,
        ),
        isNotEmpty,
      );
      expect(
        check((c) => (c['text'] as Map<String, dynamic>).remove('see_odds')),
        isNotEmpty,
      );
      expect(
        chanceProblems(null, chainsJson: const [], generatorsJson: const []),
        isNotEmpty,
      );
    });

    test('a Pearl spin cannot win a jar that may hold Pearls', () {
      expect(check((c) => first(c)['items'] = ['clayjar_01']), isNotEmpty);
      // A jar that holds none is fine.
      expect(check((c) => first(c)['items'] = ['treasurejar_01']), isEmpty);
    });

    test('Pearls can never be won on a paid try', () {
      expect(check((c) => first(c)['pearls'] = 2), isNotEmpty);
      expect(
        check((c) {
          for (final p in prizes(c)) {
            (p as Map<String, dynamic>)['free_only'] = true;
          }
        }),
        isNotEmpty,
      );
    });
  });
}
