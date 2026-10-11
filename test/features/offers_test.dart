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
import 'package:whispers_of_joppa/features/shop/purchases_controller.dart';

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
const _text = {
  'offer_subtitle': 'A special offer',
  'offer_ends_in': 'Ends in {time}',
  'offer_no_thanks': 'No thanks',
  'offer_close': 'Close',
};

void main() {
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
