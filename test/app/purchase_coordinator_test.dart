import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/features/shop/purchases_controller.dart';
import 'package:whispers_of_joppa/services/purchase_backend.dart';
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
            saveNow: () async => saves++,
          )
          ..start();
  });
  tearDown(() => shop.dispose());

  test(
    'a confirmed purchase grants once, then tells the store it is finished',
    () async {
      await shop.buy('pearls_tier1');
      await settle();
      expect(backend.verified, ['tx1']);
      expect(wallet.pearls, 50);
      expect(store.finished, ['tx1']);
      expect(store.finishedAsConsumable, [true]);
      expect(shop.message.value, contains('50 Pearls'));
      expect(shop.busy.value, isFalse);
    },
  );

  test('the store reporting the same purchase twice grants once', () async {
    final tx = store.emit('pearls_tier1');
    store.emit('pearls_tier1', transactionId: tx);
    await settle();
    expect(wallet.pearls, 50);
    // The second report is recognised without asking the server again.
    expect(backend.verified, [tx]);
  });

  test(
    'the purchase carries the signed-in player\'s id to the store',
    () async {
      await shop.buy('pearls_tier1');
      await settle();
      expect(store.accountIds, ['player-1']);
    },
  );

  test(
    'the game is saved before the store is told the purchase is finished',
    () async {
      final order = <String>[];
      shop.target = PurchaseTarget(
        applyConfirmed: wallet.applyConfirmed,
        hasApplied: wallet.hasApplied,
        saveNow: () async {
          // At this moment the store must not have been told yet.
          order.add('saved with ${store.finished.length} finished');
        },
      );
      await shop.buy('pearls_tier1');
      await settle();
      expect(order, ['saved with 0 finished']);
      expect(store.finished.length, 1);
    },
  );

  test(
    'a purchase the store re-sends by itself is delivered without a message',
    () async {
      // Not started by tapping Buy in this run (an interrupted purchase).
      store.emit('pearls_tier1');
      await settle();
      expect(wallet.pearls, 50);
      expect(shop.message.value, isNull);
    },
  );

  test(
    'an undelivered purchase is retried on resume even if the store stays quiet',
    () async {
      // On iPhone the store reports an unfinished purchase only once per launch.
      backend.answer = VerifyResult.unavailable;
      await shop.buy('pearls_tier1');
      await settle();
      expect(wallet.pearls, 0);
      store.unfinished.clear(); // the store will not send it again
      backend.answer = VerifyResult.confirmed;
      await shop.resume();
      await settle();
      expect(wallet.pearls, 50);
      expect(store.finished, ['tx1']);
    },
  );

  test(
    'a store that fails to finish does not undo the grant or block the shop',
    () async {
      store.throwOnFinish = true;
      await shop.buy('pearls_tier1');
      await settle();
      expect(wallet.pearls, 50);
      expect(shop.message.value, contains('50 Pearls'));
      expect(shop.busy.value, isFalse);
    },
  );

  test(
    'purchases wait while no game is attached and are delivered once one is',
    () async {
      final game = shop.target;
      shop.detach();
      store.emit('pearls_tier1');
      await settle();
      expect(wallet.pearls, 0);
      expect(backend.verified, isEmpty);
      shop.target = game;
      await shop.resume();
      await settle();
      expect(wallet.pearls, 50);
    },
  );

  test('Restore purchases says what came back, or that nothing did', () async {
    await shop.restore();
    expect(shop.message.value, 'Nothing new to restore.');
    backend.recorded.add(
      const PurchaseRecord(
        transactionId: 'old',
        productId: 'starter_pack',
        granted: true,
      ),
    );
    await shop.restore();
    expect(shop.message.value, contains('restored'));
    expect(wallet.pearls, 100);
  });

  test('a rejected purchase grants nothing and is left unfinished', () async {
    backend.answer = VerifyResult.rejected;
    await shop.buy('pearls_tier1');
    await settle();
    expect(wallet.pearls, 0);
    expect(store.finished, isEmpty);
    expect(shop.message.value, "Purchase couldn't be verified.");
  });

  test(
    'the store saying "purchased" is never enough without the server',
    () async {
      backend.answer = VerifyResult.unavailable;
      await shop.buy('pearls_tier1');
      await settle();
      expect(wallet.pearls, 0);
      expect(store.finished, isEmpty);
      expect(shop.message.value, contains('delivered automatically'));
    },
  );

  test(
    'a purchase interrupted before delivery is delivered on the next launch',
    () async {
      // The server could not be reached, so the purchase stays unfinished...
      backend.answer = VerifyResult.unavailable;
      await shop.buy('pearls_tier1');
      await settle();
      expect(wallet.pearls, 0);
      // ...and when the app next starts, the store reports it again.
      backend.answer = VerifyResult.confirmed;
      await shop.restore();
      await settle();
      expect(wallet.pearls, 50);
      expect(store.finished, ['tx1']);
    },
  );

  test(
    'resume quietly delivers an unfinished purchase without a restore prompt',
    () async {
      backend.answer = VerifyResult.unavailable;
      await shop.buy('pearls_tier1');
      await settle();
      backend.answer = VerifyResult.confirmed;
      await shop.resume();
      await settle();
      expect(wallet.pearls, 50);
      expect(store.quietChecks, 1);
      // The player was never sent through the store's restore flow.
      expect(store.restores, 0);
    },
  );

  test(
    'a purchase confirmed by the server but not yet in the game is delivered',
    () async {
      // The app died after the server recorded it and before it was granted.
      backend.recorded.add(
        const PurchaseRecord(
          transactionId: 'old',
          productId: 'pearls_tier1',
          granted: true,
        ),
      );
      final added = await shop.deliverConfirmed();
      expect(added.pearls, 50);
      expect(wallet.pearls, 50);
      expect((await shop.deliverConfirmed()).isEmpty, isTrue);
      expect(wallet.pearls, 50);
    },
  );

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
}
