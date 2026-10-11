import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/offers.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';

final _now = DateTime.utc(2026, 10, 12, 9);
const _rules = OfferRules();

Offer _offer(
  String id, {
  String kind = 'session_start',
  String audience = 'any',
  int minLevel = 1,
  String? next,
  int priority = 0,
  Duration duration = const Duration(hours: 24),
  DateTime? startsAt,
  DateTime? endsAt,
}) => Offer(
  id: id,
  kind: kind,
  productId: 'offer_099',
  title: id,
  contents: const PurchaseGrant(pearls: 40),
  audience: audience,
  minLevel: minLevel,
  nextOfferId: next,
  priority: priority,
  duration: duration,
  startsAt: startsAt,
  endsAt: endsAt,
);

Offer? _choose(
  List<Offer> offers, {
  OfferTrigger trigger = OfferTrigger.sessionStart,
  int level = 10,
  bool hasPaid = false,
  OfferMemory memory = const OfferMemory(),
  DateTime? now,
}) => chooseOffer(
  offers: offers,
  trigger: trigger,
  level: level,
  hasPaid: hasPaid,
  memory: memory,
  now: now ?? _now,
);

void main() {
  test('a level-up offer comes when a fifth level is reached or passed', () {
    expect(levelBringsOffer(_rules, from: 4, to: 5), isTrue);
    expect(levelBringsOffer(_rules, from: 9, to: 10), isTrue);
    expect(levelBringsOffer(_rules, from: 6, to: 7), isFalse);
    // A jump over one.
    expect(levelBringsOffer(_rules, from: 4, to: 6), isTrue);
    expect(levelBringsOffer(_rules, from: 5, to: 5), isFalse);
    expect(
      levelBringsOffer(const OfferRules(levelEvery: 0), from: 4, to: 5),
      isFalse,
    );
  });

  test('a bought offer is not offered again, nor is its next; after a good '
      'while everything about an offer is forgotten and it may return', () {
    final offers = [_offer('first', next: 'better'), _offer('better')];
    var memory = const OfferMemory()
        .afterShown(offers[0], OfferTrigger.outOfManna, _now)
        .afterBought(offers[0]);
    expect(_choose(offers, memory: memory), isNull);
    final back = OfferMemory.fromJson(memory.toJson());
    expect(back.bought, {'first'});

    const week = Duration(days: 7);
    expect(memory.lapsed(_now.add(const Duration(days: 6)), week).bought, {
      'first',
    });
    memory = memory.lapsed(_now.add(const Duration(days: 8)), week);
    expect(memory.bought, isEmpty);
    expect(memory.firstShown, isEmpty);
    expect(
      _choose(
        offers,
        memory: memory,
        now: _now.add(const Duration(days: 8)),
      )?.id,
      'first',
    );
    // Zero means offers never return.
    final kept = const OfferMemory()
        .afterShown(offers[0], OfferTrigger.outOfManna, _now)
        .afterDeclined(offers[0])
        .lapsed(_now.add(const Duration(days: 400)), Duration.zero);
    expect(kept.declined, {'first'});
  });

  test('rules and memory are read carefully and survive saving', () {
    final rules = OfferRules.fromJson(<String, dynamic>{
      'max_per_session': 2,
      'level_every': 'x',
    });
    expect(rules.maxPerSession, 2);
    expect(rules.levelEvery, 5);
    expect(OfferRules.fromJson(null).maxAtSessionStart, 1);

    final memory = const OfferMemory()
        .afterShown(_offer('a'), OfferTrigger.sessionStart, _now)
        .afterDeclined(_offer('a'));
    final back = OfferMemory.fromJson(memory.toJson());
    expect(back.startsOn(_now), 1);
    expect(back.firstShown['a'], _now);
    expect(back.declined, {'a'});
    final damaged = OfferMemory.fromJson(<String, dynamic>{
      'day': 3,
      'starts': -1,
      'shown': <String, dynamic>{'a': 'not a time', 'b': 7},
      'declined': 'x',
    });
    expect(damaged.startsOn(_now), 0);
    expect(damaged.firstShown, isEmpty);
    expect(damaged.declined, isEmpty);
  });
}
