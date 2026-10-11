// The Treasure Jar in play: it fills, says it is full, and is opened only
// by a purchase the server confirmed. Uses a stand-in store and server.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/domain/treasure_jar.dart';
import 'package:whispers_of_joppa/features/shop/purchases_controller.dart';
import 'package:whispers_of_joppa/features/shop/treasure_jar_controller.dart';
import 'package:whispers_of_joppa/features/shop/treasure_jar_popup.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

import '../support/store_fakes.dart';

const _offers = <String, dynamic>{
  'treasure_jar': {
    'sizes': [
      {'id': 'small', 'product_id': 'treasure_jar_small', 'pearls': 10},
      {'id': 'large', 'product_id': 'treasure_jar_large', 'pearls': 30},
    ],
    'earn': {'order': 4, 'task': 6, 'level': 5},
  },
};
const _text = {
  'title': 'Treasure Jar',
  'count': '{saved} of {pearls} Pearls',
  'open': 'Open for {price}',
  'not_full': 'Keep playing to fill it',
  'filling': 'It fills as you play.',
  'full': 'Your jar is full!',
  'next': 'The next is bigger.',
  'close': 'Later',
  'sign_in': 'Sign in to open your jar.',
  'unavailable': 'The market is closed.',
};

void main() {
  final rules =
      TreasureJarRules.fromJson(_offers['treasure_jar']) ?? fail('no rules');
  final products = treasureJarProductsFrom(_offers);
  late SaveExtras extras;
  late TreasureJarController jar;
  late FakeStore store;
  late FakePurchaseBackend backend;
  late PurchasesController wallet;
  late PurchaseCoordinator shop;

  setUp(() {
    extras = SaveExtras();
    jar = TreasureJarController(rules: rules, extras: extras, level: 7);
    store = FakeStore();
    backend = FakePurchaseBackend();
    wallet = PurchasesController(
      products: products,
      announced: products.keys.toSet(),
      addManna: (_) {},
      raiseGenerators: (_) {},
    );
    shop =
        PurchaseCoordinator(store: store, backend: backend, products: products)
          ..target = PurchaseTarget(
            applyConfirmed: wallet.applyConfirmed,
            hasApplied: wallet.hasApplied,
            applyRefunds: wallet.applyRefunds,
            saveNow: () async {},
          )
          ..start();
  });
  tearDown(() {
    shop.dispose();
    extras.dispose();
  });

  test('orders, tasks and levels fill the jar; it says so once when full', () {
    jar.orderDelivered();
    expect(jar.state.saved, 4);
    jar.taskDone();
    expect(jar.state.saved, 10);
    expect(jar.isFull, isTrue);
    expect(jar.newlyFull, isTrue);
    jar.toldFull();
    expect(jar.newlyFull, isFalse);
    // A full jar takes no more, and is not written again.
    var writes = 0;
    extras.addListener(() => writes++);
    jar.orderDelivered();
    jar.toldFull();
    expect(jar.state.saved, 10);
    expect(writes, 0);
  });

  test('each level won saves its Pearls, once', () {
    jar.levelIs(7);
    expect(jar.state.saved, 0);
    jar.levelIs(8);
    expect(jar.state.saved, 5);
    jar.levelIs(8);
    jar.levelIs(6);
    expect(jar.state.saved, 5);
    // Two levels at once.
    final big = TreasureJarController(
      rules: rules,
      extras: SaveExtras({
        treasureJarRecord: const TreasureJarState(opened: 1).toJson(),
      }),
      level: 7,
    )..levelIs(9);
    expect(big.state.saved, 10);
  });

  test('only a confirmed jar purchase empties the jar, and the next is '
      'bigger', () {
    jar
      ..orderDelivered()
      ..taskDone()
      ..toldFull()
      ..purchasesApplied(const [
        PurchaseRecord(
          transactionId: 'a',
          productId: 'offer_099',
          granted: true,
        ),
      ]);
    expect(jar.isFull, isTrue);
    jar.purchasesApplied(const [
      PurchaseRecord(
        transactionId: 'b',
        productId: 'treasure_jar_small',
        granted: true,
      ),
    ]);
    expect(jar.state.saved, 0);
    expect(jar.state.opened, 1);
    expect(jar.size.id, 'large');
    expect(jar.newlyFull, isFalse);
  });

  test('a jar purchase is not put into the game until the jar is there to '
      'be emptied; then it is, whole', () {
    const record = PurchaseRecord(
      transactionId: 'jar1',
      productId: 'treasure_jar_small',
      granted: true,
      grant: PurchaseGrant(pearls: 10),
    );
    expect(wallet.applyConfirmed([record]).isEmpty, isTrue);
    expect(wallet.pearls, 0);
    expect(wallet.hasApplied('jar1'), isFalse);
    wallet.onApplied = jar.purchasesApplied;
    expect(wallet.applyConfirmed([record]).pearls, 10);
    expect(jar.state.opened, 1);
    // Reading the server again changes nothing.
    expect(wallet.applyConfirmed([record]).isEmpty, isTrue);
    expect(jar.state.opened, 1);
  });

  group('the pop-up', () {
    Future<void> open(WidgetTester tester, {String? price = r'$2.99'}) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTreasureJar(
                context,
                rules: rules,
                state: () => jar.state,
                changes: extras,
                text: _text,
                shop: shop,
                price: price,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    FilledButton button(WidgetTester tester) =>
        tester.widget(find.byKey(const Key('treasure_jar_open')));

    testWidgets('a jar still filling cannot be opened', (tester) async {
      jar.orderDelivered();
      await open(tester);
      expect(find.text('4 of 10 Pearls'), findsOneWidget);
      expect(find.text('Keep playing to fill it'), findsOneWidget);
      expect(button(tester).onPressed, isNull);
      await tester.tap(find.byKey(const Key('treasure_jar_close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('treasure_jar_popup')), findsNothing);
      expect(store.accountIds, isEmpty);
    });

    testWidgets('a full jar is opened at the store\'s price; the Pearls '
        'come from the server\'s record and the jar is left empty and '
        'bigger', (tester) async {
      wallet.onApplied = jar.purchasesApplied;
      backend.offerGrants[null] = const PurchaseGrant(pearls: 10);
      jar
        ..orderDelivered()
        ..taskDone();
      await open(tester);
      expect(find.text(r'Open for $2.99'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('treasure_jar_open')));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      await tester.pump();
      expect(wallet.pearls, 10);
      expect(store.finishedAsConsumable, [true]);
      expect(find.text('0 of 30 Pearls'), findsOneWidget);
      expect(button(tester).onPressed, isNull);
    });

    testWidgets('signed out, or with no price from the store, it says why '
        'and cannot be opened', (tester) async {
      jar
        ..orderDelivered()
        ..taskDone();
      await open(tester, price: null);
      expect(find.text('The market is closed.'), findsOneWidget);
      expect(button(tester).onPressed, isNull);
      await tester.tap(find.byKey(const Key('treasure_jar_close')));
      await tester.pumpAndSettle();
      backend.signedIn = false;
      await open(tester);
      expect(find.text('Sign in to open your jar.'), findsOneWidget);
      expect(button(tester).onPressed, isNull);
    });
  });
}
