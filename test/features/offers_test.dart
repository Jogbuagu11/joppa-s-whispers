import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/data/offers_validator.dart';
import 'package:whispers_of_joppa/domain/offers.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/features/offers/offer_parts.dart';
import 'package:whispers_of_joppa/features/offers/offer_popup.dart';
import 'package:whispers_of_joppa/features/offers/offers_controller.dart';
import 'package:whispers_of_joppa/features/shop/purchases_controller.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

import '../support/offer_fakes.dart';
import '../support/store_fakes.dart';

Object? _read(String name) =>
    jsonDecode(File('content/$name.json').readAsStringSync());

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
const _text = {
  'offer_subtitle': 'A special offer',
  'offer_ends_in': 'Ends in {time}',
  'offer_no_thanks': 'No thanks',
  'offer_close': 'Close',
};

void main() {
  group('the offers controller', () {
    var now = DateTime.utc(2026, 10, 12, 9);
    late SaveExtras extras;
    late List<String> notes;
    late OffersController offers;

    Future<OffersController> make() async {
      final controller = OffersController(
        source: FakeOffersSource([_welcome, _more, _thirsty]),
        rules: const OfferRules(),
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

    test('one offer at the start, a day; turned down, its next comes the '
        'day after', () async {
      expect(next(OfferTrigger.sessionStart)?.id, 'welcome');
      final ends = offers.shown(_welcome, OfferTrigger.sessionStart);
      expect(ends, now.add(const Duration(hours: 2)));
      expect(next(OfferTrigger.sessionStart), isNull);
      offers.declined(_welcome);
      expect(notes, ['welcome:shown', 'welcome:dismissed']);

      // The game closed and opened again the same day: still none.
      offers = await make();
      expect(next(OfferTrigger.sessionStart), isNull);
      // The next day: the bigger one.
      now = now.add(const Duration(days: 1));
      offers = await make();
      expect(next(OfferTrigger.sessionStart)?.id, 'welcome_more');
    });

    test('at most three offers in one session', () {
      offers.shown(_welcome, OfferTrigger.sessionStart);
      expect(next(OfferTrigger.outOfManna)?.id, 'thirsty');
      offers.shown(_thirsty, OfferTrigger.outOfManna);
      expect(next(OfferTrigger.outOfManna)?.id, 'thirsty');
      offers.shown(_thirsty, OfferTrigger.outOfManna);
      expect(next(OfferTrigger.outOfManna), isNull);
    });

    test('a level-up offer only at every fifth level', () async {
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
      expect(next(OfferTrigger.levelUp, level: 7), isNull);
      expect(next(OfferTrigger.levelUp, level: 10)?.id, 'grown');
    });
  });

  group('the offer pop-up', () {
    late FakeStore store;
    late FakePurchaseBackend backend;
    late PurchasesController wallet;
    late PurchaseCoordinator shop;
    final products = offerProductsFrom({
      'offer_products': ['offer_099'],
    });

    setUp(() {
      store = FakeStore();
      backend = FakePurchaseBackend();
      wallet = PurchasesController(
        products: products,
        addManna: (_) {},
        raiseGenerators: (_) {},
      );
      shop =
          PurchaseCoordinator(
              store: store,
              backend: backend,
              products: products,
            )
            ..target = PurchaseTarget(
              applyConfirmed: wallet.applyConfirmed,
              hasApplied: wallet.hasApplied,
              applyRefunds: wallet.applyRefunds,
              saveNow: () async {},
            )
            ..start();
    });
    tearDown(() => shop.dispose());

    Future<bool?> open(
      WidgetTester tester, {
      DateTime Function()? clock,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      bool? result;
      final start = DateTime.utc(2026, 10, 12, 9);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showOfferPopup(
                context,
                offer: _welcome,
                price: r'$0.99',
                endsAt: start.add(const Duration(hours: 2)),
                shop: shop,
                text: _text,
                picture: 'assets/ui/board_header.jpg',
                gifts: const [
                  OfferGift(
                    words: '40 Pearls',
                    icon: Icons.circle,
                    color: Colors.white,
                  ),
                  OfferGift(
                    words: '50 Manna',
                    icon: Icons.bolt,
                    color: Colors.amber,
                  ),
                ],
                clock: clock ?? () => start,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      _result = () => result;
      return result;
    }

    testWidgets('says exactly what it gives, the store\'s price, the time '
        'left, and can be turned down', (tester) async {
      await open(tester);
      expect(find.text('Welcome gift'), findsOneWidget);
      expect(find.text('40 Pearls'), findsOneWidget);
      expect(find.text('50 Manna'), findsOneWidget);
      expect(find.text(r'$0.99'), findsOneWidget);
      expect(find.text('Ends in 2:00:00'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('offer_no_thanks')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('offer_popup')), findsNothing);
      expect(_result(), isFalse);
      expect(backend.verified, isEmpty);
    });

    testWidgets('buying sends the offer to the server, gives what the server '
        'recorded, and says so', (tester) async {
      backend.offerGrants['welcome'] = const PurchaseGrant(pearls: 40);
      await open(tester);
      await tester.tap(find.byKey(const Key('offer_buy')));
      // The stand-in store and server were made outside the test's fake
      // clock, so their work happens in real time: give it a moment.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(backend.offerIds, ['welcome']);
      expect(wallet.pearls, 40);
      expect(find.byKey(const Key('offer_message')), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      await tester.tap(find.byKey(const Key('offer_no_thanks')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_result(), isTrue);
    });

    testWidgets('closes by itself when its time runs out', (tester) async {
      var now = DateTime.utc(2026, 10, 12, 9);
      await open(tester, clock: () => now);
      now = now.add(const Duration(hours: 2, seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('offer_popup')), findsNothing);
      expect(_result(), isFalse);
    });
  });

  test('time left reads naturally', () {
    expect(
      formatTimeLeft(const Duration(hours: 2, minutes: 5, seconds: 9)),
      '2:05:09',
    );
    expect(formatTimeLeft(const Duration(minutes: 9, seconds: 3)), '9:03');
    expect(formatTimeLeft(Duration.zero), '0:00');
    expect(formatTimeLeft(const Duration(seconds: -4)), '0:00');
  });

  test('the checker reports a bad offer set-up', () {
    final offers = _read('offers') as Map<String, dynamic>;
    List<String> check(void Function(Map<String, dynamic> offers) change) {
      final copy = jsonDecode(jsonEncode(offers)) as Map<String, dynamic>;
      change(copy);
      return offersProblems(
        copy,
        chainsJson: _read('chains'),
        productsJson: _read('products'),
      );
    }

    expect(check((o) {}), isEmpty);
    expect(check((o) => o.remove('offer_products')), isNotEmpty);
    expect(check((o) => o['offer_products'] = ['pearls_tier1']), isNotEmpty);
    expect(
      check((o) => o['offer_products'] = ['offer_099', 'offer_099']),
      isNotEmpty,
    );
    expect(check((o) => o.remove('rules')), isNotEmpty);
    expect(
      check((o) => (o['rules'] as Map<String, dynamic>)['level_every'] = -1),
      isNotEmpty,
    );
    expect(
      check((o) => (o['text'] as Map<String, dynamic>).remove('offer_ends_in')),
      isNotEmpty,
    );
  });
}

bool? Function() _result = () => null;
