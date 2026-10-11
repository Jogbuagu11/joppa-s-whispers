import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/offers_validator.dart';
import 'package:whispers_of_joppa/domain/deals.dart';

dynamic _read(String name) =>
    jsonDecode(File('content/$name.json').readAsStringSync());

const _config = DealsConfig(
  free: [
    DailyDeal(id: 'f1', name: '15 Manna', manna: 15),
    DailyDeal(id: 'f2', name: '40 Talents', talents: 40),
  ],
  forPearls: [
    DailyDeal(id: 'p1', name: 'A', pearlPrice: 5, manna: 60),
    DailyDeal(id: 'p2', name: 'B', pearlPrice: 6, manna: 70),
    DailyDeal(id: 'p3', name: 'C', pearlPrice: 7, manna: 80),
  ],
  pearlDealsPerDay: 2,
);

void main() {
  final monday = DateTime(2026, 10, 12, 8);
  List<String> ids(DateTime at) => [
    for (final d in dealsFor(_config, at)) d.id,
  ];

  test('a day has one free gift and two Pearl deals, the same all day', () {
    final morning = ids(monday);
    expect(morning, hasLength(3));
    expect(dealsFor(_config, monday).first.free, isTrue);
    expect(dealsFor(_config, monday).skip(1).every((d) => !d.free), isTrue);
    expect(ids(DateTime(2026, 10, 12, 23, 59)), morning);
    // Two different Pearl deals, never the same one twice.
    expect(morning.skip(1).toSet(), hasLength(2));
  });

  test('the next day brings other deals, each list in turn', () {
    final days = [
      for (var i = 0; i < 6; i++) ids(monday.add(Duration(days: i))),
    ];
    expect(days[0].first, isNot(days[1].first));
    expect(days[0].first, days[2].first);
    // Over three days every Pearl deal has had its turn.
    expect({for (final d in days.take(3)) ...d.skip(1)}, {'p1', 'p2', 'p3'});
  });

  test('fewer Pearl deals than asked for: all of them, once each', () {
    const few = DealsConfig(
      free: [],
      forPearls: [DailyDeal(id: 'p1', name: 'A', pearlPrice: 5, manna: 1)],
      pearlDealsPerDay: 3,
    );
    expect([for (final d in dealsFor(few, monday)) d.id], ['p1']);
  });

  test('a deal is taken once a day; the next day it can be taken again', () {
    const deal = DailyDeal(id: 'f1', name: '15 Manna', manna: 15);
    var tally = const DealsTally();
    expect(tally.hasTaken(deal, monday), isFalse);
    tally = tally.after(deal, monday);
    expect(tally.hasTaken(deal, monday), isTrue);
    expect(tally.hasTaken(deal, monday.add(const Duration(days: 1))), isFalse);
    // A clock wound back to an earlier day forgets nothing.
    final tuesday = monday.add(const Duration(days: 1));
    final later = tally.after(deal, tuesday);
    expect(later.hasTaken(deal, monday), isTrue);
    expect(later.on(monday).day, later.day);
    final back = DealsTally.fromJson(tally.toJson());
    expect(back.hasTaken(deal, monday), isTrue);
    // Damage counts as nothing taken.
    expect(DealsTally.fromJson({'day': 3, 'taken': 'x'}).taken, isEmpty);
    expect(DealsTally.fromJson(null).day, '');
  });

  group('the real game', () {
    final offers = _read('offers') as Map<String, dynamic>;

    test('the offers file is sound', () {
      expect(offersProblems(offers, chainsJson: _read('chains')), isEmpty);
      final config = DealsConfig.fromJson(
        offers['daily_deals'] as Map<String, dynamic>,
      );
      expect(dealsFor(config, monday), hasLength(1 + config.pearlDealsPerDay));
    });

    test('the checker reports what is wrong', () {
      List<String> check(void Function(Map<String, dynamic> deals) change) {
        final copy = jsonDecode(jsonEncode(offers)) as Map<String, dynamic>;
        change(copy['daily_deals'] as Map<String, dynamic>);
        return offersProblems(copy, chainsJson: _read('chains'));
      }

      Map<String, dynamic> first(Map<String, dynamic> deals, String list) =>
          (deals[list] as List<dynamic>).first as Map<String, dynamic>;
      expect(check((d) => first(d, 'free')['pearl_price'] = 3), isNotEmpty);
      expect(
        check((d) => first(d, 'for_pearls')['pearl_price'] = 0),
        isNotEmpty,
      );
      expect(
        check((d) => first(d, 'for_pearls')['items'] = ['nothing']),
        isNotEmpty,
      );
      expect(check((d) => first(d, 'free').remove('manna')), isNotEmpty);
      expect(check((d) => first(d, 'free')['name'] = ''), isNotEmpty);
      expect(
        check((d) => first(d, 'free')['id'] = first(d, 'for_pearls')['id']),
        isNotEmpty,
      );
      expect(check((d) => d['pearl_deals_per_day'] = -1), isNotEmpty);
      expect(offersProblems(null, chainsJson: const []), isNotEmpty);
    });
  });
}
