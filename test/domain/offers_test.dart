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
  test('an offer is read from a row; one that gives nothing is no offer', () {
    final offer = Offer.fromJson(<String, dynamic>{
      'id': 'welcome',
      'kind': 'session_start',
      'product_id': 'offer_099',
      'title': 'Welcome gift',
      'subtitle': 'For new friends',
      'contents': <String, dynamic>{
        'pearls': 40,
        'items': ['manna_jar_02'],
      },
      'audience': 'non_payer',
      'min_level': 3,
      'next_offer_id': 'welcome_more',
      'duration_seconds': 7200,
      'ends_at': '2026-10-20T00:00:00Z',
      'priority': 5,
    });
    expect(offer?.title, 'Welcome gift');
    expect(offer?.contents.pearls, 40);
    expect(offer?.contents.items, ['manna_jar_02']);
    expect(offer?.audience, 'non_payer');
    expect(offer?.minLevel, 3);
    expect(offer?.nextOfferId, 'welcome_more');
    expect(offer?.duration, const Duration(hours: 2));
    expect(offer?.endsAt, DateTime.utc(2026, 10, 20));
    expect(offer?.priority, 5);

    expect(Offer.fromJson(null), isNull);
    expect(Offer.fromJson(<String, dynamic>{'id': 'x'}), isNull);
    expect(
      Offer.fromJson(<String, dynamic>{
        'id': 'empty',
        'kind': 'session_start',
        'product_id': 'offer_099',
        'title': 'Nothing',
        'contents': <String, dynamic>{},
      }),
      isNull,
    );
  });

  test('each moment shows its own kind; flash sales and themed bundles come '
      'when the game is opened', () {
    final offers = [
      _offer('start'),
      _offer('thirsty', kind: 'out_of_manna'),
      _offer('grown', kind: 'level_up'),
      _offer('done', kind: 'chapter_complete'),
    ];
    expect(_choose(offers)?.id, 'start');
    expect(_choose(offers, trigger: OfferTrigger.outOfManna)?.id, 'thirsty');
    expect(_choose(offers, trigger: OfferTrigger.levelUp)?.id, 'grown');
    expect(_choose(offers, trigger: OfferTrigger.chapterComplete)?.id, 'done');
    expect(_choose([_offer('flash', kind: 'flash_sale')])?.id, 'flash');
    expect(_choose([_offer('feast', kind: 'themed')])?.id, 'feast');
    expect(
      _choose([
        _offer('flash', kind: 'flash_sale'),
      ], trigger: OfferTrigger.outOfManna),
      isNull,
    );
  });

  test('offers are for their own players: by spending and by level', () {
    final offers = [
      _offer('small', audience: 'non_payer'),
      _offer('large', audience: 'payer', priority: 9),
    ];
    expect(_choose(offers)?.id, 'small');
    expect(_choose(offers, hasPaid: true)?.id, 'large');
    expect(_choose([_offer('late', minLevel: 20)], level: 19), isNull);
    expect(_choose([_offer('late', minLevel: 20)], level: 20)?.id, 'late');
  });

  test('the higher priority wins', () {
    final offers = [_offer('a', priority: 1), _offer('b', priority: 7)];
    expect(_choose(offers)?.id, 'b');
  });

  test('an offer turned down gives way to its next, which is never shown '
      'first; with no next it is not shown again', () {
    final offers = [
      _offer('first', next: 'better'),
      _offer('better', next: 'best'),
      _offer('best'),
    ];
    expect(_choose(offers)?.id, 'first');
    var memory = const OfferMemory().afterDeclined(offers[0]);
    expect(_choose(offers, memory: memory)?.id, 'better');
    memory = memory.afterDeclined(offers[1]);
    expect(_choose(offers, memory: memory)?.id, 'best');
    memory = memory.afterDeclined(offers[2]);
    expect(_choose(offers, memory: memory), isNull);
    // A chain that loops back on itself ends, too.
    final loop = [_offer('x', next: 'y'), _offer('y', next: 'x')];
    final both = const OfferMemory()
        .afterDeclined(loop[0])
        .afterDeclined(loop[1]);
    expect(_choose(loop, memory: both), isNull);
  });

  test('an offer runs for its countdown from when it was first shown, and '
      'only inside its window', () {
    final offer = _offer('hour', duration: const Duration(hours: 1));
    final shown = const OfferMemory().afterShown(
      offer,
      OfferTrigger.outOfManna,
      _now,
    );
    expect(offerEndsAt(offer, _now), _now.add(const Duration(hours: 1)));
    expect(
      _choose(
        [offer],
        memory: shown,
        now: _now.add(const Duration(minutes: 59)),
      )?.id,
      'hour',
    );
    expect(
      _choose(
        [offer],
        memory: shown,
        now: _now.add(const Duration(minutes: 61)),
      ),
      isNull,
    );
    // Shown again later, the countdown does not start over.
    final again = shown.afterShown(
      offer,
      OfferTrigger.outOfManna,
      _now.add(const Duration(minutes: 30)),
    );
    expect(again.firstShown['hour'], _now);

    final soon = _offer('soon', startsAt: _now.add(const Duration(hours: 2)));
    expect(_choose([soon]), isNull);
    final over = _offer(
      'over',
      endsAt: _now.subtract(const Duration(hours: 1)),
    );
    expect(_choose([over]), isNull);
    // A window that closes first cuts the countdown short.
    final closing = _offer(
      'closing',
      endsAt: _now.add(const Duration(hours: 3)),
    );
    expect(offerEndsAt(closing, _now), _now.add(const Duration(hours: 3)));
  });

  test('at most three a session, one at the start, and one start offer a '
      'day', () {
    bool may(
      OfferTrigger trigger, {
      int session = 0,
      int start = 0,
      OfferMemory memory = const OfferMemory(),
    }) => mayShowOffer(
      rules: _rules,
      trigger: trigger,
      shownThisSession: session,
      shownAtThisStart: start,
      memory: memory,
      now: _now,
    );
    expect(may(OfferTrigger.sessionStart), isTrue);
    expect(may(OfferTrigger.sessionStart, start: 1), isFalse);
    expect(may(OfferTrigger.outOfManna, session: 2), isTrue);
    expect(may(OfferTrigger.outOfManna, session: 3), isFalse);
    final today = const OfferMemory().afterShown(
      _offer('start'),
      OfferTrigger.sessionStart,
      _now,
    );
    expect(may(OfferTrigger.sessionStart, memory: today), isFalse);
    // Other moments do not use up the day's start offer.
    final thirsty = const OfferMemory().afterShown(
      _offer('thirsty', kind: 'out_of_manna'),
      OfferTrigger.outOfManna,
      _now,
    );
    expect(may(OfferTrigger.sessionStart, memory: thirsty), isTrue);
    // A new day.
    expect(
      mayShowOffer(
        rules: _rules,
        trigger: OfferTrigger.sessionStart,
        shownThisSession: 0,
        shownAtThisStart: 0,
        memory: today,
        now: _now.add(const Duration(days: 1)),
      ),
      isTrue,
    );
  });
}
