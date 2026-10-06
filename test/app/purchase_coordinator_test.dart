import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/features/shop/purchases_controller.dart';
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
        applyRefunds: wallet.applyRefunds,
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
}
