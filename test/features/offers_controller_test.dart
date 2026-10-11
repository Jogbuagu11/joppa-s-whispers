import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/offers.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/features/offers/offers_controller.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

import '../support/offer_fakes.dart';

const _welcome = Offer(
  id: 'welcome',
  kind: 'session_start',
  productId: 'offer_099',
  title: 'Welcome gift',
  contents: PurchaseGrant(pearls: 40, manna: 50),
  nextOfferId: 'welcome_more',
  duration: Duration(hours: 2),
);
const _more = Offer(
  id: 'welcome_more',
  kind: 'session_start',
  productId: 'offer_099',
  title: 'A bigger gift',
  contents: PurchaseGrant(pearls: 55),
);
const _thirsty = Offer(
  id: 'thirsty',
  kind: 'out_of_manna',
  productId: 'offer_099',
  title: 'Manna for the road',
  contents: PurchaseGrant(manna: 100),
);
void main() {
  group('the offers controller', () {
    var now = DateTime.utc(2026, 10, 12, 9);
    late SaveExtras extras;
    late List<String> notes;
    late OffersController offers;

    Future<OffersController> make() async {
      final controller = OffersController(
        source: FakeOffersSource([_welcome, _more, _thirsty]),
        rules: const OfferRules(sessionStartPerDay: 4),
        extras: extras,
        note: (offer, outcome) => notes.add('${offer.id}:$outcome'),
        clock: () => now,
      );
      await controller.load();
      return controller;
    }

    Offer? next(OfferTrigger trigger, {int level = 10}) =>
        offers.next(trigger, level: level, hasPaid: false);

    setUp(() async {
      now = DateTime.utc(2026, 10, 12, 9);
      extras = SaveExtras();
      notes = [];
      offers = await make();
    });
    tearDown(() => extras.dispose());

    test('nothing is offered before the offers are read', () {
      final unread = OffersController(
        source: FakeOffersSource([_welcome]),
        rules: const OfferRules(),
        extras: extras,
      );
      expect(
        unread.next(OfferTrigger.sessionStart, level: 5, hasPaid: false),
        isNull,
      );
    });

    test('one greeting each time the game is opened, up to the day\'s '
        'limit; turned down, its next comes at the next opening', () async {
      expect(next(OfferTrigger.sessionStart)?.id, 'welcome');
      final ends = offers.shown(_welcome, OfferTrigger.sessionStart);
      expect(ends, now.add(const Duration(hours: 2)));
      // Only one at one opening.
      expect(next(OfferTrigger.sessionStart), isNull);
      offers.declined(_welcome);
      expect(notes, ['welcome:shown', 'welcome:dismissed']);

      // Opened again later the same day: the bigger one.
      now = now.add(const Duration(hours: 1));
      offers = await make();
      expect(next(OfferTrigger.sessionStart)?.id, 'welcome_more');
      offers.shown(_more, OfferTrigger.sessionStart);
      offers.declined(_more);
      // Both turned down: nothing more today.
      offers = await make();
      expect(next(OfferTrigger.sessionStart), isNull);
      // Tomorrow they come round again.
      now = now.add(const Duration(days: 1));
      offers = await make();
      expect(next(OfferTrigger.sessionStart)?.id, 'welcome');
    });

    test('a day\'s limit of greetings, and a fresh count after a break', () {
      final tight = OffersController(
        source: FakeOffersSource([_welcome]),
        rules: const OfferRules(sessionStartPerDay: 1),
        extras: extras,
        clock: () => now,
      );
      tight.shown(_welcome, OfferTrigger.sessionStart);
      tight.newSession();
      // A new session, but the day's one greeting is used.
      expect(
        tight.next(OfferTrigger.sessionStart, level: 5, hasPaid: false),
        isNull,
      );
      offers
        ..shown(_thirsty, OfferTrigger.outOfManna)
        ..shown(_thirsty, OfferTrigger.outOfManna)
        ..shown(_thirsty, OfferTrigger.outOfManna);
      expect(next(OfferTrigger.sessionStart), isNull);
      offers.newSession();
      expect(next(OfferTrigger.sessionStart)?.id, 'welcome');
    });

    test('at most three offers in one session', () {
      offers.shown(_welcome, OfferTrigger.sessionStart);
      expect(next(OfferTrigger.outOfManna)?.id, 'thirsty');
      offers.shown(_thirsty, OfferTrigger.outOfManna);
      expect(next(OfferTrigger.outOfManna)?.id, 'thirsty');
      offers.shown(_thirsty, OfferTrigger.outOfManna);
      expect(next(OfferTrigger.outOfManna), isNull);
    });

    test('a level-up offer only when a fifth level is reached', () async {
      const grown = Offer(
        id: 'grown',
        kind: 'level_up',
        productId: 'offer_299',
        title: 'Well done',
        contents: PurchaseGrant(pearls: 100),
      );
      offers = OffersController(
        source: FakeOffersSource([grown]),
        rules: const OfferRules(),
        extras: extras,
        clock: () => now,
      );
      await offers.load();
      Offer? at(int from, int to) => offers.next(
        OfferTrigger.levelUp,
        level: to,
        hasPaid: false,
        fromLevel: from,
      );
      expect(at(6, 7), isNull);
      expect(at(9, 10)?.id, 'grown');
      expect(at(8, 11)?.id, 'grown');
    });

    test('a bought offer is not offered again until a good while later', () {
      offers.shown(_thirsty, OfferTrigger.outOfManna);
      offers.bought(_thirsty);
      expect(next(OfferTrigger.outOfManna), isNull);
      now = now.add(const Duration(days: 8));
      expect(next(OfferTrigger.outOfManna)?.id, 'thirsty');
    });

    test('offers are read again once they are old, and a reloaded game '
        'carries on the session\'s count', () async {
      final source = FakeOffersSource([_thirsty]);
      final first = OffersController(
        source: source,
        rules: const OfferRules(),
        extras: extras,
        clock: () => now,
      );
      await first.refreshIfStale();
      await first.refreshIfStale();
      expect(source.fetches, 1);
      now = now.add(const Duration(minutes: 11));
      await first.refreshIfStale();
      expect(source.fetches, 2);

      first
        ..shown(_thirsty, OfferTrigger.outOfManna)
        ..shown(_thirsty, OfferTrigger.outOfManna)
        ..shown(_thirsty, OfferTrigger.outOfManna);
      final second = OffersController(
        source: source,
        rules: const OfferRules(),
        extras: extras,
        carryOn: first,
        clock: () => now,
      );
      await second.load();
      expect(
        second.next(OfferTrigger.outOfManna, level: 5, hasPaid: false),
        isNull,
      );
    });
  });
}
