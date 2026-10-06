import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/features/shop/purchases_controller.dart';
import 'package:whispers_of_joppa/services/store_service.dart';

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

  /// Lets the store's report travel through the coordinator.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

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
  tearDown(() => shop.dispose());

  test('a receipt recorded for a different player grants nothing', () async {
    backend.recordForSomeoneElse = true;
    await shop.buy('pearls_tier1');
    await settle();
    expect(wallet.pearls, 0);
    expect(store.finished, isEmpty);
    expect(shop.message.value, "Purchase couldn't be verified.");
  });

  test(
    'cancelling at the payment sheet grants nothing and shows no error',
    () async {
      store.nextStatus = StorePurchaseStatus.canceled;
      await shop.buy('pearls_tier1');
      await settle();
      expect(wallet.pearls, 0);
      expect(backend.verified, isEmpty);
      expect(shop.message.value, isNull);
    },
  );

  test('a failed or pending payment grants nothing', () async {
    store.nextStatus = StorePurchaseStatus.failed;
    await shop.buy('pearls_tier1');
    await settle();
    expect(wallet.pearls, 0);
    expect(shop.message.value, contains('not charged'));

    store.nextStatus = StorePurchaseStatus.pending;
    await shop.buy('pearls_tier1');
    await settle();
    expect(wallet.pearls, 0);
    expect(backend.verified, isEmpty);
  });

  test(
    'buying needs an account, and the payment sheet is not opened without one',
    () async {
      backend.signedIn = false;
      await shop.buy('pearls_tier1');
      await settle();
      expect(shop.message.value, contains('Sign in first'));
      expect(backend.verified, isEmpty);
      expect(wallet.pearls, 0);
    },
  );

  test('a purchase arriving while signed out is kept for later', () async {
    backend.signedIn = false;
    store.emit('pearls_tier1');
    await settle();
    expect(wallet.pearls, 0);
    expect(store.finished, isEmpty);
    backend.signedIn = true;
    await shop.restore();
    await settle();
    expect(wallet.pearls, 50);
  });

  test(
    'if the purchase list cannot be read after verifying, nothing is finished',
    () async {
      backend.listOffline = true;
      await shop.buy('pearls_tier1');
      await settle();
      expect(wallet.pearls, 0);
      expect(store.finished, isEmpty);
      backend.listOffline = false;
      await shop.deliverConfirmed();
      expect(wallet.pearls, 50);
    },
  );

  test(
    'the starter pack is granted and finished as a one-time product',
    () async {
      await shop.buy('starter_pack');
      await settle();
      expect(wallet.pearls, 100);
      expect(wallet.canBuyProduct('starter_pack'), isFalse);
      expect(store.finishedAsConsumable, [false]);
    },
  );

  test('a store that cannot open reports it without crashing', () async {
    store.throwOnBuy = true;
    await shop.buy('pearls_tier1');
    expect(shop.message.value, contains('could not be opened'));
  });

  test(
    'products come from the store with its own prices; none if unavailable',
    () async {
      final listed = await shop.loadProducts();
      expect({for (final p in listed) p.id}, _products.keys.toSet());
      expect(listed.first.price, isNotEmpty);
      store.available = false;
      expect(await shop.loadProducts(), isEmpty);
    },
  );

  test('a refund is taken back the next time the server is checked', () async {
    await shop.buy('pearls_tier1');
    await settle();
    expect(wallet.pearls, 50);
    final savesBefore = saves;
    backend.refund('tx1');
    await shop.resume();
    expect(wallet.pearls, 0);
    expect(saves, savesBefore + 1);
    // Checking again takes nothing more and does not save again.
    await shop.resume();
    expect(wallet.pearls, 0);
    expect(saves, savesBefore + 1);
  });

  test('a refund never takes Pearls from other purchases twice', () async {
    await shop.buy('pearls_tier1');
    await settle();
    await shop.buy('pearls_tier1');
    await settle();
    backend.refund('tx1');
    await shop.deliverConfirmed();
    await shop.deliverConfirmed();
    expect(wallet.pearls, 50);
  });

  test('signing in on a new phone restores the starter pack', () async {
    backend.recorded.add(
      const PurchaseRecord(
        transactionId: 'old',
        productId: 'starter_pack',
        granted: true,
      ),
    );
    await shop.resume();
    expect(wallet.pearls, 100);
    expect(wallet.canBuyProduct('starter_pack'), isFalse);
  });
}
