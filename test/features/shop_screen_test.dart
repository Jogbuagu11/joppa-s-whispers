import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/features/shop/purchases_controller.dart';
import 'package:whispers_of_joppa/features/shop/shop_screen.dart';
import 'package:whispers_of_joppa/services/purchase_backend.dart';

import '../support/store_fakes.dart';

const _products = {
  'pearls_tier1': ProductModel(
    id: 'pearls_tier1',
    consumable: true,
    pearls: 50,
  ),
  'starter_pack': ProductModel(
    id: 'starter_pack',
    consumable: false,
    pearls: 100,
    manna: 100,
    generatorLevel: 2,
  ),
};

void main() {
  late FakeStore store;
  late FakePurchaseBackend backend;
  late PurchasesController wallet;
  late PurchaseCoordinator shop;
  var saves = 0;

  setUp(() {
    store = FakeStore();
    backend = FakePurchaseBackend();
    wallet = PurchasesController(
      products: _products,
      addManna: (_) {},
      raiseGenerators: (_) {},
    );
    shop =
        PurchaseCoordinator(store: store, backend: backend, products: _products)
          ..target = PurchaseTarget(
            applyConfirmed: wallet.applyConfirmed,
            hasApplied: wallet.hasApplied,
            applyRefunds: wallet.applyRefunds,
            saveNow: () async => saves++,
          )
          ..start();
  });

  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ShopScreen(shop: shop, purchases: wallet),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The stand-in store and server were created outside the test's fake
  /// clock, so their work happens in real time: give it a moment.
  Future<void> letStoreRun(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> buy(WidgetTester tester, String productId) async {
    await tester.ensureVisible(find.byKey(Key('shop_buy_$productId')));
    await tester.tap(find.byKey(Key('shop_buy_$productId')));
    await letStoreRun(tester);
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data ?? '';

  testWidgets('lists each product with what it gives and the store price', (
    tester,
  ) async {
    await show(tester);
    expect(tester.takeException(), isNull);
    expect(text(tester, 'shop_pearls'), 'You have 0 Pearls');
    expect(find.text('50 Pearls'), findsOneWidget);
    expect(
      find.text('100 Pearls + 100 Manna + a level-2 generator'),
      findsOneWidget,
    );
    // The price shown is the store's.
    expect(find.text(r'$0.99'), findsNWidgets(2));
  });

  testWidgets('buying adds the Pearls and says so', (tester) async {
    await show(tester);
    await buy(tester, 'pearls_tier1');
    expect(text(tester, 'shop_pearls'), 'You have 50 Pearls');
    expect(text(tester, 'shop_message'), contains('50 Pearls'));
  });

  testWidgets(
    'the starter pack shows as owned after buying and cannot be bought again',
    (tester) async {
      await show(tester);
      await buy(tester, 'starter_pack');
      expect(find.text('Owned'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('shop_buy_starter_pack')),
      );
      expect(button.onPressed, isNull);
      expect(wallet.pearls, 100);
    },
  );

  testWidgets('a purchase the server rejects adds nothing and says so', (
    tester,
  ) async {
    backend.answer = VerifyResult.rejected;
    await show(tester);
    await buy(tester, 'pearls_tier1');
    expect(text(tester, 'shop_pearls'), 'You have 0 Pearls');
    expect(text(tester, 'shop_message'), "Purchase couldn't be verified.");
  });

  testWidgets('signed out: asked to sign in, nothing bought', (tester) async {
    backend.signedIn = false;
    await show(tester);
    await buy(tester, 'pearls_tier1');
    expect(text(tester, 'shop_message'), contains('Sign in first'));
    expect(wallet.pearls, 0);
  });

  testWidgets('says so when the store is not available', (tester) async {
    store.available = false;
    await show(tester);
    expect(find.byKey(const Key('shop_unavailable')), findsOneWidget);
  });

  testWidgets('restore delivers a purchase the server already holds', (
    tester,
  ) async {
    backend.recorded.add(
      const PurchaseRecord(
        transactionId: 'old',
        productId: 'starter_pack',
        granted: true,
      ),
    );
    await show(tester);
    await tester.tap(find.byKey(const Key('shop_restore')));
    await letStoreRun(tester);
    expect(text(tester, 'shop_pearls'), 'You have 100 Pearls');
    expect(store.restores, 1);
  });
}
